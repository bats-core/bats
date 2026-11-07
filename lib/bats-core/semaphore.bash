#!/usr/bin/env bash

# setup the semaphore environment for the loading file
bats_semaphore_setup() {
  export BATS_SEMAPHORE_DIR="$BATS_RUN_TMPDIR/semaphores"
}

# $1 - output directory for stdout/stderr
# $@ - command to run
# run the given command in a semaphore
# block when there is no free slot for the semaphore
# when there is a free slot, run the command in background
# gather the output of the command in files in the given directory
bats_semaphore_run() {
  local output_dir=$1
  shift
  local semaphore_slot
  semaphore_slot=$(bats_semaphore_acquire_slot)
  bats_semaphore_release_wrapper "$output_dir" "$semaphore_slot" "$@" &
  printf "%d\n" "$!"
}

# $1 - output directory for stdout/stderr
# $@ - command to run
# this wraps the actual function call to install some traps on exiting
bats_semaphore_release_wrapper() {
  local output_dir="$1"
  local semaphore_name="$2"
  shift 2 # all other parameters will be use for the command to execute

  trap 'status=$?; bats_semaphore_release_slot "$semaphore_name"; exit "$status"' EXIT

  # Bash starts asynchronous jobs with SIGINT ignored when job control is off.
  # Restore it so commands run as parallel tests can handle SIGINT themselves.
  trap - INT

  mkdir -p "$output_dir"
  "$@" 2>"$output_dir/stderr" >"$output_dir/stdout"
  local status=$?

  # bash bug: the exit trap is not called for the background process
  bats_semaphore_release_slot "$semaphore_name"
  trap - EXIT # avoid calling release twice
  return $status
}

# block until a semaphore slot becomes free
# prints the number of the slot that it received
bats_semaphore_acquire_slot() {
  mkdir -p "$BATS_SEMAPHORE_DIR"
  local slot
  while true; do
    for ((slot = 0; slot < BATS_SEMAPHORE_NUMBER_OF_SLOTS; ++slot)); do
      # Bash noclobber creates the file with O_CREAT|O_EXCL, so only one
      # process can successfully claim a given slot.
      if (set -C; : > "$BATS_SEMAPHORE_DIR/slot-$slot") 2>/dev/null; then
        printf "%d\n" "$slot"
        return 0
      fi
    done
    sleep 1
  done
}

bats_semaphore_release_slot() {
  # We don't need additional synchronization: only our process owns this slot
  # file, and releasing a slot cannot conflict with another process.
  rm "$BATS_SEMAPHORE_DIR/slot-$1" # fails if we did not acquire this slot
}
