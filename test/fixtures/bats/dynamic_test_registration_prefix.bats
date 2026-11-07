record_args() {
  local arg
  {
    printf '%d' "$#"
    for arg in "$@"; do
      printf ' <%s>' "$arg"
    done
    printf '\n'
  } >>"${REGISTRATION_LOG:?}"
}

register_duplicates_with_ifs() {
  local IFS=$1
  bats_test_function --description "first" -- record_args one
  bats_test_function --description "other" -- record_args two
  bats_test_function --description "duplicate" -- record_args one
}

case "${REGISTRATION_CASE:?}" in
long-first | nounset | unset-ifs)
  if [[ $REGISTRATION_CASE == nounset ]]; then
    set -u
  elif [[ $REGISTRATION_CASE == unset-ifs ]]; then
    unset IFS
  fi
  bats_test_function --description "long one" -- record_args --format plain
  bats_test_function --description "short one" -- record_args
  ;;
short-first)
  bats_test_function --description "short one" -- record_args
  bats_test_function --description "long one" -- record_args --format plain
  ;;
multi-word)
  bats_test_function --description "long one" -- record_args --format "plain text"
  bats_test_function --description "short one" -- record_args --format
  ;;
glob)
  bats_test_function --description "long one" -- record_args '*' extra
  bats_test_function --description "short one" -- record_args '*'
  ;;
empty)
  bats_test_function --description "long one" -- record_args ''
  bats_test_function --description "short one" -- record_args
  ;;
trailing-space)
  bats_test_function --description "trailing space" -- record_args "value "
  bats_test_function --description "leading space" -- record_args " value"
  ;;
duplicate)
  bats_test_function --description "first" -- record_args --format plain
  bats_test_function --description "duplicate" -- record_args --format plain
  ;;
duplicate-comma)
  register_duplicates_with_ifs ','
  ;;
duplicate-empty-ifs)
  register_duplicates_with_ifs ''
  ;;
single)
  bats_test_function --description "single" -- record_args --format plain
  ;;
esac
