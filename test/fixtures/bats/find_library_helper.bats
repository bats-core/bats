@test "find a library" {
    run find_in_bats_lib_path "$LIBRARY_NAME"
    [ $status -eq 0 ]
    [ ${lines[0]} = "$LIBRARY_PATH" ]
}
