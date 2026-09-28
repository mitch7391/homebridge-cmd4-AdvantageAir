# Executes the exact operator script with fake CLI/HTTP boundaries. No lab is started.
& {
    $ErrorActionPreference = 'Stop'
    Set-StrictMode -Version Latest
    $operator = Join-Path $PSScriptRoot '../../dev/lab/myzone.ps1'
    $fixtureText = Get-Content -LiteralPath (Join-Path $PSScriptRoot '../../dev/lab/fixtures/myzone.json') -Raw
    $caseContext = @{ passed = 0 }

    function node([string]$Module, [string]$Component, [string]$Operation) {
        if ([IO.Path]::GetFileName($Module) -cne 'lab.mjs') { throw 'Unexpected CLI target.' }
        $caseContext.calls.Add("$Component $Operation")
        $global:LASTEXITCODE = 0
        if ($caseContext.fault -eq "$Component $Operation") {
            $global:LASTEXITCODE = 1
            return 'simulated command failure'
        }
        if ($Component -eq 'simulator' -and $Operation -eq 'start') { $caseContext.running = $true }
        if ($Component -eq 'homebridge' -and $Operation -eq 'stop' -and $caseContext.fault -eq 'disappears') {
            $caseContext.running = $false
        }
        if ($Component -eq 'homebridge' -and $Operation -eq 'start' -and $caseContext.fault -eq 'changes-after-start') {
            $caseContext.simulatorPid = 456
        }
        if ($Component -eq 'simulator' -and $Operation -eq 'status') {
            if ($caseContext.fault -eq 'starting') { return 'simulator: starting (PID 123)' }
            if ($caseContext.running) { return "simulator: running (PID $($caseContext.simulatorPid))" }
            return 'simulator: stopped'
        }
        return "$Component`: $Operation complete"
    }

    function Invoke-WebRequest([string]$Uri, [switch]$UseBasicParsing, [int]$TimeoutSec) {
        if (-not $UseBasicParsing -or $TimeoutSec -ne 5) { throw 'Missing HTTP bounds.' }
        $url = [uri]$Uri
        $action = if ($url.AbsolutePath -eq '/reInit') { 'reset' } else { 'load' }
        $caseContext.calls.Add("http $action")
        if (-not $caseContext.running -or $caseContext.fault -eq $action) { throw "HTTP $action failed" }
        if ($action -eq 'load') { $caseContext.scenario = $fixtureText | ConvertFrom-Json }
        return [pscustomobject]@{ StatusCode = 200 }
    }

    function Invoke-RestMethod([string]$Uri, [int]$TimeoutSec) {
        if ($Uri -cne 'http://127.0.0.1:52025/getSystemData' -or $TimeoutSec -ne 5) { throw 'Unexpected read.' }
        $caseContext.calls.Add('http read')
        $caseContext.reads++
        if (-not $caseContext.running -or $caseContext.fault -eq 'unreachable') { throw 'Simulator unreachable.' }
        $data = $caseContext.scenario | ConvertTo-Json -Depth 30 | ConvertFrom-Json
        switch ($caseContext.fault) {
            'wrong-controller' { $data.system.mid = 'wrong' }
            'wrong-aircon' { $data.aircons.ac1.info.uid = 'wrong' }
            'wrong-count' { $data.aircons.ac1.zones.PSObject.Properties.Remove('z06') }
            'wrong-selection' { $data.aircons.ac1.info.myZone = 0 }
            'wrong-number' { $data.aircons.ac1.zones.z02.number = 2 }
            'unstable' { if ($caseContext.reads -eq 2) { $data.aircons.ac1.zones.z06.value = 55 } }
        }
        return $data
    }

    function Run-Case([string]$Fault, [string]$Action, [bool]$ExpectFailure, [bool]$InitiallyRunning = $true) {
        $caseContext.fault = $Fault
        $caseContext.running = $InitiallyRunning
        $caseContext.simulatorPid = 123
        $caseContext.reads = 0
        $caseContext.calls = [Collections.Generic.List[string]]::new()
        $caseContext.scenario = $fixtureText | ConvertFrom-Json
        $caught = $false
        $failureReason = ''
        try { & $operator -Action $Action } catch { $caught = $true; $failureReason = $_.Exception.Message }
        if ($caught -ne $ExpectFailure) { throw "Unexpected result: $Action / $Fault : $failureReason" }
        if ($ExpectFailure -and $Fault -notin @('changes-after-start', 'homebridge start') -and
            $caseContext.calls.Contains('homebridge start')) { throw "Unsafe Homebridge start: $Fault" }
        if ($Action -eq 'RestartHomebridge' -and ($caseContext.calls.Contains('simulator start') -or
            $caseContext.calls.Contains('http reset') -or $caseContext.calls.Contains('http load'))) {
            throw 'Persistence test mutated simulator lifecycle.'
        }
        if (-not $ExpectFailure -and $Action -eq 'Reset') {
            $expected = 'homebridge stop,simulator start,simulator status,http reset,http load,http read,http read,simulator status,homebridge start,simulator status'
            if (($caseContext.calls -join ',') -cne $expected) { throw 'Reset sequence changed.' }
        }
        $caseContext.passed++
        Write-Host "PASS: $Action / $Fault"
    }

    Run-Case 'success' 'Reset' $false $false
    Run-Case 'success-running' 'Reset' $false
    foreach ($fault in @('homebridge stop', 'simulator start', 'simulator status', 'starting', 'reset', 'load',
        'unreachable', 'wrong-controller', 'wrong-aircon', 'wrong-count', 'wrong-selection', 'wrong-number', 'unstable', 'homebridge start')) {
        Run-Case $fault 'Reset' $true
    }
    Run-Case 'success' 'RestartHomebridge' $false
    Run-Case 'missing' 'RestartHomebridge' $true $false
    if ($caseContext.calls -contains 'http read') { throw 'Persistence read was attempted with no simulator.' }
    Run-Case 'disappears' 'RestartHomebridge' $true
    Run-Case 'unstable' 'RestartHomebridge' $true
    Run-Case 'changes-after-start' 'RestartHomebridge' $true
    Write-Host "PASS: $($caseContext.passed) operator cases; actual PowerShell control flow, mocked CLI and HTTP."
}
