load helper.bash

check_ifs

setup_file() {
  check_ifs
}

teardown_file() {
  check_ifs
}

@test test {
  check_ifs
}
