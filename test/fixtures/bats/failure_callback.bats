# shellcheck disable=SC2329
bats::on_failure() {
  # shellcheck disable=SC2317
  echo "called failure callback"
}

@test "failure callback is called on failure" {
  false
}

@test "failure callback is not called on success" {
  echo passed
}

@test "failure callback can be overridden locally" {
  bats::on_failure() {
    echo "override failure callback"
  }
  false
}
