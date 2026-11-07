bats_require_minimum_version 1.5.0

load 'test_helper'
fixtures file_setup_teardown

setup_file() {
  export SETUP_FILE_EXPORT_TEST=true
}

assert_variables_are_readonly() {
  local scope=$1
  shift
  reentrant_run env REASSIGNMENT_SCOPE="$scope" VARIABLES_TO_REASSIGN="$*" \
    bats "$FIXTURE_ROOT/variables_readonly.bats"
  echo "$output"
  [[ $status -eq 0 ]]
}

@test "setup_file is run once per file" {
  # shellcheck disable=SC2031,SC2030
  export LOG="$BATS_TEST_TMPDIR/setup_file_once.log"
  bats "$FIXTURE_ROOT/setup_file.bats"
}

@test "Bats-owned variables are readonly in setup_file" {
  assert_variables_are_readonly setup_file \
    BATS_BASH \
    BATS_FILE_FIRST_TEST_NUMBER_IN_SUITE \
    BATS_TEST_FILENAME \
    BATS_TEST_FILE_NUMBER \
    BATS_FILE_TMPDIR \
    BATS_SUITE_TMPDIR
}

@test "Bats-owned variables are readonly in test" {
  assert_variables_are_readonly test \
    BATS_BASH \
    BATS_TEST_FILENAME \
    BATS_TEST_FILE_NUMBER \
    BATS_FILE_TMPDIR \
    BATS_SUITE_TMPDIR
}

@test "teardown_file is run once per file" {
  # shellcheck disable=SC2031,SC2030
  export LOG="$BATS_TEST_TMPDIR/teardown_file_once.log"
  reentrant_run bats "$FIXTURE_ROOT/teardown_file.bats"
  [[ $status -eq 0 ]]
  # output the log for faster debugging
  cat "$LOG"
  # expect to find an entry for the tested file
  grep 'teardown_file.bats' "$LOG"
  # it should be the only entry
  run wc -l <"$LOG"
  [[ $output -eq 1 ]]
}

@test "setup_file is called correctly in multi file suite" {
  # shellcheck disable=SC2031,SC2030
  export LOG="$BATS_TEST_TMPDIR/setup_file_multi_file_suite.log"
  reentrant_run bats "$FIXTURE_ROOT/setup_file.bats" "$FIXTURE_ROOT/no_setup_file.bats" "$FIXTURE_ROOT/setup_file2.bats"
  [[ $status -eq 0 ]]
  run wc -l <"$LOG"
  # each setup_file[2].bats is in the log exactly once!
  [[ $output -eq 2 ]]
  grep setup_file.bats "$LOG"
  grep setup_file2.bats "$LOG"
}

@test "teardown_file is called correctly in multi file suite" {
  # shellcheck disable=SC2031,SC2030
  export LOG="$BATS_TEST_TMPDIR/teardown_file_multi_file_suite.log"
  reentrant_run bats "$FIXTURE_ROOT/teardown_file.bats" "$FIXTURE_ROOT/no_teardown_file.bats" "$FIXTURE_ROOT/teardown_file2.bats"
  [[ $status -eq 0 ]]
  run wc -l <"$LOG"
  # each teardown_file[2].bats is in the log exactly once!
  [[ $output -eq 2 ]]
  grep teardown_file.bats "$LOG"
  grep teardown_file2.bats "$LOG"

}

@test "setup_file failure aborts tests for this file" {
  # this might need to mark them as skipped as the test count is already determined at this point
  reentrant_run bats "$FIXTURE_ROOT/setup_file_failed.bats"
  echo "$output"
  [[ "${lines[0]}" == "1..2" ]]
  [[ "${lines[1]}" == "not ok 1 setup_file failed" ]]
  [[ "${lines[2]}" == "# (from function \`setup_file' in test file $RELATIVE_FIXTURE_ROOT/setup_file_failed.bats, line 2)" ]]
  [[ "${lines[3]}" == "#   \`false' failed" ]]
  [[ "${lines[4]}" == "# bats warning: Executed 1 instead of expected 2 tests" ]] # this warning is expected
  # to appease the count validator, we would have to reduce the expected number of tests (retroactively?) or
  # output even those tests that should be skipped due to a failed setup_file.
  # Since we are already in a failure mode, the additional error does not hurt and is less verbose than
  # printing all the failed/skipped tests due to the setup failure.
}

@test "teardown_file failure fails at least one test from the file" {
  reentrant_run bats "$FIXTURE_ROOT/teardown_file_failed.bats"
  [[ $status -ne 0 ]]
  echo "$output"
  [[ "${lines[0]}" == "1..1" ]]
  [[ "${lines[1]}" == "ok 1 test" ]]
  [[ "${lines[2]}" == "not ok 2 teardown_file failed" ]]
  [[ "${lines[3]}" == "# (from function \`teardown_file' in test file $RELATIVE_FIXTURE_ROOT/teardown_file_failed.bats, line 2)" ]]
  [[ "${lines[4]}" == "#   \`false' failed" ]]
  [[ "${lines[5]}" == "# bats warning: Executed 2 instead of expected 1 tests" ]] # for now this warning is expected
  # for a failed teardown_file not to change the number of tests being reported, we would have to alter at least one previous test result report
  # this would require arbitrary amounts of buffering so we simply add our own line with a fake test number
  # tripping the count validator won't change the overall result, as we already are in a failure mode
}

@test "teardown_file runs even if any test in the file failed" {
  # shellcheck disable=SC2031,SC2030
  export LOG="$BATS_TEST_TMPDIR/teardown_file_failed.log"
  reentrant_run bats "$FIXTURE_ROOT/teardown_file_after_failing_test.bats"
  [[ $status -ne 0 ]]
  grep teardown_file_after_failing_test.bats "$LOG"
  echo "$output"
  [[ $output == "1..1
not ok 1 failing test
# (in test file $RELATIVE_FIXTURE_ROOT/teardown_file_after_failing_test.bats, line 6)
#   \`false' failed" ]]
}

@test "teardown_file should run even after user abort via CTRL-C" {
  if [[ "${BATS_NUMBER_OF_PARALLEL_JOBS:-1}" -gt 1 ]]; then
    skip "Aborts don't work in parallel mode"
  fi
  # shellcheck disable=SC2031,SC2030
  export LOG="$BATS_TEST_TMPDIR/teardown_file_abort.log"
  # guarantee that background processes get their own process group -> pid=pgid
  set -m
  SECONDS=0
  # run testsubprocess in background to not avoid blocking this test
  bats "$FIXTURE_ROOT/teardown_file_after_long_test.bats" &
  SUBPROCESS_PID=$!
  # wait until we enter the test
  sleep 2
  # fake sending SIGINT (CTRL-C) to the process group of the background subprocess
  kill -SIGINT -- -$SUBPROCESS_PID
  wait # for the test to finish either way (SIGINT or normal execution)
  echo "Waited: $SECONDS seconds"
  [[ $SECONDS -lt 10 ]] # make sure we really cut it short with SIGINT
  # check that teardown_file ran and created the log file
  [[ -f "$LOG" ]]
  grep teardown_file_after_long_test.bats "$LOG"
  # but the test must not have run to the end!
  run ! grep "test finished successfully" "$LOG"
}

@test "setup_file runs even if all tests in the file are skipped" {
  # shellcheck disable=SC2031,SC2030
  export LOG="$BATS_TEST_TMPDIR/setup_file_skipped.log"
  reentrant_run bats "$FIXTURE_ROOT/setup_file_even_if_all_tests_are_skipped.bats"
  [[ -f "$LOG" ]]
  grep setup_file_even_if_all_tests_are_skipped.bats "$LOG"
}

@test "teardown_file runs even if all tests in the file are skipped" {
  # shellcheck disable=SC2031,SC2030
  export LOG="$BATS_TEST_TMPDIR/teardown_file_skipped.log"
  reentrant_run bats "$FIXTURE_ROOT/teardown_file_even_if_all_tests_are_skipped.bats"
  [[ $status -eq 0 ]]
  [[ -f "$LOG" ]]
  grep teardown_file_even_if_all_tests_are_skipped.bats "$LOG"
}

@test "setup_file must not leak context between tests in the same suite" {
  # example: BATS_ROOT was unset in one test but used in others, therefore, the suite failed
  # Simulate leaking env var from first to second test by: export SETUP_FILE_VAR="LEAK!"
  reentrant_run bats "$FIXTURE_ROOT/setup_file_does_not_leak_env.bats" "$FIXTURE_ROOT/setup_file_does_not_leak_env2.bats"
  echo "$output"
  [[ $status -eq 0 ]]
}

@test "teardown_file must not leak context between tests in the same suite" {
  # example: BATS_ROOT was unset in one test but used in others, therefore, the suite failed
  reentrant_run bats "$FIXTURE_ROOT/teardown_file_does_not_leak.bats" "$FIXTURE_ROOT/teardown_file_does_not_leak2.bats"
  echo "$output"
  [[ $status -eq 0 ]]
  [[ $output == "1..2
ok 1 test
ok 2 must not see variable from first run" ]]
}

@test "halfway setup_file errors are caught and reported" {
  reentrant_run bats "$FIXTURE_ROOT/setup_file_halfway_error.bats"
  [ $status -ne 0 ]
  echo "$output"
  [ "${lines[0]}" == "1..1" ]
  [ "${lines[1]}" == "not ok 1 setup_file failed" ]
  [ "${lines[2]}" == "# (from function \`setup_file' in test file $RELATIVE_FIXTURE_ROOT/setup_file_halfway_error.bats, line 3)" ]
  [ "${lines[3]}" == "#   \`false' failed" ]
}

@test "halfway teardown_file errors are ignored" {
  reentrant_run -0 bats "$FIXTURE_ROOT/teardown_file_halfway_error.bats"
  [ "${lines[0]}" == "1..1" ]
  [ "${lines[1]}" == "ok 1 empty" ]
  [ "${#lines[@]}" -eq 2 ]

}

@test "variables exported in setup_file are visible in tests" {
  [[ $SETUP_FILE_EXPORT_TEST == "true" ]]
}

@test "Don't run setup_file for files without tests" {
  # shellcheck disable=SC2031
  export LOG="$BATS_TEST_TMPDIR/setup_file.log"
  # only select the test from no_setup_file
  reentrant_run bats -f test "$FIXTURE_ROOT/setup_file.bats" "$FIXTURE_ROOT/no_setup_file.bats"

  [ ! -f "$LOG" ]             # setup_file must not have been executed!
  [ "${lines[0]}" == '1..1' ] # but at least one test should have been run
}

@test "Failure in setup_file and teardown_file still prints error message" {
  reentrant_run ! bats "$FIXTURE_ROOT/error_in_setup_and_teardown_file.bats"
  [ "${lines[0]}" == '1..1' ]
  [ "${lines[1]}" == 'not ok 1 setup_file failed' ]
  [ "${lines[2]}" == "# (from function \`setup_file' in test file $RELATIVE_FIXTURE_ROOT/error_in_setup_and_teardown_file.bats, line 2)" ]
  [ "${lines[3]}" == "#   \`false' failed" ]
  [ "${#lines[@]}" -eq 4 ]
}
