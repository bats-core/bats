#!/usr/bin/env bats

load test_helper
fixtures bats

@test "no arguments prints message and usage instructions" {
  run bats
  [ $status -eq 1 ]
  [ "${lines[0]}" == 'Error: Must specify at least one <test>' ]
  [ "${lines[1]%% *}" == 'Usage:' ]
}

@test "invalid option prints message and usage instructions" {
  run bats --invalid-option
  [ $status -eq 1 ]
  [ "${lines[0]}" == "Error: Bad command line option '--invalid-option'" ]
  [ "${lines[1]%% *}" == 'Usage:' ]
}

@test "-v and --version print version number" {
  run bats -v
  [ $status -eq 0 ]
  [ $(expr "$output" : "Bats [0-9][0-9.]*") -ne 0 ]
}

@test "-h and --help print help" {
  run bats -h
  [ $status -eq 0 ]
  [ "${#lines[@]}" -gt 3 ]
}

@test "invalid filename prints an error" {
  run bats nonexistent
  [ $status -eq 1 ]
  [ $(expr "$output" : ".*does not exist") -ne 0 ]
}

@test "empty test file runs zero tests" {
  run bats "$FIXTURE_ROOT/empty.bats"
  [ $status -eq 0 ]
  [ "$output" = "1..0" ]
}

@test "one passing test" {
  run bats "$FIXTURE_ROOT/passing.bats"
  [ $status -eq 0 ]
  [ "${lines[0]}" = "1..1" ]
  [ "${lines[1]}" = "ok 1 a passing test" ]
}

@test "summary passing tests" {
  run filter_control_sequences bats -p "$FIXTURE_ROOT/passing.bats"
  [ $status -eq 0 ]
  [ "${lines[1]}" = "1 test, 0 failures" ]
}

@test "summary passing and skipping tests" {
  run filter_control_sequences bats -p "$FIXTURE_ROOT/passing_and_skipping.bats"
  [ $status -eq 0 ]
  [ "${lines[3]}" = "3 tests, 0 failures, 2 skipped" ]
}

@test "tap passing and skipping tests" {
  run filter_control_sequences bats --formatter tap "$FIXTURE_ROOT/passing_and_skipping.bats"
  [ $status -eq 0 ]
  [ "${lines[0]}" = "1..3" ]
  [ "${lines[1]}" = "ok 1 a passing test" ]
  [ "${lines[2]}" = "ok 2 a skipped test with no reason # skip" ]
  [ "${lines[3]}" = "ok 3 a skipped test with a reason # skip for a really good reason" ]
}

@test "summary passing and failing tests" {
  run filter_control_sequences bats -p "$FIXTURE_ROOT/failing_and_passing.bats"
  [ $status -eq 0 ]
  [ "${lines[4]}" = "2 tests, 1 failure" ]
}

@test "summary passing, failing and skipping tests" {
  run filter_control_sequences bats -p "$FIXTURE_ROOT/passing_failing_and_skipping.bats"
  [ $status -eq 0 ]
  [ "${lines[5]}" = "3 tests, 1 failure, 1 skipped" ]
}

@test "tap passing, failing and skipping tests" {
  run filter_control_sequences bats --formatter tap "$FIXTURE_ROOT/passing_failing_and_skipping.bats"
  [ $status -eq 0 ]
  [ "${lines[0]}" = "1..3" ]
  [ "${lines[1]}" = "ok 1 a passing test" ]
  [ "${lines[2]}" = "ok 2 a skipping test # skip" ]
  [ "${lines[3]}" = "not ok 3 a failing test" ]
}

@test "BATS_CWD is correctly set to PWD as validated by bats_trim_filename" {
  local trimmed
  bats_trim_filename "$PWD/foo/bar" 'trimmed'
  printf 'ACTUAL: %s\n' "$trimmed" >&2
  [ "$trimmed" = 'foo/bar' ]
}

@test "one failing test" {
  run bats "$FIXTURE_ROOT/failing.bats"
  [ $status -eq 1 ]
  [ "${lines[0]}" = '1..1' ]
  [ "${lines[1]}" = 'not ok 1 a failing test' ]
  [ "${lines[2]}" = "# (in test file $RELATIVE_FIXTURE_ROOT/failing.bats, line 4)" ]
  [ "${lines[3]}" = "#   \`eval \"( exit \${STATUS:-1} )\"' failed" ]
}

@test "one failing and one passing test" {
  run bats "$FIXTURE_ROOT/failing_and_passing.bats"
  [ $status -eq 1 ]
  [ "${lines[0]}" = '1..2' ]
  [ "${lines[1]}" = 'not ok 1 a failing test' ]
  [ "${lines[2]}" = "# (in test file $RELATIVE_FIXTURE_ROOT/failing_and_passing.bats, line 2)" ]
  [ "${lines[3]}" = "#   \`false' failed" ]
  [ "${lines[4]}" = 'ok 2 a passing test' ]
}

@test "failing test with significant status" {
  STATUS=2 run bats "$FIXTURE_ROOT/failing.bats"
  [ $status -eq 1 ]
  [ "${lines[3]}" = "#   \`eval \"( exit \${STATUS:-1} )\"' failed with status 2" ]
}

@test "failing helper function logs the test case's line number" {
  run bats "$FIXTURE_ROOT/failing_helper.bats"
  [ $status -eq 1 ]
  [ "${lines[1]}" = 'not ok 1 failing helper function' ]
  [ "${lines[2]}" = "# (from function \`failing_helper' in file $RELATIVE_FIXTURE_ROOT/test_helper.bash, line 6," ]
  [ "${lines[3]}" = "#  in test file $RELATIVE_FIXTURE_ROOT/failing_helper.bats, line 5)" ]
  [ "${lines[4]}" = "#   \`failing_helper' failed" ]
}

@test "test environments are isolated" {
  run bats "$FIXTURE_ROOT/environment.bats"
  [ $status -eq 0 ]
}

@test "setup is run once before each test" {
  make_bats_test_suite_tmpdir
  run bats "$FIXTURE_ROOT/setup.bats"
  [ $status -eq 0 ]
  run cat "$BATS_TEST_SUITE_TMPDIR/setup.log"
  [ ${#lines[@]} -eq 3 ]
}

@test "teardown is run once after each test, even if it fails" {
  make_bats_test_suite_tmpdir
  run bats "$FIXTURE_ROOT/teardown.bats"
  [ $status -eq 1 ]
  run cat "$BATS_TEST_SUITE_TMPDIR/teardown.log"
  [ ${#lines[@]} -eq 3 ]
}

@test "setup failure" {
  run bats "$FIXTURE_ROOT/failing_setup.bats"
  [ $status -eq 1 ]
  [ "${lines[1]}" = 'not ok 1 truth' ]
  [ "${lines[2]}" = "# (from function \`setup' in test file $RELATIVE_FIXTURE_ROOT/failing_setup.bats, line 2)" ]
  [ "${lines[3]}" = "#   \`false' failed" ]
}

@test "passing test with teardown failure" {
  PASS=1 run bats "$FIXTURE_ROOT/failing_teardown.bats"
  [ $status -eq 1 ]
  echo "$output"
  [ "${lines[1]}" = 'not ok 1 truth' ]
  [ "${lines[2]}" = "# (from function \`teardown' in test file $RELATIVE_FIXTURE_ROOT/failing_teardown.bats, line 2)" ]
  [ "${lines[3]}" = "#   \`eval \"( exit \${STATUS:-1} )\"' failed" ]
}

@test "failing test with teardown failure" {
  PASS=0 run bats "$FIXTURE_ROOT/failing_teardown.bats"
  [ $status -eq 1 ]
  [ "${lines[1]}" =  'not ok 1 truth' ]
  [ "${lines[2]}" =  "# (in test file $RELATIVE_FIXTURE_ROOT/failing_teardown.bats, line 6)" ]
  [ "${lines[3]}" = $'#   `[ "$PASS" = 1 ]\' failed' ]
}

@test "teardown failure with significant status" {
  PASS=1 STATUS=2 run bats "$FIXTURE_ROOT/failing_teardown.bats"
  [ $status -eq 1 ]
  [ "${lines[3]}" = "#   \`eval \"( exit \${STATUS:-1} )\"' failed with status 2" ]
}

@test "failing test file outside of BATS_CWD" {
  make_bats_test_suite_tmpdir
  cd "$BATS_TEST_SUITE_TMPDIR"
  run bats "$FIXTURE_ROOT/failing.bats"
  [ $status -eq 1 ]
  [ "${lines[2]}" = "# (in test file $FIXTURE_ROOT/failing.bats, line 4)" ]
}

@test "find_library_load_path finds single-file libraries with the suffix .bash" {
  lib_dir="$BATS_TMPNAME/find_library_path/single_file_suffix"
  mkdir -p "$lib_dir"
  cp "${FIXTURE_ROOT}/test_helper.bash" "${lib_dir}/test_helper.bash"

  run find_library_load_path "$lib_dir/test_helper"
  [ $status -eq 0 ]
  [ ${lines[0]} = "$lib_dir/test_helper.bash" ]
}

@test "find_library_load_path finds single-file libraries without a suffix" {
  lib_dir="$BATS_TMPNAME/find_library_path/single_file_no_suffix"
  mkdir -p "$lib_dir"
  cp "${FIXTURE_ROOT}/test_helper.bash" "${lib_dir}/test_helper"

  run find_library_load_path "$lib_dir/test_helper"
  [ $status -eq 0 ]
  [ ${lines[0]} = "$lib_dir/test_helper" ]
}

@test "find_library_load_path finds directory libraries with a load.bash loader" {
  lib_dir="$BATS_TMPNAME/find_library_path/directory_loader_suffix"
  mkdir -p "$lib_dir/test_helper"
  cp "${FIXTURE_ROOT}/test_helper.bash" "${lib_dir}/test_helper/load.bash"

  run find_library_load_path "$lib_dir/test_helper"
  [ $status -eq 0 ]
  [ ${lines[0]} = "$lib_dir/test_helper/load.bash" ]
}

@test "find_library_load_path finds directory libraries with a load loader" {
  lib_dir="$BATS_TMPNAME/find_library_path/directory_loader_no_suffix"
  mkdir -p "$lib_dir/test_helper"
  cp "${FIXTURE_ROOT}/test_helper.bash" "${lib_dir}/test_helper/load"

  run find_library_load_path "$lib_dir/test_helper"
  [ $status -eq 0 ]
  [ ${lines[0]} = "$lib_dir/test_helper/load" ]
}

@test "find_library_load_path finds directory libraries without a loader" {
  lib_dir="$BATS_TMPNAME/find_library_path/directory_no_loader"
  mkdir -p "$lib_dir/test_helper"
  cp "${FIXTURE_ROOT}/test_helper.bash" "${lib_dir}/test_helper/not_a_loader.bash"

  run find_library_load_path "$lib_dir/test_helper"
  [ $status -eq 0 ]
  [ ${lines[0]} = "$lib_dir/test_helper" ]
}

@test "find_library_load_path returns 1 if no library load path is found" {
  lib_dir="$BATS_TMPNAME/find_library_path/return1"
  mkdir -p "$lib_dir/test_helper"
  cp "${FIXTURE_ROOT}/test_helper.bash" "${lib_dir}/test_helper/not_a_loader.bash"

  run find_library_load_path "$lib_dir/does_not_exist"
  [ $status -eq 1 ]
  [ -z "${lines[0]}" ]
}

@test "find_in_bats_lib_path recognizes files relative to test file" {
  test_dir="$BATS_TMPNAME/find_in_bats_lib_path/bats_test_dirname_priorty"
  mkdir -p "$test_dir"
  cp "$FIXTURE_ROOT/test_helper.bash" "$test_dir/"
  cp "$FIXTURE_ROOT/find_library_helper.bats" "$test_dir"

  BATS_LIB_PATH="" LIBRARY_NAME="test_helper" LIBRARY_PATH="$test_dir/test_helper.bash" run bats "$test_dir/find_library_helper.bats"
}

@test "find_in_bats_lib_path recognizes files in BATS_LIB_PATH" {
  test_dir="$BATS_TMPNAME/find_in_bats_lib_path/bats_test_dirname_priorty"
  mkdir -p "$test_dir"
  cp "$FIXTURE_ROOT/test_helper.bash" "$test_dir/"

  BATS_LIB_PATH="$test_dir" LIBRARY_NAME="test_helper" LIBRARY_PATH="$test_dir/test_helper.bash" run bats "$FIXTURE_ROOT/find_library_helper.bats"
}

@test "find_in_bats_lib_path returns 1 if no load path is found" {
  test_dir="$BATS_TMPNAME/find_in_bats_lib_path/no_load_path_found"
  mkdir -p "$test_dir"
  cp "$FIXTURE_ROOT/test_helper.bash" "$test_dir/"

  BATS_LIB_PATH="$test_dir" LIBRARY_NAME="test_helper" run bats "$FIXTURE_ROOT/find_library_helper_err.bats"
}

@test "find_in_bats_lib_path follows the priority of BATS_LIB_PATH" {
  test_dir="$BATS_TMPNAME/find_in_bats_lib_path/follows_priority"

  first_dir="$test_dir/first"
  mkdir -p "$first_dir"
  cp "$FIXTURE_ROOT/test_helper.bash" "$first_dir/target.bash"

  second_dir="$test_dir/second"
  mkdir -p "$second_dir"
  cp "$FIXTURE_ROOT/exit1.bash" "$second_dir/target.bash"

  BATS_LIB_PATH="$first_dir:$second_dir" LIBRARY_NAME="target" LIBRARY_PATH="$first_dir/target.bash" run bats "$FIXTURE_ROOT/find_library_helper.bats"
}

@test "load sources scripts relative to the current test file" {
  run bats "$FIXTURE_ROOT/load.bats"
  [ $status -eq 0 ]
}

@test "load sources relative scripts with filename extension" {
  HELPER_NAME="test_helper.bash" run bats "$FIXTURE_ROOT/load.bats"
  [ $status -eq 0 ]
}

@test "load aborts if the specified script does not exist" {
  HELPER_NAME="nonexistent" run bats "$FIXTURE_ROOT/load.bats"
  [ $status -eq 1 ]
}

@test "load sources scripts by absolute path" {
  HELPER_NAME="${FIXTURE_ROOT}/test_helper.bash" run bats "$FIXTURE_ROOT/load.bats"
  [ $status -eq 0 ]
}

@test "load aborts if the script, specified by an absolute path, does not exist" {
  HELPER_NAME="${FIXTURE_ROOT}/nonexistent" run bats "$FIXTURE_ROOT/load.bats"
  [ $status -eq 1 ]
}

@test "load relative script with ambiguous name" {
  HELPER_NAME="ambiguous" run bats "$FIXTURE_ROOT/load.bats"
  [ $status -eq 0 ]
}

@test "load loads scripts on the BATS_LIB_PATH" {
  path_dir="$BATS_TMPNAME/path"
  mkdir -p "$path_dir"
  cp "${FIXTURE_ROOT}/test_helper.bash" "${path_dir}/on_path"
  BATS_LIB_PATH="${path_dir}"  HELPER_NAME="on_path" run bats "$FIXTURE_ROOT/load.bats"
  [ $status -eq 0 ]
}

@test "load supports plain symbols" {
  local -r helper="${BATS_TMPDIR}/load_helper_plain"
  {
    echo "plain_variable='value of plain variable'"
    echo "plain_array=(test me hard)"
  } > "${helper}"

  load "${helper}"

  [ "${plain_variable}" = 'value of plain variable' ]
  [ "${plain_array[2]}" = 'hard' ]

  rm "${helper}"
}

@test "load doesn't support _declare_d symbols" {
  local -r helper="${BATS_TMPDIR}/load_helper_declared"
  {
    echo "declare declared_variable='value of declared variable'"
    echo "declare -r a_constant='constant value'"
    echo "declare -i an_integer=0x7e4"
    echo "declare -a an_array=(test me hard)"
    echo "declare -x exported_variable='value of exported variable'"
  } > "${helper}"

  load "${helper}"

  ! [ "${declared_variable:-}" = 'value of declared variable' ]
  ! [ "${a_constant:-}" = 'constant value' ]
  ! (( "${an_integer:-2019}" == 2020 ))
  ! [ "${an_array[2]:-}" = 'hard' ]
  ! [ "${exported_variable:-}" = 'value of exported variable' ]

  rm "${helper}"
}

@test "load supports libraries with loaders on the BATS_LIB_PATH" {
  path_dir="$BATS_TMPNAME/libraries/test_helper"
  mkdir -p "$path_dir"
  cp "${FIXTURE_ROOT}/test_helper.bash" "${path_dir}/load.bash"
  cp "${FIXTURE_ROOT}/exit1.bash" "${path_dir}/exit1.bash"
  BATS_LIB_PATH="${BATS_TMPNAME}/libraries" HELPER_NAME="test_helper" run bats "$FIXTURE_ROOT/load.bats"
}

@test "load supports libraries with loaders on the BATS_LIB_PATH with multiple libraries" {
  path_dir="$BATS_TMPNAME/libraries2/"
  for lib in liba libb libc; do
      mkdir -p "$path_dir/$lib"
      cp "${FIXTURE_ROOT}/exit1.bash" "$path_dir/$lib/load.bash"
  done
  mkdir -p "$path_dir/test_helper"
  cp "${FIXTURE_ROOT}/test_helper.bash" "$path_dir/test_helper/load.bash"
  BATS_LIB_PATH="$path_dir" HELPER_NAME="test_helper" run bats "$FIXTURE_ROOT/load.bats"
}

@test "load supports libraries without loaders on the BATS_LIB_PATH" {
  path_dir="$BATS_TMPNAME/libraries/test_helper"
  mkdir -p "$path_dir"
  cp "${FIXTURE_ROOT}/test_helper.bash" "${path_dir}/test_helper.bash"
  BATS_LIB_PATH="${BATS_TMPNAME}/libraries" HELPER_NAME="test_helper" run bats "$FIXTURE_ROOT/load.bats"
}

@test "load can handle whitespaces in BATS_LIB_PATH" {
  path_dir="$BATS_TMPNAME/libraries with spaces/"
  for lib in liba libb libc; do
      mkdir -p "$path_dir/$lib"
      cp "${FIXTURE_ROOT}/exit1.bash" "$path_dir/$lib/load.bash"
  done
  mkdir -p "$path_dir/test_helper"
  cp "${FIXTURE_ROOT}/test_helper.bash" "$path_dir/test_helper/load.bash"
  BATS_LIB_PATH="$path_dir" HELPER_NAME="test_helper" run bats "$FIXTURE_ROOT/load.bats"
}

@test "bats errors when a library errors while sourcing" {
  path_dir="$BATS_TMPNAME/libraries_err_sourcing/"
  mkdir -p "$path_dir/return1"
  cp "${FIXTURE_ROOT}/return1.bash" "$path_dir/return1/load.bash"

  BATS_LIB_PATH="$path_dir" run bats "$FIXTURE_ROOT/failing_load.bats"
  [ $status -eq 1 ]
}

@test "bats skips directories when sourcing .bash files in library" {
  path_dir="$BATS_TMPNAME/libraries_skip_dir/"
  mkdir -p "$path_dir/target_lib/adir.bash"
  cp "${FIXTURE_ROOT}/test_helper.bash" "$path_dir/target_lib/test_helper.bash"
  BATS_LIB_PATH="$path_dir" HELPER_NAME="target_lib" run bats "$FIXTURE_ROOT/load.bats"
}

@test "output is discarded for passing tests and printed for failing tests" {
  run bats "$FIXTURE_ROOT/output.bats"
  [ $status -eq 1 ]
  [ "${lines[6]}"  = '# failure stdout 1' ]
  [ "${lines[7]}"  = '# failure stdout 2' ]
  [ "${lines[11]}" = '# failure stderr' ]
}

@test "-c prints the number of tests" {
  run bats -c "$FIXTURE_ROOT/empty.bats"
  [ $status -eq 0 ]
  [ "$output" = 0 ]

  run bats -c "$FIXTURE_ROOT/output.bats"
  [ $status -eq 0 ]
  [ "$output" = 4 ]
}

@test "dash-e is not mangled on beginning of line" {
  run bats "$FIXTURE_ROOT/intact.bats"
  [ $status -eq 0 ]
  [ "${lines[1]}" = "ok 1 dash-e on beginning of line" ]
}

@test "dos line endings are stripped before testing" {
  run bats "$FIXTURE_ROOT/dos_line.bats"
  [ $status -eq 0 ]
}

@test "test file without trailing newline" {
  run bats "$FIXTURE_ROOT/without_trailing_newline.bats"
  [ $status -eq 0 ]
  [ "${lines[1]}" = "ok 1 truth" ]
}

@test "skipped tests" {
  run bats "$FIXTURE_ROOT/skipped.bats"
  [ $status -eq 0 ]
  [ "${lines[1]}" = "ok 1 a skipped test # skip" ]
  [ "${lines[2]}" = "ok 2 a skipped test with a reason # skip a reason" ]
}

@test "skipped test with parens (pretty formatter)" {
  run bats --pretty "$FIXTURE_ROOT/skipped_with_parens.bats"
  [ $status -eq 0 ]

  # Some systems (Alpine, for example) seem to emit an extra whitespace into
  # entries in the 'lines' array when a carriage return is present from the
  # pretty formatter.  This is why a '+' is used after the 'skipped' note.
  [[ "${lines[@]}" =~ "- a skipped test with parentheses in the reason (skipped: "+"a reason (with parentheses))" ]]
}

@test "extended syntax" {
  emulate_bats_env
  run bats-exec-suite -x "$FIXTURE_ROOT/failing_and_passing.bats"
  echo "$output"
  [ $status -eq 1 ]
  [ "${lines[1]}" = 'suite failing_and_passing.bats' ]
  [ "${lines[2]}" = 'begin 1 a failing test' ]
  [ "${lines[3]}" = 'not ok 1 a failing test' ]
  [ "${lines[6]}" = 'begin 2 a passing test' ]
  [ "${lines[7]}" = 'ok 2 a passing test' ]
}

@test "timing syntax" {
  run bats -T "$FIXTURE_ROOT/failing_and_passing.bats"
  echo "$output"
  [ $status -eq 1 ]
  regex='not ok 1 a failing test in [0-1]sec'
  [[ "${lines[1]}" =~ $regex ]]
  regex='ok 2 a passing test in [0-1]sec'
  [[ "${lines[4]}" =~ $regex ]]
}

@test "extended timing syntax" {
  emulate_bats_env
  run bats-exec-suite -x -T "$FIXTURE_ROOT/failing_and_passing.bats"
  echo "$output"
  [ $status -eq 1 ]
  regex="not ok 1 a failing test in [0-1]sec"
  [ "${lines[2]}" = 'begin 1 a failing test' ]
  [[ "${lines[3]}" =~ $regex ]]
  [ "${lines[6]}" = 'begin 2 a passing test' ]
  regex="ok 2 a passing test in [0-1]sec"
  [[ "${lines[7]}" =~ $regex ]]
}

@test "pretty and tap formats" {
  run bats --formatter tap "$FIXTURE_ROOT/passing.bats"
  tap_output="$output"
  [ $status -eq 0 ]

  run bats --pretty "$FIXTURE_ROOT/passing.bats"
  pretty_output="$output"
  [ $status -eq 0 ]

  [ "$tap_output" != "$pretty_output" ]
}

@test "pretty formatter bails on invalid tap" {
  run bats-format-pretty < <(printf "This isn't TAP!\nGood day to you\n")
  [ $status -eq 0 ]
  [ "${lines[0]}" = "This isn't TAP!" ]
  [ "${lines[1]}" = "Good day to you" ]
}

@test "single-line tests" {
  run bats "$FIXTURE_ROOT/single_line.bats"
  [ $status -eq 1 ]
  [ "${lines[1]}" =  'ok 1 empty' ]
  [ "${lines[2]}" =  'ok 2 passing' ]
  [ "${lines[3]}" =  'ok 3 input redirection' ]
  [ "${lines[4]}" =  'not ok 4 failing' ]
  [ "${lines[5]}" =  "# (in test file $RELATIVE_FIXTURE_ROOT/single_line.bats, line 9)" ]
  [ "${lines[6]}" = $'#   `@test "failing" { false; }\' failed' ]
}

@test "testing IFS not modified by run" {
  run bats "$FIXTURE_ROOT/loop_keep_IFS.bats"
  [ $status -eq 0 ]
  [ "${lines[1]}" = "ok 1 loop_func" ]
}

@test "expand variables in test name" {
  SUITE='test/suite' run bats "$FIXTURE_ROOT/expand_var_in_test_name.bats"
  [ $status -eq 0 ]
  [ "${lines[1]}" = "ok 1 test/suite: test with variable in name" ]
}

@test "handle quoted and unquoted test names" {
  run bats "$FIXTURE_ROOT/quoted_and_unquoted_test_names.bats"
  [ $status -eq 0 ]
  [ "${lines[1]}" = "ok 1 single-quoted name" ]
  [ "${lines[2]}" = "ok 2 double-quoted name" ]
  [ "${lines[3]}" = "ok 3 unquoted name" ]
}

@test 'ensure compatibility with unofficial Bash strict mode' {
  local expected='ok 1 unofficial Bash strict mode conditions met'

  # Run Bats under `set -u` to catch as many unset variable accesses as
  # possible.
  run bash -u "${BATS_TEST_DIRNAME%/*}/bin/bats" \
    "$FIXTURE_ROOT/unofficial_bash_strict_mode.bats"
  if [[ "$status" -ne 0 || "${lines[1]}" != "$expected" ]]; then
    cat <<END_OF_ERR_MSG

This test failed because the Bats internals are violating one of the
constraints imposed by:

--------
$(< "$FIXTURE_ROOT/unofficial_bash_strict_mode.bash")
--------

See:
- https://github.com/sstephenson/bats/issues/171
- http://redsymbol.net/articles/unofficial-bash-strict-mode/

If there is no error output from the test fixture, run the following to
debug the problem:

  $ bash -u bats $RELATIVE_FIXTURE_ROOT/unofficial_bash_strict_mode.bats

If there's no error output even with this command, make sure you're using the
latest version of Bash, as versions before 4.1-alpha may not produce any error
output for unset variable accesses.

If there's no output even when running the latest Bash, the problem may reside
in the DEBUG trap handler. A particularly sneaky issue is that in Bash before
4.1-alpha, an expansion of an empty array, e.g. "\${FOO[@]}", is considered
an unset variable access. The solution is to add a size check before the
expansion, e.g. [[ "\${#FOO[@]}" -ne 0 ]].

END_OF_ERR_MSG
    emit_debug_output && return 1
  fi
}

@test "parse @test lines with various whitespace combinations" {
  run bats "$FIXTURE_ROOT/whitespace.bats"
  [ $status -eq 0 ]
  [ "${lines[1]}" = 'ok 1 no extra whitespace' ]
  [ "${lines[2]}" = 'ok 2 tab at beginning of line' ]
  [ "${lines[3]}" = 'ok 3 tab before description' ]
  [ "${lines[4]}" = 'ok 4 tab before opening brace' ]
  [ "${lines[5]}" = 'ok 5 tabs at beginning of line and before description' ]
  [ "${lines[6]}" = 'ok 6 tabs at beginning, before description, before brace' ]
  [ "${lines[7]}" = 'ok 7 extra whitespace around single-line test' ]
  [ "${lines[8]}" = 'ok 8 no extra whitespace around single-line test' ]
  [ "${lines[9]}" = 'ok 9 parse unquoted name between extra whitespace' ]
  [ "${lines[10]}" = 'ok 10 {' ]  # unquoted single brace is a valid description
  [ "${lines[11]}" = 'ok 11 ' ]   # empty name from single quote
}

@test "duplicate tests error and generate a warning on stderr" {
  run bats --tap "$FIXTURE_ROOT/duplicate-tests.bats"
  [ $status -eq 1 ]

  local expected='Error: Duplicate test name(s) in file '
  expected+="\"${FIXTURE_ROOT}/duplicate-tests.bats\": test_gizmo_test"

  printf 'expected: "%s"\n' "$expected" >&2
  printf 'actual:   "%s"\n' "${lines[0]}" >&2
  [ "${lines[0]}" = "$expected" ]

  printf 'num lines: %d\n' "${#lines[*]}" >&2
  [ "${#lines[*]}" = "1" ]
}

@test "sourcing a nonexistent file in setup produces error output" {
  run bats "$FIXTURE_ROOT/source_nonexistent_file_in_setup.bats"
  [ $status -eq 1 ]
  [ "${lines[1]}" = 'not ok 1 sourcing nonexistent file fails in setup' ]
  [ "${lines[2]}" = "# (from function \`setup' in test file $RELATIVE_FIXTURE_ROOT/source_nonexistent_file_in_setup.bats, line 2)" ]
  [ "${lines[3]}" = "#   \`source \"nonexistent file\"' failed" ]
}

@test "referencing unset parameter in setup produces error output" {
  run bats "$FIXTURE_ROOT/reference_unset_parameter_in_setup.bats"
  [ $status -eq 1 ]
  [ "${lines[1]}" = 'not ok 1 referencing unset parameter fails in setup' ]
  [ "${lines[2]}" = "# (from function \`setup' in test file $RELATIVE_FIXTURE_ROOT/reference_unset_parameter_in_setup.bats, line 3)" ]
  [ "${lines[3]}" = "#   \`echo \"\$unset_parameter\"' failed" ]
}

@test "sourcing a nonexistent file in test produces error output" {
  run bats "$FIXTURE_ROOT/source_nonexistent_file.bats"
  [ $status -eq 1 ]
  [ "${lines[1]}" = 'not ok 1 sourcing nonexistent file fails' ]
  [ "${lines[2]}" = "# (in test file $RELATIVE_FIXTURE_ROOT/source_nonexistent_file.bats, line 2)" ]
  [ "${lines[3]}" = "#   \`source \"nonexistent file\"' failed" ]
}

@test "referencing unset parameter in test produces error output" {
  run bats "$FIXTURE_ROOT/reference_unset_parameter.bats"
  [ $status -eq 1 ]
  [ "${lines[1]}" = 'not ok 1 referencing unset parameter fails' ]
  [ "${lines[2]}" = "# (in test file $RELATIVE_FIXTURE_ROOT/reference_unset_parameter.bats, line 3)" ]
  [ "${lines[3]}" = "#   \`echo \"\$unset_parameter\"' failed" ]
}

@test "sourcing a nonexistent file in teardown produces error output" {
  run bats "$FIXTURE_ROOT/source_nonexistent_file_in_teardown.bats"
  [ $status -eq 1 ]
  [ "${lines[1]}" = 'not ok 1 sourcing nonexistent file fails in teardown' ]
  [ "${lines[2]}" = "# (from function \`teardown' in test file $RELATIVE_FIXTURE_ROOT/source_nonexistent_file_in_teardown.bats, line 2)" ]
  [ "${lines[3]}" = "#   \`source \"nonexistent file\"' failed" ]
}

@test "referencing unset parameter in teardown produces error output" {
  run bats "$FIXTURE_ROOT/reference_unset_parameter_in_teardown.bats"
  [ $status -eq 1 ]
  [ "${lines[1]}" = 'not ok 1 referencing unset parameter fails in teardown' ]
  [ "${lines[2]}" = "# (from function \`teardown' in test file $RELATIVE_FIXTURE_ROOT/reference_unset_parameter_in_teardown.bats, line 3)" ]
  [ "${lines[3]}" = "#   \`echo \"\$unset_parameter\"' failed" ]
}

@test "execute exported function without breaking failing test output" {
  exported_function() { return 0; }
  export -f exported_function
  run bats "$FIXTURE_ROOT/exported_function.bats"
  [ $status -eq 1 ]
  [ "${lines[0]}" = "1..1" ]
  [ "${lines[1]}" = "not ok 1 failing test" ]
  [ "${lines[2]}" = "# (in test file $RELATIVE_FIXTURE_ROOT/exported_function.bats, line 7)" ]
  [ "${lines[3]}" = "#   \`false' failed" ]
  [ "${lines[4]}" = "# a='exported_function'" ]
}

@test "output printed even when no final newline" {
  run bats "$FIXTURE_ROOT/no-final-newline.bats"
  printf 'num lines: %d\n' "${#lines[@]}" >&2
  printf 'LINE: %s\n' "${lines[@]}" >&2
  [ "$status" -eq 1 ]
  [ "${#lines[@]}" -eq 7 ]
  [ "${lines[1]}" = 'not ok 1 no final newline' ]
  [ "${lines[2]}" = "# (in test file $RELATIVE_FIXTURE_ROOT/no-final-newline.bats, line 2)" ]
  [ "${lines[3]}" = "#   \`printf 'foo\nbar\nbaz' >&2 && return 1' failed" ]
  [ "${lines[4]}" = '# foo' ]
  [ "${lines[5]}" = '# bar' ]
  [ "${lines[6]}" = '# baz' ]
}

@test "run tests which consume stdin (see #197)" {
  run bats "$FIXTURE_ROOT/read_from_stdin.bats"
  [ "$status" -eq 0 ]
  [[ "${lines[0]}" == "1..3" ]]
  [[ "${lines[1]}" == "ok 1 test 1" ]]
  [[ "${lines[2]}" == "ok 2 test 2 with	TAB in name" ]]
  [[ "${lines[3]}" == "ok 3 test 3" ]]
}

@test "report correct line on unset variables" {
  run bats "$FIXTURE_ROOT/unbound_variable.bats"
  [ "$status" -eq 1 ]
  [ "${#lines[@]}" -eq 9 ]
  [ "${lines[1]}" = 'not ok 1 access unbound variable' ]
  [ "${lines[2]}" = "# (in test file $RELATIVE_FIXTURE_ROOT/unbound_variable.bats, line 8)" ]
  [ "${lines[3]}" = "#   \`foo=\$unset_variable' failed" ]
  [[ "${lines[4]}" =~ ".src: line 8:" ]]
  [ "${lines[5]}" = 'not ok 2 access second unbound variable' ]
  [ "${lines[6]}" = "# (in test file $RELATIVE_FIXTURE_ROOT/unbound_variable.bats, line 13)" ]
  [ "${lines[7]}" = "#   \`foo=\$second_unset_variable' failed" ]
  [[ "${lines[8]}" =~ ".src: line 13:" ]]
}

@test "report correct line on external function calls" {
  run bats "$FIXTURE_ROOT/external_function_calls.bats"
  [ "$status" -eq 1 ]

  expectedNumberOfTests=12
  linesOfOutputPerTest=3
  [ "${#lines[@]}" -gt $((expectedNumberOfTests * linesOfOutputPerTest + 1)) ]

  outputOffset=1
  currentErrorLine=9
  linesPerTest=5

  for t in $(seq $expectedNumberOfTests); do
    [[ "${lines[$outputOffset]}" =~ "not ok $t " ]]
    # Skip backtrace into external function if set
    if [[ "${lines[$((outputOffset + 1))]}" =~ "# (from function " ]]; then
      outputOffset=$((outputOffset + 1))
      parenChar=" "
    else
      parenChar="("
    fi

    [ "${lines[$((outputOffset + 1))]}" = "# ${parenChar}in test file $RELATIVE_FIXTURE_ROOT/external_function_calls.bats, line $currentErrorLine)" ]
    [[ "${lines[$((outputOffset + 2))]}" =~ " failed" ]]
    outputOffset=$((outputOffset + 3))
    currentErrorLine=$((currentErrorLine + linesPerTest))
  done
}

@test "test count validator catches mismatch and returns non zero" {
  source "$BATS_ROOT/lib/bats-core/validator.bash"
  export -f bats_test_count_validator
  run bash -c "echo $'1..1\n' | bats_test_count_validator"
  [[ $status -ne 0 ]]

  run bash -c "echo $'1..1\nok 1\nok 2' | bats_test_count_validator"
  [[ $status -ne 0 ]]

  run bash -c "echo $'1..1\nok 1' | bats_test_count_validator"
  [[ $status -eq 0 ]]
}

@test "running the same file twice runs its tests twice without errors" {
  run bats "$FIXTURE_ROOT/passing.bats" "$FIXTURE_ROOT/passing.bats"
  echo "$output"
  [[ $status -eq 0 ]]
  [[ "${lines[0]}" == "1..2" ]] # got 2x1 tests
}
