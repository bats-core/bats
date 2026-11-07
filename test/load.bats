#!/usr/bin/env bats

bats_require_minimum_version 1.5.0

setup() {
  load test_helper
  fixtures load
  REENTRANT_RUN_PRESERVE+=(BATS_LIB_PATH)
}

@test "find_in_bats_lib_path recognizes files relative to test file" {
  test_dir="$BATS_TEST_TMPDIR/find_in_bats_lib_path/bats_test_dirname_priority"
  mkdir -p "$test_dir"
  cp "$FIXTURE_ROOT/test_helper.bash" "$test_dir/"
  cp "$FIXTURE_ROOT/find_library_helper.bats" "$test_dir"

  BATS_LIB_PATH="" LIBRARY_NAME="test_helper" LIBRARY_PATH="$test_dir/test_helper.bash" reentrant_run bats "$test_dir/find_library_helper.bats"
}

@test "find_in_bats_lib_path recognizes files in BATS_LIB_PATH" {
  test_dir="$BATS_TEST_TMPDIR/find_in_bats_lib_path/bats_test_dirname_priority"
  mkdir -p "$test_dir"
  cp "$FIXTURE_ROOT/test_helper.bash" "$test_dir/"

  BATS_LIB_PATH="$test_dir" LIBRARY_NAME="test_helper" LIBRARY_PATH="$test_dir/test_helper.bash" reentrant_run bats "$FIXTURE_ROOT/find_library_helper.bats"
}

@test "find_in_bats_lib_path returns 1 if no load path is found" {
  test_dir="$BATS_TEST_TMPDIR/find_in_bats_lib_path/no_load_path_found"
  mkdir -p "$test_dir"
  cp "$FIXTURE_ROOT/test_helper.bash" "$test_dir/"

  BATS_LIB_PATH="$test_dir" LIBRARY_NAME="test_helper" reentrant_run bats "$FIXTURE_ROOT/find_library_helper_err.bats"
}

@test "find_in_bats_lib_path follows the priority of BATS_LIB_PATH" {
  test_dir="$BATS_TEST_TMPDIR/find_in_bats_lib_path/follows_priority"

  first_dir="$test_dir/first"
  mkdir -p "$first_dir"
  cp "$FIXTURE_ROOT/test_helper.bash" "$first_dir/target.bash"

  second_dir="$test_dir/second"
  mkdir -p "$second_dir"
  cp "$FIXTURE_ROOT/exit1.bash" "$second_dir/target.bash"

  BATS_LIB_PATH="$first_dir:$second_dir" LIBRARY_NAME="target" LIBRARY_PATH="$first_dir/target.bash" reentrant_run bats "$FIXTURE_ROOT/find_library_helper.bats"
}

@test "load sources scripts relative to the current test file" {
  reentrant_run bats "$FIXTURE_ROOT/load.bats"
  [ $status -eq 0 ]
}

@test "load sources relative scripts with filename extension" {
  HELPER_NAME="test_helper.bash" reentrant_run bats "$FIXTURE_ROOT/load.bats"
  [ $status -eq 0 ]
}

@test "load aborts if the specified script does not exist" {
  HELPER_NAME="nonexistent" reentrant_run bats "$FIXTURE_ROOT/load.bats"
  [ $status -eq 1 ]
}

@test "load sources scripts by absolute path" {
  HELPER_NAME="${FIXTURE_ROOT}/test_helper.bash" reentrant_run bats "$FIXTURE_ROOT/load.bats"
  [ $status -eq 0 ]
}

@test "load aborts if the script, specified by an absolute path, does not exist" {
  HELPER_NAME="${FIXTURE_ROOT}/nonexistent" reentrant_run bats "$FIXTURE_ROOT/load.bats"
  [ $status -eq 1 ]
}

@test "load relative script with ambiguous name" {
  HELPER_NAME="ambiguous" reentrant_run bats "$FIXTURE_ROOT/load.bats"
  [ $status -eq 0 ]
}

@test "load does not use the BATS_LIB_PATH" {
  path_dir="$BATS_TEST_TMPDIR/path"
  mkdir -p "$path_dir/on_path"
  cp "${FIXTURE_ROOT}/test_helper.bash" "${path_dir}/on_path/load.bash"
  # shellcheck disable=SC2030,SC2031
  export BATS_LIB_PATH="${path_dir}" HELPER_NAME="on_path"
  reentrant_run ! bats "$FIXTURE_ROOT/load.bats"
  reentrant_run -0 bats "$FIXTURE_ROOT/bats_load_library.bats"
}

@test "load supports plain symbols" {
  local -r helper="${BATS_TEST_TMPDIR}/load_helper_plain"
  {
    echo "plain_variable='value of plain variable'"
    echo "plain_array=(test me hard)"
  } >"${helper}"

  load "${helper}"
  # shellcheck disable=SC2154
  [ "${plain_variable}" = 'value of plain variable' ]
  # shellcheck disable=SC2154
  [ "${plain_array[2]}" = 'hard' ]

  rm "${helper}"
}

@test "load doesn't support _declare_d symbols" {
  local -r helper="${BATS_TEST_TMPDIR}/load_helper_declared"
  {
    echo "declare declared_variable='value of declared variable'"
    echo "declare -r a_constant='constant value'"
    echo "declare -i an_integer=0x7e4"
    echo "declare -a an_array=(test me hard)"
    echo "declare -x exported_variable='value of exported variable'"
  } >"${helper}"

  load "${helper}"

  [ "${declared_variable:-}" != 'value of declared variable' ]
  [ "${a_constant:-}" != 'constant value' ]
  (("${an_integer:-2019}" != 2020))
  [ "${an_array[2]:-}" != 'hard' ]
  [ "${exported_variable:-}" != 'value of exported variable' ]

  rm "${helper}"
}

@test "load supports scripts on the PATH" {
  path_dir="$BATS_TEST_TMPDIR/path"
  mkdir -p "$path_dir"
  cp "${FIXTURE_ROOT}/test_helper.bash" "${path_dir}/on_path"
  # shellcheck disable=SC2030,SC2031
  export PATH="${path_dir}:$PATH" HELPER_NAME="on_path"
  reentrant_run -0 bats "$FIXTURE_ROOT/load.bats"
}

@test "bats_load_library supports libraries with loaders on the BATS_LIB_PATH" {
  path_dir="$BATS_TEST_TMPDIR/libraries/$BATS_TEST_NAME"
  mkdir -p "$path_dir"
  cp "${FIXTURE_ROOT}/test_helper.bash" "${path_dir}/load.bash"
  cp "${FIXTURE_ROOT}/exit1.bash" "${path_dir}/exit1.bash"
  # shellcheck disable=SC2030,SC2031
  export BATS_LIB_PATH="${BATS_TEST_TMPDIR}/libraries" HELPER_NAME="$BATS_TEST_NAME"
  reentrant_run -0 bats "$FIXTURE_ROOT/bats_load_library.bats"
  reentrant_run ! bats "$FIXTURE_ROOT/bats_load.bats" # load does not use BATS_LIB_PATH!
}

@test "bats_load_library supports a Windows-form BATS_LIB_PATH inherited at startup" {
  if [[ ${OSTYPE-} != cygwin && ${OSTYPE-} != msys ]]; then
    skip "Run only on Windows"
  fi

  library_root="$BATS_TEST_TMPDIR/libraries"
  mkdir -p "$library_root/$BATS_TEST_NAME"
  cp "$FIXTURE_ROOT/test_helper.bash" "$library_root/$BATS_TEST_NAME/load.bash"

  BATS_LIB_PATH="$(cygpath --windows "$library_root")" \
  HELPER_NAME="$BATS_TEST_NAME" \
    reentrant_run -0 "$BATS_ROOT/bin/bats" "$FIXTURE_ROOT/bats_load_library.bats"
}

@test "bats_load_library honors BATS_LIB_PATH overridden in the test file" {
  BATS_LIB_PATH="$BATS_TEST_TMPDIR/missing" \
    reentrant_run -0 "$BATS_ROOT/bin/bats" "$FIXTURE_ROOT/bats_load_library_with_overridden_path.bats"
}

@test "Bats preserves BATS_LIB_PATH when cygpath is unavailable" {
  if [[ ${OSTYPE-} != cygwin && ${OSTYPE-} != msys ]]; then
    skip "Run only on Windows"
  fi

  command() {
    if [[ ${1-} == -v && ${2-} == cygpath ]]; then
      return 1
    fi
    builtin command "$@"
  }
  eval 'cygpath() { return 127; }'
  export -f command cygpath

  BATS_LIB_PATH='C:\unconverted' \
    reentrant_run -0 "$BATS_ROOT/bin/bats" "$FIXTURE_ROOT/cygpath_unavailable.bats"
}

@test "bats_load_library supports libraries with loaders on the BATS_LIB_PATH with multiple libraries" {
  path_dir="$BATS_TEST_TMPDIR/libraries/"
  for lib in liba libb libc; do
    mkdir -p "$path_dir/$lib"
    cp "${FIXTURE_ROOT}/exit1.bash" "$path_dir/$lib/load.bash"
  done
  mkdir -p "$path_dir/$BATS_TEST_NAME"
  cp "${FIXTURE_ROOT}/test_helper.bash" "$path_dir/$BATS_TEST_NAME/load.bash"
  # shellcheck disable=SC2030,SC2031
  export BATS_LIB_PATH="$path_dir" HELPER_NAME="$BATS_TEST_NAME"
  reentrant_run -0 bats "$FIXTURE_ROOT/bats_load_library.bats"
  reentrant_run ! bats "$FIXTURE_ROOT/load.bats" # load does not use BATS_LIB_PATH!
}

@test "bats_load_library can handle whitespaces in BATS_LIB_PATH" {
  path_dir="$BATS_TEST_TMPDIR/libraries with spaces/"
  for lib in liba libb libc; do
    mkdir -p "$path_dir/$lib"
    cp "${FIXTURE_ROOT}/exit1.bash" "$path_dir/$lib/load.bash"
  done
  mkdir -p "$path_dir/$BATS_TEST_NAME"
  cp "${FIXTURE_ROOT}/test_helper.bash" "$path_dir/$BATS_TEST_NAME/load.bash"
  # shellcheck disable=SC2030,SC2031
  export BATS_LIB_PATH="$path_dir" HELPER_NAME="$BATS_TEST_NAME"
  reentrant_run -0 bats "$FIXTURE_ROOT/bats_load_library.bats"
}

@test "bats_load_library errors when a library errors while sourcing" {
  path_dir="$BATS_TEST_TMPDIR/libraries_err_sourcing/"
  mkdir -p "$path_dir/return1"
  cp "${FIXTURE_ROOT}/return1.bash" "$path_dir/return1/load.bash"

  # shellcheck disable=SC2030,SC2031
  export BATS_LIB_PATH="$path_dir"
  reentrant_run -1 bats "$FIXTURE_ROOT/failing_bats_load_library.bats"
}

@test "load in teardown after failure does not prevent test from being counted (see #609)" {
  reentrant_run -1 bats "$FIXTURE_ROOT/load_in_teardown_after_failure.bats"
  [ "${lines[0]}" = 1..1 ]
  [ "${lines[1]}" = "not ok 1 failed" ]
  [ "${lines[3]}" = "#   \`false' failed" ]
  [ ${#lines[@]} -eq 4 ]
}

@test "load reports the missing helper after a successful load (#1186)" {
  reentrant_run -1 bats --filter "^missing helper" "$FIXTURE_ROOT/failing_load_after_success.bats"
  [ "${lines[2]}" = "# (in test file $RELATIVE_FIXTURE_ROOT/failing_load_after_success.bats, line 3)" ]
  [ "${lines[3]}" = "#   \`load nonexistent' failed" ]
}

@test "load reports the failing helper after a successful load (#1186)" {
  reentrant_run -1 bats --filter "^helper returning" "$FIXTURE_ROOT/failing_load_after_success.bats"
  [ "${lines[2]}" = "# (from function \`source' in file $RELATIVE_FIXTURE_ROOT/return1.bash, line 1," ]
  [[ "$output" == *"failing_load_after_success.bats, line 8)"* ]]
  [[ "$output" == *"\`load return1' failed"* ]]
}

@test "bats_load_library reports the missing library after a successful load (#1186)" {
  reentrant_run -1 bats --filter "^missing library" "$FIXTURE_ROOT/failing_load_after_success.bats"
  [ "${lines[2]}" = "# (in test file $RELATIVE_FIXTURE_ROOT/failing_load_after_success.bats, line 13)" ]
  [ "${lines[3]}" = "#   \`bats_load_library \"\$BATS_TEST_DIRNAME/nonexistent.bash\"' failed" ]
}

@test "bats_load_library reports the failing library after a successful load (#1186)" {
  reentrant_run -1 bats --filter "^library returning" "$FIXTURE_ROOT/failing_load_after_success.bats"
  [ "${lines[2]}" = "# (from function \`source' in file $RELATIVE_FIXTURE_ROOT/return1.bash, line 1," ]
  [[ "$output" == *"failing_load_after_success.bats, line 18)"* ]]
  [[ "$output" == *"\`bats_load_library \"\$BATS_TEST_DIRNAME/return1.bash\"' failed"* ]]
}
