emulate_bats_env() {
  export BATS_CWD="$PWD"
  export BATS_ROOT_PID=$$
  export BATS_RUN_TMPDIR
  BATS_RUN_TMPDIR=$(mktemp -d "${BATS_RUN_TMPDIR}/emulated-tmpdir-${BATS_ROOT_PID}-XXXXXX")
  REENTRANT_RUN_PRESERVE+=(BATS_CWD BATS_ROOT_PID BATS_RUN_TMPDIR)
  export BATS_LINE_REFERENCE_FORMAT=comma_line
  export BATS_BEGIN_CODE_QUOTE='`'
  export BATS_END_CODE_QUOTE="'"
  export BATS_CODE_QUOTE_STYLE="\`'"
}

fixtures() {
  FIXTURE_ROOT="$BATS_TEST_DIRNAME/fixtures/$1"
  # shellcheck disable=SC2034
  RELATIVE_FIXTURE_ROOT="${FIXTURE_ROOT#"$BATS_CWD"/}"
  if [[ $BATS_ROOT == "$BATS_CWD" ]]; then
    RELATIVE_BATS_ROOT=''
  else
    RELATIVE_BATS_ROOT=${BATS_ROOT#"$BATS_CWD"/}
  fi
  if [[ -n "$RELATIVE_BATS_ROOT" && "$RELATIVE_BATS_ROOT" != */ ]]; then
    RELATIVE_BATS_ROOT+=/
  fi
}

filter_control_sequences() {
  local status=0
  "$@" | sed $'s,\x1b\\[[0-9;]*[a-zA-Z],,g' || status=$?
  return "$status"
}

if ! command -v tput >/dev/null; then
  tput() {
    printf '1000\n'
  }
  export -f tput
fi

emit_debug_output() {
  # shellcheck disable=SC2154
  printf '%s\n' 'output:' "$output" >&2
}

execute_with_unset_bats_vars() { # <command to execute...>
  for var_to_delete in "${!BATS_@}"; do
    for var_to_exclude in "${REENTRANT_RUN_PRESERVE[@]-}"; do
      # is this var excluded -> skip unset
      if [[ $var_to_delete == "$var_to_exclude" ]]; then
        continue 2
      fi
    done
    unset "$var_to_delete"
  done
  "$@"
}

REENTRANT_RUN_PRESERVE+=(BATS_SAVED_PATH BATS_ROOT BATS_TEST_TAGS BATS_PARALLEL_BINARY_NAME BATS_LIBDIR BATS_killer_pid)
# readonly variables cannot be unset before a reentrant run
REENTRANT_RUN_PRESERVE+=(BATS_LIBEXEC BATS_TEST_FILENAME BATS_TEST_FILE_NUMBER BATS_FILE_TMPDIR BATS_SUITE_TMPDIR)

# call run with all BATS_* variables purged from the environment
reentrant_run() { # <same args as run>
  # take up all args to run except the command,
  # to avoid having to deal with empty arrays in Bash 3
  local -a pre_command_args=()

  # remove all flags to run to leave the command in $@
  while [[ $1 == -* || $1 == ! ]]; do
    pre_command_args+=("$1")
    if [[ "$1" == -- ]]; then
      shift
      break
    fi
    shift
  done

  # put that here to ensure Bash 3 won't have to deal with empty pre_command_args
  pre_command_args+=(execute_with_unset_bats_vars)

  run "${pre_command_args[@]}" "$@"
}
