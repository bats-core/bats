teardown() {
    load '../../concurrent-coordination'
    single-use-latch::signal hang_in_teardown
    sleep 30
}

@test "empty" {
    :
}