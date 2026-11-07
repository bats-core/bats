#!/usr/bin/env bash

bats_export_preprocess_source_BATS_TEST_SOURCE() {
  # export to make it visible to bats_evaluate_preprocessed_source
  # since the latter runs in bats-exec-test's bash while this runs in bats-exec-file's
  export BATS_TEST_SOURCE="$BATS_RUN_TMPDIR/${BATS_TEST_FILE_NUMBER?}-${BATS_TEST_FILENAME##*/}.src"
}

bats_preprocess_source() { # index
  bats_export_preprocess_source_BATS_TEST_SOURCE
  # shellcheck disable=SC2153
  CHECK_BATS_COMMENT_COMMANDS=1 bats_execute_internal bats-preprocess "$BATS_TEST_FILENAME" >"$BATS_TEST_SOURCE"
}

bats_evaluate_preprocessed_source() {
  # Dynamically loaded user files provided outside of Bats.
  # shellcheck disable=SC1090
  source "${BATS_TEST_SOURCE?}"
}
