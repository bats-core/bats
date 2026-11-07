# bats test_tags=bats:focus
@test "focused test" {
  true
}

# bats test_tags=filter
@test "unfocused tests" {
  true
}
