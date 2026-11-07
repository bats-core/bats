# Writing tests

Each Bats test file is evaluated _n+1_ times, where _n_ is the number of
test cases in the file. The first run counts the number of test cases,
then iterates over the test cases and executes each one in its own
process.

For more details about how Bats evaluates test files, see [Bats Evaluation
Process][bats-eval] on the wiki.

For sample test files, see [examples](https://github.com/bats-core/bats-core/tree/master/docs/examples).

[bats-eval]: https://github.com/bats-core/bats-core/wiki/Bats-Evaluation-Process

## Tagging tests

Starting with version 1.8.0, Bats comes with a tagging system that allows users
to categorize their tests and filter according to those categories.

Each test has a list of tags attached to it. Without specification, this list is empty.
Tags can be defined in two ways. The first being `# bats test_tags=`:

```bash
# bats test_tags=tag:1, tag:2, tag:3
@test "first test" {
  # ...
}

@test "second test" {
  # ...
}
```

These tags (`tag:1`, `tag:2`, `tag:3`) will be attached to the test `first test`.
The second test will have no tags attached. Values defined in the `# bats test_tags=`
directive will be assigned to the next `@test` that is being encountered in the
file and forgotten after that. Only the value of the last `# bats test_tags=` directive
before a given test will be used.

Sometimes, we want to give all tests in a file a set of the same tags. This can
be achieved via `# bats file_tags=`. They will be added to all tests in the file
after that directive. An additional `# bats file_tags=` directive will override
the previously defined values:

```bash
@test "Zeroth test" { 
  # will have no tags
}

# bats file_tags=a:b
# bats test_tags=c:d

@test "First test" { 
  # will be tagged a:b, c:d
}

# bats file_tags=

@test "Second test" {
  # will have no tags
}
```

Tags are case sensitive and must only consist of alphanumeric characters and `_`,
 `-`, or `:`. They must not contain whitespaces!
The colon is intended as a separator for (recursive) namespacing.

Tag lists must be separated by commas and are allowed to contain whitespace.
They must not contain empty tags like `test_tags=,b` (first tag is empty),
`test_tags=a,,c`, `test_tags=a,  ,c` (second tag is only whitespace/empty),
`test_tags=a,b,` (third tag is empty).

Every tag starting with `bats:` (case insensitive!) is reserved for Bats'
internal use.

### Special tags

#### Focusing on tests with `bats:focus` tag

If a test with the tag `bats:focus` is encountered in a test suite,
all other tests will be filtered out and only those tagged with this tag will be executed.

In focus mode, the exit code of successful runs will be overridden to 1 to prevent CI from silently running on a subset of tests due to an accidentally committed `bats:focus` tag.    
Should you require the true exit code, e.g. for a `git bisect` operation, you can disable this behavior by setting
`BATS_NO_FAIL_FOCUS_RUN=1` when running `bats`, but make sure not to commit this to CI!

### Filtering execution

Tags can be used for more finegrained filtering of which tests to run via `--filter-tags`.
This accepts a comma separated list of tags. Only tests that match all of these
tags will be executed. For example, `bats --filter-tags a,b,c` will pick up tests
with tags `a,b,c`, but not tests that miss one or more of those tags.

Additionally, you can specify negative tags via `bats --filter-tags a,!b,c`,
which now won't match tests with tags `a,b,c`, due to the `b`, but will select `a,c`.
To put it more formally, `--filter-tags` is a boolean conjunction.

To allow for more complex queries, you can specify multiple `--filter-tags`.
A test will be executed, if it matches at least one of them.
This means multiple `--filter-tags` form a boolean disjunction.

A query of `--filter-tags a,!b --filter-tags b,c` can be translated to:
Execute only tests that (have tag a, but not tag b) or (have tag b and c).

An empty tag list matches tests without tags.

## Comment syntax

External tools (like `shellcheck`, `shfmt`, and various IDE's) may not support
the standard `.bats` syntax.  Because of this, we provide a valid `bash`
alternative:

```bash
function invoking_foo_without_arguments_prints_usage { #@test
  run foo
  [ "$status" -eq 1 ]
  [ "${lines[0]}" = "usage: foo <filename>" ]
}
```

When using this syntax, the function name will be the title in the result output
and the value checked when using `--filter`.

## Dynamic test registration via `bats_test_function`

Due to the way BATS preprocesses its scripts, the following won't work:

```bash
for i in 1 2 3 ; do
  @test "$i is equal to 1" {
    [ "$1" == 1 ]
  }
done
```

The correct way is to define a function that accepts an argument:

```bash
test_body() {
  [ "$1" == 1 ]
}
```

and then use `bats_test_function` to register calls to it:

```bash
for i in 1 2 3 ; do
  bats_test_function --description "$i is equal to 1" --tags test:$i -- test_body $i
done
```

giving us the following output:

```
 ✓ 1 is equal to 1
 ✗ 2 is equal to 1
   (from function `test_body' in test file test.bats, line 2)
     `[ "$1" == 1 ]' failed
 ✗ 3 is equal to 1
   (from function `test_body' in test file test.bats, line 2)
     `[ "$1" == 1 ]' failed

3 tests, 2 failures
```

Note that the body of the `for` loop uses `$i` but the `test_body` function uses `$1`.

```
bats_test_function [--tags <tags>...] [--description <description>] -- [test command...]

  --tags <tags...>            comma separated list of tags to apply to the test
  --description <description> text to display as name in result output
```

## `run`: Test other commands

Many Bats tests need to run a command and then make assertions about its exit
status and output. Bats includes a `run` helper that invokes its arguments as a
command, saves the exit status and output into special global variables, and
then returns with a `0` status code so you can continue to make assertions in
your test case.

For example, let's say you're testing that the `foo` command, when passed a
nonexistent filename, exits with a `1` status code and prints an error message.

```bash
@test "invoking foo with a nonexistent file prints an error" {
  run foo nonexistent_filename
  [ "$status" -eq 1 ]
  [ "$output" = "foo: no such file 'nonexistent_filename'" ]
  [ "$BATS_RUN_COMMAND" = "foo nonexistent_filename" ]

}
```

The `$status` variable contains the status code of the command, the
`$output` variable contains the combined contents of the command's standard
output and standard error streams, and the `$BATS_RUN_COMMAND` string contains the
command and command arguments passed to `run` for execution.

If invoked with one of the following as the first argument, `run`
will perform an implicit check on the exit status of the invoked command:

```pre
    -N  expect exit status N (0-255), fail if otherwise
    ! expect nonzero exit status (1-255), fail if command succeeds
```

We can then write the above more elegantly as:

```bash
@test "invoking foo with a nonexistent file prints an error" {
  run -1 foo nonexistent_filename
  [ "$output" = "foo: no such file 'nonexistent_filename'" ]
}
```

A third special variable, the `$lines` array, is available for easily accessing
individual lines of output. For example, if you want to test that invoking `foo`
without any arguments prints usage information on the first line:

```bash
@test "invoking foo without arguments prints usage" {
  run -1 foo
  [ "${lines[0]}" = "usage: foo <filename>" ]
}
```

__Note:__ The `run` helper executes its argument(s) in a subshell, so if
writing tests against environmental side-effects like a variable's value
being changed, these changes will not persist after `run` completes.

By default `run` leaves out empty lines in `${lines[@]}`. Use
`run --keep-empty-lines` to retain them.

Additionally, you can use `--separate-stderr` to split stdout and stderr
into `$output`/`$stderr` and `${lines[@]}`/`${stderr_lines[@]}`.

All additional parameters to run should come before the command.
If you want to run a command that starts with `-`, prefix it with `--` to
prevent `run` from parsing it as an option.

### When not to use `run`

In case you only need to check the command succeeded, it is better to not use `run`, since the following code

```bash
run -0 command args ...
```

is equivalent to

```bash
command args ...
```

(because bats sets `set -e` for all tests).

__Note__: In contrast to the above, testing that a command failed is best done via

```bash
run ! command args ...
```

because 

```bash
! command args ...
```

will only fail the test if it is the last command and thereby determines the test function's exit code.
This is due to Bash's decision to (counterintuitively?) not trigger `set -e` on `!` commands.
(See also [the associated gotcha](gotchas.html#my-negated-statement-e-g-true-does-not-fail-the-test-even-when-it-should))


### `run` and pipes

Don't fool yourself with pipes when using `run`. Bash parses the pipe outside of `run`, not internal to its command. Take this example:

```bash
run command args ... | jq -e '.limit == 42'
```

Here, `jq` receives no input (which is captured by `run`), 
executes no filters, and always succeeds, so the test does not work as 
expected.

To correctly handle commands with pipes see `bats_pipe`.

## `bats_pipe`: Run commands with pipes

The `bats_pipe` helper command is meant to handle piping between commands. Its
main purpose is to aide the `run` helper command (which cannot handle pipes, due
to bash parsing priority). `run command0 | command1` will parse `|` before
`run`, which is commonly not intended by test authors.

Running `run bats_pipe command0 \| command1` will have the piped commands run
within the context of the `run` command, and thus have the output and status
variables properly contained within the normal `output` and `status` variables.

Note that this requires the usage of `\|`, not `|`. This is to avoid bash
parsing out `|` first, instead sending `\|` to the `bats_pipe` command for it to
parse and set up intended piping. Running `bats_pipe` with no instances of `\|`
will always fail; this is intended to catch typos (accidentally using `|`) by
the test author.

The `bats_pipe` command will also properly propagate exit status from the piped
commands. The default behavior mimics `set -o pipefail`, returning the status of
the last (rightmost) command that exits with a non-zero status. This ensures
that usage of pipes do not mask the exit statuses of earlier commands.

```bash
@test "invoking foo piped to bar" {
  run bats_pipe foo \| bar
  # asserting foo or bar would return 17 (from foo if bar returns 0).
  [ "$status" -eq 17 ]
  [ "$output" = "bar output." ]
}
```

Alternatively, if the test always cares about the status of a specific command,
the `-<N>` option can be given (e.g. `-0`) to always return the status of the
command of interest.

```bash
@test "invoking foo piped to bar always return foo status" {
  run bats_pipe -0 foo \| bar
  # status of bar is ignored, status is always from foo.
  [ "$status" -eq 2 ]
  [ "$output" = "bar output." ]
}
```

Similarly, `--returned-status N` (or `--returned-status=N`) can be used for
similar functionality. This option supports negative values, which always return
the of the command starting from the end and in reverse order.

```bash
@test "invoking foo piped to bar always return foo status" {
  run bats_pipe --returned-status -2 foo \| bar
  # status of bar is ignored, status is always from foo.
  [ "$status" -eq 2 ]
  [ "$output" = "bar output." ]
}
```

Piping of command output is especially helpful when the output needs to be
modified in some way (e.g. the command outputs binary data into stdout, which
cannot be stored as-is in an environment variable).

```bash
@test "invoking foo that returns binary data" {
  run bats_pipe foo \| hexdump -v -e "1/1 \"0x%02X \""
  [ "$status" -eq 17 ]
  [[ "$output" =~ 0xDE\ 0xAD ]]
}
```

Any number of pipes can be used in conjunction to chain output between some set
of running commands.

## `load`: Share common code

You may want to share common code across multiple test files. Bats
includes a convenient `load` command for sourcing a Bash source files
relative to the current test file and from absolute paths.

For example, if you have a Bats test in `test/foo.bats`, the command

```bash
load test_helper.bash
```

will source the script `test/test_helper.bash` in your test file (limitations
apply, see below). This can be useful for sharing functions to set up your
environment or load fixtures. `load` delegates to Bash's `source` command after
resolving paths.

If `load` encounters errors - e.g. because the targeted source file
errored - it will print a message with the failing library and Bats
exits.

To allow to use `load` in conditions `bats_load_safe` has been added.
`bats_load_safe` prints a message and returns `1` if a source file cannot be
loaded instead of exiting Bats.
Aside from that `bats_load_safe` acts exactly like `load`.

__Note:__ : As pointed out by @iatrou in the [Advanced Bash Scripting Guide
(section 9.2)](https://www.tldp.org/LDP/abs/html/declareref.html),
using the `declare` builtin restricts scope of a variable. Thus, since actual
`source`-ing is performed in context of the `load` function, symbols
defined using `declare` will _not_ be made available to callers of `load` (unless `declare -g`
is used).

### `load` argument resolution

`load` supports the following arguments:

- absolute paths
- relative paths (to the current test file)

> For backwards compatibility `load` first searches for a file ending in
> `.bash` (e.g. `load test_helper` searches for `test_helper.bash` before
> it looks for `test_helper`). This behaviour is deprecated and subject to
> change, please use exact filenames instead.

If `argument` is an absolute path `load` tries to determine the load
path directly.

If `argument` is a relative path or a name `load` looks for a matching
path in the directory of the current test.

## `bats_load_library`: Load system wide libraries

Some libraries are installed on the system, e.g. by `npm` or `brew`.
These should not be `load`ed, as their path depends on the installation method.
Instead, one should use `bats_load_library` together with setting
`BATS_LIB_PATH`, a `PATH`-like colon-delimited variable.

`bats_load_library` has two modes of resolving requests:

1. by relative path from the `BATS_LIB_PATH` to a file in the library
2. by library name, expecting libraries to have a `load.bash` entrypoint

For example if your `BATS_LIB_PATH` is set to
`~/.bats/libs:/usr/lib/bats`, then `bats_load_library test_helper`
would look for existing files with the following paths:

- `~/.bats/libs/test_helper`
- `~/.bats/libs/test_helper/load.bash`
- `/usr/lib/bats/test_helper`
- `/usr/lib/bats/test_helper/load.bash`

The first existing file in this list will be sourced.

If you want to load only part of a library or the entry point is not named `load.bash`,
you have to include it in the argument:
`bats_load_library library_name/file_to_load` will try

- `~/.bats/libs/library_name/file_to_load`
- `~/.bats/libs/library_name/file_to_load/load.bash`
- `/usr/lib/bats/library_name/file_to_load`
- `/usr/lib/bats/library_name/file_to_load/load.bash`

Apart from the changed lookup rules, `bats_load_library` behaves like `load`.

__Note:__ As seen above `load.bash` is the entry point for libraries and
meant to load more files from its directory or other libraries.

__Note:__ Obviously, the actual `BATS_LIB_PATH` is highly dependent on the environment.
To maintain a uniform location across systems, (distribution) package maintainers
are encouraged to use `/usr/lib/bats/` as the install path for libraries where possible.
However, if the package manager has another preferred location, like `npm` or `brew`,
you should use this instead.

## `skip`: Easily skip tests

Tests can be skipped by using the `skip` command at the point in a test you wish
to skip.

```bash
@test "A test I don't want to execute for now" {
  skip
  run foo
  [ "$status" -eq 0 ]
}
```

Optionally, you may include a reason for skipping:

```bash
@test "A test I don't want to execute for now" {
  skip "This command will return zero soon, but not now"
  run foo
  [ "$status" -eq 0 ]
}
```

Or you can skip conditionally:

```bash
@test "A test which should run" {
  if [ foo != bar ]; then
    skip "foo isn't bar"
  fi

  run foo
  [ "$status" -eq 0 ]
}
```

__Note:__ `setup` and `teardown` hooks still run for skipped tests.

## `setup` and `teardown`: Pre- and post-test hooks

You can define special `setup` and `teardown` functions, which run before and
after each test case, respectively. Use these to load fixtures, set up your
environment, and clean up when you're done.

You can also define `setup_file` and `teardown_file`, which will run once before
the first test's `setup` and after the last test's `teardown` for the containing
file. Variables that are exported in `setup_file` will be visible to all following
functions (`setup`, the test itself, `teardown`, `teardown_file`).

Similarly, there is `setup_suite` (and `teardown_suite`) which run once before (and
after) all tests of the test run.

__Note:__ As `setup_suite` and `teardown_suite` are intended for all files in a suite,
they must be defined in a separate `setup_suite.bash` file. Automatic discovery works
by searching for `setup_suite.bash` in the folder of the first `*.bats` file of the suite.
If this automatism does not work for your usecase, you can work around by specifying
`--setup-suite-file` on the `bats` command. If you have a `setup_suite.bash`, it must define
`setup_suite`! However, defining `teardown_suite` is optional.

<!-- markdownlint-disable  MD033 -->
<details>
  <summary>Example of setup/{,_file,_suite} (and teardown{,_file,_suite}) call order</summary>
For example the following call order would result from two files (file 1 with
tests 1 and 2, and file 2 with test3) with a corresponding `setup_suite.bash` file being tested:

```text
setup_suite # from setup_suite.bash
  setup_file # from file 1, on entering file 1
    setup
      test1
    teardown
    setup
      test2
    teardown
  teardown_file # from file 1, on leaving file 1
  setup_file # from file 2,  on enter file 2
    setup
      test3
    teardown
  teardown_file # from file 2,  on leaving file 2
teardown_suite # from setup_suite.bash
```

</details>
<!-- markdownlint-enable MD033 -->

Note that the `teardown*` functions can fail a test, if their return code is nonzero.
This means, using `return 1` or having the last command in teardown fail, will
fail the teardown. Unlike `@test`, failing commands within `teardown` won't
trigger failure as ERREXIT is disabled.

<!-- markdownlint-disable MD033 -->
<details>
  <summary>Example of different teardown failure modes</summary>

```bash
teardown() {
  false # this will fail the test, as it determines the return code
}

teardown() {
  false # this won't fail the test ...
  echo some more code # ... and this will be executed too!
}

teardown() {
  return 1 # this will fail the test, but the rest won't be executed
  echo some more code
}

teardown() {
  if true; then
    false # this will also fail the test, as it is the last command in this function
  else
    true
  fi
}
```

</details>
<!-- markdownlint-enable MD033 -->

## `bats::on_failure` hook

While `teardown` unconditionally handles cleanup after the test ends, the `bats::on_failure` hook gets called 
only when a test is aborted due to an error. `bats::on_failure` will be called before `teardown`.

You can define `bats::on_failure` anywhere in your test files, even inside the test functions, to change its behavior midtest:

```bash
@test "my awesome test" {
  simple_test_setup

  bats::on_failure() {
    handle_simple_error_case
  }

  complex_test_setup

  bats::on_failure() {
    print_debug_information_only_on_error
  }

  do_actual_tests

  check_results
}
```

The `bats::on_failure` hook is available in `setup_suite`/`setup_file`/`setup`, their respective teardown functions, and test functions.

## `bats_require_minimum_version <Bats version number>`

Added in [v1.7.0](https://github.com/bats-core/bats-core/releases/tag/v1.7.0)

Code for newer versions of Bats can be incompatible with older versions.
In the best case this will lead to an error message and a failed test suite.
In the worst case, the tests will pass erroneously, potentially masking a failure.

Use `bats_require_minimum_version <Bats version number>` to avoid this.
It communicates in a concise manner, that you intend the following code to be run
under the given Bats version or higher.

Additionally, this function will communicate the current Bats version floor to
subsequent code, allowing e.g. Bats' internal warning to give more informed warnings.

__Note__: By default, calling `bats_require_minimum_version` with versions before
Bats 1.7.0 will fail regardless of the required version as the function is not
available. However, you can use the
[bats-backports plugin](https://github.com/bats-core/bats-backports) to make
your code usable with older versions, e.g. during migration while your CI system
is not yet upgraded.

## Code outside of test cases

In general you should avoid code outside tests, because each test file will be evaluated many times.
However, there are situations in which this might be useful, e.g. when you want to check for dependencies
and fail immediately if they're not present. 

In general, you should avoid printing outside of `@test`, `setup*` or `teardown*` functions.
Have a look at section [printing to the terminal](#printing-to-the-terminal) for more details.
## File descriptor 3 (read this if Bats hangs)

Bats makes a separation between output from the code under test and output that
forms the TAP stream (which is produced by Bats internals). This is done in
order to produce TAP-compliant output. In the [Printing to the
terminal](#printing-to-the-terminal) section, there are details on how to use
file descriptor 3 to print custom text properly.

A side effect of using file descriptor 3 is that, under some circumstances, it
can cause Bats to block and execution to seem dead without reason. This can
happen if a child process is spawned in the background from a test. In this
case, the child process will inherit file descriptor 3. Bats, as the parent
process, will wait for the file descriptor to be closed by the child process
before continuing execution. If the child process takes a lot of time to
complete (eg if the child process is a `sleep 100` command or a background
service that will run indefinitely), Bats will be similarly blocked for the same
amount of time.

**To prevent this from happening, close FD 3 explicitly when running any command
that may launch long-running child processes**, e.g. `command_name 3>&-` .

## Printing to the terminal

Bats produces output compliant with [version 12 of the TAP protocol](https://testanything.org/tap-specification.html). The
produced TAP stream is by default piped to a pretty formatter for human
consumption, but if Bats is called with the `-t` flag, then the TAP stream is
directly printed to the console.

This has implications if you try to print custom text to the terminal. As
mentioned in [File descriptor 3](#file-descriptor-3-read-this-if-bats-hangs),
bats provides a special file descriptor, `&3`, that you should use to print
your custom text. Here are some detailed guidelines to refer to:

- Printing **from within a test function**:
  - First you should consider if you want the text to be always visible or only
    when the test fails. Text that is output directly to stdout or stderr (file
    descriptor 1 or 2), ie `echo 'text'` is considered part of the test function
    output and is printed only on test failures for diagnostic purposes,
    regardless of the formatter used (TAP or pretty).
  - To have text printed unconditionally from within a test function you need to
    redirect the output to file descriptor 3, eg `echo 'text' >&3`. This output
    will become part of the TAP stream. You are encouraged to prepend text printed
    this way with a hash (eg `echo '# text' >&3`) in order to produce 100% TAP compliant
    output. Otherwise, depending on the 3rd-party tools you use to analyze the
    TAP stream, you can encounter unexpected behavior or errors.

- Printing **from within the `setup*` or `teardown*` functions**: The same hold
  true as for printing with test functions.

- Printing **outside test or `setup*`/`teardown*` functions**:
  - You should avoid printing in free code: Due to the multiple executions
    contexts (`setup_file`, multiple `@test`s)  of test files, output
    will be printed more than once.

  - Regardless of where text is redirected to (stdout, stderr or file descriptor 3)
    text is immediately visible in the terminal, as it is not piped into the formatter.

  - Text printed to stdout may interfere with formatters as it can
    make output non-compliant with the TAP spec. The reason for this is that
    such output will be produced before the [_plan line_][tap-plan] is printed,
    contrary to the spec that requires the _plan line_ to be either the first or
    the last line of the output.

  - Due to internal pipes/redirects, output to stderr is always printed first.

[tap-plan]: https://testanything.org/tap-specification.html#the-plan

## Special variables

There are several global variables you can use to introspect on Bats tests:

- `$BATS_RUN_COMMAND` is the run command used in your test case.
- `$BATS_TEST_FILENAME` is the fully expanded path to the Bats test file.
- `$BATS_TEST_DIRNAME` is the directory in which the Bats test file is located.
- `$BATS_TEST_NAMES` is an array of function names for each test case.
- `$BATS_TEST_NAME` is the name of the function containing the current test case.
- `$BATS_TEST_NAME_PREFIX` will be prepended to the description of each test on
   stdout and in reports.
- `$BATS_TEST_DESCRIPTION` is the description of the current test case.
- `$BATS_TEST_RETRIES` is the maximum number of additional attempts that will be
  made on a failed test before it is finally considered failed.
  The default of 0 means the test must pass on the first attempt.
- `$BATS_TEST_TIMEOUT` is the number of seconds after which a test (including setup)
  will be aborted and marked as failed. Updates to this value in `setup()` or `@test`
  cannot change the running timeout countdown, so the latest useful update location
  is `setup_file()`.
- `$BATS_TEST_NUMBER` is the (1-based) index of the current test case in the test file.
- `$BATS_SUITE_TEST_NUMBER` is the (1-based) index of the current test case in the test suite (over all files).
- `$BATS_JOBSLOT` is the unique job slot number for a given test, an integer
  between 1 and `$BATS_JOBSLOTS` inclusive. No two tests will ever run
  concurrently with the same slot number.
- `$BATS_JOBSLOTS` is the maximum number of concurrent test jobs. This is not
  necessarily the same as the value of the `-j` option! When running with
  `--no-parallelize-across-files` or `--no-parallelize-within-files`, this
  will be the same as `-j`. When running without either option (default),
  it will be `-j` _squared_ because Bats uses its own algorithm to
  run same-file tests.
- `$BATS_TEST_TAGS` the tags of the current test.
- `$BATS_TMPDIR` is the base temporary directory used by bats to create its
   temporary files / directories.
   (default: `$TMPDIR`. If `$TMPDIR` is not set, `/tmp` is used.)
- `$BATS_RUN_TMPDIR` is the location to the temporary directory used by bats to
   store all its internal temporary files during the tests.
   (default: `$BATS_TMPDIR/bats-run-$BATS_ROOT_PID-XXXXXX`)
- `$BATS_FILE_EXTENSION` (default: `bats`) specifies the extension of test files that should be found when running a suite (via `bats [-r] suite_folder/`)
- `$BATS_SUITE_TMPDIR` is a temporary directory common to all tests of a suite.
  Could be used to create files required by multiple tests.
- `$BATS_FILE_TMPDIR` is a temporary directory common to all tests of a test file.
  Could be used to create files required by multiple tests in the same test file.
- `$BATS_TEST_TMPDIR` is a temporary directory unique for each test.
  Could be used to create files required only for specific tests.
- `$BATS_VERSION` is the version of Bats running the test.

## Libraries and Add-ons

Bats supports loading external assertion libraries and helpers. Those under `bats-core` are officially supported libraries (integration tests welcome!):

- <https://github.com/bats-core/bats-assert> - common assertions for Bats
- <https://github.com/bats-core/bats-support> - supporting library for Bats test helpers
- <https://github.com/bats-core/bats-file> - common filesystem assertions for Bats
- <https://github.com/bats-core/bats-detik> - e2e tests of applications in K8s environments

Furthermore, you can find a list of [3rd-party libraries](https://github.com/bats-core/bats-core/wiki/3rd%E2%80%90party-Libraries-for-Bats) in our Wiki.