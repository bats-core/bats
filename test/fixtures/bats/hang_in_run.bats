setup() {
    load '../../concurrent-coordination'
}

@test "test" {
    single-use-latch::signal hang_in_run
    run sleep 30
}