#!/usr/bin/env bats

bats_require_minimum_version 1.5.0

load test_helper
fixtures trap_timing

@test "install_libs temporary directory is cleaned up if startup is interrupted" {
  local capture_file="$BATS_TEST_TMPDIR/install-libs-tmpdir"
  local temporary_dir

  run env \
    TMPDIR="$BATS_TEST_TMPDIR" \
    BASH_ENV="$FIXTURE_ROOT/fault_injection.bash" \
    BATS_FAULT_SCRIPT=install_libs.sh \
    BATS_FAULT_COMMAND='USAGE=*' \
    BATS_FAULT_CAPTURE=TMPDIR \
    BATS_FAULT_CAPTURE_FILE="$capture_file" \
    BATS_FAULT_ACTION=TERM \
    bash "$BATS_TEST_DIRNAME/../docker/install_libs.sh" support 0.3.0

  read -r temporary_dir <"$capture_file"
  [ "$status" -eq 143 ]
  [ ! -d "$temporary_dir" ]
}

@test "install_libs exits after handling TERM" {
  local continued_file="$BATS_TEST_TMPDIR/continued-after-term"

  run env \
    TMPDIR="$BATS_TEST_TMPDIR" \
    BASH_ENV="$FIXTURE_ROOT/fault_injection.bash" \
    BATS_FAULT_SCRIPT=install_libs.sh \
    BATS_FAULT_COMMAND='*# -ne 2*' \
    BATS_FAULT_ACTION=TERM-then-mark \
    BATS_FAULT_CONTINUED_FILE="$continued_file" \
    bash "$BATS_TEST_DIRNAME/../docker/install_libs.sh" support 0.3.0

  [ ! -e "$continued_file" ]
}
