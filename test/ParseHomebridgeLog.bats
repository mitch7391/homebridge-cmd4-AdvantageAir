setup()
{
   load './test/setup'
   _common_setup
}

teardown()
{
   _common_teardown
}


file_to_be_parsed="../homebridge.log.txt"

@test "AdvAir ( ezone / zone ) Test $file_to_be_parsed" {

   ln -s ./testData/dataPassOn5 ./data
   if [ ! -f "$file_to_be_parsed" ]; then
      skip "Skipping test. No $file_to_be_parsed from $( pwd )"
   fi
   myc=0
   while IFS= read -a line; do
      if [[ "${line}" = *" function for: "* ]] &&
         [[ "${line}" = *" cmd: "* ]]
      then
         # convert line in log file to an Array
         #line is like:
         # [13/08/2021, 7:02:54 pm] [Cmd4] getValue: accTypeEnumIndex:( 46 )-"CurrentTemperature" function for: Theatre_Room cmd: bash /home/pi/ezone.sh Get 'Theatre_Room' 'CurrentTemperature' z02 timeout: 5000
         arr=($line)
         io="${arr[14]}"
         displayName="${arr[15]}"
         characteristic="${arr[16]}"
         # remove single quotes
         characteristic=$(echo -n "$characteristic" | cut -d "'" -f 2 )
         zone=""
         if [ "$io" = "Get" ]; then
            possibleZPos=17
         else
            value="${arr[17]}"
            possibleZPos=18
         fi
         if [[ "${arr[$possibleZPos]}" = z* ]]; then
            zone="${arr[$possibleZPos]}"
         fi
         if [ "$io" = "Set" ]
         then
            if [ "$zone" = "" ]; then
               echo "  $myc AdvAir ( zones ) $io $displayName $characteristic $value TEST_ON" >&3
               _common_compareAgainstEzone "$io" "$displayName" "$characteristic" "$value" TEST_ON
            else
               echo "AdvAir ( zones ) $io $displayName $characteristic $value $zone TEST_ON" >&3
               _common_compareAgainstZones "$io" "$displayName" "$characteristic" "$value" "$zone" TEST_ON
            fi
         fi
         if [ "$io" = "Get" ]
         then
            if [ "$zone" = "" ]; then
               echo "  $myc AdvAir ( ezone ) $io $displayName $characteristic TEST_ON" >&3
               _common_compareAgainstEzone "$io" "$displayName" "$characteristic" TEST_ON
            else
               echo "  $myc AdvAir ( ezone ) $io $displayName $characteristic $zone TEST_ON" >&3
               _common_compareAgainstZones "$io" "$displayName" "$characteristic" "$zone" TEST_ON
            fi
         fi
      fi
      myc=$((myc+1))
   done < $file_to_be_parsed

}
