#!/usr/bin/env bash

BATS_TEST_DIRNAME="${BATS_TEST_FILENAME%/*}"
BATS_TEST_NAMES=()

# Shorthand for source-ing files relative to the BATS_TEST_DIRNAME,
# optionally with a .bash suffix appended. If the argument doesn't
# resolve relative to BATS_TEST_DIRNAME it is sourced as-is.
load() {
  local file="${1:?}"

  # For backwards-compatibility first look for a .bash-suffixed file.
  # TODO consider flipping the order here; it would be more consistent
  # and less surprising to look for an exact-match first.
  if [[ -f "${BATS_TEST_DIRNAME}/${file}.bash" ]]; then
    file="${BATS_TEST_DIRNAME}/${file}.bash"
  elif [[ -f "${BATS_TEST_DIRNAME}/${file}" ]]; then
    file="${BATS_TEST_DIRNAME}/${file}"
  fi

  if [[ ! -f "$file" ]] && ! type -P "$file" >/dev/null; then
    printf 'bats: %s does not exist\n' "$file" >&2
    exit 1
  fi

  # Dynamically loaded user file provided outside of Bats.
  # Note: 'source "$file" || exit' doesn't work on bash3.2.
  # shellcheck disable=SC1090
  source "${file}"
}

###############
#  _bats_die  #  Abort with helpful and visible message
###############
_bats_die() {
  printf "#/vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv\n"  >&2
  printf "#| FAIL: %s\n" "$1"                                      >&2
  shift
  # Any more?
  for line in "$@"; do
    printf "#|    > %s\n" "$line"                                  >&2
  done

  printf "#\\^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^\n" >&2
  false
}

run() {
  local expected_rc=

  # Possible first arguments: '!' = any nonzero, '=n' = exactly n
  if [[ "$1" = '!' ]]; then
    expected_rc=-1
    shift
  elif [[ ${1:0:1} = '=' ]]; then
    expected_rc=${1#=}
    if [[ $expected_rc =~ [^0-9] ]]; then
      _bats_die "Usage error: run: '=NNN' requires numeric NNN (got: $1)"
    elif [[ $expected_rc -gt 255 ]]; then
      _bats_die "Usage error: run: '=NNN': NNN must be <= 255 (got: $1)"
    fi
    shift
  fi

  # stdout is emitted only on error; this echo is to help debug test failures
  printf "${BATS_PS1}%s\n" "$*"

  local origFlags="$-"
  set +eET
  local origIFS="$IFS"
  # 'output', 'status', 'lines' are global variables available to tests.
  # shellcheck disable=SC2034
  output="$("$@" 2>&1)"
  # shellcheck disable=SC2034
  status="$?"
  # shellcheck disable=SC2034,SC2206
  IFS=$'\n' lines=($output)
  IFS="$origIFS"
  set "-$origFlags"

  # Show results. Without quotes, multiple lines are glommed together into one
  if [ -n "$output" ]; then
    printf "%s\n" "$output"
  fi

  # Check exit status if requested
  if [[ "$status" -ne 0 ]]; then
    printf "[ rc=%d " $status
    if [[ -n "$expected_rc" ]]; then
      if [[ "$status" -eq "$expected_rc" ]]; then
        printf "(expected) "
      elif [[ $expected_rc -lt 0 ]]; then
        printf "(expected any error)"
        expected_rc=$status           # don't die below
      else
        printf "(** EXPECTED %d **) " $expected_rc;
      fi
    fi
    printf "]\n"
  fi

  if [[ -n "$expected_rc" ]]; then
    if [[ "$expected_rc" = "-1" ]]; then
      if [[ "$status" -eq 0 ]]; then
        _bats_die "exit code is $status; expected nonzero"
      fi
    elif [ "$status" -ne "$expected_rc" ]; then
      _bats_die "exit code is $status; expected $expected_rc"
    fi
  fi
}

setup() {
  return 0
}

teardown() {
  return 0
}

skip() {
  # if this is a skip in teardown ...
  if [[ -n "${BATS_TEARDOWN_STARTED-}" ]]; then
    # ... we want to skip the rest of teardown.
    # communicate to bats_exit_trap that the teardown was completed without error
    # shellcheck disable=SC2034
    BATS_TEARDOWN_COMPLETED=1
    # if we are already in the exit trap (e.g. due to previous skip) ...
    if [[ "$BATS_TEARDOWN_STARTED" == as-exit-trap ]]; then
      # ... we need to do the rest of the tear_down_trap that would otherwise be skipped after the next call to exit
      bats_exit_trap
      # and then do the exit (at the end of this function)
    fi
    # if we aren't in exit trap, the normal exit handling should suffice
  else
    # ... this is either skip in test or skip in setup.
    # Following variables are used in bats-exec-test which sources this file
    # shellcheck disable=SC2034
    BATS_TEST_SKIPPED="${1:-1}"
    # shellcheck disable=SC2034
    BATS_TEST_COMPLETED=1
  fi
  exit 0
}

bats_test_begin() {
  BATS_TEST_DESCRIPTION="$1"
  if [[ -n "$BATS_EXTENDED_SYNTAX" ]]; then
    printf 'begin %d %s\n' "$BATS_SUITE_TEST_NUMBER" "$BATS_TEST_DESCRIPTION" >&3
  fi
  setup
}

bats_test_function() {
  local test_name="$1"
  BATS_TEST_NAMES+=("$test_name")
}
