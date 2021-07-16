# block until at least <barrier-size> processes of this barrier group entered the barrier
# once this happened, all latecomers will go through immediately!
# WARNING: a barrier group consists of all processes with the same barrier name *and* size!
single-use-barrier() { # <barrier-name> <barrier-size> [<timeout-in-seconds> [<sleep-cycle-time>]]
    local barrier_name="$1"
    local barrier_size="$2"
    local timeout_in_seconds="${3:-0}"
    local sleep_cycle_time="${4:-1}"
    # use name and size to distinguish between invocations
    # this will block inconsistent sizes on the same name!
    local BARRIER_SUFFIX=${barrier_name//\//_}-$barrier_size
    local BARRIER_FILE="$BATS_SUITE_TMPDIR/barrier-$BARRIER_SUFFIX"
    # mark our entry for all others
    # concurrent writes may interleave but should not lose their newlines
    echo "in-$$" >> "$BARRIER_FILE"
    local start="$SECONDS"
    # wait for others to enter
    while [[ $(wc -l <"$BARRIER_FILE" ) -lt $barrier_size ]]; do
        if [[ $timeout_in_seconds -ne 0 && $(( SECONDS - start )) -gt $timeout_in_seconds ]]; then
            mv "$BARRIER_FILE" "$BARRIER_FILE-timeout"
            printf "ERROR: single-use-barrier %s timed out\n" "$BARRIER_SUFFIX" >&2
            return 1
        fi
        sleep "$sleep_cycle_time"
    done
    # mark our exit
    echo "out-$$" >> "$BARRIER_FILE"
}

# block until at least <latch-size> signalling threads have passed the latch
# SINGLE_USE_LATCH_DIR must be exported!
single-use-latch::wait() { # <latch-name> <latch-size> [<timeout-in-seconds> [<sleep-cycle-time>]]
    local latch_name="$1"
    local latch_size="$2"
    local timeout_in_seconds="${3:-0}"
    local sleep_cycle_time="${4:-1}"
    
    local LATCH_FILE="$(single-use-latch::_filename "$latch_name")"
    local start="$SECONDS"
    while [[ (! -e "$LATCH_FILE") || $(wc -l <"$LATCH_FILE" ) -lt $latch_size ]]; do
        if [[ $timeout_in_seconds -ne 0 && $(( SECONDS - start )) -gt $timeout_in_seconds ]]; then
            printf "ERROR: single-use-latch %s timed out\n" "$latch_name" >&2
            mv "$LATCH_FILE" "$LATCH_FILE-timeout"
            return 1
        fi
        sleep "$sleep_cycle_time"
    done
}

# signal the waiting process that the latch was passed
# this does not block
# SINGLE_USE_LATCH_DIR must be exported!
single-use-latch::signal() { # <latch-name>
    local latch_name="$1"
    local LATCH_FILE="$(single-use-latch::_filename "$latch_name")"
    # mark our passing
    # concurrent process might interleave but will still post their newline
    echo "passed-$$" >> "$LATCH_FILE"
    echo "passed-$$ >> $LATCH_FILE" >> /tmp/latch
}

single-use-latch::_filename() { # <latch-name> 
    printf "%s\n" "${SINGLE_USE_LATCH_DIR?}/latch-${1//\//_}"
}
