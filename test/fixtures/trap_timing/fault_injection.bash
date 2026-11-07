# This file is loaded through BASH_ENV to inject a failure at an exact command
# boundary in another Bash process.
set -T

_bats_inject_fault() {
  local command=$1

  [[ ${0##*/} == "${BATS_FAULT_SCRIPT:-}" ]] || return 0
  # shellcheck disable=SC2053 # BATS_FAULT_COMMAND is intentionally a pattern.
  [[ $command == ${BATS_FAULT_COMMAND:-} ]] || return 0

  trap - DEBUG

  if [[ ${BATS_FAULT_CAPTURE:-} == TMPDIR ]]; then
    printf '%s\n' "$TMPDIR" >"$BATS_FAULT_CAPTURE_FILE"
  fi

  case ${BATS_FAULT_ACTION:-TERM} in
  TERM)
    kill -TERM "$$"
    ;;
  TERM-then-mark)
    kill -TERM "$$"
    : >"$BATS_FAULT_CONTINUED_FILE"
    ;;
  esac
}

trap '_bats_inject_fault "$BASH_COMMAND"' DEBUG
