load 'test_helper'
fixtures bats # reuse bats fixtures

@test "passing test" {
  reentrant_run bats --formatter cat "${FIXTURE_ROOT}/passing.bats"

  [ "${lines[0]}" == '1..1' ]
  [ "${lines[1]}" == "suite ${FIXTURE_ROOT}/passing.bats" ]
  [ "${lines[2]}" == 'begin 1 a passing test' ]
  [ "${lines[3]}" == 'ok 1 a passing test' ]
  [ "${#lines[@]}" -eq 4 ]
}

@test "failing test" {
  reentrant_run bats --formatter cat "${FIXTURE_ROOT}/failing.bats"

  [ "${lines[0]}" == '1..1' ]
  [ "${lines[1]}" == "suite ${FIXTURE_ROOT}/failing.bats" ]
  [ "${lines[2]}" == 'begin 1 a failing test' ]
  [ "${lines[3]}" == 'not ok 1 a failing test' ]
  [ "${lines[4]}" == "# (in test file ${RELATIVE_FIXTURE_ROOT}/failing.bats, line 4)" ]
  [ "${lines[5]}" == "#   \`eval \"( exit \${STATUS:-1} )\"' failed" ]
  [ "${#lines[@]}" -eq 6 ]
}

@test "passing test with timing" {
  reentrant_run bats --formatter cat --timing "${FIXTURE_ROOT}/passing.bats"

  [ "${lines[0]}" == '1..1' ]
  [ "${lines[1]}" == "suite ${FIXTURE_ROOT}/passing.bats" ]
  [ "${lines[2]}" == 'begin 1 a passing test' ]
  [ "${lines[3]::23}" == 'ok 1 a passing test in ' ]
  [ "${lines[3]: -2}" == 'ms' ]
  [ "${#lines[@]}" -eq 4 ]
}

@test "failing test with timing" {
  reentrant_run bats --formatter cat --timing "${FIXTURE_ROOT}/failing.bats"

  [ "${lines[0]}" == '1..1' ]
  [ "${lines[1]}" == "suite ${FIXTURE_ROOT}/failing.bats" ]
  [ "${lines[2]}" == 'begin 1 a failing test' ]
  [ "${lines[3]::27}" == 'not ok 1 a failing test in ' ]
  [ "${lines[3]: -2}" == 'ms' ]
  [ "${lines[4]}" == "# (in test file ${RELATIVE_FIXTURE_ROOT}/failing.bats, line 4)" ]
  [ "${lines[5]}" == "#   \`eval \"( exit \${STATUS:-1} )\"' failed" ]
  [ "${#lines[@]}" -eq 6 ]
}

@test "Cat formatter prints the extended tap stream" {
  cd "$BATS_ROOT/libexec/bats-core/"

  local formatter="bats-format-cat"

  reentrant_run bash -u "$formatter" <<EOF
1..1
suite "$FIXTURE_ROOT/failing.bats"
# output from setup_file
begin 1 test_a_failing_test
# fd3 output from test
not ok 1 a failing test
# (in test file test/fixtures/bats/failing.bats, line 4)
#   \`eval "( exit ${STATUS:-1} )"' failed
begin 2 test_a_successful_test
ok 2 a successful test
unknown line
EOF

  [[ "${#lines[@]}" -eq 11 ]]
}
