#!/usr/bin/env bats

load test_helper

# Positive assertions: each of these should succeed
@test "basic return-code checking" {
  run      true
  run =0   true
  run '!'  false
  run !    false
  run =1   false
  run =3   exit 3
  run =5   exit 5
  run =111 exit 111
  run =255 exit 255
  run =127 /no/such/command

  # No status checking: these should all succeed
  run false
  run ls /no/such/f1l3
}

# Negative assertions.
# We can't just run 'bats' on an entire list of tests, because each test here
# is expected to fail and we need to know _how_ it should fail.
# So this is a test helper. It assumes that the caller has defined 'commands'
# as an array of one or more instructions; Those will be written to a .bats
# tmpfile which we then run. Our function arguments are patterns to search for
# in the output from the test.
function _run_test() {
  # Write a test file
  local testfile=${BATS_TMPDIR}/bats-testfile-$$.bats
  rm -f $testfile
  echo "@test \"negative test\" {"   >$testfile
  for c in "${commands[@]}"; do
      echo "    $c"                 >>$testfile
  done
  echo "}"                          >>$testfile

  # Run it
  export BATS_PS1='run> '
  run '=1' bats $testfile
  rm -f $testfile

  if [[ "${lines[0]}" != "1..1" ]]; then
    die "Internal error: expected '1..1' as first line, got '${lines[0]}'"
  fi
  if [[ "${lines[1]}" != "not ok 1 negative test" ]]; then
    die "Internal error: expected 'not ok 1 negative test' as second line, got '${lines[1]}'"
  fi

  local lineno=1
  for e in "$@"; do
    while :; do
      lineno=$(( lineno + 1 ))
      if [ $lineno -gt ${#lines[*]} ]; then
        die "$testname: did not find '$e' in output from this test" \
            "${lines[@]}"
      fi

      if [[ ${lines[$lineno]} =~ $e ]]; then
        lines[$lineno]="${lines[$lineno]}   [MATCHED]"
        break
      fi
    done
  done
}

@test "run: unexpected fail" {
  local -a commands=("run =0 false")
  _run_test "\(in test file .*, line 2\)" \
            "\`run =0 false' failed" \
            "\[ rc=1 \(\*\* EXPECTED 0 \*\*\) \]" \
            "/vvvvvvvvvvvvvv" \
            "\| FAIL: exit code is 1; expected 0"
}

@test "run: unexpected pass; includes output check" {
  local -a commands=("run =1 echo hi")
  _run_test "\(in test file .*, line 2\)" \
            "\`run =1 echo hi' failed" \
            "# run> echo hi" \
            "# hi" \
            "/vvvvvvvvvvvvvv" \
            "\| FAIL: exit code is 0; expected 1"
}

@test "run: incorrect exit status" {
  local -a commands=("run =2 exit 3")
  _run_test "# run> exit 3" \
            "\| FAIL: exit code is 3; expected 2"
}

@test "run: input validation on '=NNN': invalid number" {
  local -a commands=("run =4evah echo hi")
  _run_test "Usage error: .* requires numeric NNN"
}

@test "run: input validation on '=NNN': invalid exit status" {
  local -a commands=("run =256 echo hi")
  _run_test "Usage error: .* NNN must be <= 255"
}


@test "run: success when expecting error" {
  local -a commands=("run ! true")
  _run_test "# run> true" \
            "\| FAIL: exit code is 0; expected nonzero"
}

@test "run: multiple pass/fails" {
  local -a commands=("run ! false"
                     "run =0 echo hi"
                     "run =127 /no/such/cmd"
                     "run =1 /etc")
  _run_test "\(in test file .*, line 5\)" \
            "\`run =1 /etc' failed" \
            "# run> false" \
            "# \[ rc=1 \(expected any error\)\]" \
            "# run> echo hi" \
            "# hi" \
            "# .* /no/such/cmd: No such file or directory" \
            "# .* /etc: .s a directory" \
            "\[ rc=126 \(\*\* EXPECTED 1 \*\*\) \]" \
            "/vvvvvvvvvvvvvv" \
            "\| FAIL: exit code is 126; expected 1"
}
