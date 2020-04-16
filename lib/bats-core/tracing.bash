#!/usr/bin/env bash

bats_capture_stack_trace() {
	local test_file
	local funcname
	local i

	BATS_DEBUG_LAST_STACK_TRACE=()

	for ((i = 2; i != ${#FUNCNAME[@]}; ++i)); do
		# Use BATS_TEST_SOURCE if necessary to work around Bash < 4.4 bug whereby
		# calling an exported function erases the test file's BASH_SOURCE entry.
		test_file="${BASH_SOURCE[$i]:-$BATS_TEST_SOURCE}"
		funcname="${FUNCNAME[$i]}"
		BATS_DEBUG_LAST_STACK_TRACE+=("${BASH_LINENO[$((i-1))]} $funcname $test_file")
		if [[ "$test_file" == "$BATS_TEST_SOURCE" ]]; then
			case "$funcname" in
			"$BATS_TEST_NAME" | setup | teardown | setup_file | teardown_file)
				break
				;;
			esac
		fi
	done
}

bats_get_failure_stack_trace() {
	local stack_trace_var
	# See bats_debug_trap for details.
	if [[ -n "${BATS_DEBUG_LAST_STACK_TRACE_IS_VALID}" ]]; then
		stack_trace_var=BATS_DEBUG_LAST_STACK_TRACE
	else
		stack_trace_var=BATS_DEBUG_LASTLAST_STACK_TRACE
	fi
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

		if [[ $index -eq 1 ]]; then
			printf '# ('
		else
			printf '#  '
		fi

		local fn
		bats_frame_function "$frame" 'fn'
		if [[ "$fn" != "$BATS_TEST_NAME" ]]; then
			printf "from function \`%s' " "$fn"
		fi

		if [[ $index -eq $count ]]; then
			printf 'in test file %s, line %d)\n' "$filename" "$lineno"
		else
			printf 'in file %s, line %d,\n' "$filename" "$lineno"
		fi

		((++index))
	done
}

bats_print_failed_command() {
	local stack_trace=("${@}")
	local frame="${stack_trace[${#stack_trace[@]} - 1]}"
	local filename
	local lineno
	local failed_line
	local failed_command

	bats_frame_filename "$frame" 'filename'
	bats_frame_lineno "$frame" 'lineno'
	bats_extract_line "$filename" "$lineno" 'failed_line'
	bats_strip_string "$failed_line" 'failed_command'
	printf '%s' "#   \`${failed_command}' "

	if [[ "$BATS_ERROR_STATUS" -eq 1 ]]; then
		printf 'failed\n'
	else
		printf 'failed with status %d\n' "$BATS_ERROR_STATUS"
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

	if [[ "$__bff_filename" == "$BATS_TEST_SOURCE" ]]; then
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
	printf -v "$2" '%s' "${1#$BATS_CWD/}"
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
	# don't update the trace within library functions or we get backtraces from inside traps
	if [[ "$1" != $BATS_ROOT/lib/* && "$1" != $BATS_ROOT/libexec/* ]]; then
		BATS_DEBUG_LASTLAST_STACK_TRACE=(
			${BATS_DEBUG_LAST_STACK_TRACE[@]+"${BATS_DEBUG_LAST_STACK_TRACE[@]}"}
		)

		BATS_DEBUG_LAST_LINENO=(${BASH_LINENO[@]+"${BASH_LINENO[@]}"})
		BATS_DEBUG_LAST_SOURCE=(${BASH_SOURCE[@]+"${BASH_SOURCE[@]}"})
		bats_capture_stack_trace
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
	if [[ -z "$BATS_TEST_COMPLETED" ]]; then
		BATS_ERROR_STATUS="${BATS_ERROR_STATUS:-$status}"
		if [[ "$BATS_ERROR_STATUS" -eq 0 ]]; then
			BATS_ERROR_STATUS=1
		fi
		trap - DEBUG
	fi
}

bats_error_trap() {
  bats_check_status_from_trap

  # If necessary, undo the most recent stack trace captured by bats_debug_trap.
  # See bats_debug_trap for details.
  if [[ "${BASH_LINENO[*]}" = "${BATS_DEBUG_LAST_LINENO[*]:-}"
     && "${BASH_SOURCE[*]}" = "${BATS_DEBUG_LAST_SOURCE[*]:-}" ]]; then
    BATS_DEBUG_LAST_STACK_TRACE=(
      ${BATS_DEBUG_LASTLAST_STACK_TRACE[@]+"${BATS_DEBUG_LASTLAST_STACK_TRACE[@]}"}
    )
  fi
  BATS_DEBUG_LAST_STACK_TRACE_IS_VALID=1
}
