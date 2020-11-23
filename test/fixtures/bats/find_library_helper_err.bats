@test "does not find a library" {
    run find_in_bats_lib_path "$LIBRARY_NAME"
    [ $status -eq 1 ]
}
