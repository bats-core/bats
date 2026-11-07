load test_helper
fixtures suite_setup_teardown
bats_require_minimum_version 1.5.0

setup() {
  export LOGFILE="$BATS_TEST_TMPDIR/log"
}

@test "setup_suite.bash is picked up in toplevel folder of suite" {
  reentrant_run -0 bats -r "$FIXTURE_ROOT/pick_up_toplevel"
  run cat "$LOGFILE"

  [ "${lines[0]}" = "$FIXTURE_ROOT/pick_up_toplevel/setup_suite.bash setup_suite" ]
  [ "${lines[1]}" = "$FIXTURE_ROOT/pick_up_toplevel/setup_suite.bash teardown_suite" ]
}

@test "setup_suite.bash is picked up in folder of first test file" {
  reentrant_run -0 bats "$FIXTURE_ROOT/pick_up_toplevel/folder1/test.bats" "$FIXTURE_ROOT/pick_up_toplevel/folder2/test.bats"
  run cat "$LOGFILE"

  [ "${lines[0]}" = "$FIXTURE_ROOT/pick_up_toplevel/folder1/setup_suite.bash setup_suite" ]
  [ "${lines[1]}" = "$FIXTURE_ROOT/pick_up_toplevel/folder1/setup_suite.bash teardown_suite" ]
}

@test "setup_suite is not picked up from wrongly named file" {
  reentrant_run -0 bats "$FIXTURE_ROOT/non_default_name/"
  run cat "$LOGFILE"
  [[ "${output}" != *"setup_suite"* ]] || false
  [[ "${output}" != *"teardown_suite"* ]] || false
}

@test "setup_suite is picked up from --setup-suite-file" {
  reentrant_run -0 bats "$FIXTURE_ROOT/non_default_name/" \
    --setup-suite-file "$FIXTURE_ROOT/non_default_name/setup_suite_non_default.bash"
  run cat "$LOGFILE"
  [ "${lines[0]}" == "setup_suite non_default" ]
  [ "${lines[1]}" == "teardown_suite non_default" ]
}

@test "--setup-suite-file takes precedence over convention" {
  reentrant_run -0 bats "$FIXTURE_ROOT/default_name/" \
    --setup-suite-file "$FIXTURE_ROOT/non_default_name/setup_suite_non_default.bash"
  run cat "$LOGFILE"
  [ "${lines[0]}" == "setup_suite non_default" ]
  [ "${lines[1]}" == "teardown_suite non_default" ]
}

@test "passing a nonexisting file to --setup-suite-file prints an error message" {
  reentrant_run -1 bats "$FIXTURE_ROOT/default_name/" \
    --setup-suite-file "/non-existing/setup_suite.bash"
  [ "${lines[0]}" == "Error: --setup-suite-file /non-existing/setup_suite.bash does not exist!" ]
}

@test "setup_suite.bash without setup_suite() is an error" {
  reentrant_run ! bats "$FIXTURE_ROOT/no_setup_suite_function/"
  [ "${lines[0]}" == "1..1" ]
  [ "${lines[1]}" == "not ok 1 setup_suite" ]
  [ "${lines[2]}" == "# $FIXTURE_ROOT/no_setup_suite_function/setup_suite.bash does not define \`setup_suite()\`" ]
  [ "${#lines[@]}" -eq 3 ]
}

@test "exported variables from setup_suite are visible in setup_file, setup and @test" {
  unset EXPORTED_VAR
  EXPECTED_VALUE=exported_var reentrant_run -0 bats "$FIXTURE_ROOT/exported_vars/"
}

@test "Bats runtime variables are readonly in setup_suite" {
  reentrant_run -0 env VARIABLES_TO_REASSIGN=BATS_BASH \
    bats "$FIXTURE_ROOT/variables_readonly/"
}

@test "PATH mutations in setup_suite do not break Bats internals" {
  reentrant_run -0 bats "$FIXTURE_ROOT/path_mutation/"
  [ "${lines[0]}" = "1..1" ]
  [ "${lines[1]}" = "ok 1 passing" ]
  [ "${#lines[@]}" -eq 2 ]
}

@test "PATH mutations in setup_suite do not invoke Bash from PATH" {
  local helper_dir="$BATS_TEST_TMPDIR/helpers"
  mkdir "$helper_dir"
  ln -s "$BATS_ROOT/libexec/bats-core/bats-exec-file" "$helper_dir/bats-exec-file"
  printf '%s\n' '#!/bin/sh' 'exit 127' >"$helper_dir/bash"
  chmod +x "$helper_dir/bash"

  PATH_MUTATION_VALUE="$helper_dir:$BATS_SAVED_PATH" reentrant_run -0 bats "$FIXTURE_ROOT/path_mutation/"
  [ "${lines[0]}" = "1..1" ]
  [ "${lines[1]}" = "ok 1 passing" ]
  [ "${#lines[@]}" -eq 2 ]
}

@test "parallel PATH mutations in setup_suite do not break Bats internals" {
  local parallel_binary="${BATS_PARALLEL_BINARY_NAME:-parallel}"
  local parallel_path
  parallel_path="$(type -p "$parallel_binary")" || skip "--jobs requires $parallel_binary"

  emulate_bats_env
  local libexec_with_spaces="$BATS_TEST_TMPDIR/libexec with spaces"
  mkdir -p "$libexec_with_spaces"
  # Exercise GNU parallel command-template quoting for BATS_LIBEXEC paths with spaces.
  for helper in "$BATS_ROOT"/libexec/bats-core/bats-*; do
    ln -s "$helper" "$libexec_with_spaces/${helper##*/}"
  done

  local exec_file_marker="$BATS_TEST_TMPDIR/parallel-exec-file-ran"
  export EXEC_FILE_MARKER="$exec_file_marker"
  export REAL_EXEC_FILE="$BATS_ROOT/libexec/bats-core/bats-exec-file"
  rm "$libexec_with_spaces/bats-exec-file"
  # shellcheck disable=SC2016 # generated script variables expand when the wrapper runs
  printf '%s\n' \
    '#!/usr/bin/env bash' \
    'printf "bats-exec-file\n" >>"$EXEC_FILE_MARKER"' \
    'exec "$BATS_BASH" "$REAL_EXEC_FILE" "$@"' >"$libexec_with_spaces/bats-exec-file"
  chmod +x "$libexec_with_spaces/bats-exec-file"

  REENTRANT_RUN_PRESERVE+=(BATS_LIBEXEC)
  BATS_LIBEXEC="$libexec_with_spaces" \
    PATH_MUTATION_VALUE="$(dirname "$parallel_path"):/usr/bin:/bin" \
    reentrant_run -0 bats-exec-suite -j 2 \
      --setup-suite-file "$FIXTURE_ROOT/path_mutation/setup_suite.bash" \
      "$FIXTURE_ROOT/path_mutation/test.bats"

  [ "${lines[0]}" = "1..1" ]
  [ "${lines[1]}" = "ok 1 passing" ]
  [ "${#lines[@]}" -eq 2 ]
  [ "$(wc -l <"$exec_file_marker")" -eq 1 ]
}

@test "syntax errors in setup_suite.bash are reported and lead to non zero exit code" {
  LANG=C reentrant_run ! bats --setup-suite-file "$FIXTURE_ROOT/syntax_error/setup_suite_no_shellcheck" "$FIXTURE_ROOT/syntax_error/"
  [[ "${lines[1]}" == "$FIXTURE_ROOT/syntax_error/setup_suite_no_shellcheck: line 2: syntax error: unexpected end of file"* ]]
}

@test "errors in setup_suite.bash's free code reported correctly" {
  LANG=C reentrant_run ! bats "$FIXTURE_ROOT/error_in_free_code/"
  [ "${lines[1]}" == "$FIXTURE_ROOT/error_in_free_code/setup_suite.bash: line 1: call-to-undefined-command: command not found" ]
}

@test "errors in setup_suite reported correctly" {
  LANG=C reentrant_run ! bats "$FIXTURE_ROOT/error_in_setup_suite/"
  [ "${lines[4]}" == "# $FIXTURE_ROOT/error_in_setup_suite/setup_suite.bash: line 2: call-to-undefined-command: command not found" ]
}

@test "errors in teardown_suite reported correctly" {
  LANG=C reentrant_run ! bats "$FIXTURE_ROOT/error_in_teardown_suite/"
  [ "${lines[5]}" == "# $FIXTURE_ROOT/error_in_teardown_suite/setup_suite.bash: line 6: call-to-undefined-command: command not found" ]
}

@test "failure in setup_suite skips further setup and suite but runs teardown_suite" {
  reentrant_run ! bats "$FIXTURE_ROOT/failure_in_setup_suite/"
  [ "${lines[0]}" == "1..1" ]
  # get a nice error message
  [ "${lines[1]}" == "not ok 1 setup_suite" ]
  [ "${lines[2]}" == "# (from function \`setup_suite' in test file $RELATIVE_FIXTURE_ROOT/failure_in_setup_suite/setup_suite.bash, line 3)" ]
  [ "${lines[3]}" == "#   \`false' failed" ]
  [ "${lines[4]}" == "# setup_suite before" ] # <- only setup_suite code before failure is run
  [ "${lines[5]}" == "# teardown_suite" ]     # <- teardown is run
  [ ${#lines[@]} -eq 6 ]
}

@test "midway failure in teardown_suite does not fail test suite, remaining code is executed" {
  reentrant_run -0 bats --show-output-of-passing-tests "$FIXTURE_ROOT/failure_in_teardown_suite/"
  [ "${lines[2]}" == "# teardown_suite before" ]
  [ "${lines[3]}" == "# teardown_suite after" ]
  [ "${#lines[@]}" -eq 4 ]
}

@test "nonzero return in teardown_suite does fails test suite" {
  reentrant_run -1 bats "$FIXTURE_ROOT/return_nonzero_in_teardown_suite/"
  [ "${lines[0]}" == "1..1" ]
  [ "${lines[1]}" == "ok 1 test" ]
  [ "${lines[2]}" == "not ok 2 teardown_suite" ]
  [ "${lines[3]}" == "# (from function \`teardown_suite' in test file $RELATIVE_FIXTURE_ROOT/return_nonzero_in_teardown_suite/setup_suite.bash, line 7)" ]
  [ "${lines[4]}" == "#   \`return 1' failed" ]
  [ "${lines[5]}" == "# teardown_suite before" ]
  [ "${lines[6]}" == "# bats warning: Executed 2 instead of expected 1 tests" ]
  [ "${#lines[@]}" -eq 7 ]
}

@test "stderr from setup/teardown_suite does not overtake stdout" {
  reentrant_run -1 --separate-stderr bats "$FIXTURE_ROOT/stderr_in_setup_teardown_suite/"
  [[ "$output" == *$'setup_suite stdout\n'*'setup_suite stderr'* ]] || false
  [[ "$output" == *$'teardown_suite stdout\n'*'teardown_suite stderr'* ]] || false
}

@test "load is available in setup_suite" {
  reentrant_run -0 bats "$FIXTURE_ROOT/call_load/"
  [ "${lines[0]}" = "1..1" ]
  [ "${lines[1]}" = "ok 1 passing" ]
  [ "${#lines[@]}" -eq 2 ]
}

@test "output frorm setup_suite is only visible on failure" {
  reentrant_run -0 bats "$FIXTURE_ROOT/default_name/"
  [ "${lines[0]}" = "1..1" ]
  [ "${lines[1]}" = "ok 1 passing" ]
  [ "${#lines[@]}" -eq 2 ]

  reentrant_run -1 bats "$FIXTURE_ROOT/output_with_failure/"
  [ "${lines[0]}" = "1..1" ]
  [ "${lines[1]}" = "not ok 1 setup_suite" ]
  [ "${lines[2]}" = "# (from function \`setup_suite' in test file $RELATIVE_FIXTURE_ROOT/output_with_failure/setup_suite.bash, line 3)" ]
  [ "${lines[3]}" = "#   \`false' failed" ]
  [ "${lines[4]}" = "# setup_suite" ]
  [ "${lines[5]}" = "# teardown_suite" ]
  [ "${#lines[@]}" -eq 6 ]
}

@test "skip in setup_file skips all tests in file" {
  reentrant_run -0 bats "$FIXTURE_ROOT/skip_in_setup_file.bats"
  [ "${lines[0]}" = '1..2' ]
  [ "${lines[1]}" = 'ok 1 first # skip Reason' ]
  [ "${lines[2]}" = 'ok 2 second # skip Reason' ]
  [ "${#lines[@]}" -eq 3 ]
}
