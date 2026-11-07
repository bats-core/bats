@test "should not be executed" {
  echo "$BATS_TEST_SOURCE" >>"${MARKER_FILE?}"
}
