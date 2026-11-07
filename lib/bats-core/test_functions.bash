#!/usr/bin/env bash

# this must be called for each test file!
_bats_test_functions_setup() { # <BATS_TEST_NUMBER>
  BATS_TEST_DIRNAME="${BATS_TEST_FILENAME%/*}"
  BATS_TEST_NAMES=()
  # shellcheck disable=SC2034
  BATS_TEST_NUMBER=${1?}
}

# shellcheck source=lib/bats-core/warnings.bash
source "$BATS_ROOT/$BATS_LIBDIR/bats-core/warnings.bash"

# find_in_bats_lib_path echoes the first recognized load path to
# a library in BATS_LIB_PATH or relative to BATS_TEST_DIRNAME.
#
# Libraries relative to BATS_TEST_DIRNAME take precedence over
# BATS_LIB_PATH.
#
# If no library is found find_in_bats_lib_path returns 1.
find_in_bats_lib_path() { # <return-var> <library-name>
  local return_var="${1:?}"
  local library_name="${2:?}"

  local -a bats_lib_paths
  IFS=: read -ra bats_lib_paths <<<"$BATS_LIB_PATH"

  for path in "${bats_lib_paths[@]}"; do
    if [[ -f "$path/$library_name" ]]; then
      printf -v "$return_var" "%s" "$path/$library_name"
      # A library load path was found, return
      return 0
    elif [[ -f "$path/$library_name/load.bash" ]]; then
      printf -v "$return_var" "%s" "$path/$library_name/load.bash"
      # A library load path was found, return
      return 0
    fi
  done

  return 1
}

# bats_internal_load expects an absolute path that is a library load path.
#
# If the library load path points to a file (a library loader) it is
# sourced.
#
# If it points to a directory all files ending in .bash inside of the
# directory are sourced.
#
# If the sourcing of the library loader or of a file in a library
# directory fails bats_internal_load prints an error message and returns 1.
#
# If the passed library load path is not absolute or is not a valid file
# or directory bats_internal_load prints an error message and returns 1.
bats_internal_load() {
  local library_load_path="${1:?}"

  if [[ "${library_load_path:0:1}" != / ]]; then
    printf "Passed library load path is not an absolute path: %s\n" "$library_load_path" >&2
    return 1
  fi

  # library_load_path is a library loader
  if [[ -f "$library_load_path" ]]; then
    # shellcheck disable=SC1090
    if ! source "$library_load_path"; then
      printf "Error while sourcing library loader at '%s'\n" "$library_load_path" >&2
      return 1
    fi
    return 0
  fi

  printf "Passed library load path is neither a library loader nor library directory: %s\n" "$library_load_path" >&2
  return 1
}

# bats_load_safe accepts an argument called 'slug' and attempts to find and
# source a library based on the slug.
#
# A slug can be an absolute path or a relative path.
#
# If the slug is not an absolute path it is resolved relative to
# BATS_TEST_DIRNAME
#
# The resolved slug is passed to bats_internal_load.
# If bats_internal_load fails bats_load_safe returns 1.
#
# If no library load path can be found bats_load_safe prints an error message
# and returns 1.
bats_load_safe() {
  local slug="${1:?}"
  if [[ ${slug:0:1} != / ]]; then # relative paths are relative to BATS_TEST_DIRNAME
    slug="$BATS_TEST_DIRNAME/$slug"
  fi

  if [[ -f "$slug.bash" ]]; then
    bats_internal_load "$slug.bash"
    return $?
  elif [[ -f "$slug" ]]; then
    bats_internal_load "$slug"
    return $?
  fi

  # loading from PATH (retained for backwards compatibility)
  if [[ ! -f "$1" ]] && type -P "$1" >/dev/null; then
    # shellcheck disable=SC1090
    source "$1"
    return $?
  fi

  # No library load path can be found
  printf "bats_load_safe: Could not find '%s'[.bash]\n" "$slug" >&2
  return 1
}

bats_load_library_safe() { # <slug>
  local slug="${1:?}" library_path

  # Check for library load paths in BATS_TEST_DIRNAME and BATS_LIB_PATH
  if [[ ${slug:0:1} != / ]]; then
    if ! find_in_bats_lib_path library_path "$slug"; then
      printf "Could not find library '%s' relative to test file or in BATS_LIB_PATH\n" "$slug" >&2
      return 1
    fi
  else
    # absolute paths are taken as is
    library_path="$slug"
    if [[ ! -f "$library_path" ]]; then
      printf "Could not find library on absolute path '%s'\n" "$library_path" >&2
      return 1
    fi
  fi

  bats_internal_load "$library_path"
  return $?
}

# immediately exit on error, use bats_load_library_safe to catch and handle errors
bats_load_library() { # <slug>
  if ! bats_load_library_safe "$@"; then
    # No ERR trap runs for this exit, and internal calls do not update the trace.
    BATS_DEBUG_LAST_STACK_TRACE_IS_VALID=1
    exit 1
  fi
}

# load acts like bats_load_safe but exits the shell instead of returning 1.
load() {
  if ! bats_load_safe "$@"; then
    # No ERR trap runs for this exit, and internal calls do not update the trace.
    BATS_DEBUG_LAST_STACK_TRACE_IS_VALID=1
    exit 1
  fi
}

bats_redirect_stderr_into_file() {
  "$@" 2>>"$bats_run_separate_stderr_file" # use >> to see collisions' content
}

bats_merge_stdout_and_stderr() {
  "$@" 2>&1
}

# write separate lines from <input-var> into <output-array>
bats_separate_lines() { # <output-array> <input-var>
  local -r output_array_name="$1"
  local -r input_var_name="$2"
  local input="${!input_var_name}"
  if [[ $keep_empty_lines ]]; then
    local bats_separate_lines_lines=()
    if [[ -n "$input" ]]; then # avoid getting an empty line for empty input
      # remove one trailing \n if it exists to compensate its addition by <<<
      input=${input%$'\n'}
      while IFS= read -r line; do
        bats_separate_lines_lines+=("$line")
      done <<<"${input}"
    fi
    eval "${output_array_name}=(\"\${bats_separate_lines_lines[@]}\")"
  else
    # shellcheck disable=SC2034,SC2206
    IFS=$'\n' read -d '' -r -a "$output_array_name" <<<"${!input_var_name}" || true # don't fail due to EOF
  fi
}

bats_errexit_subshell() { # <command with args...>
  (
    set -eET
    "$@"
  )
}

bats_pipe() { # [-N] [--] command0 [ \| command1 [ \| command2 [...]]]
  # This will run each command given, piping them appropriately.
  # Meant to be used in combination with `run` helper to allow piped commands
  # to be used.
  # Note that `\|` must be used, not `|`.
  # By default, the exit code of this command will be the last failure in the
  # chain of piped commands (similar to `set -o pipefail`).
  # Supplying -N (e.g. -0) will instead always use the exit code of the command
  # at that position in the chain.
  # --returned-status=N could be used as an alternative to -N. This also allows
  # for negative values (which count from the end in reverse order).

  local pipestatus_position=

  # parse options starting with -
  while [[ $# -gt 0 ]] && [[ $1 == -* ]]; do
    case "$1" in
    -[0-9]*)
      pipestatus_position="${1#-}"
      ;;
    --returned-status*)
      if [ "$1" = "--returned-status" ]; then
        pipestatus_position="$2"
        shift
      elif [[ "$1" =~ ^--returned-status= ]]; then
        pipestatus_position="${1#--returned-status=}"
      else
        printf "Usage error: unknown flag '%s'" "$1" >&2
        return 1
      fi
      ;;
    --)
      shift # eat the -- before breaking away
      break
      ;;
    *)
      printf "Usage error: unknown flag '%s'" "$1" >&2
      return 1
      ;;
    esac
    shift
  done

  # parse and validate arguments, escape as necessary
  local -a commands_and_args=("$@")
  local -a escaped_args=()
  local -i pipe_count=0
  local -i previous_pipe_index=-1
  local -i index=0
  for ((index = 0; index < $#; index++)); do
    local current_command_or_arg="${commands_and_args[$index]}"
    local escaped_arg="$current_command_or_arg"
    if [[ "$current_command_or_arg" != '|' ]]; then
      # escape args to protect them when eval'd (e.g. if they contain whitespace).
      printf -v escaped_arg "%q" "$current_command_or_arg"
    elif [ "$current_command_or_arg" = "|" ]; then
      if [ "$index" -eq 0 ]; then
        printf "Usage error: Cannot have leading \`\\|\`.\n" >&2
        return 1
      fi
      if (((previous_pipe_index + 1) >= index)); then
        printf "Usage error: Cannot have consecutive \`\\|\`. Found at argument position '%s'.\n" "$index" >&2
        return 1
      fi
      ((++pipe_count))
      previous_pipe_index="$index"
    fi
    escaped_args+=("$escaped_arg")
  done

  if (((previous_pipe_index > 0) && (previous_pipe_index == ($# - 1)))); then
    printf "Usage error: Cannot have trailing \`\\|\`.\n" >&2
    return 1
  fi

  if ((pipe_count == 0)); then
    # Don't allow for no pipes. This might be a typo in the test,
    # e.g. `run bats_pipe command0 | command1`
    # instead of `run bats_pipe command0 \| command1`
    # Unfortunately, we can't catch `run bats_pipe command0 \| command1 | command2`.
    # But this check is better than just allowing no pipes.
    printf "Usage error: No \`\\|\`s found. Is this an error?\n" >&2
    return 1
  fi

  # there will be pipe_count + 1 entries in PIPE_STATUS (pipe_count number of \|'s between each entry).
  # valid indices are [-(pipe_count + 1), pipe_count]
  if [ -n "$pipestatus_position" ] && (((pipestatus_position > pipe_count) || (-pipestatus_position > (pipe_count + 1)))); then
    printf "Usage error: Too large of -N argument (or --returned-status) given. Argument value: '%s'.\n" "$pipestatus_position" >&2
    return 1
  fi

  # run commands and return appropriate pipe status
  local -a __bats_pipe_eval_pipe_status=()
  eval "${escaped_args[*]}" '; __bats_pipe_eval_pipe_status=(${PIPESTATUS[@]})'

  local result_status=
  if [ -z "$pipestatus_position" ]; then
    # if we are performing default "last failure" behavior,
    # iterate backwards through pipe_status to find the last error.
    result_status=0
    for index in "${!__bats_pipe_eval_pipe_status[@]}"; do
      # OSX bash doesn't support negative indexing.
      local backward_iter_index="$((${#__bats_pipe_eval_pipe_status[@]} - index - 1))"
      local status_at_backward_iter_index="${__bats_pipe_eval_pipe_status[$backward_iter_index]}"
      if ((status_at_backward_iter_index != 0)); then
        result_status="$status_at_backward_iter_index"
        break
      fi
    done
  elif ((pipestatus_position >= 0)); then
    result_status="${__bats_pipe_eval_pipe_status[$pipestatus_position]}"
  else
    # Must use positive values for some bash's (like OSX).
    local backward_iter_index="$((${#__bats_pipe_eval_pipe_status[@]} + pipestatus_position))"
    result_status="${__bats_pipe_eval_pipe_status[$backward_iter_index]}"
  fi

  return "$result_status"
}

run() { # [!|-N] [--keep-empty-lines] [--separate-stderr] [--] <command to run...>
  local expected_rc=
  local keep_empty_lines=
  local output_case=merged
  local has_flags=
  # parse options starting with -
  while [[ $# -gt 0 ]] && [[ $1 == -* || $1 == '!' ]]; do
    has_flags=1
    case "$1" in
    '!')
      expected_rc=-1
      ;;
    -[0-9]*)
      expected_rc=${1#-}
      if [[ $expected_rc =~ [^0-9] ]]; then
        printf "Usage error: run: '-NNN' requires numeric NNN (got: %s)\n" "$expected_rc" >&2
        return 1
      elif [[ $expected_rc -gt 255 ]]; then
        printf "Usage error: run: '-NNN': NNN must be <= 255 (got: %d)\n" "$expected_rc" >&2
        return 1
      fi
      ;;
    --keep-empty-lines)
      keep_empty_lines=1
      ;;
    --separate-stderr)
      output_case="separate"
      ;;
    --)
      shift # eat the -- before breaking away
      break
      ;;
    *)
      printf "Usage error: unknown flag '%s'" "$1" >&2
      return 1
      ;;
    esac
    shift
  done

  local saved_traps
  saved_traps=$(trap -p INT ERR DEBUG)
  # This has to be restored on return from this function to avoid leaking our trap INT into surrounding code.
  # Non zero exits won't restore under the assumption that they will fail the test before it can be aborted,
  # which allows us to avoid duplicating the restore code on every exit path
  trap bats_interrupt_trap_in_run INT
  trap - ERR DEBUG

  if [[ -n $has_flags ]]; then
    bats_warn_minimum_guaranteed_version "Using flags on \`run\`" 1.5.0
  fi

  local -a pre_command=()
  # make sure tmpdir exists in case run() is called outside a @test
  local tmpdir=${BATS_TEST_TMPDIR:-${BATS_FILE_TMPDIR:-${BATS_RUN_TMPDIR}}}

  case "$output_case" in
  merged) # redirects stderr into stdout and fills only $output/$lines
    pre_command=(bats_merge_stdout_and_stderr)
    ;;
  separate) # splits stderr into own file and fills $stderr/$stderr_lines too
    local bats_run_separate_stderr_file
    bats_run_separate_stderr_file="$(mktemp "${tmpdir}/separate-stderr-XXXXXX")"
    pre_command=(bats_redirect_stderr_into_file)
    ;;
  esac

  if [[ -n "${BATS_RUN_ERREXIT:-}" ]]; then
    pre_command=(bats_errexit_subshell "${pre_command[@]}")
  fi

  local origFlags="$-"
  set +eET

  if [[ $keep_empty_lines ]]; then
    # 'output', 'status', 'lines' are global variables available to tests.
    # preserve trailing newlines by appending . and removing it later
    # shellcheck disable=SC2034
    output="$(
      "${pre_command[@]}" "$@"
      status=$?
      printf .
      exit $status
    )"
    status=$?
    output="${output%.}"
  else
    # 'output', 'status', 'lines' are global variables available to tests.
    # shellcheck disable=SC2034
    output="$("${pre_command[@]}" "$@")"
    status=$?
  fi

  bats_separate_lines lines output

  if [[ "$output_case" == separate ]]; then
    # shellcheck disable=SC2034
    read -d '' -r stderr <"$bats_run_separate_stderr_file" || true
    bats_separate_lines stderr_lines stderr
  else
    unset stderr stderr_lines
  fi

  # shellcheck disable=SC2034
  BATS_RUN_COMMAND="${*}"
  set "-$origFlags"

  bats_run_print_output() {
    if [[ -n "$output" ]]; then
      printf "%s\n" "$output"
    fi
    if [[ "$output_case" == separate && -n "$stderr" ]]; then
      printf "stderr:\n%s\n" "$stderr"
    fi
  }

  if [[ -n "$expected_rc" ]]; then
    if [[ "$expected_rc" = "-1" ]]; then
      if [[ "$status" -eq 0 ]]; then
        BATS_ERROR_SUFFIX=", expected nonzero exit code!"
        bats_run_print_output
        eval "$saved_traps"
        return 1
      fi
    elif [ "$status" -ne "$expected_rc" ]; then
      # shellcheck disable=SC2034
      BATS_ERROR_SUFFIX=", expected exit code $expected_rc, got $status"
      bats_run_print_output
      eval "$saved_traps"
      return 1
    fi
  elif [[ "$status" -eq 127 ]]; then # "command not found"
    bats_generate_warning 1 "$BATS_RUN_COMMAND"
  fi

  if [[ ${BATS_VERBOSE_RUN:-} ]]; then
    bats_run_print_output
  fi

  # don't leak our trap into surrounding code
  eval "$saved_traps"
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

bats_test_function() {
  local tags=() current_tags=()
  while (($# > 0)); do
    case "$1" in
    --description)
      local test_description=
      # use eval to resolve variable references in test names
      eval "printf -v test_description '%s' \"$2\""
      shift 2
      ;;
    --tags)
      if [[ "$2" != "" ]]; then # avoid unbound variable with set -u Bash 3
        IFS=',' read -ra current_tags <<<"$2"
        tags+=("${current_tags[@]}")
      fi
      shift 2
      ;;
    --)
      shift
      break
      ;;
    *)
      printf "ERROR: unknown option %s for bats_test_function" "$1" >&2
      exit 1
      ;;
    esac
  done

  if ((${#tags[@]} > 1)); then # avoid unbound variable with set -u Bash 3
    bats_sort tags "${tags[@]}"
  fi

  BATS_TEST_NAMES+=("$*")
  local quoted_parameters
  printf -v quoted_parameters " %q" "$@"
  quoted_parameters=${quoted_parameters:1} # cut off leading space

  # if this is the currently selected test, set tags and name
  # this should only be entered from bats-exec-test
  if [[ ${BATS_TEST_NAME-} == "$quoted_parameters" ]]; then
    # shellcheck disable=SC2034
    BATS_TEST_TAGS=("${tags[@]+${tags[@]}}")
    export BATS_TEST_DESCRIPTION="${test_description-$*}"
    # shellcheck disable=SC2034
    BATS_TEST_COMMAND=("$@")
  fi
}

# decides whether a failed test should be run again
bats_should_retry_test() {
  # test try number starts at 1
  # 0 retries means run only first try
  ((BATS_TEST_TRY_NUMBER <= BATS_TEST_RETRIES))
}
