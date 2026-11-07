: "${MARKER_FILE?}" # ensure the parameter is set!

@test failing {
  false
}

@test waiting {
  sleep 1
}

@test marking {
  echo "$BATS_TEST_SOURCE" >>"${MARKER_FILE?}"
}
