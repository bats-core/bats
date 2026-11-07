load test_helper
fixtures timeout

bats_require_minimum_version 1.5.0

@test "test faster than timeout" {
  SECONDS=0
  TIMEOUT=10
  reentrant_run -0 env BATS_TEST_TIMEOUT=$TIMEOUT SLEEP=1 bats -T "$FIXTURE_ROOT/sleep2.bats"
  [ "${lines[0]}" == '1..1' ]
  [[ "${lines[1]}" == 'ok 1 my sleep 1 in '*'ms' ]] || false
  [ "${#lines[@]}" -eq 2 ]
  # the timeout background process should not hold up execution
  ((SECONDS < TIMEOUT)) || false
}

@test "test longer than timeout" {
  SECONDS=0
  reentrant_run ! env BATS_TEST_TIMEOUT=1 SLEEP=10 bats -T "$FIXTURE_ROOT/sleep2.bats"
  [ "${lines[0]}" == '1..1' ]
  [[ "${lines[1]}" == 'not ok 1 my sleep 10 in '*'ms # timeout after 1s' ]] || false
  [ "${lines[2]}" == "# (in test file $RELATIVE_FIXTURE_ROOT/sleep2.bats, line 2)" ]
  [ "${lines[3]}" == "#   \`sleep \"\${SLEEP?}\"' failed due to timeout" ]
  ((SECONDS < 10)) || false
}

@test "run longer than timeout" {
  SECONDS=0
  reentrant_run ! env BATS_TEST_TIMEOUT=1 SLEEP=10 bats -T "$FIXTURE_ROOT/run sleep.bats" --print-output-on-failure
  [ "${lines[0]}" == '1..1' ]
  [[ "${lines[1]}" == 'not ok 1 my sleep 10 in '*'ms # timeout after 1s' ]] || false
  [ "${lines[2]}" == "# (in test file $RELATIVE_FIXTURE_ROOT/run sleep.bats, line 1)" ]
  #[ "${lines[3]}" == "#   \`run sleep \"\${SLEEP?}\"' failed due to timeout" ]
  [[ "${lines[3]}" == *"failed due to timeout" ]]
  ((SECONDS < 10)) || false
}

@test "timeout should not hold up faster (skipped) tests (#1067)" {
  SECONDS=0
  DURATION=10
  reentrant_run -0 env BATS_TEST_TIMEOUT=$DURATION bats -T "$FIXTURE_ROOT/issue1067.bats"
  echo Took $SECONDS seconds
  ((SECONDS < DURATION))
}
