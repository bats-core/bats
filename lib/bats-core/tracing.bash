#!/usr/bin/env bash

# shellcheck source=lib/bats-core/common.bash
source "$BATS_ROOT/$BATS_LIBDIR/bats-core/common.bash"

# set limit such that traces are only captured for calls at the same depth as this function in the calltree
bats_set_stacktrace_limit() {
  BATS_STACK_TRACE_LIMIT=$((${#FUNCNAME[@]} - 1)) # adjust by -1 to account for call to this functions
}

bats_capture_stack_trace() {
  local test_file
  local funcname
  local i

  BATS_DEBUG_LAST_STACK_TRACE=()
  local limit=$((${#FUNCNAME[@]} - ${BATS_STACK_TRACE_LIMIT-0}))
  # TODO: why is the line number off by one in  @test "--trace recurses into functions but not into run"
  for ((i = 2; i < limit; ++i)); do
    # Use BATS_TEST_SOURCE if necessary to work around Bash < 4.4 bug whereby
    # calling an exported function erases the test file's BASH_SOURCE entry.
    test_file="${BASH_SOURCE[$i]:-$BATS_TEST_SOURCE}"
    funcname="${FUNCNAME[$i]}"
    BATS_DEBUG_LAST_STACK_TRACE+=("${BASH_LINENO[$((i - 1))]} $funcname $test_file")
  done
}

bats_get_failure_stack_trace() {
  local stack_trace_var
  # See bats_debug_trap for details.
  if [[ -n "${BATS_DEBUG_LAST_STACK_TRACE_IS_VALID:-}" ]]; then
    stack_trace_var=BATS_DEBUG_LAST_STACK_TRACE
  else
    stack_trace_var=BATS_DEBUG_LASTLAST_STACK_TRACE
  fi
  # shellcheck disable=SC2016
  eval "$(printf \
    '%s=(${%s[@]+"${%s[@]}"})' \
    "${1}" \
    "${stack_trace_var}" \
    "${stack_trace_var}")"
}

bats_print_stack_trace() {
  local frame
  local index=1
  local count="${#@}"
  local filename
  local lineno

  for frame in "$@"; do
    bats_frame_filename "$frame" 'filename'
    bats_trim_filename "$filename" 'filename'
    bats_frame_lineno "$frame" 'lineno'

    printf '%s' "${BATS_STACK_TRACE_PREFIX-# }"
    if [[ $index -eq 1 ]]; then
      printf '('
    else
      printf ' '
    fi

    local fn
    bats_frame_function "$frame" 'fn'
    if [[ "$fn" != "${BATS_TEST_NAME-}" ]] &&
      # don't print "from function `source'"",
      # when failing in free code during `source $test_file` from bats-exec-file
      ! [[ "$fn" == 'source' && $index -eq $count ]]; then
      local quoted_fn
      bats_quote_code quoted_fn "$fn"
      printf "from function %s " "$quoted_fn"
    fi

    local reference
    bats_format_file_line_reference reference "$filename" "$lineno"
    if [[ $index -eq $count ]]; then
      printf 'in test file %s)\n' "$reference"
    else
      printf 'in file %s,\n' "$reference"
    fi

    ((++index))
  done
}

bats_print_failed_command() {
  local stack_trace=("${@}")
  if [[ ${#stack_trace[@]} -eq 0 ]]; then
    return 0
  fi
  local frame="${stack_trace[${#stack_trace[@]} - 1]}"
  local filename
  local lineno
  local failed_line
  local failed_command

  bats_frame_filename "$frame" 'filename'
  bats_frame_lineno "$frame" 'lineno'
  bats_extract_line "$filename" "$lineno" 'failed_line'
  bats_strip_string "$failed_line" 'failed_command'
  local quoted_failed_command
  bats_quote_code quoted_failed_command "$failed_command"
  printf '#   %s ' "${quoted_failed_command}"

  if [[ "${BATS_TIMED_OUT-NOTSET}" != NOTSET ]]; then
    # the other values can be safely overwritten here,
    # as the timeout is the primary reason for failure
    BATS_ERROR_SUFFIX=" due to timeout"
  fi

  if [[ "$BATS_ERROR_STATUS" -eq 1 ]]; then
    printf 'failed%s\n' "$BATS_ERROR_SUFFIX"
  else
    printf 'failed with status %d%s\n' "$BATS_ERROR_STATUS" "$BATS_ERROR_SUFFIX"
  fi
}

bats_frame_lineno() {
  printf -v "$2" '%s' "${1%% *}"
}

bats_frame_function() {
  local __bff_function="${1#* }"
  printf -v "$2" '%s' "${__bff_function%% *}"
}

bats_frame_filename() {
  local __bff_filename="${1#* }"
  __bff_filename="${__bff_filename#* }"

  if [[ "$__bff_filename" == "${BATS_TEST_SOURCE-}" ]]; then
    __bff_filename="$BATS_TEST_FILENAME"
  fi
  printf -v "$2" '%s' "$__bff_filename"
}

bats_extract_line() {
  local __bats_extract_line_line
  local __bats_extract_line_index=0

  while IFS= read -r __bats_extract_line_line; do
    if [[ "$((++__bats_extract_line_index))" -eq "$2" ]]; then
      printf -v "$3" '%s' "${__bats_extract_line_line%$'\r'}"
      break
    fi
  done <"$1"
}

bats_strip_string() {
  [[ "$1" =~ ^[[:space:]]*(.*)[[:space:]]*$ ]]
  printf -v "$2" '%s' "${BASH_REMATCH[1]}"
}

bats_trim_filename() {
  printf -v "$2" '%s' "${1#"$BATS_CWD"/}"
}

# normalize a windows path from e.g. C:/directory to /c/directory
# The path must point to an existing/accessible directory, not a file!
bats_normalize_windows_dir_path() { # <output-var> <path>
  local output_var="$1" path="$2"
  if [[ "$output_var" != NORMALIZED_INPUT ]]; then
    local NORMALIZED_INPUT
  fi
  if [[ $path == ?:* ]]; then
    NORMALIZED_INPUT="$(
      cd "$path" || exit 1
      pwd
    )"
  else
    NORMALIZED_INPUT="$path"
  fi
  printf -v "$output_var" "%s" "$NORMALIZED_INPUT"
}

bats_emit_trace_context() {
  local padding='$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$'
  local reference
  bats_format_file_line_reference reference "${file##*/}" "$line"
  printf '%s [%s]\n' "${padding::${#BASH_LINENO[@]}-limit-3}" "$reference" >&4
}

bats_emit_trace_command() {
  local padding='$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$'
  printf '%s %s\n' "${padding::${#BASH_LINENO[@]}-limit-3}" "$BASH_COMMAND" >&4

  # keep track of printed commands
  BATS_LAST_BASH_COMMAND="$BASH_COMMAND"
  BATS_LAST_BASH_LINENO="$line"
}

BATS_EMIT_TRACE_LAST_STACK_DIFF=0

bats_emit_trace() {
  if [[ ${BATS_TRACE_LEVEL:-0} -gt 0 ]]; then
    local line=${BASH_LINENO[1]} limit=${BATS_STACK_TRACE_LIMIT-0}
    # shellcheck disable=SC2016
    if
      ((${#FUNCNAME[@]} > limit + 2)) # only emit below BATS_STRACK_TRACE_LIMIT (adjust by 2 for trap+this function call)
      # avoid printing the same line twice on errexit
      [[ $BASH_COMMAND != "$BATS_LAST_BASH_COMMAND" || $line != "$BATS_LAST_BASH_LINENO" ]]
    then
      local file="${BASH_SOURCE[2]}" # index 2: skip over bats_emit_trace and bats_debug_trap
      if [[ $file == "${BATS_TEST_SOURCE:-}" ]]; then
        file="$BATS_TEST_FILENAME"
      fi
      # stack size difference since last call of this function
      # <0: means new function call
      # >0: means return
      # =0: in same function as before (assuming we did not skip return/call)
      local stack_diff=$((BATS_LAST_STACK_DEPTH - ${#BASH_LINENO[@]}))
      # show context immediately when returning or on second command in new function
      # as the first "command" is the function itself
      if ((stack_diff > 0)) || ((BATS_EMIT_TRACE_LAST_STACK_DIFF < 0)); then
        bats_emit_trace_context
      fi
      # only print command when moving up or staying in same function
      # again, avoids printing the first command (the function itself) in new function
      if ((stack_diff >= 0)); then
        bats_emit_trace_command
      fi

      BATS_EMIT_TRACE_LAST_STACK_DIFF=$stack_diff
    fi
    # always update to detect stack depth changes regardless of printing
    BATS_LAST_STACK_DEPTH="${#BASH_LINENO[@]}"
  fi
}

# bats_debug_trap tracks the last line of code executed within a test. This is
# necessary because $BASH_LINENO is often incorrect inside of ERR and EXIT
# trap handlers.
#
# Below are tables describing different command failure scenarios and the
# reliability of $BASH_LINENO within different the executed DEBUG, ERR, and EXIT
# trap handlers. Naturally, the behaviors change between versions of Bash.
#
# Table rows should be read left to right. For example, on bash version
# 4.0.44(2)-release, if a test executes `false` (or any other failing external
# command), bash will do the following in order:
# 1. Call the DEBUG trap handler (bats_debug_trap) with $BASH_LINENO referring
#    to the source line containing the `false` command, then
# 2. Call the DEBUG trap handler again, but with an incorrect $BASH_LINENO, then
# 3. Call the ERR trap handler, but with a (possibly-different) incorrect
#    $BASH_LINENO, then
# 4. Call the DEBUG trap handler again, but with $BASH_LINENO set to 1, then
# 5. Call the EXIT trap handler, with $BASH_LINENO set to 1.
#
# bash version 4.4.20(1)-release
#  command     | first DEBUG | second DEBUG | ERR     | third DEBUG | EXIT
# -------------+-------------+--------------+---------+-------------+--------
#  false       | OK          | OK           | OK      | BAD[1]      | BAD[1]
#  [[ 1 = 2 ]] | OK          | BAD[2]       | BAD[2]  | BAD[1]      | BAD[1]
#  (( 1 = 2 )) | OK          | BAD[2]       | BAD[2]  | BAD[1]      | BAD[1]
#  ! true      | OK          | ---          | BAD[4]  | ---         | BAD[1]
#  $var_dne    | OK          | ---          | ---     | BAD[1]      | BAD[1]
#  source /dne | OK          | ---          | ---     | BAD[1]      | BAD[1]
#
# bash version 4.0.44(2)-release
#  command     | first DEBUG | second DEBUG | ERR     | third DEBUG | EXIT
# -------------+-------------+--------------+---------+-------------+--------
#  false       | OK          | BAD[3]       | BAD[3]  | BAD[1]      | BAD[1]
#  [[ 1 = 2 ]] | OK          | ---          | BAD[3]  | ---         | BAD[1]
#  (( 1 = 2 )) | OK          | ---          | BAD[3]  | ---         | BAD[1]
#  ! true      | OK          | ---          | BAD[3]  | ---         | BAD[1]
#  $var_dne    | OK          | ---          | ---     | BAD[1]      | BAD[1]
#  source /dne | OK          | ---          | ---     | BAD[1]      | BAD[1]
#
# [1] The reported line number is always 1.
# [2] The reported source location is that of the beginning of the function
#     calling the command.
# [3] The reported line is that of the last command executed in the DEBUG trap
#     handler.
# [4] The reported source location is that of the call to the function calling
#     the command.
bats_debug_trap() {
  # on windows we sometimes get a mix of paths (when install via nmp install -g)
  # which have C:/... or /c/... comparing them is going to be problematic.
  # We need to normalize them to a common format!
  local NORMALIZED_INPUT
  bats_normalize_windows_dir_path NORMALIZED_INPUT "${1%/*}"
  local path
  for path in "${BATS_DEBUG_EXCLUDE_PATHS[@]}"; do
    if [[ "$NORMALIZED_INPUT" == "$path"* ]]; then
      return # skip this call
    fi
  done

  # don't update the trace within library functions or we get backtraces from inside traps
  # also don't record new stack traces while handling interruptions, to avoid overriding the interrupted command
  if [[ "${BATS_INTERRUPTED-NOTSET}" == NOTSET &&
    "${BATS_TIMED_OUT-NOTSET}" == NOTSET ]]; then
    BATS_DEBUG_LASTLAST_STACK_TRACE=(
      ${BATS_DEBUG_LAST_STACK_TRACE[@]+"${BATS_DEBUG_LAST_STACK_TRACE[@]}"}
    )

    BATS_DEBUG_LAST_LINENO=(${BASH_LINENO[@]+"${BASH_LINENO[@]}"})
    BATS_DEBUG_LAST_SOURCE=(${BASH_SOURCE[@]+"${BASH_SOURCE[@]}"})
    bats_capture_stack_trace
    bats_emit_trace
  fi
}

# For some versions of Bash, the `ERR` trap may not always fire for every
# command failure, but the `EXIT` trap will. Also, some command failures may not
# set `$?` properly. See #72 and #81 for details.
#
# For this reason, we call `bats_check_status_from_trap` at the very beginning
# of `bats_teardown_trap` and check the value of `$BATS_TEST_COMPLETED` before
# taking other actions. We also adjust the exit status value if needed.
#
# See `bats_exit_trap` for an additional EXIT error handling case when `$?`
# isn't set properly during `teardown()` errors.
bats_check_status_from_trap() {
  local status="$?"
  if [[ -z "${BATS_TEST_COMPLETED:-}" ]]; then
    BATS_ERROR_STATUS="${BATS_ERROR_STATUS:-$status}"
    if [[ "$BATS_ERROR_STATUS" -eq 0 ]]; then
      BATS_ERROR_STATUS=1
    fi
    trap - DEBUG
  fi
}

bats_add_debug_exclude_path() { # <path>
  if [[ -z "$1" ]]; then        # don't exclude everything
    printf "bats_add_debug_exclude_path: Exclude path must not be empty!\n" >&2
    return 1
  fi
  if [[ "$OSTYPE" == cygwin || "$OSTYPE" == msys ]]; then
    local normalized_dir
    bats_normalize_windows_dir_path normalized_dir "$1"
    BATS_DEBUG_EXCLUDE_PATHS+=("$normalized_dir")
  else
    BATS_DEBUG_EXCLUDE_PATHS+=("$1")
  fi
}

bats_setup_tracing() {
  # Variables for capturing accurate stack traces. See bats_debug_trap for
  # details.
  #
  # BATS_DEBUG_LAST_LINENO, BATS_DEBUG_LAST_SOURCE, and
  # BATS_DEBUG_LAST_STACK_TRACE hold data from the most recent call to
  # bats_debug_trap.
  #
  # BATS_DEBUG_LASTLAST_STACK_TRACE holds data from two bats_debug_trap calls
  # ago.
  #
  # BATS_DEBUG_LAST_STACK_TRACE_IS_VALID indicates that
  # BATS_DEBUG_LAST_STACK_TRACE contains the stack trace of the test's error. If
  # unset, BATS_DEBUG_LAST_STACK_TRACE is unreliable and
  # BATS_DEBUG_LASTLAST_STACK_TRACE should be used instead.
  BATS_DEBUG_LASTLAST_STACK_TRACE=()
  BATS_DEBUG_LAST_LINENO=()
  BATS_DEBUG_LAST_SOURCE=()
  BATS_DEBUG_LAST_STACK_TRACE=()
  BATS_DEBUG_LAST_STACK_TRACE_IS_VALID=
  BATS_ERROR_SUFFIX=
  BATS_DEBUG_EXCLUDE_PATHS=()
  # exclude some paths by default
  bats_add_debug_exclude_path "$BATS_ROOT/$BATS_LIBDIR/"
  bats_add_debug_exclude_path "$BATS_ROOT/libexec/"

  exec 4<&1 # used for tracing
  if [[ "${BATS_TRACE_LEVEL:-0}" -gt 0 ]]; then
    # avoid undefined variable errors
    BATS_LAST_BASH_COMMAND=
    BATS_LAST_BASH_LINENO=
    BATS_LAST_STACK_DEPTH=
    # try to exclude helper libraries if found, this is only relevant for tracing
    while read -r path; do
      bats_add_debug_exclude_path "$path"
    done < <(find "$PWD" -type d -name bats-assert -o -name bats-support)
  fi

  local exclude_paths path
  # exclude user defined libraries
  IFS=':' read -r exclude_paths <<<"${BATS_DEBUG_EXCLUDE_PATHS:-}"
  for path in "${exclude_paths[@]}"; do
    if [[ -n "$path" ]]; then
      bats_add_debug_exclude_path "$path"
    fi
  done

  # turn on traps after setting excludes to avoid tracing the exclude setup
  trap 'bats_debug_trap "$BASH_SOURCE" "$_"' DEBUG
  trap 'bats_error_trap "$_"' ERR
}

# predefine to avoid problems when the user does not declare one
bats::on_failure() {
  :
}

bats_error_trap() {
  bats_check_status_from_trap
  bats::on_failure "$BATS_ERROR_STATUS"

  # If necessary, undo the most recent stack trace captured by bats_debug_trap.
  # See bats_debug_trap for details.
  if [[ "${BASH_LINENO[*]}" = "${BATS_DEBUG_LAST_LINENO[*]:-}" &&
    "${BASH_SOURCE[*]}" = "${BATS_DEBUG_LAST_SOURCE[*]:-}" &&
    -z "$BATS_DEBUG_LAST_STACK_TRACE_IS_VALID" ]]; then
    BATS_DEBUG_LAST_STACK_TRACE=(
      ${BATS_DEBUG_LASTLAST_STACK_TRACE[@]+"${BATS_DEBUG_LASTLAST_STACK_TRACE[@]}"}
    )
  fi
  BATS_DEBUG_LAST_STACK_TRACE_IS_VALID=1
}

bats_interrupt_trap() {
  # mark the interruption, to handle during exit
  BATS_INTERRUPTED=true
  BATS_ERROR_STATUS=130
  # debug trap fires before interrupt trap but gets wrong linenumber (line 1)
  # -> use last stack trace instead of BATS_DEBUG_LAST_STACK_TRACE_IS_VALID=true
}

# this is used inside run()
bats_interrupt_trap_in_run() {
  # mark the interruption, to handle during exit
  BATS_INTERRUPTED=true
  BATS_ERROR_STATUS=130
  BATS_DEBUG_LAST_STACK_TRACE_IS_VALID=true
  exit 130
}
