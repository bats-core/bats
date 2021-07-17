setup_file() {
    load '../../concurrent-coordination'
    single-use-latch::signal hang_in_setup_file
    sleep 30
}

@test "empty" {
    :
}