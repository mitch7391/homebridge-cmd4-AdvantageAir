setup() {
   # This code is run *BEFORE* every test. Even skipped ones.
   # Bug, defining setup() must have code in it
   echo "Before each" > /dev/null
}

teardown() {
   # This code is run *AFTER* every test. Even skipped ones.
   # Bug, defining teardown() must have code in it
   echo "After each" > /dev/null
}

@test "Sample Test (How to Skip)" {
   skip "This test is skipped just to show that skippping can be done."
   echo "Done"
}

@test "Sample Test Check Status of run command" {
   # The Bats run command gobbles up stdout
   run echo "Hello world"
   [ "$status" = "0" ]
}

@test "Sample Test Check stdout of command" {
   # The Bats run command gobbles up stdout
   # Remove the word "run" if test fails to see results to stdout
   run echo "Hello world"
   [ "${lines[0]}" = "Hello world" ]
}
