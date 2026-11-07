@test bats_version_lt {
  bats_require_minimum_version 1.5.0
  run ! bats_version_lt 1.0.0 1.0
  [ "$output" = "ERROR: version '1.0' must be of format <major>.<minor>.<patch>!" ]

  run ! bats_version_lt 1.0 1.0.0
  [ "$output" = "ERROR: version '1.0' must be of format <major>.<minor>.<patch>!" ]

  run -0 bats_version_lt 1.0.0 2.0.0
  run -0 bats_version_lt 1.2.0 2.0.0
  run -0 bats_version_lt 1.2.3 2.0.0
  run -0 bats_version_lt 1.0.0 1.1.0
  run -0 bats_version_lt 1.0.2 1.1.0
  run -0 bats_version_lt 1.0.0 1.0.1

  run -1 bats_version_lt 2.0.0 1.0.0
  run -1 bats_version_lt 2.0.0 1.2.0
  run -1 bats_version_lt 2.0.0 1.2.3
  run -1 bats_version_lt 1.1.0 1.0.0
  run -1 bats_version_lt 1.1.0 1.0.2
  run -1 bats_version_lt 1.0.1 1.0.0

  run -2 bats_version_lt 1.0.0 1.0.0
}

@test bats_require_minimum_version {
  [ "$BATS_GUARANTEED_MINIMUM_VERSION" = 0.0.0 ] # check default

  bats_require_minimum_version 0.1.2 # (a version that should be safe not to fail)
  [ "${BATS_GUARANTEED_MINIMUM_VERSION}" = 0.1.2 ]

  # a higher version should upgrade
  bats_require_minimum_version 0.2.3
  [ "${BATS_GUARANTEED_MINIMUM_VERSION}" = 0.2.3 ]

  # a lower version should not change
  bats_require_minimum_version 0.1.2
  [ "${BATS_GUARANTEED_MINIMUM_VERSION}" = 0.2.3 ]
}

@test bats_binary_search {
  bats_require_minimum_version 1.5.0

  run -2 bats_binary_search "search-value"
  [ "$output" = "ERROR: bats_binary_search requires exactly 2 arguments: <search value> <array name>" ]

  # unset array = empty array: a bit unfortunate but we can't tell the difference (on older Bash?)
  unset no_array
  run -1 bats_binary_search "search-value" "no_array"

  # shellcheck disable=SC2034
  empty_array=()
  run -1 bats_binary_search "search-value" "empty_array"

  # shellcheck disable=SC2034
  odd_length_array=(1 2 3)
  run -1 bats_binary_search a odd_length_array
  run -0 bats_binary_search 1 odd_length_array
  run -0 bats_binary_search 2 odd_length_array
  run -0 bats_binary_search 3 odd_length_array

  # shellcheck disable=SC2034
  even_length_array=(1 2 3 4)
  run -1 bats_binary_search a even_length_array
  run -0 bats_binary_search 1 even_length_array
  run -0 bats_binary_search 2 even_length_array
  run -0 bats_binary_search 3 even_length_array
  run -0 bats_binary_search 4 even_length_array

}

@test bats_linear_reverse_search {
  bats_require_minimum_version 1.5.0
  # shellcheck disable=SC2030
  local -a empty one_element=(1) two_sorted=(1 2) two_elements_reversed=(2 1) three_elements_scrambled=(2 1 3)

  run -1 bats_linear_reverse_search 0 empty

  run -1 bats_linear_reverse_search 0 one_element
  run -0 bats_linear_reverse_search 1 one_element

  run -1 bats_linear_reverse_search 0 two_sorted
  run -0 bats_linear_reverse_search 1 two_sorted
  run -0 bats_linear_reverse_search 2 two_sorted

  run -1 bats_linear_reverse_search 0 two_elements_reversed
  run -0 bats_linear_reverse_search 1 two_elements_reversed
  run -0 bats_linear_reverse_search 2 two_elements_reversed

  run -1 bats_linear_reverse_search 0 three_elements_scrambled
  run -0 bats_linear_reverse_search 1 three_elements_scrambled
  run -0 bats_linear_reverse_search 2 three_elements_scrambled
  run -0 bats_linear_reverse_search 3 three_elements_scrambled
}

# shellcheck disable=SC2031
@test bats_sort {
  local -a empty one_element two_sorted two_elements_reversed three_elements_scrambled

  bats_sort empty
  echo "empty(${#empty[@]}): ${empty[*]}"
  [ ${#empty[@]} -eq 0 ]

  bats_sort one_element 1
  echo "one_element(${#one_element[@]}): ${one_element[*]}"
  [ ${#one_element[@]} -eq 1 ]
  [ "${one_element[0]}" = 1 ]

  bats_sort two_sorted 1 2
  echo "two_sorted(${#two_sorted[@]}): ${two_sorted[*]}"
  [ ${#two_sorted[@]} -eq 2 ]
  [ "${two_sorted[0]}" = 1 ]
  [ "${two_sorted[1]}" = 2 ]

  bats_sort two_elements_reversed 2 1
  echo "two_elements_reversed(${#two_elements_reversed[@]}): ${two_elements_reversed[*]}"
  [ ${#two_elements_reversed[@]} -eq 2 ]
  [ "${two_elements_reversed[0]}" = 1 ]
  [ "${two_elements_reversed[1]}" = 2 ]

  bats_sort three_elements_scrambled 2 1 3
  echo "three_elements_scrambled(${#three_elements_scrambled[@]}): ${three_elements_scrambled[*]}"
  [ ${#three_elements_scrambled[@]} -eq 3 ]
  [ "${three_elements_scrambled[0]}" = 1 ]
  [ "${three_elements_scrambled[1]}" = 2 ]
  [ "${three_elements_scrambled[2]}" = 3 ]
}

@test bats_all_in {
  bats_require_minimum_version 1.5.0

  local -ra empty=() one=(1) onetwo=(1 2)
  # find nothing in any array
  run -0 bats_all_in empty
  run -0 bats_all_in one
  run -0 bats_all_in onetwo
  # find single search value in single element array
  run -0 bats_all_in one 1
  # find single search values in multi element array
  run -0 bats_all_in onetwo 1
  # find multiple search values in multi element array
  run -0 bats_all_in onetwo 1 2

  # don't find in empty array
  run -1 bats_all_in empty 1
  # don't find in non empty
  run -1 bats_all_in one 2
  # don't find smaller values
  run -1 bats_all_in onetwo 0 1 2
  # don't find greater values
  run -1 bats_all_in onetwo 1 2 3
}

@test bats_any_in {
  bats_require_minimum_version 1.5.0

  # shellcheck disable=SC2030,SC2034
  local -ra empty=() one=(1) onetwo=(1 2)
  # empty search set is always false
  run -1 bats_any_in empty
  run -1 bats_any_in one
  run -1 bats_any_in onetwo

  # find single search value in single element array
  run -0 bats_any_in one 1
  # find single search values in multi element array
  run -0 bats_any_in onetwo 2
  # find multiple search values in multi element array
  run -0 bats_any_in onetwo 1 2

  # don't find in empty array
  run -1 bats_any_in empty 1
  # don't find in non empty
  run -1 bats_any_in one 2
  # don't find smaller values
  run -1 bats_any_in onetwo 0
  # don't find greater values
  run -1 bats_any_in onetwo 3
}

@test bats_trim {
  local empty already_trimmed trimmed whitespaces_within
  bats_trim empty ""
  # shellcheck disable=SC2031
  [ "${empty-NOTSET}" = "" ]

  bats_trim already_trimmed "abc"
  [ "$already_trimmed" = abc ]

  bats_trim trimmed "  abc  "
  [ "$trimmed" = abc ]

  bats_trim whitespaces_within "  a b  "
  [ "$whitespaces_within" = "a b" ]
}

@test bats_append_arrays_as_args {
  bats_require_minimum_version 1.5.0
  count_and_print_args() {
    echo "$# $*"
  }

  run -1 bats_append_arrays_as_args
  [ "${lines[0]}" == "Error: append_arrays_as_args is missing a command or -- separator" ]

  run -1 bats_append_arrays_as_args --
  [ "${lines[0]}" == "Error: append_arrays_as_args is missing a command or -- separator" ]

  # shellcheck disable=SC2034
  empty=()
  run -0 bats_append_arrays_as_args empty -- count_and_print_args
  [ "${lines[0]}" == '0 ' ]

  run -0 bats_append_arrays_as_args -- count_and_print_args
  [ "${lines[0]}" == '0 ' ]

  # shellcheck disable=SC2034
  arr=(a)
  run -0 bats_append_arrays_as_args arr -- count_and_print_args
  [ "${lines[0]}" == '1 a' ]

  # shellcheck disable=SC2034
  arr2=(b)
  run -0 bats_append_arrays_as_args arr arr2 -- count_and_print_args
  [ "${lines[0]}" == '2 a b' ]

  run -0 bats_append_arrays_as_args arr empty arr2 -- count_and_print_args
  [ "${lines[0]}" == '2 a b' ]
}
