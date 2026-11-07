setup() {
  declare -p BATS_TEST_TAGS
}

@test "no tags" {
  [ ${#BATS_TEST_TAGS[@]} -eq 0 ]
}

# bats test_tags=test_tag
@test "only test tags" {
  [ ${#BATS_TEST_TAGS[@]} -eq 1 ]
  [ "${BATS_TEST_TAGS[0]}" == test_tag ]
}

# bats file_tags=file_tag
@test "only file tags" {
  [ ${#BATS_TEST_TAGS[@]} -eq 1 ]
  [ "${BATS_TEST_TAGS[0]}" == file_tag ]
}

# bats test_tags=test_tag
@test "test and file tags" {
  [ ${#BATS_TEST_TAGS[@]} -eq 2 ]
  [ "${BATS_TEST_TAGS[0]}" == file_tag ]
  [ "${BATS_TEST_TAGS[1]}" == test_tag ]
}
