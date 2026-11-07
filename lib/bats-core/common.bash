#!/usr/bin/env bash

bats_prefix_lines_for_tap_output() {
  while IFS= read -r line; do
    printf '# %s\n' "$line" || break # avoid feedback loop when errors are redirected into BATS_OUT (see #353)
  done
  if [[ -n "$line" ]]; then
    printf '# %s\n' "$line"
  fi
}

function bats_replace_filename() {
  local line
  while read -r line; do
    printf "%s\n" "${line//$BATS_TEST_SOURCE/$BATS_TEST_FILENAME}"
  done
  if [[ -n "$line" ]]; then
    printf "%s\n" "${line//$BATS_TEST_SOURCE/$BATS_TEST_FILENAME}"
  fi
}

bats_quote_code() { # <var> <code>
  printf -v "$1" -- "%s%s%s" "$BATS_BEGIN_CODE_QUOTE" "$2" "$BATS_END_CODE_QUOTE"
}

bats_check_valid_version() {
  if [[ ! $1 =~ [0-9]+.[0-9]+.[0-9]+ ]]; then
    printf "ERROR: version '%s' must be of format <major>.<minor>.<patch>!\n" "$1" >&2
    exit 1
  fi
}

# compares two versions. Return 0 when version1 < version2
bats_version_lt() { # <version1> <version2>
  bats_check_valid_version "$1"
  bats_check_valid_version "$2"

  local -a version1_parts version2_parts
  IFS=. read -ra version1_parts <<<"$1"
  IFS=. read -ra version2_parts <<<"$2"

  local -i i
  for i in {0..2}; do
    if ((version1_parts[i] < version2_parts[i])); then
      return 0
    elif ((version1_parts[i] > version2_parts[i])); then
      return 1
    fi
  done
  # if we made it this far, they are equal -> also not less then
  return 2 # use other failing return code to distinguish equal from gt
}

# ensure a minimum version of bats is running or exit with failure
bats_require_minimum_version() { # <required version>
  local required_minimum_version=$1

  if bats_version_lt "$BATS_VERSION" "$required_minimum_version"; then
    printf "BATS_VERSION=%s does not meet required minimum %s\n" "$BATS_VERSION" "$required_minimum_version"
    exit 1
  fi

  if bats_version_lt "$BATS_GUARANTEED_MINIMUM_VERSION" "$required_minimum_version"; then
    BATS_GUARANTEED_MINIMUM_VERSION="$required_minimum_version"
  fi
}

# returns 0 when search-value is found in array
bats_linear_reverse_search() { # <search-value> <array-name>
  local -r search_value=$1 array_name=$2
  eval "local -ri array_length=\${#${array_name}[@]}"
  # shellcheck disable=SC2154
  for ((i = array_length - 1; i >= 0; --i)); do
    eval "local value=\"\${${array_name}[i]}\""
    # shellcheck disable=SC2154
    if [[ $value == "$search_value" ]]; then
      return 0
    fi
  done
  return 1
}

# returns 0 when search-value is found in array
bats_binary_search() { # <search-value> <array-name>
  if [[ $# -ne 2 ]]; then
    printf "ERROR: bats_binary_search requires exactly 2 arguments: <search value> <array name>\n" >&2
    return 2
  fi

  local -r search_value=$1 array_name=$2

  # we'd like to test if array is set but we cannot distinguish unset from empty arrays, so we need to skip that

  local start=0 mid end mid_value
  # start is inclusive, end is exclusive ...
  eval "end=\${#${array_name}[@]}"

  # so start == end means empty search space
  while ((start < end)); do
    mid=$(((start + end) / 2))
    eval "mid_value=\${${array_name}[$mid]}"
    if [[ "$mid_value" == "$search_value" ]]; then
      return 0
    elif [[ "$mid_value" < "$search_value" ]]; then
      # This branch excludes equality -> +1 to skip the mid element.
      # This +1 also avoids endless recursion on odd sized search ranges.
      start=$((mid + 1))
    else
      end=$mid
    fi
  done

  # did not find it -> its not there
  return 1
}

# store the values in ascending (string!) order in result array
# Intended for short lists! (uses insertion sort)
bats_sort() { # <result-array-name> <values to sort...>
  local -r result_name=$1
  shift

  if (($# == 1)) && [[ $1 == "" ]]; then
    shift # remove leading "" to deal with bash 3 expanding "${empty_array[@]}" to one ""
  fi

  if (($# == 0)); then
    eval "$result_name=()"
    return 0
  fi

  local -a sorted_array=()
  local -i i
  while (($# > 0)); do # loop over input values
    local current_value="$1"
    shift
    for ((i = ${#sorted_array[@]}; i >= 0; --i)); do # loop over output array from end
      if ((i == 0)) || [[ ${sorted_array[i - 1]} < $current_value ]]; then
        # insert new element at (freed) desired location
        sorted_array[i]=$current_value
        break
      else
        # shift bigger elements one position to the end
        sorted_array[i]=${sorted_array[i - 1]}
      fi
    done
  done

  eval "$result_name=(\"\${sorted_array[@]}\")"
}

# check if all search values (must be sorted!) are in the (sorted!) array
# Intended for short lists/arrays!
bats_all_in() { # <sorted-array> <sorted search values...>
  local -r haystack_array=$1
  shift

  local -i haystack_length # just to appease shellcheck
  eval "local -r haystack_length=\${#${haystack_array}[@]}"

  local -i haystack_index=0         # initialize only here to continue from last search position
  local search_value haystack_value # just to appease shellcheck
  local -i i
  for ((i = 1; i <= $#; ++i)); do
    eval "local search_value=${!i}"
    for (( ; haystack_index < haystack_length; ++haystack_index)); do
      eval "local haystack_value=\${${haystack_array}[$haystack_index]}"
      if [[ $haystack_value > "$search_value" ]]; then
        # we passed the location this value would have been at -> not found
        return 1
      elif [[ $haystack_value == "$search_value" ]]; then
        continue 2 # search value found  -> try the next one
      fi
    done
    return 1 # we ran of the end of the haystack without finding the value!
  done

  # did not return from loop above -> all search values were found
  return 0
}

# check if any search value (must be sorted!) is in the (sorted!) array
# intended for short lists/arrays
bats_any_in() { # <sorted-array> <sorted search values>
  local -r haystack_array=$1
  shift

  local -i haystack_length # just to appease shellcheck
  eval "local -r haystack_length=\${#${haystack_array}[@]}"

  local -i haystack_index=0         # initialize only here to continue from last search position
  local search_value haystack_value # just to appease shellcheck
  local -i i
  for ((i = 1; i <= $#; ++i)); do
    eval "local search_value=${!i}"
    for (( ; haystack_index < haystack_length; ++haystack_index)); do
      eval "local haystack_value=\${${haystack_array}[$haystack_index]}"
      if [[ $haystack_value > "$search_value" ]]; then
        continue 2 # search value not in array! -> try next
      elif [[ $haystack_value == "$search_value" ]]; then
        return 0 # search value found
      fi
    done
  done

  # did not return from loop above -> no search value was found
  return 1
}

bats_trim() {                                            # <output-variable> <string>
  local -r bats_trim_ltrimmed=${2#"${2%%[![:space:]]*}"} # cut off leading whitespace
  # shellcheck disable=SC2034 # used in eval!
  local -r bats_trim_trimmed=${bats_trim_ltrimmed%"${bats_trim_ltrimmed##*[![:space:]]}"} # cut off trailing whitespace
  eval "$1=\$bats_trim_trimmed"
}

# a helper function to work around unbound variable errors with ${arr[@]} on Bash 3
bats_append_arrays_as_args() { # <array...> -- <command ...>
  local -a trailing_args=()
  while (($# > 0)) && [[ $1 != -- ]]; do
    local array=$1
    shift

    if eval "(( \${#${array}[@]} > 0 ))"; then
      eval "trailing_args+=(\"\${${array}[@]}\")"
    fi
  done
  shift # remove -- separator

  if (($# == 0)); then
    printf "Error: append_arrays_as_args is missing a command or -- separator\n" >&2
    return 1
  fi

  if ((${#trailing_args[@]} > 0)); then
    "$@" "${trailing_args[@]}"
  else
    "$@"
  fi
}

bats_format_file_line_reference() { # <output> <file> <line>
  # shellcheck disable=SC2034 # will be used in subimplementation
  local output="${1?}"
  shift
  "bats_format_file_line_reference_${BATS_LINE_REFERENCE_FORMAT?}" "$@"
}

bats_format_file_line_reference_comma_line() {
  printf -v "$output" "%s, line %d" "$@"
}

bats_format_file_line_reference_colon() {
  printf -v "$output" "%s:%d" "$@"
}

# approximate realpath without subshell
bats_approx_realpath() { # <output-variable> <path>
  local output=$1 path=$2
  if [[ $path != /* ]]; then
    path="$PWD/$path"
  fi
  # x/./y -> x/y
  path=${path//\/.\//\/}
  printf -v "$output" "%s" "$path"
}

bats_format_file_line_reference_uri() {
  local filename=${1?} line=${2?}
  bats_approx_realpath filename "$filename"
  printf -v "$output" "file://%s:%d" "$filename" "$line"
}

# execute command with backed up path
# to prevent path mocks from interfering with our internals
bats_execute() { # <command...>
  PATH="${BATS_SAVED_PATH?}" "$@"
}
