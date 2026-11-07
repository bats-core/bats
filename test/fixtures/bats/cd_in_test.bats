#!/usr/bin/env bats

@test "test_that_does_cd" {
  mkdir -p test
  cd test
  echo "yey from test directory"
}
