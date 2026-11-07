setup() {
  export PATH
  PATH="$(dirname "$BATS_TEST_FILENAME"):$PATH"
}

@test "dummy" {
  echo "$PATH"
  run -0 date
  echo "$output"
  [ "${output}" = 'dummy date' ]
}
