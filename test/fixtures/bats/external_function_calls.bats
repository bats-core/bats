load test_helper

# Test various combinations that may fail line number detection in stack trace
# Tests are designed so the first statement succeeds and 2nd fails
# All tests fail on the same line so checking can be automated

@test "Call true function && false stackdepth=1" {
  help_me
  # padding: keeps the failing statement on the 6-line grid (see test/bats.bats)
  help_me && false
}

@test "Call true function && return 1 stackdepth=1" {
  help_me
  # padding: keeps the failing statement on the 6-line grid (see test/bats.bats)
  help_me && return 1
}

@test "Call true function and invert stackdepth=2" {
  help_me
  # shellcheck disable=SC2314
  ! help_me
}

@test "Call false function || false stackdepth=1" {
  # shellcheck disable=SC2314
  ! failing_helper
  failing_helper || false
}

@test "Call false function && return 1 stackdepth=1" {
  # shellcheck disable=SC2314
  ! failing_helper
  failing_helper || return 1
}

@test "Call false function stackdepth=2" {
  # shellcheck disable=SC2314
  ! failing_helper
  failing_helper
}

@test "Call return_0 function && false stackdepth=1" {
  return_0
  # padding: keeps the failing statement on the 6-line grid (see test/bats.bats)
  return_0 && false
}

@test "Call return_0 function && return 1 stackdepth=1" {
  return_0
  # padding: keeps the failing statement on the 6-line grid (see test/bats.bats)
  return_0 && return 1
}

@test "Call return_0 function and invert stackdepth=2" {
  return_0
  # shellcheck disable=SC2314
  ! return_0
}

@test "Call return_1 function || false stackdepth=1" {
  # shellcheck disable=SC2314
  ! return_1
  return_1 || false
}

@test "Call return_1 function && return 1 stackdepth=1" {
  # shellcheck disable=SC2314
  ! return_1
  return_1 || return 1
}

@test "Call return_1 function stackdepth=2" {
  # shellcheck disable=SC2314
  ! return_1
  return_1
}
