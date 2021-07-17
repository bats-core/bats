setup() {
  load '../../concurrent-coordination'
}

@test "slow test 1" {
  single-use-latch::signal parallel_factor
  single-use-barrier parallel_factor $PARALLELITY 30
}

@test "slow test 2" {
  single-use-latch::signal parallel_factor
  single-use-barrier parallel_factor $PARALLELITY 30
}

@test "slow test 3" {
  single-use-latch::signal parallel_factor
  single-use-barrier parallel_factor $PARALLELITY 30
}

@test "slow test 4" {
  single-use-latch::signal parallel_factor
  single-use-barrier parallel_factor $PARALLELITY 30
}

@test "slow test 5" {
  single-use-latch::signal parallel_factor
  single-use-barrier parallel_factor $PARALLELITY 30
}

@test "slow test 6" {
  single-use-latch::signal parallel_factor
  single-use-barrier parallel_factor $PARALLELITY 30
}

@test "slow test 7" {
  single-use-latch::signal parallel_factor
  single-use-barrier parallel_factor $PARALLELITY 30
}

@test "slow test 8" {
  single-use-latch::signal parallel_factor
  single-use-barrier parallel_factor $PARALLELITY 30
}

@test "slow test 9" {
  single-use-latch::signal parallel_factor
  single-use-barrier parallel_factor $PARALLELITY 30
}

@test "slow test 10" {
  single-use-latch::signal parallel_factor
  single-use-barrier parallel_factor $PARALLELITY 30
}
