param(
    [ValidateSet('Reset', 'RestartHomebridge')]
    [string]$Action = 'Reset'
)

# One invocation: any failed guard prevents the later Homebridge start.
& {
    $ErrorActionPreference = 'Stop'
    Set-StrictMode -Version Latest
    $labModule = Join-Path $PSScriptRoot 'lab.mjs'
    $fixturePath = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot 'fixtures/myzone.json')).Path
    $fixture = Get-Content -LiteralPath $fixturePath -Raw | ConvertFrom-Json
    $baseUrl = 'http://127.0.0.1:52025'

    function Invoke-Lab([string]$Component, [string]$Operation) {
        # Same CLI as lab.cmd; using Node directly also makes exit handling explicit.
        $output = @(& node $labModule $Component $Operation)
        if ($LASTEXITCODE -ne 0) {
            throw "Lab command failed: $Component $Operation. Homebridge will not be started by later steps."
        }
        foreach ($line in $output) { Write-Host $line }
        return ($output -join "`n")
    }

    function Get-SimulatorPid {
        $status = Invoke-Lab 'simulator' 'status'
        if ($status -notmatch '(?m)^simulator: running \(PID ([0-9]+)\)\r?$') {
            throw 'The managed simulator is not running. No HTTP request or Homebridge start is permitted.'
        }
        return $Matches[1]
    }

    function Assert-SimulatorPid([string]$Expected) {
        if ((Get-SimulatorPid) -ne $Expected) {
            throw 'The simulator process changed. Its previous memory cannot be assumed to survive.'
        }
    }

    function Get-ScenarioState([bool]$RequireInitial) {
        $data = Invoke-RestMethod -Uri ($baseUrl + '/getSystemData') -TimeoutSec 5
        if ($data.system.mid -cne $fixture.system.mid -or @($data.aircons.PSObject.Properties).Count -ne 1) {
            throw 'Unexpected controller identity or aircon count.'
        }
        $ac = $data.aircons.ac1
        $zoneKeys = @($ac.zones.PSObject.Properties.Name | Sort-Object)
        if ($ac.info.uid -cne $fixture.aircons.ac1.info.uid -or ($zoneKeys -join ',') -cne 'z01,z02,z06' -or
            $ac.zones.z01.number -ne 1 -or $ac.zones.z02.number -ne 7 -or
            $ac.zones.z01.type -ne 1 -or $ac.zones.z02.type -ne 1 -or $ac.zones.z06.type -ne 0 -or
            $ac.info.myZone -notin @(1, 7)) {
            throw 'The expected three-zone MyZone scenario is not active.'
        }
        if ($RequireInitial -and ($ac.info.myZone -ne 1 -or $ac.info.setTemp -ne 24 -or $ac.zones.z02.state -cne 'close')) {
            throw 'The reset fixture did not provide its expected initial MyZone state.'
        }
        # Compare control state, not transient timestamps or sensor telemetry.
        $zones = @($zoneKeys | ForEach-Object {
            $zone = $ac.zones.$_
            [ordered]@{ key = $_; number = $zone.number; type = $zone.type; state = $zone.state; target = $zone.setTemp; value = $zone.value }
        })
        return ([ordered]@{
            controller = $data.system.mid; aircon = $ac.info.uid
            myZone = $ac.info.myZone; target = $ac.info.setTemp
            power = $ac.info.state; mode = $ac.info.mode; fan = $ac.info.fan; zones = $zones
        } | ConvertTo-Json -Depth 8 -Compress)
    }

    if ($Action -eq 'Reset') {
        $null = Invoke-Lab 'homebridge' 'stop'
        $null = Invoke-Lab 'simulator' 'start'
        $simulatorPid = Get-SimulatorPid
        Invoke-WebRequest -Uri ($baseUrl + '/reInit') -UseBasicParsing -TimeoutSec 5 | Out-Null
        $loadUrl = $baseUrl + '/?load=' + [uri]::EscapeDataString($fixturePath)
        Invoke-WebRequest -Uri $loadUrl -UseBasicParsing -TimeoutSec 5 | Out-Null
        $before = Get-ScenarioState $true
        if ((Get-ScenarioState $true) -cne $before) {
            throw 'Consecutive scenario reads differ. Homebridge remains stopped.'
        }
        Assert-SimulatorPid $simulatorPid
        $null = Invoke-Lab 'homebridge' 'start'
        Assert-SimulatorPid $simulatorPid
        Write-Host 'PASS: reset, load and consecutive MyZone reads verified before Homebridge startup.'
    } else {
        # Never start or reset the simulator in a persistence test.
        $simulatorPid = Get-SimulatorPid
        $null = Invoke-Lab 'homebridge' 'stop'
        Assert-SimulatorPid $simulatorPid
        $before = Get-ScenarioState $false
        if ((Get-ScenarioState $false) -cne $before) {
            throw 'The scenario is changing. Wait for confirmed commands before testing persistence.'
        }
        Assert-SimulatorPid $simulatorPid
        $null = Invoke-Lab 'homebridge' 'start'
        Assert-SimulatorPid $simulatorPid
        if ((Get-ScenarioState $false) -cne $before) {
            throw 'Control state changed across the Homebridge-only restart; persistence test failed.'
        }
        Write-Host 'PASS: Homebridge-only restart retained the same simulator process and control state.'
    }
}
