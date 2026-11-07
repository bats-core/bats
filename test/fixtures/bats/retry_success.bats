# shellcheck disable=SC2034
BATS_TEST_RETRIES=2 # means three tries per test

@test "Fail once" {
  ((BATS_TEST_TRY_NUMBER > 1)) || false
}
