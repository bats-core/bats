#!/usr/bin/env bats

bats_require_minimum_version 1.5.0

load test_helper
fixtures parallel

# shellcheck disable=SC2034
BATS_TEST_TIMEOUT=10 # only intended for the "short form ..."" test

setup() {
  (type -p "${BATS_PARALLEL_BINARY_NAME:-"parallel"}" &>/dev/null && "${BATS_PARALLEL_BINARY_NAME:-"parallel"}" --version &>/dev/null) || skip "--jobs requires GNU parallel"
}

check_parallel_tests() { # <expected maximum parallelity>
  local expected_maximum_parallelity="$1"
  local expected_number_of_lines="${2:-$((2 * expected_maximum_parallelity))}"

  max_parallel_tests=0
  started_tests=0
  read_lines=0
  while IFS= read -r line; do
    ((++read_lines))
    case "$line" in
    "start "*)
      if ((++started_tests > max_parallel_tests)); then
        max_parallel_tests="$started_tests"
      fi
      ;;
    "stop "*)
      ((started_tests--))
      ;;
    esac
  done <"$FILE_MARKER"

  echo "max_parallel_tests: $max_parallel_tests"
  [[ $max_parallel_tests -eq $expected_maximum_parallelity ]]

  echo "read_lines: $read_lines"
  [[ $read_lines -eq $expected_number_of_lines ]]
}

@test "parallel test execution with --jobs" {
  # shellcheck disable=SC2031,SC2030
  export FILE_MARKER
  # shellcheck disable=SC2030
  FILE_MARKER=$(mktemp "${BATS_RUN_TMPDIR}/file_marker.XXXXXX")
  # shellcheck disable=SC2030
  export PARALLELITY=3
  reentrant_run bats --jobs $PARALLELITY "$FIXTURE_ROOT/parallel.bats"

  [ "$status" -eq 0 ]
  # Make sure the lines are in-order.
  [[ "${lines[0]}" == "1..3" ]]
  for t in {1..3}; do
    [[ "${lines[$t]}" == "ok $t slow test $t" ]]
  done

  check_parallel_tests $PARALLELITY
}

@test "parallel can preserve environment variables" {
  export TEST_ENV_VARIABLE='test-value'
  reentrant_run bats --jobs 2 "$FIXTURE_ROOT/parallel-preserve-environment.bats"
  echo "$output"
  [[ "$status" -eq 0 ]]
}

@test "parallel suite execution with --jobs" {
  # shellcheck disable=SC2034
  BATS_TEST_RETRIES=2 # be more robust against flaky MacOS runners
  # shellcheck disable=SC2031,SC2030
  export FILE_MARKER
  # shellcheck disable=SC2030
  FILE_MARKER=$(mktemp "${BATS_RUN_TMPDIR}/file_marker.XXXXXX")
  # shellcheck disable=SC2031,SC2030
  export PARALLELITY=12

  # file parallelization is needed for maximum parallelity!
  # If we got over the skip (if no GNU parallel) in setup() we can re-enable it safely!
  unset BATS_NO_PARALLELIZE_ACROSS_FILES
  reentrant_run bash -c "bats --jobs $PARALLELITY \"${FIXTURE_ROOT}/suite/\" 2> >(grep -v '^parallel: Warning: ')"

  echo "$output"
  [ "$status" -eq 0 ]

  # Make sure the lines are in-order.
  [[ "${lines[0]}" == "1..$PARALLELITY" ]]
  i=0
  for _ in {1..4}; do
    for t in {1..3}; do
      ((++i))
      [[ "${lines[$i]}" == "ok $i slow test $t" ]]
    done
  done

  check_parallel_tests $PARALLELITY
}

@test "setup_file is not over parallelized" {
  #shellcheck disable=SC2031
  export FILE_MARKER
  FILE_MARKER=$(mktemp "${BATS_RUN_TMPDIR}/file_marker.XXXXXX")
  #shellcheck disable=SC2031,SC2030
  export PARALLELITY=2

  # file parallelization is needed for this test!
  # If we got over the skip (if no GNU parallel) in setup() we can re-enable it safely!
  unset BATS_NO_PARALLELIZE_ACROSS_FILES
  # run 4 files with parallelity of 2 -> serialize 2
  reentrant_run bats --jobs $PARALLELITY "$FIXTURE_ROOT/setup_file"

  [[ $status -eq 0 ]] || (
    echo "$output"
    false
  )

  cat "$FILE_MARKER"

  [[ $(grep -c "start " "$FILE_MARKER") -eq 4 ]] # beware of grepping the filename as well!
  [[ $(grep -c "stop " "$FILE_MARKER") -eq 4 ]]

  check_parallel_tests $PARALLELITY 8
}

@test "running the same file twice runs its tests twice without errors" {
  reentrant_run bats --jobs 2 "$FIXTURE_ROOT/../bats/passing.bats" "$FIXTURE_ROOT/../bats/passing.bats"
  echo "$output"
  [[ $status -eq 0 ]]
  [[ "${lines[0]}" == "1..2" ]] # got 2x1 tests
  [[ "${lines[1]}" == "ok 1 "* ]]
  [[ "${lines[2]}" == "ok 2 "* ]]
  [[ "${#lines[@]}" -eq 3 ]]
}

@test "parallelity factor is met exactly" {
  # shellcheck disable=SC2031
  export MARKER_FILE="${BATS_TEST_TMPDIR}/marker" PARALLELITY=5 # run the 10 tests in 2 batches with 5 test each
  bats --jobs $PARALLELITY "$FIXTURE_ROOT/parallel_factor.bats"
  local current_parallel_count=0 maximum_parallel_count=0 total_count=0
  while read -r line; do
    case "$line" in
    setup*)
      ((++current_parallel_count))
      ((++total_count))
      ;;
    teardown*)
      ((current_parallel_count--))
      ;;
    esac
    if ((current_parallel_count > maximum_parallel_count)); then
      maximum_parallel_count=$current_parallel_count
    fi
  done <"$MARKER_FILE"

  cat "$MARKER_FILE" # for debugging purposes
  [[ "$maximum_parallel_count" -eq $PARALLELITY ]]
  [[ "$current_parallel_count" -eq 0 ]]
  [[ "$total_count" -eq 10 ]]
}

@test "parallel mode correctly forwards failure return code" {
  reentrant_run bats --jobs 2 "$FIXTURE_ROOT/../bats/failing.bats"
  [[ "$status" -eq 1 ]]
}

@test "--no-parallelize-across-files test file detects parallel execution" {
  # ensure that we really run parallelization across files!
  # (setup should have skipped already, if there was no GNU parallel)
  unset BATS_NO_PARALLELIZE_ACROSS_FILES
  FILE_MARKER=$(mktemp "${BATS_RUN_TMPDIR}/file_marker.XXXXXX") \
    reentrant_run ! bats --jobs 2 "$FIXTURE_ROOT/must_not_parallelize_across_files/"
}

@test "--no-parallelize-across-files prevents parallelization across files" {
  FILE_MARKER=$(mktemp "${BATS_RUN_TMPDIR}/file_marker.XXXXXX") \
    bats --jobs 2 --no-parallelize-across-files "$FIXTURE_ROOT/must_not_parallelize_across_files/"
}

@test "--no-parallelize-across-files does not prevent parallelization within files" {
  reentrant_run ! bats --jobs 2 --no-parallelize-across-files "$FIXTURE_ROOT/must_not_parallelize_within_file.bats"
}

@test "--no-parallelize-within-files test file detects parallel execution" {
  reentrant_run ! bats --jobs 2 "$FIXTURE_ROOT/must_not_parallelize_within_file.bats"
}

@test "--no-parallelize-within-files prevents parallelization within files" {
  bats --jobs 2 --no-parallelize-within-files "$FIXTURE_ROOT/must_not_parallelize_within_file.bats"
}

@test "--no-parallelize-within-files does not prevent parallelization across files" {
  # ensure that we really run parallelization across files!
  # (setup should have skipped already, if there was no GNU parallel)
  unset BATS_NO_PARALLELIZE_ACROSS_FILES
  FILEMARKER=$(mktemp "${BATS_RUN_TMPDIR}/file_marker.XXXXXX") \
    reentrant_run ! bats --jobs 2 --no-parallelize-within-files "$FIXTURE_ROOT/must_not_parallelize_across_files/"
}

@test "BATS_NO_PARALLELIZE_WITHIN_FILE works from inside setup_file()" {
  DISABLE_IN_SETUP_FILE_FUNCTION=1 bats --jobs 2 "$FIXTURE_ROOT/must_not_parallelize_within_file.bats"
}

@test "BATS_NO_PARALLELIZE_WITHIN_FILE works from outside all functions" {
  DISABLE_OUTSIDE_ALL_FUNCTIONS=1 bats --jobs 2 "$FIXTURE_ROOT/must_not_parallelize_within_file.bats"
}

@test "BATS_NO_PARALLELIZE_WITHIN_FILE does not work from inside setup()" {
  DISABLE_IN_SETUP_FUNCTION=1 reentrant_run ! bats --jobs 2 "$FIXTURE_ROOT/must_not_parallelize_within_file.bats"
}

@test "BATS_NO_PARALLELIZE_WITHIN_FILE does not work from inside test function" {
  DISABLE_IN_TEST_FUNCTION=1 reentrant_run ! bats --jobs 2 "$FIXTURE_ROOT/must_not_parallelize_within_file.bats"
}

@test "Negative jobs number does not run endlessly" {
  unset BATS_NO_PARALLELIZE_ACROSS_FILES
  run bats -j -3 "$FIXTURE_ROOT/../bats/passing.bats"
  ((SECONDS < 5))
  [ "${lines[1]}" = 'Invalid number of jobs: -3' ]
}
