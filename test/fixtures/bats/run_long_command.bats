@test "run long command" {
    load '../../concurrent-coordination'
    single-use-latch::signal run_long_command
    run sleep 30
}