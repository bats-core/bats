> # :warning: WARNING: documentation of unreleased features ahead
>
> This is the current development version. You can find the documentation for v1.2.0 [here](../v1.2.0/README.md).
> Please refer to [this list](docs/versions.md) for older versions.

# Bats-core: Bash Automated Testing System (2018)

[![Latest release](https://img.shields.io/github/release/bats-core/bats-core.svg)](https://github.com/bats-core/bats-core/releases/latest)
[![npm package](https://img.shields.io/npm/v/bats.svg)](https://www.npmjs.com/package/bats)
[![License](https://img.shields.io/github/license/bats-core/bats-core.svg)](https://github.com/bats-core/bats-core/blob/master/LICENSE.md)
[![Continuous integration status for Linux and macOS](https://img.shields.io/travis/bats-core/bats-core/master.svg?label=travis%20build)](https://travis-ci.org/bats-core/bats-core)
[![Continuous integration status for Windows](https://img.shields.io/appveyor/ci/bats-core/bats-core/master.svg?label=appveyor%20build)](https://ci.appveyor.com/project/bats-core/bats-core)

[![Join the chat in bats-core/bats-core on gitter](https://badges.gitter.im/bats-core/bats-core.svg)][gitter]

Bats is a [TAP][]-compliant testing framework for Bash.  It provides a simple
way to verify that the UNIX programs you write behave as expected.

[TAP]: https://testanything.org

A Bats test file is a Bash script with special syntax for defining test cases.
Under the hood, each test case is just a function with a description.

```bash
#!/usr/bin/env bats

@test "addition using bc" {
  result="$(echo 2+2 | bc)"
  [ "$result" -eq 4 ]
}

@test "addition using dc" {
  result="$(echo 2 2+p | dc)"
  [ "$result" -eq 4 ]
}
```

Bats is most useful when testing software written in Bash, but you can use it to
test any UNIX program.

Test cases consist of standard shell commands. Bats makes use of Bash's
`errexit` (`set -e`) option when running test cases. If every command in the
test case exits with a `0` status code (success), the test passes. In this way,
each line is an assertion of truth.

## Table of contents

<!-- toc -->

- [Installation](#installation)
  * [Supported Bash versions](#supported-bash-versions)
  * [Homebrew](#homebrew)
  * [npm](#npm)
  * [Installing Bats from source](#installing-bats-from-source)
  * [Installing Bats from source onto Windows Git Bash](#installing-bats-from-source-onto-windows-git-bash)
  * [Running Bats in Docker](#running-bats-in-docker)
    + [Building a Docker image](#building-a-docker-image)
- [Usage](#usage)
  * [Parallel Execution](#parallel-execution)
- [Writing tests](#writing-tests)
  * [`run`: Test other commands](#run-test-other-commands)
  * [`load`: Share common code](#load-share-common-code)
  * [`skip`: Easily skip tests](#skip-easily-skip-tests)
  * [`setup` and `teardown`: Pre- and post-test hooks](#setup-and-teardown-pre--and-post-test-hooks)
  * [Code outside of test cases](#code-outside-of-test-cases)
  * [File descriptor 3 (read this if Bats hangs)](#file-descriptor-3-read-this-if-bats-hangs)
  * [Printing to the terminal](#printing-to-the-terminal)
  * [Special variables](#special-variables)
  * [Libraries and Add-ons](#libraries-and-add-ons)
- [Testing](#testing)
- [Support](#support)
- [Contributing](#contributing)
- [Contact](#contact)
- [Version history](#version-history)
- [Background](#background)
  * [What's the plan and why?](#whats-the-plan-and-why)
  * [Why was this fork created?](#why-was-this-fork-created)
- [Copyright](#copyright)

<!-- tocstop -->

## Installation

### Supported Bash versions

The following is a list of Bash versions that are currently supported by Bats.
This list is composed of platforms that Bats has been tested on and is known to
work on without issues.

- Bash versions:
  - Everything from `3.2.57(1)` and higher (macOS's highest version)

- Operating systems:
  - Arch Linux
  - Alpine Linux
  - Ubuntu Linux
  - FreeBSD `10.x` and `11.x`
  - macOS
  - Windows 10

- Latest version for the following Windows platforms:
  - Git for Windows Bash (MSYS2 based)
  - Windows Subsystem for Linux
  - MSYS2
  - Cygwin

### Homebrew

On macOS, you can install [Homebrew](https://brew.sh/) if you haven't already,
then run:

```bash
$ brew install bats-core
```

### npm

You can install the [Bats npm package](https://www.npmjs.com/package/bats) via:

```
# To install globally:
$ npm install -g bats

# To install into your project and save it as one of the "devDependencies" in
# your package.json:
$ npm install --save-dev bats
```

### Installing Bats from source

Check out a copy of the Bats repository. Then, either add the Bats `bin`
directory to your `$PATH`, or run the provided `install.sh` command with the
location to the prefix in which you want to install Bats. For example, to
install Bats into `/usr/local`,

    $ git clone https://github.com/bats-core/bats-core.git
    $ cd bats-core
    $ ./install.sh /usr/local

__Note:__ You may need to run `install.sh` with `sudo` if you do not have
permission to write to the installation prefix.

### Installing Bats from source onto Windows Git Bash

Check out a copy of the Bats repository and install it to `$HOME`. This
will place the `bats` executable in `$HOME/bin`, which should already be
in `$PATH`.

    $ git clone https://github.com/bats-core/bats-core.git
    $ cd bats-core
    $ ./install.sh $HOME

### Running Bats in Docker

There is an official image on the Docker Hub:

    $ docker run -it bats/bats:latest --version

#### Building a Docker image

Check out a copy of the Bats repository, then build a container image:

    $ git clone https://github.com/bats-core/bats-core.git
    $ cd bats-core
    $ docker build --tag bats/bats:latest .

This creates a local Docker image called `bats/bats:latest` based on [Alpine
Linux](https://github.com/gliderlabs/docker-alpine/blob/master/docs/usage.md)
(to push to private registries, tag it with another organisation, e.g.
`my-org/bats:latest`).

To run Bats' internal test suite (which is in the container image at
`/opt/bats/test`):

    $ docker run -it bats/bats:latest /opt/bats/test

To run a test suite from a directory called `test` in the current directory of
your local machine, mount in a volume and direct Bats to its path inside the
container:

    $ docker run -it -v "${PWD}:/code" bats/bats:latest test

> `/code` is the working directory of the Docker image. "${PWD}/test" is the
> location of the test directory on the local machine.

This is a minimal Docker image. If more tools are required this can be used as a
base image in a Dockerfile using `FROM <Docker image>`.  In the future there may
be images based on Debian, and/or with more tools installed (`curl` and `openssl`,
for example). If you require a specific configuration please search and +1 an
issue or [raise a new issue](https://github.com/bats-core/bats-core/issues).

Further usage examples are in
[the wiki](https://github.com/bats-core/bats-core/wiki/Docker-Usage-Examples).

## Usage

Bats comes with two manual pages. After installation you can view them with `man
1 bats` (usage manual) and `man 7 bats` (writing test files manual). Also, you
can view the available command line options that Bats supports by calling Bats
with the `-h` or `--help` options. These are the options that Bats currently
supports:

```
Bats x.y.z
Usage: bats [OPTIONS] <tests>
       bats [-h | -v]

  <tests> is the path to a Bats test file, or the path to a directory
  containing Bats test files (ending with ".bats")

  -c, --count               Count test cases without running any tests
  -f, --filter <regex>      Only run tests that match the regular expression
  -F, --formatter <type>    Switch between formatters: pretty (default),
                              tap (default w/o term), tap13, junit
  -h, --help                Display this help message
  -j, --jobs <jobs>         Number of parallel jobs (requires GNU parallel)
  --no-tempdir-cleanup      Preserve test output temporary directory
  --no-parallelize-across-files
                            Serialize test file execution instead of running
                            them in parallel (requires --jobs >1)
  --no-parallelize-within-files
                            Serialize test execution within files instead of
                            running them in parallel (requires --jobs >1)
  --report-formatter <type> Switch between reporters (same options as --formatter)
  -o, --output <dir>        Directory to write report files
  -p, --pretty              Shorthand for "--formatter pretty"
  -r, --recursive           Include tests in subdirectories
  -t, --tap                 Shorthand for "--formatter tap"
  -T, --timing              Add timing information to tests
  -v, --version             Display the version number

  For more information, see https://github.com/bats-core/bats-core
```

To run your tests, invoke the `bats` interpreter with one or more paths to test
files ending with the `.bats` extension, or paths to directories containing test
files. (`bats` will only execute `.bats` files at the top level of each
directory; it will not recurse unless you specify the `-r` flag.)

Test cases from each file are run sequentially and in isolation. If all the test
cases pass, `bats` exits with a `0` status code. If there are any failures,
`bats` exits with a `1` status code.

When you run Bats from a terminal, you'll see output as each test is performed,
with a check-mark next to the test's name if it passes or an "X" if it fails.

    $ bats addition.bats
     ✓ addition using bc
     ✓ addition using dc

    2 tests, 0 failures

If Bats is not connected to a terminal—in other words, if you run it from a
continuous integration system, or redirect its output to a file—the results are
displayed in human-readable, machine-parsable [TAP format][TAP].

You can force TAP output from a terminal by invoking Bats with the `--formatter tap`
option.

    $ bats --formatter tap addition.bats
    1..2
    ok 1 addition using bc
    ok 2 addition using dc

With `--formatter junit`, it is possible
to output junit-compatible report files.

    $ bats --formatter junit addition.bats
    1..2
    ok 1 addition using bc
    ok 2 addition using dc

Test reports will be output in the executing directory, but may be placed elsewhere
by specifying the `--output` flag.

    $ bats --formatter junit addition.bats --output /tmp
    1..2
    ok 1 addition using bc
    ok 2 addition using dc

### Parallel Execution

By default, Bats will execute your tests serially. However, Bats supports
parallel execution of tests (provided you have [GNU parallel][gnu-parallel] or
a compatible replacement installed) using the `--jobs` parameter. This can
result in your tests completing faster (depending on your tests and the testing
hardware).

Ordering of parallised tests is not guaranteed, so this mode may break suites
with dependencies between tests (or tests that write to shared locations). When
enabling `--jobs` for the first time be sure to re-run bats multiple times to
identify any inter-test dependencies or non-deterministic test behaviour.

When parallelizing, the results of a file only become visible after it has been finished.
You can use `--no-parallelize-across-files` to get immediate output at the cost of reduced
overall parallelity, as parallelization will only happen within files and files will be run
sequentially.

If you have files where tests within the file would interfere with each other, you can use
`--no-parallelize-within-files` to disable parallelization within all files.
If you want more finegrained control, you can `export BATS_NO_PARALLELIZE_WITHIN_FILE=true` in `setup_file()`
or outside any function to disable parallelization only within the containing file.    

[gnu-parallel]: https://www.gnu.org/software/parallel/

## Writing tests

Each Bats test file is evaluated _n+1_ times, where _n_ is the number of
test cases in the file. The first run counts the number of test cases,
then iterates over the test cases and executes each one in its own
process.

For more details about how Bats evaluates test files, see [Bats Evaluation
Process][bats-eval] on the wiki.

For sample test files, see [examples](/docs/examples).

[bats-eval]: https://github.com/bats-core/bats-core/wiki/Bats-Evaluation-Process

### `run`: Test other commands

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
}
```

The `$status` variable contains the status code of the command, and the
`$output` variable contains the combined contents of the command's standard
output and standard error streams.

If invoked with one of the following as the first argument, `run`
will perform an implicit check on the exit status of the invoked command:

    =N  expect exit status N (0-255), fail if otherwise
    '!' expect nonzero exit status (1-255), fail if command succeeds

We can then write the above more elegantly as:

```bash
@test "invoking foo with a nonexistent file prints an error" {
  run =1 foo nonexistent_filename
  [ "$output" = "foo: no such file 'nonexistent_filename'" ]
}
```

A third special variable, the `$lines` array, is available for easily accessing
individual lines of output. For example, if you want to test that invoking `foo`
without any arguments prints usage information on the first line:

```bash
@test "invoking foo without arguments prints usage" {
  run =1 foo
  [ "${lines[0]}" = "usage: foo <filename>" ]
}
```

__Note:__ The `run` helper executes its argument(s) in a subshell, so if
writing tests against environmental side-effects like a variable's value
being changed, these changes will not persist after `run` completes.

#### When not to use `run`

In some cases, using `run` is redundant and results in a longer and less readable code.
Here are a few examples.

1. In case you only need to check the command succeeded, it is better to not use run, since

```bash
run command args ...
echo "$output"
[ "$status" -eq 0 ]
```

is equivalent to

```bash
command args ...
```

since bats sets `set -e` for all tests.

2. In case you need to assign command output to a variable (and maybe check
   the command exit status), it is better to not use run, since

```bash
run =0 command args ...
var="$output"
```

is equivalent to
```bash
var=$(command args ...)
```



### `load`: Share common code

You may want to share common code across multiple test files. Bats includes a
convenient `load` command for sourcing a Bash source file relative to the
location of the current test file. For example, if you have a Bats test in
`test/foo.bats`, the command

```bash
load test_helper.bash
```

will source the script `test/test_helper.bash` in your test file (limitations
apply, see below). This can be useful for sharing functions to set up your
environment or load fixtures. `load` delegates to Bash's `source` command after
resolving relative paths.

As pointed out by @iatrou in https://www.tldp.org/LDP/abs/html/declareref.html,
using the `declare` builtin restricts scope of a variable. Thus, since actual
`source`-ing is performed in context of the `load` function, `declare`d symbols
will _not_ be made available to callers of `load`.

> For backwards compatibility `load` first searches for a file ending in
> `.bash` (e.g. `load test_helper` searches for `test_helper.bash` before
> it looks for `test_helper`). This behaviour is deprecated and subject to
> change, please use exact filenames instead.

### `skip`: Easily skip tests

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

### `setup` and `teardown`: Pre- and post-test hooks

You can define special `setup` and `teardown` functions, which run before and
after each test case, respectively. Use these to load fixtures, set up your
environment, and clean up when you're done.

You can also define `setup_file` and `teardown_file`, which will run once before the first test's `setup` and after the last test's `teardown` for the containing file. Variables that are exported in `setup_file` will be visible to all following functions (`setup`, the test itself, `teardown`, `teardown_file`).

<details>
  <Summary>Example of setup/setup_file/teardown/teardown_file call order</summary>
For example the following call order would result from two files (file 1 with tests 1 and 2, and file 2 with test3) beeing tested:

```
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
```
</details>

### Code outside of test cases

You can include code in your test file outside of `@test` functions.  For
example, this may be useful if you want to check for dependencies and fail
immediately if they're not present. However, any output that you print in code
outside of `@test`, `setup` or `teardown` functions must be redirected to
`stderr` (`>&2`). Otherwise, the output may cause Bats to fail by polluting the
TAP stream on `stdout`.

### File descriptor 3 (read this if Bats hangs)

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

### Printing to the terminal

Bats produces output compliant with [version 12 of the TAP protocol][TAP]. The
produced TAP stream is by default piped to a pretty formatter for human
consumption, but if Bats is called with the `-t` flag, then the TAP stream is
directly printed to the console.

This has implications if you try to print custom text to the terminal. As
mentioned in [File descriptor 3](#file-descriptor-3-read-this-if-bats-hangs),
bats provides a special file descriptor, `&3`, that you should use to print
your custom text. Here are some detailed guidelines to refer to:

- Printing **from within a test function**:
  - To have text printed from within a test function you need to redirect the
    output to file descriptor 3, eg `echo 'text' >&3`. This output will become
    part of the TAP stream. You are encouraged to prepend text printed this way
    with a hash (eg `echo '# text' >&3`) in order to produce 100% TAP compliant
    output. Otherwise, depending on the 3rd-party tools you use to analyze the
    TAP stream, you can encounter unexpected behavior or errors.

  - The pretty formatter that Bats uses by default to process the TAP stream
    will filter out and not print text output to file descriptor 3.

  - Text that is output directly to stdout or stderr (file descriptor 1 or 2),
    ie `echo 'text'` is considered part of the test function output and is
    printed only on test failures for diagnostic purposes, regardless of the
    formatter used (TAP or pretty).

- Printing **from within the `setup` or `teardown` functions**: The same hold
  true as for printing with test functions.

- Printing **outside test or `setup`/`teardown` functions**:
  - Regardless of where text is redirected to (stdout, stderr or file descriptor
    3) text is immediately visible in the terminal.

  - Text printed in such a way, will disable pretty formatting. Also, it will
    make output non-compliant with the TAP spec. The reason for this is that
    each test file is evaluated n+1 times (as mentioned
    [earlier](#writing-tests)). The first run will cause such output to be
    produced before the [_plan line_][tap-plan] is printed, contrary to the spec
    that requires the _plan line_ to be either the first or the last line of the
    output.

  - Due to internal pipes/redirects, output to stderr is always printed first.

[tap-plan]: https://testanything.org/tap-specification.html#the-plan

### Special variables

There are several global variables you can use to introspect on Bats tests:

* `$BATS_TEST_FILENAME` is the fully expanded path to the Bats test file.
* `$BATS_TEST_DIRNAME` is the directory in which the Bats test file is located.
* `$BATS_TEST_NAMES` is an array of function names for each test case.
* `$BATS_TEST_NAME` is the name of the function containing the current test
  case.
* `$BATS_TEST_DESCRIPTION` is the description of the current test case.
* `$BATS_TEST_NUMBER` is the (1-based) index of the current test case in the
  test file.
* `$BATS_SUITE_TEST_NUMBER` is the (1-based) index of the current test case in
 the test suite (over all files).
* `$BATS_TMPDIR` is the location to a directory that may be used to store
  temporary files.

### Libraries and Add-ons

Bats supports loading external assertion libraries and helpers. Those under `bats-core` are officially supported libraries (integration tests welcome!):

- https://github.com/bats-core/bats-assert - common assertions for Bats
- https://github.com/bats-core/bats-support - supporting library for Bats test helpers
- https://github.com/bats-core/bats-file - common filesystem assertions for Bats
- https://github.com/bats-core/bats-detik - e2e tests of applications in K8s environments

and some external libraries, supported on a "best-effort" basis:

- https://github.com/ztombol/bats-docs (still relevant? Requires review)
- https://github.com/grayhemp/bats-mock (as per #147)
- https://github.com/jasonkarns/bats-mock (how is this different from grayhemp/bats-mock?)

## Testing

```sh
bin/bats --tap test
```
See also the [CI](.travis.yml) settings for the current test environment and
scripts.

## Support

The Bats source code repository is [hosted on
GitHub](https://github.com/bats-core/bats-core). There you can file bugs on the
issue tracker or submit tested pull requests for review.

For real-world examples from open-source projects using Bats, see [Projects
Using Bats](https://github.com/bats-core/bats-core/wiki/Projects-Using-Bats) on
the wiki.

To learn how to set up your editor for Bats syntax highlighting, see [Syntax
Highlighting](https://github.com/bats-core/bats-core/wiki/Syntax-Highlighting)
on the wiki.

## Contributing

For now see the ``docs`` folder for project guides, work with us on the wiki
or look at the other communication channels.

## Contact

- We are `#bats` on freenode;
- Or leave a message on [gitter].

## Version history

See `docs/CHANGELOG.md`.

## Background

### What's the plan and why?

**Tuesday, September 19, 2017:** This was forked from [Bats][bats-orig] at
commit [0360811][].  It was created via `git clone --bare` and `git push
--mirror`.

[bats-orig]: https://github.com/sstephenson/bats
[0360811]: https://github.com/sstephenson/bats/commit/03608115df2071fff4eaaff1605768c275e5f81f

This [bats-core repo](https://github.com/bats-core/bats-core) is the community-maintained Bats project.

### Why was this fork created?

There was an initial [call for maintainers][call-maintain] for the original Bats repository, but write access to it could not be obtained. With development activity stalled, this fork allowed ongoing maintenance and forward progress for Bats.

[call-maintain]: https://github.com/sstephenson/bats/issues/150

## Copyright

© 2017-2020 bats-core organization

© 2011-2016 Sam Stephenson

Bats is released under an MIT-style license; see `LICENSE.md` for details.

See the [parent project](https://github.com/bats-core) at GitHub or the
[AUTHORS](AUTHORS) file for the current project maintainer team.

[gitter]: https://gitter.im/bats-core/bats-core?utm_source=badge&utm_medium=badge&utm_campaign=pr-badge&utm_content=badge
