bats::on_failure() {
  echo "failure callback"
}

setup_file() {
  false
}

@test dummy {
  true
}
