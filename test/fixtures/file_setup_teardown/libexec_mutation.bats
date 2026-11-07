setup_file() {
  if [[ $(declare -p BATS_LIBEXEC) != "declare -"*r* ]]; then
    export BATS_LIBEXEC="$BATS_RUN_TMPDIR/missing-libexec"
  fi
}

@test "passing" {
  true
}
