setup() {
  skip "always skip"
}

@test test_one {
  echo "test something"
}

@test test_two {
  echo "test another thing"
}

teardown() {
  skip "always skip"
}
