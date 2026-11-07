#!/usr/bin/env bats

@test "passing" {
  [ "$PATH" = "${PATH_MUTATION_VALUE:-/usr/bin:/bin}" ]
}
