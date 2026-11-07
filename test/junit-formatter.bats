#!/usr/bin/env bats

load test_helper
fixtures junit-formatter

FLOAT_REGEX='[0-9]+(\.[0-9]+)?'
TIMESTAMP_REGEX='[0-9]+-[0-1][0-9]-[0-3][0-9]T[0-2][0-9]:[0-5][0-9]:[0-5][0-9]'
TESTSUITES_REGEX="<testsuites time=\"$FLOAT_REGEX\">"

@test "junit formatter with skipped test does not fail" {
  reentrant_run bats --formatter junit "$FIXTURE_ROOT/skipped.bats"

  [[ $status -eq 0 ]]
  [[ "${lines[0]}" == '<?xml version="1.0" encoding="UTF-8"?>' ]]

  [[ "${lines[1]}" =~ $TESTSUITES_REGEX ]]

  TESTSUITE_REGEX="<testsuite name=\"skipped.bats\" tests=\"2\" failures=\"0\" errors=\"0\" skipped=\"2\" time=\"$FLOAT_REGEX\" timestamp=\"$TIMESTAMP_REGEX\" hostname=\".*\">"
  echo "TESTSUITE_REGEX='$TESTSUITE_REGEX'"
  [[ "${lines[2]}" =~ $TESTSUITE_REGEX ]]

  TESTCASE_REGEX="<testcase classname=\"skipped.bats\" name=\"a skipped test\" time=\"$FLOAT_REGEX\">"
  [[ "${lines[3]}" =~ $TESTCASE_REGEX ]]

  [[ "${lines[4]}" == *"<skipped></skipped>"* ]]
  [[ "${lines[5]}" == *"</testcase>"* ]]

  TESTCASE_REGEX="<testcase classname=\"skipped.bats\" name=\"a skipped test with a reason\" time=\"$FLOAT_REGEX\">"
  [[ "${lines[6]}" =~ $TESTCASE_REGEX ]]
  [[ "${lines[7]}" == *"<skipped>a reason</skipped>"* ]]
  [[ "${lines[8]}" == *"</testcase>"* ]]

  [[ "${lines[9]}" == *"</testsuite>"* ]]
  [[ "${lines[10]}" == *"</testsuites>"* ]]
}

@test "junit formatter: escapes xml special chars" {
  case $OSTYPE in
  linux* | darwin)
    # their CI can handle special chars on filename
    TEST_FILE_NAME="xml-escape-\"<>'&.bats"
    ESCAPED_TEST_FILE_NAME="xml-escape-&quot;&lt;&gt;&#39;&amp;.bats"
    TEST_FILE_PATH="$BATS_TEST_TMPDIR/$TEST_FILE_NAME"
    cp "$FIXTURE_ROOT/xml-escape.bats" "$TEST_FILE_PATH"
    ;;
  *)
    # use the filename without special chars
    TEST_FILE_NAME="xml-escape.bats"
    ESCAPED_TEST_FILE_NAME="$TEST_FILE_NAME"
    TEST_FILE_PATH="$FIXTURE_ROOT/$TEST_FILE_NAME"
    ;;
  esac
  reentrant_run bats --formatter junit "$TEST_FILE_PATH"

  [[ "${lines[2]}" == "<testsuite name=\"$ESCAPED_TEST_FILE_NAME\" tests=\"3\" failures=\"1\" errors=\"0\" skipped=\"1\" time=\""*"\" timestamp=\""*"\" hostname=\""*"\">" ]]
  [[ "${lines[3]}" == "    <testcase classname=\"$ESCAPED_TEST_FILE_NAME\" name=\"Successful test with escape characters: &quot;&#39;&lt;&gt;&amp; (0x1b)\" time=\""*"\" />" ]]
  [[ "${lines[4]}" == "    <testcase classname=\"$ESCAPED_TEST_FILE_NAME\" name=\"Failed test with escape characters: &quot;&#39;&lt;&gt;&amp; (0x1b)\" "* ]]
  [[ "${lines[5]}" == '        <failure type="failure">(in test file '*"$ESCAPED_TEST_FILE_NAME, line 6)" ]]
  [[ "${lines[6]}" == '  `echo &quot;&lt;&gt;&#39;&amp;&quot;$&#39;\x01\x02\x03\x04\x05\x06\x07\x08\x09\x0a\x0b\x0c\x0d\x0e\x0f\x10\x11\x12\x13\x14\x15\x16\x17\x18\x19\x1a\x1b\x1c\x1d\x1e\x1fstop&#39; &amp;&amp; false&#39; failed'* ]]
  [[ "${lines[7]}" == '&lt;&gt;&#39;&amp;' ]]
  [[ "${lines[8]}" == $'\x0Dstop</failure>' ]]
  [[ "${lines[10]}" == "    <testcase classname=\"$ESCAPED_TEST_FILE_NAME\" name=\"Skipped test with escape characters: &quot;&#39;&lt;&gt;&amp; (0x1b)\" time=\""*"\">" ]]
  [[ "${lines[11]}" == "        <skipped>&quot;&#39;&lt;&gt;&amp;</skipped>" ]]
}

@test "junit formatter: test suites" {
  reentrant_run bats --formatter junit "$FIXTURE_ROOT/suite/"

  [[ "${lines[0]}" == '<?xml version="1.0" encoding="UTF-8"?>' ]]
  [[ "${lines[1]}" == *"<testsuites "* ]]
  [[ "${lines[2]}" == *"<testsuite name=\"file1.bats\""* ]]
  [[ "${lines[3]}" == *"<testcase "* ]]
  [[ "${lines[4]}" == *"</testsuite>"* ]]
  [[ "${lines[5]}" == *"<testsuite name=\"file2.bats\""* ]]
  [[ "${lines[6]}" == *"<testcase"* ]]
  [[ "${lines[7]}" == *"</testsuite>"* ]]
  [[ "${lines[8]}" == *"</testsuites>"* ]]
}

@test "junit formatter: test suites relative path" {
  cd "$FIXTURE_ROOT"
  reentrant_run bats --formatter junit "suite/"

  [[ "${lines[0]}" == '<?xml version="1.0" encoding="UTF-8"?>' ]]
  [[ "${lines[1]}" == *"<testsuites "* ]]
  [[ "${lines[2]}" == *"<testsuite name=\"file1.bats\""* ]]
  [[ "${lines[3]}" == *"<testcase "* ]]
  [[ "${lines[4]}" == *"</testsuite>"* ]]
  [[ "${lines[5]}" == *"<testsuite name=\"file2.bats\""* ]]
  [[ "${lines[6]}" == *"<testcase"* ]]
  [[ "${lines[7]}" == *"</testsuite>"* ]]
  [[ "${lines[8]}" == *"</testsuites>"* ]]
}

@test "junit formatter: files with the same name are distinguishable" {
  reentrant_run bats --formatter junit -r "$FIXTURE_ROOT/duplicate/"

  [[ "${lines[2]}" == *"<testsuite name=\"first/file1.bats\""* ]]
  [[ "${lines[5]}" == *"<testsuite name=\"second/file1.bats\""* ]]
}

@test "junit formatter as report formatter creates report.xml" {
  cd "$BATS_TEST_TMPDIR" # don't litter sources with output files
  reentrant_run bats --report-formatter junit "$FIXTURE_ROOT/suite/"
  echo "$output" # duplicate for later comparison

  [[ -e "report.xml" ]]
  run cat "report.xml"

  [[ "${lines[2]}" == *"<testsuite name=\"file1.bats\" tests=\"1\" failures=\"0\" errors=\"0\" skipped=\"0\""* ]]
  [[ "${lines[5]}" == *"<testsuite name=\"file2.bats\" tests=\"1\" failures=\"0\" errors=\"0\" skipped=\"0\""* ]]
}

@test "junit does not mark tests with FD 3 output as failed (issue #360)" {
  reentrant_run bats --formatter junit "$FIXTURE_ROOT/issue_360.bats"

  [[ "${lines[2]}" == '<testsuite name="issue_360.bats" '*'>' ]]
  [[ "${lines[3]}" == '    <testcase classname="issue_360.bats" '*'>' ]]
  # only the outputs on FD3 should be visible on a successful test
  [[ "${lines[4]}" == '        <system-out>setup FD3' ]]
  [[ "${lines[5]}" == 'hello Bilbo' ]]
  [[ "${lines[6]}" == 'teardown FD3</system-out>' ]]
  [[ "${lines[7]}" == '    </testcase>' ]]
  [[ "${lines[8]}" == '    <testcase classname="issue_360.bats" name="fail to say hello to Biblo" time="'*'">' ]]
  # a failed test should show FD3 output first ...
  [[ "${lines[9]}" == '        <system-out>setup FD3' ]]
  [[ "${lines[10]}" == 'hello Bilbo' ]]
  [[ "${lines[11]}" == 'teardown FD3</system-out>' ]]
  [[ "${lines[12]}" == '        <failure type="failure">(in test file '*'test/fixtures/junit-formatter/issue_360.bats, line 21)' ]]
  [[ "${lines[13]}" == '  `false&#39; failed' ]]
  # ... and then the stdout output
  [[ "${lines[14]}" == '# setup stdout' ]]
  [[ "${lines[15]}" == '# hello stdout' ]]
  [[ "${lines[16]}" == '# teardown stdout</failure>' ]]
  [[ "${lines[17]}" == '    </testcase>' ]]
  [[ "${lines[18]}" == '</testsuite>' ]]
}

@test "junit does not mark tests with FD 3 output in teardown_file as failed (issue #531)" {
  bats_require_minimum_version 1.5.0
  reentrant_run -0 bats --formatter junit "$FIXTURE_ROOT/issue_531.bats"

  [[ "${lines[2]}" == '<testsuite name="issue_531.bats" '*'>' ]]
  [[ "${lines[3]}" == '    <testcase classname="issue_531.bats" '*'>' ]]
  # only the outputs on FD3 should be visible on a successful test
  [[ "${lines[4]}" == '        <system-out>test fd3' ]]
  [[ "${lines[5]}" == 'teardown_file fd3</system-out>' ]]
  [[ "${lines[6]}" == '    </testcase>' ]]
  [[ "${lines[7]}" == '</testsuite>' ]]
}

@test "junit does not mark tests with FD 3 output in teardown_suite as failed (issue #1180)" {
  bats_require_minimum_version 1.5.0
  local stderr='' # silence shellcheck
  name=non-empty reentrant_run -0 --separate-stderr bats --formatter junit "$FIXTURE_ROOT/issue1180"
  [ "${stderr}" == "" ] || {
    echo "stderr should be empty but was: ${stderr}" >&3
    return 1
  }
  [[ "${output}" != *'<failure '* ]]
  [[ "${output}" == *'teardown_suite fd3'* ]]
}

@test "skipped tests report output in <system-out> when using --show-output-of-passing-tests (issue #1190)" {
  bats_require_minimum_version 1.5.0
  reentrant_run bats --formatter junit --show-output-of-passing-tests "$FIXTURE_ROOT/issue_1190.bats"
  [ "$status" -eq 0 ]
  [[ "$output" == *'<system-out>output</system-out>'* ]]
  [[ "$output" != '<system-err>' ]]
}

@test "don't choke on setup_file errors" {
  bats_require_minimum_version 1.5.0
  local stderr='' # silence shellcheck
  reentrant_run -1 --separate-stderr bats --formatter junit "$FIXTURE_ROOT/../file_setup_teardown/setup_file_failed.bats"
  [ "${stderr}" == "" ]
}

@test "junit outputs status of last completed test when a test is retried (issue #1149)" {
  bats_require_minimum_version 1.8.0
  reentrant_run bats --formatter junit "$FIXTURE_ROOT/issue_1149.bats"

  [[ "${lines[2]}" == '<testsuite name="issue_1149.bats" '*'>' ]]
  # The first failing (and retried) test has one entry, as expected
  [[ "${lines[3]}" == '    <testcase classname="issue_1149.bats" name="test fail" '*'>' ]]
  [[ "${lines[4]}" == "        <failure type=\"failure\">(in test file $RELATIVE_FIXTURE_ROOT/issue_1149.bats, line 7)" ]]
  [[ "${lines[5]}" == '  `false&#39; failed</failure>' ]]
  [[ "${lines[6]}" == '    </testcase>' ]]
  # Second failing test (also retried) should also only have one entry, and that includes the failure message
  [[ "${lines[7]}" == '    <testcase classname="issue_1149.bats" name="test foobar" '*'>' ]]
  [[ "${lines[8]}" == "        <failure type=\"failure\">(in test file $RELATIVE_FIXTURE_ROOT/issue_1149.bats, line 11)" ]]
  [[ "${lines[9]}" == '  `false&#39; failed</failure>' ]]
  [[ "${lines[10]}" == '    </testcase>' ]]
  [[ "${lines[11]}" == '</testsuite>' ]]
}

@test "don't choke on setup_suite errors (issue #1106)" {
  bats_require_minimum_version 1.5.0
  local stderr='' # silence shellcheck
  name=non-empty reentrant_run -1 --separate-stderr bats --formatter junit "$FIXTURE_ROOT/../suite_setup_teardown/error_in_setup_suite/test.bats"
  [ "${stderr}" == "" ]
  [[ "${lines[2]}" == '<testsuite name="setup_suite" '*'>' ]]
  [[ "${lines[3]}" == '    <testcase classname="setup_suite" '*'>' ]]
  [[ "${lines[5]}" == *'call-to-undefined-command'* ]]
}
