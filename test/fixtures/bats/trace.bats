evaluate_result() {
  [ "$1" = 'The TEST_RESULT is: PASS' ]
}

@test "traced test case" {
  run printf 'The TEST_RESULT is: %s\n' "$TEST_RESULT"
  evaluate_result "$output"
}
