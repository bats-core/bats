#!/usr/bin/env bats

bats_require_minimum_version 1.5.0

setup() {
  load test_helper
  fixtures tagging
}

@test "No tag filter runs all tests" {
  run -0 bats "$FIXTURE_ROOT/tagged.bats"
  [ "${lines[0]}" == "1..5" ]
  [ "${lines[1]}" == "ok 1 No tags" ]
  [ "${lines[2]}" == "ok 2 Only file tags" ]
  [ "${lines[3]}" == "ok 3 File and test tags" ]
  [ "${lines[4]}" == "ok 4 File and other test tags" ]
  [ "${lines[5]}" == "ok 5 Only test tags" ]
  [ ${#lines[@]} -eq 6 ]
}

@test "Empty tag filter runs tests without tag" {
  run -0 bats --filter-tags '' "$FIXTURE_ROOT/tagged.bats"
  [ "${lines[0]}" == "1..1" ]
  [ "${lines[1]}" == "ok 1 No tags" ]
  [ ${#lines[@]} -eq 2 ]
}

@test "--filter-tags (also) selects tests that contain additional tags" {
  run -0 bats --filter-tags 'file:tag:1' "$FIXTURE_ROOT/tagged.bats"
  [ "${lines[0]}" == "1..3" ]
  [ "${lines[1]}" == "ok 1 Only file tags" ]
  [ "${lines[2]}" == "ok 2 File and test tags" ]
  [ "${lines[3]}" == "ok 3 File and other test tags" ]
  [ ${#lines[@]} -eq 4 ]
}

@test "--filter-tags only selects tests that match all tags (logic and)" {
  run -0 bats --filter-tags 'test:tag:1,file:tag:1' "$FIXTURE_ROOT/tagged.bats"
  [ "${lines[0]}" == "1..1" ]
  [ "${lines[1]}" == "ok 1 File and test tags" ]
  [ ${#lines[@]} -eq 2 ]
}

@test "multiple --filter-tags work as logical or" {
  run -0 bats --filter-tags 'test:tag:1,file:tag:1' --filter-tags 'test:tag:2,file:tag:1' "$FIXTURE_ROOT/tagged.bats"
  [ "${lines[0]}" == "1..2" ]
  [ "${lines[1]}" == "ok 1 File and test tags" ]
  [ "${lines[2]}" == "ok 2 File and other test tags" ]
  [ ${#lines[@]} -eq 3 ]
}

@test "--filter-tags order of tags does not matter" {
  # note the reversed order in comparison to test above
  run -0 bats --filter-tags 'file:tag:1,test:tag:1' "$FIXTURE_ROOT/tagged.bats"
  [ "${lines[0]}" == "1..1" ]
  [ "${lines[1]}" == "ok 1 File and test tags" ]
  [ ${#lines[@]} -eq 2 ]
}

@test "exit with error on invalid tags in .bats file" {
  run -1 bats "$FIXTURE_ROOT/invalid_tags.bats"
  [ "${lines[0]}" = "$FIXTURE_ROOT/invalid_tags.bats:1: Error: Invalid file_tags: ',bc'. Tags must not be empty. Please remove redundant commas!" ]
  [ "${lines[1]}" = "$FIXTURE_ROOT/invalid_tags.bats:2: Error: Invalid file_tags: 'a+b'. Valid tags must match [-_:[:alnum:]]+ and be separated with comma (and optional spaces)" ]
  [ "${lines[2]}" = "$FIXTURE_ROOT/invalid_tags.bats:4: Error: Invalid test_tags: ',bc'. Tags must not be empty. Please remove redundant commas!" ]
  [ "${lines[3]}" = "$FIXTURE_ROOT/invalid_tags.bats:5: Error: Invalid test_tags: 'a+b'. Valid tags must match [-_:[:alnum:]]+ and be separated with comma (and optional spaces)" ]
  [ "${lines[4]}" = "1..1" ]
  [ "${lines[5]}" = "not ok 1 bats-gather-tests" ]
  [ ${#lines[@]} -eq 6 ]
}

@test "--filter-tags allows for negation via !" {
  run -0 bats --filter-tags '!file:tag:1' "$FIXTURE_ROOT/tagged.bats"
  [ "${lines[0]}" = '1..2' ]
  [ "${lines[1]}" = 'ok 1 No tags' ]
  [ "${lines[2]}" = 'ok 2 Only test tags' ]
  [ "${#lines[@]}" -eq 3 ]
}

@test "BATS_TEST_TAGS are set correctly" {
  run -0 bats "$FIXTURE_ROOT/BATS_TEST_TAGS.bats"
}

@test "Print tags on error" {
  run -1 bats "$FIXTURE_ROOT/print_tags_on_error.bats"

  [ "${lines[2]}" = '# tags: file_tag test_tag' ]
}
