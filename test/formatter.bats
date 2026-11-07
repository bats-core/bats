#!/usr/bin/env bats

setup() {
  load test_helper
  fixtures formatter
}

@test "default formatter in CI is TAP" {
  bats_require_minimum_version 1.5.0
  reentrant_run -0 -- env CI=1 bats "$FIXTURE_ROOT/passing.bats"
  [ "${lines[0]}" = "1..1" ]
  [ "${lines[1]}" = "ok 1 a passing test" ]
  [ ${#lines[@]} -eq 2 ]
}

@test "default formatter in interactive shell is interactive pretty" {
  bats_require_minimum_version 1.5.0
  unset CI
  if [[ "$OSTYPE" == "linux"* ]]; then
    script_cmd=(script -q /dev/null -c "bats \"$FIXTURE_ROOT/passing.bats\"")
  else
    script_cmd=(script -q /dev/null bats "$FIXTURE_ROOT/passing.bats")
  fi
  if [[ "$OSTYPE" == msys || "$OSTYPE" == cygwin ]]; then
    skip "script is not available on $OSTYPE"
  fi
  if ! type script; then
    echo "script executable not available on $OSTYPE" || false
  fi
  reentrant_run -0 -- "${script_cmd[@]}"
  expected_lines=(
    $'\x1b[34;1mpassing.bats'
    $'\x1b[2G\x1b[1G ✓ a passing test\x1b[K'
    $'\x1b[0m\x1b[32;1m'
    $'1 test, 0 failures'
    $'\x1b[0m'
  )

  for ((i = 0; i < ${#expected_lines[@]}; ++i)); do
    if ! [[ "${lines[i]}" = *"${expected_lines[i]}"* ]]; then
      echo "line $i:"
      diff --unified <(xxd <<<"${lines[i]}") <(xxd <<<"${expected_lines[i]}")
    fi
  done
}

@test "pretty formatter in CI is non-interactive" {
  bats_require_minimum_version 1.5.0
  reentrant_run -0 -- env CI=1 bats --pretty "$FIXTURE_ROOT/passing.bats"
  [ "${lines[0]}" = $'\x1b[34;1mpassing.bats' ]
  [ "${lines[1]}" = $'\x1b[0m ✓ a passing test\x1b[K' ]
  [ "${lines[2]}" = $'\x1b[0m\x1b[32;1m' ]
  [ "${lines[3]}" = $'1 test, 0 failures' ]
  [ "${lines[4]}" = $'\x1b[0m' ]
  [ ${#lines[@]} -eq 5 ]
}

@test "tap passing and skipping tests" {
  reentrant_run filter_control_sequences bats --formatter tap "$FIXTURE_ROOT/passing_and_skipping.bats"
  [ $status -eq 0 ]
  [ "${lines[0]}" = "1..3" ]
  [ "${lines[1]}" = "ok 1 a passing test" ]
  [ "${lines[2]}" = "ok 2 a skipped test with no reason # skip" ]
  [ "${lines[3]}" = "ok 3 a skipped test with a reason # skip for a really good reason" ]
}

@test "tap passing, failing and skipping tests" {
  reentrant_run filter_control_sequences bats --formatter tap "$FIXTURE_ROOT/passing_failing_and_skipping.bats"
  [ $status -eq 0 ]
  [ "${lines[0]}" = "1..3" ]
  [ "${lines[1]}" = "ok 1 a passing test" ]
  [ "${lines[2]}" = "ok 2 a skipping test # skip" ]
  [ "${lines[3]}" = "not ok 3 a failing test" ]
}

@test "skipped test with parens (pretty formatter)" {
  reentrant_run bats --pretty "$FIXTURE_ROOT/skipped_with_parens.bats"
  [ $status -eq 0 ]

  # Some systems (Alpine, for example) seem to emit an extra whitespace into
  # entries in the 'lines' array when a carriage return is present from the
  # pretty formatter.  This is why a '+' is used after the 'skipped' note.
  [[ "${lines[*]}" =~ "- a skipped test with parentheses in the reason (skipped: "+"a reason (with parentheses))" ]]
}

@test "pretty and tap formats" {
  reentrant_run bats --formatter tap "$FIXTURE_ROOT/passing.bats"
  tap_output="$output"
  [ $status -eq 0 ]

  reentrant_run bats --pretty "$FIXTURE_ROOT/passing.bats"
  pretty_output="$output"
  [ $status -eq 0 ]

  [ "$tap_output" != "$pretty_output" ]
}

@test "pretty formatter bails on invalid tap" {
  reentrant_run bats-format-pretty < <(printf "This isn't TAP!\nGood day to you\n")
  [ $status -eq 0 ]
  [ "${lines[0]}" = "This isn't TAP!" ]
  [ "${lines[1]}" = "Good day to you" ]
}

@test "All formatters (except cat) implement the callback interface" {
  cd "$BATS_ROOT/libexec/bats-core/"
  for formatter in bats-format-*; do
    # the cat formatter is not expected to implement this interface
    if [[ "$formatter" == *"bats-format-cat" ]]; then
      continue
    fi
    tested_at_least_one_formatter=1
    echo "Formatter: ${formatter}"
    # the replay should be possible without errors
    bash -u "$formatter" >/dev/null <<EOF
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
  done

  [[ -n "$tested_at_least_one_formatter" ]]
}

@test "absolute paths load external formatters" {
  bats_require_minimum_version 1.5.0
  reentrant_run -0 bats "$FIXTURE_ROOT/passing.bats" --formatter "$FIXTURE_ROOT/dummy-formatter"
  [ "$output" = "Dummy Formatter!" ]
}

@test "specifying nonexistent external formatter is an error" {
  bats_require_minimum_version 1.5.0
  reentrant_run -1 bats "$FIXTURE_ROOT/passing.bats" --formatter "$FIXTURE_ROOT/non-existing-file"
  [ "$output" = "ERROR: Formatter '$FIXTURE_ROOT/non-existing-file' is not readable!" ]
}

@test "specifying non executable external formatter is an error" {
  bats_require_minimum_version 1.5.0
  local non_executable="$BATS_TEST_TMPDIR/non-executable"
  touch "$non_executable"
  reentrant_run -1 bats "$FIXTURE_ROOT/passing.bats" --formatter "$non_executable"
  [ "$output" = "ERROR: Formatter '$non_executable' is not executable!" ]
}

@test "retrying tests does not mess up test names" {
  bats_require_minimum_version 1.5.0
  reentrant_run -1 bats "$FIXTURE_ROOT/retry.bats" --formatter "$FIXTURE_ROOT/echo-formatter"
  [ "${lines[0]}" = 'STREAM_PLAN: 1' ]
  [ "${lines[1]}" = "STREAM_SUITE: file $FIXTURE_ROOT/retry.bats" ]
  [ "${lines[2]}" = 'STREAM_BEGIN: index: 1, name: test foobar' ]
  [ "${lines[3]}" = 'STREAM_BEGIN: index: 1, name: test foobar' ]
  [ "${lines[4]}" = 'STREAM_NOT_OK: index 1, name test foobar' ]
  [ "${lines[5]}" = "STREAM_COMMENT: comment (in test file $RELATIVE_FIXTURE_ROOT/retry.bats, line 7), scope not_ok" ]
  [ "${lines[6]}" = "STREAM_COMMENT: comment   \`false' failed, scope not_ok" ]
  [ "${#lines[@]}" -eq 7 ]
}
