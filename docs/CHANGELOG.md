# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog][kac] and this project adheres to
[Semantic Versioning][semver].

[kac]: https://keepachangelog.com/en/1.0.0/
[semver]: https://semver.org/


## [Unreleased]

### Added

* `--` option terminator to allow test paths starting with `-` (#867, #1251)
* `$BATS_ALLOW_EMPTY_SUITE` environment variable as an alternative to `--allow-empty-suite`, which keeps test setups compatible with Bats versions before 1.14 that don't know the flag (#1240)

### Fixed

* update pre-commit hook and replace unmaintained one (#1306)
* avoid false duplicate errors for dynamic tests with argument prefixes, and
  detect duplicates with non-space `IFS` separators (#1249)
* fix incorrect stack traces when `load` or `bats_load_library` fails (#1186, #1250)
* pretty formatter was not the default on interactive shells anymore (#1220)
* `--jobs` now aborts when GNU parallel is unavailable instead of failing later (#1237, #1238)
* `bats_encode_test_name()` used the locale-dependent `[[:alnum:]]` character class, causing test names with non-ASCII characters to be silently skipped under some locales (#1236)
* normalize BATS_ROOT from PowerShell on Windows (#1257)
* normalize BATS_LIB_PATH from PowerShell on Windows (#1258)
* pretty formatter colored the summary green when tests timed out or did not run (#538, #1263)
* make LICENSE.md machine-parsable (#1262)
* preserve semaphore wrapper exit status (#1271)
* protect Bats-owned execution variables (#1269)
* fix missing newlines in `$BATS_TMPDIR`-error handling checks at startup (#1194)

### Changed

* use native Rush in tests on macOS runners, bump Rush version to 0.10.0 (#1260)
* parallel: claim semaphore slots with noclobber(#1279)

### Changed

* claim parallel semaphore slots atomically (#1259)

### Documentation

* removed the FAQ's outdated claim that suite-wide setup functionality does not exist; it now points to `setup_suite` (#1213)

## [1.14.0] - 2026-07-21

### Added

* `--errexit` flag to enable errexit (set -e) behavior for commands run in `run` (#1118)
* pretty formatter: add non-interactive, color-only mode for CI environments (#1191)

### Fixed

* junit formatter:
  * avoid interference between env and internals (#1175)
  * remove control characters (\x00-\x08\x0B\x0C\x0E-\x1F) (#1176)
  * don't report (skipped) last test as failed when `teardown_suite` generates FD3 output (#1181)
  * fix(junit-formatter): skipped tests outputs reported as <system-err> (#1177)
* fix failures with `--gather-test-outputs-in` when tests change directory (#1183)
* `run` now honors `set -e` in your functions (#1118)
  * **ATTENTION**: In previous versions this was suppressed unintentionally.
    While it might constitute a breaking change for some, we decided the new behavior should be the default because it might uncover hidden errors.
    If you need the old behavior, you can use this wrapper function `suppress_errexit() { "$@" || return $?; }` like `run suppress_errexit <your command...>`
* avoid overwriting `$_` by the DEBUG and ERR traps set by Bats (#1208)
* fail with error when receiving empty string as testfile path (#1212)

### Changed

* update the default version of the `bash` Docker image to 5.3 in `devcontainer` (#1184)
* exit with error when no tests are found. Use `--allow-empty-suite` to revert to old behavior. (#1211)

### Documentation

* added section about dynamic test registration (#1187)

## [1.13.0] - 2025-11-07

### Added

* use the [`syntax`](https://docs.docker.com/reference/dockerfile/#syntax) parser directive to declare the Dockerfile syntax version (#1127)
* Negative test filtering via `--negative-filter` - tests matching the filter are *excluded* (#1114)
* fail-fast flag `--abort` to stop test suite execution on first failure (#1155)

### Fixed

* unset `output`, `stderr`, `lines`, `stderr_lines` at the start of `run` to avoid crosstalk
  between successive invocations (#1105)
* junit:
  * XML escape fully removes ANSI sequences, e.g. color codes, cursor movements (#1103)
  * fix retried tests being listed multiple times (#1150)
  * fix crash when `setup_suite` fails (#1125)
* remove deprecated windows runner (#1119)
* renamed `docker-compose.yml` to `compose.yaml` (#1128)
* `bats_test_function`: don't require `--tags` to be sorted (#1158)
* fix `BATS_TEST_TIMEOUT` (#1160)
  * not stopping processes under `run`
  * prolonging skipped tests

### Documentation

* moved 3rd-party libraries list into wiki (#1078)

## [1.12.0] - 2025-05-18

### Added

* `bats::on_failure` hook that gets called when a test or `setup*` function fails (#1031)

### Fixed

* increase compatibility with Solaris (#1043)
* fix `noclobber` breaking `bats-gather-tests` (#1042)
* fix exiting with `0` despite `bats:focus` when all tests have been filtered out (#1058)
* remove deprecated ubuntu 20.04 from CI config (#1083)

### Documentation

* Fix hyperlink to external Bash resource (#1033)
* Remove mentions to no longer existing `find_library_load_path` in
  `lib/bats-core` docstrings (#1032)
* Add missing "status" word in `--returned-status` documentation (#1077)

## [1.11.1] - 2024-11-29

### Added

* make Dockerfile compatible with `#!/bin/bash` files (#967)

#### Documentation

* document `bats_pipe` function (#901)

### Fixed

* unbreak test suites with multiple files loading common constants (#904), introduced in v1.11.0
* docker image won't crash if a file or directory named 'bats' exists (#920)
* use $BATS_LIBDIR instead of hardcoded lib in 'bats-gather-tests' (#985, #990)

### Changed

* update Docker image with the latest `bats-detik` version 1.3.2 (#1017)
* cleanup: remove unused `$BATS_FILTER` (#907)

#### Documentation

* fix hard-coded link to readthedocs (#901)
* fix tutorial code for multiline test suite (#1011)

## [1.11.0] - 2024-03-24

### Added

* hardened CI scripts by using hashes instead of versions for actions and restricting permissions (#754, #770)
* add security.md (#762)
* add codespell CI checks (#720)
* dynamic test registration via `bats_test_function` (#349)
* add check that Bats is executed with Bash >= 3.2 (#873)

### Fixed

* `install.sh` now works for deviating `lib/` dirs (like `lib32`,`lib64`) (#487)
* catch unset `BATS_TEST_SOURCE` in `lib/bats-core/tracing.bash` so
  `set -u`/`set -o nounset` works as expected (#827)
* fix `--gather-test-outputs-in` fails on tests with multiple `/` (#789)
* install does not create unused `/usr/share/bats` anymore (#857)
* ensure IFS is unchanged in `{setup,teardown}{_suite,_file,}`, `@test` and free code (#879)
* junit formatter: remove ANSI Codes to avoid invalid XML character (#886)

### Changed

* update Docker image with the latest `bats-file` version 0.4.0 (#780)
* update Docker image with the latest `bats-detik` version 1.3.0 (#876)

#### Documentation

* clarify docker usage (#741)
* update Arch Linux package URL in installation.rst (#821)
* rename bash-bats to bats for Arch Linux in installation.rst (#836)
* fix FAQ entry about setup-/teardown_suite, as they are available now (#861)
* added logo (#881)

## [1.10.0] - 2023-07-15

### Added

* add `${BATS_TEST_TAGS[@]}` for querying the tags during a test (#705)
* print tags on failing tests (#705)
* test for negative arguments to `--jobs` (#693)
* add tests for `--formatter cat` (#710)
* test coverage in CI (#718)
* Support for [rush](https://github.com/shenwei356/rush) as alternative to GNU parallel (#729)
* add `bats_pipe` helper function for `run` that executes `\|` as pipes (#663)
* publish docker images to ghcr.io (additionally to Dockerhub) (#740)

### Documentation

* clarify use cases of `--formatter cat` (#710)

### Fixed

* fix `run` with options overwriting the value of `i` (#726, #727)
* fix `${BATS_TEST_NAMES[@]}` containing only `--tags` instead of test name since Bats v1.8.0 (#705)
* fix `run --keep-empty-lines` counting trailing `\n` as (empty) new line (#711)
* fix short flag unpacker creating bogus command lines with valued flags (#732)
* fix formatter becoming confused with retries (#734)
* fix `--gather-test-outputs-in` fails on tests with `/` (#735)
* fix overriding `date` breaks `--timing` (#736)

#### Documentation

* typos, minor edits (#704)
* simplified contributing.md (#718)

## [1.9.0] - 2023-02-12

### Added

* add installation instructions for Debian, Fedora, Gentoo, and OpenSUSE (#659)
* add `--line-reference-format` to switch file/line references in stack traces (#665)
  * `comma_line` (default): `file.bats, line 1`
  * `colon`: `file.bats:1`
  * `uri`: `file:///path/to/file.bats:1`
  * `custom`: define your own formatter in `bats_format_file_line_reference_custom`
* add `bats:focus` tag to run only focused tests (#679)
* add bats-support, bats-assert, bats-file and bats-detik to Dockerfile (#674)

### Documentation

* add `--help` text and `man` page content for `--filter-tags` (#679)

### Fixed

* explicitly check for GNU parallel (#691)
* wait for report-formatter to finish before ending `bats`' execution,
  to fix empty files with `--report-fomatter junit` under Docker (#692)

#### Documentation

* improved clarity of section about output in free code (#671)
* fixed typos (#673)
* clarify use cases of `run` (#366)

## [1.8.2] - 2022-10-19

### Fixed

* fix non zero return code on successful retried tests (#670)
* fix `skip` in `setup_file` failing test suite (#687)

## [1.8.1] - 2022-10-19

### Fixed

* `shfmt` all files and enforce via CI (#651)
* avoid kernel warning flood/hang with CTRL+C on Bash 5.2 RC (#656)
* Fix infinite wait with (invalid) `-j<n>` (without space) (#657)

## [1.8.0] - 2022-09-15

### Added

* using external formatters via `--formatter <absolute path>` (also works for
  `--report-formatter`) (#602)
* running only tests that failed in the last run via `--filter-status failed` (#483)
* variable `BATS_TEST_RETRIES` that specifies how often a test should be
  reattempted before it is considered failed (#618)
* Docker tags `latest-no-faccessat2` and `<bats-version\>-no-faccessat2` for
  avoiding `bash: bats: No such file or directory` on `docker<20.10` (or
  `runc<v1.0.0-rc93`) (#622)
* `BATS_TEST_TIMEOUT` variable to force a timeout on test (including `setup()`) (#491)
* also print (nonempty) `$stderr` (from `run --separate-stderr`) with
  `--print-output-on-failure` (#631)
* `# bats test_tags=<tag list>`/`# bats file_tags=<tag list>` and
  `--filter-tags <tag list>` for tagging tests for execution filters (#642)
* warning BW03: inform about `setup_suite` in wrong file (`.bats` instead of `setup_suite.bash`) (#652)

#### Documentation

* update gotcha about negated statements: Recommend using `run !` on Bats
  versions >=1.5.0 (#593)
* add documentation for `bats_require_minimum_version` (#595)
* improve documentation about `setup_suite` (#652)

### Fixed

* added missing shebang  (#597)
* remaining instances of `run -<N>` being incorrectly documented as `run =<N>` (#599)
* allow `--gather-test-outputs-in <directory>` to work with existing, empty
  directories (#603)
  * also add `--clean-and-gather-test-outputs-in <directory>` for improved UX
* double slashes in paths derived from TMPDIR on MacOS (#607)
* fix `load` in `teardown` marking failed tests as not run (#612)
* fix unset variable errors (with set -u) and add regression test (#621)
* `teardown_file` errors don't swallow `setup_file` errors anymore, the behavior
  is more like `teardown`'s now (only `return`/last command can trigger `teardown`
   errors) (#623)
* upgraded from deprecated CI envs for MacOS (10 -> 11,12) and Ubuntu
  (18.04 -> 22.04) (#630)
* add `/usr/lib/bats` as default value for `BATS_LIB_PATH` (#628)
* fix unset variable in `bats-formatter-junit` when `setup_file` fails (#632)
* unify error behavior of `teardown`/`teardown_file`/`teardown_suite` functions:
  only fail via return code, not via ERREXIT (#633)
* fix unbound variable errors with `set -u` on `setup_suite` failures (#643)
* fix `load` not being available in `setup_suite` (#644)
* fix RPM spec, add regression test (#648)
* fix handling of `IFS` by `run` (#650)
* only print `setup_suite`'s stderr on errors (#649)

#### Documentation

* fix typos, spelling and links (#596, #604, #619, #627)
* fix redirection order of an example in the tutorial (#617)

## [1.7.0] - 2022-05-14

### Added

* Pretty formatter print filename when entering file (#561)
* BATS_TEST_NAME_PREFIX allows prefixing test names on stdout and in reports (#561)
* setup_suite and teardown_suite (#571, #585)
* out-of-band warning infrastructure, with following warnings:
  * BW01: run command not found (exit code 127)  (#586)
  * BW02: run uses flags without proper `bats_require_minimum_version` guard (#587)
* `bats_require_minimum_version` to guard code that would not run on older
  versions (#587)

#### Documentation

* document `$BATS_VERSION` (#557)
* document new warning infrastructure (#589, #587, #586)

### Fixed

* unbound variable errors in formatters when using `SHELLOPTS=nounset` (`-u`) (#558)
* don't require `flock` *and* `shlock` for parallel mode test (#554)
* print name of failing test when using TAP13 with timing information (#559, #555)
* removed broken symlink, added regression test (#560)
* don't show empty lines as `#` with pretty formatter  (#561)
* prevent `teardown`, `teardown_file`, and `teardown_suite` from overriding bats'
  exit code by setting `$status` (e.g. via calling `run`) (#581, #575)
  * **CRITICAL**: this can return exit code 0 despite failed tests, thus preventing
    your CI from reporting test failures! The regression happened in version 1.6.0.
* `run --keep-empty-lines` now reports 0 lines on empty `$output` (#583)

#### Documentation

* remove 2018 in title, update copyright dates in README.md (#567)
* fix broken links (#568)
* corrected invalid documentation of `run -N` (had `=N` instead) (#579)
  * **CRITICAL**: using the incorrect form can lead to silent errors. See
    [issue #578](https://github.com/bats-core/bats-core/issues/578) for more
    details and how to find out if your tests are affected.

## [1.6.1] - 2022-05-14

### Fixed

* prevent `teardown`, `teardown_file`, and `teardown_suite` from overriding bats'
  exit code by setting `$status` (e.g. via calling `run`) (#581, #575)
  * **CRITICAL**: this can return exit code 0 despite failed tests, thus preventing
    your CI from reporting test failures! The regression happened in version 1.6.0.

#### Documentation

* corrected invalid documentation of `run -N` (had `=N` instead) (#579)
  * **CRITICAL**: using the incorrect form can lead to silent errors. See
    [issue #578](https://github.com/bats-core/bats-core/issues/578) for more
    details and how to find out if your tests are affected.

## [1.6.0] - 2022-02-24

### Added

* new flag `--code-quote-style` (and `$BATS_CODE_QUOTE_STYLE`) to customize
quotes around code blocks in error output (#506)
* an example/regression test for running background tasks without blocking the
  test run (#525, #535)
* `bats_load_library` for loading libraries from the search path
  `$BATS_LIB_PATH` (#548)

### Fixed

* improved error trace for some broken cases (#279)
* removed leftover debug file `/tmp/latch` in selftest suite
  (single use latch) (#516)
* fix recurring errors on CTRL+C tests with NPM on Windows in selftest suite (#516)
* fixed leaking of local variables from debug trap (#520)
* don't mark FD3 output from `teardown_file` as `<failure>` in junit output (#532)
* fix unbound variable error with Bash pre 4.4 (#550)

#### Documentation

* remove links to defunct freenode IRC channel (#515)
* improved grammar (#534)
* fixed link to TAP spec (#537)

## [1.5.0] - 2021-10-22

### Added

* new command line flags (#488)
  * `--verbose-run`: Make `run` print `$output` by default
  * `-x`, `--trace`: Print test commands as they are executed (like `set -x`)`
  * `--show-output-of-passing-tests`: Print output of passing tests
  * `--print-output-on-failure`: Automatically print the value of  `$output` on
    failed tests
  * `--gather-test-outputs-in <directory>`: Gather the output of failing **and**
    passing tests as files in directory
* Experimental: add return code checks to `run` via `!`/`-<N>` (#367, #507)
* `install.sh` and `uninstall.sh` take an optional second parameter for the lib
  folder name to allow for multilib install, e.g. into lib64 (#452)
* add `run` flag `--keep-empty-lines` to retain empty lines in `${lines[@]}` (#224,
  a894fbfa)
* add `run` flag `--separate-stderr` which also fills `$stderr` and
  `$stderr_lines` (#47, 5c9b173d, #507)

### Fixed

* don't glob `run`'s `$output` when splitting into `${lines[@]}`
  (#151, #152, #158, #156, #281, #289)
* remove empty line after test with pretty formatter on some terminals (#481)
* don't run setup_file/teardown_file on files without tests, e.g. due to
  filtering (#484)
* print final line without newline on Bash 3.2 for midtest (ERREXIT) failures
  too (#495, #145)
* abort with error on missing flock/shlock when running in parallel mode  (#496)
* improved `set -u` test and fixed some unset variable accesses (#498, #501)
* shorten suite/file/test temporary folder paths to leave enough space even on
  restricted systems (#503)

#### Documentation

* minor edits (#478)

## [1.4.1] - 2021-07-24

### Added

* Docker image architectures amd64, 386, arm64, arm/v7, arm/v6, ppc64le, s390x (#438)

### Fixed

* automatic push to Dockerhub (#438)

## [1.4.0] - 2021-07-23

### Added

* added BATS_TEST_TMPDIR, BATS_FILE_TMPDIR, BATS_SUITE_TMPDIR (#413)
* added checks and improved documentation for `$BATS_TMPDIR` (#410)
* the docker container now uses [tini](https://github.com/krallin/tini) as the
  container entrypoint to improve signal forwarding (#407)
* script to uninstall bats from a given prefix (#400)
* replace preprocessed file path (e.g. `/tmp/bats-run-22908-NP0f9h/bats.23102.src`)
  with original filename in stdout/err (but not FD3!) (#429)
* print aborted command on SIGINT/CTRL+C (#368)
* print error message when BATS_RUN_TMPDIR could not be created (#422)

#### Documentation

* added tutorial for new users (#397)
* fixed example invocation of docker container (#440)
* minor edits (#431, #439, #445, #463, #464, #465)

### Fixed

* fix `bats_tap_stream_unknown: command not found` with pretty formatter, when
  writing non compliant extended output (#412)
* avoid collisions on `$BATS_RUN_TMPDIR` with `--no-tempdir-cleanup` and docker
  by using `mktemp` additionally to PID (#409)
* pretty printer now puts text that is printed to FD 3 below the test name (#426)
* `rm semaphores/slot-: No such file or directory` in parallel mode on MacOS
  (#434, #433)
* fix YAML blocks in TAP13 formatter using `...` instead of `---` to start
  a block (#442)
* fixed some typos in comments (#441, #447)
* ensure `/code` exists in docker container, to make examples work again  (#440)
* also display error messages from free code (#429)
* npm installed version on Windows: fix broken internal LIBEXEC paths (#459)

## [1.3.0] - 2021-03-08

### Added

* custom test-file extension via `BATS_FILE_EXTENSION` when searching for test
  files in a directory (#376)
* TAP13 formatter, including millisecond timing (#337)
* automatic release to NPM via GitHub Actions (#406)

#### Documentation

* added documentation about overusing `run` (#343)
* improved documentation of `load` (#332)

### Changed

* recursive suite mode will follow symlinks now (#370)
* split options for (file-) `--report-formatter` and (stdout) `--formatter` (#345)
  * **WARNING**: This changes the meaning of `--formatter junit`.
    stdout will now show unified xml instead of TAP. From now on, please use
    `--report-formatter junit` to obtain the `.xml` report file!
* removed `--parallel-preserve-environment` flag, as this is the default
  behavior (#324)
* moved CI from Travis/AppVeyor to GitHub Actions (#405)
* preprocessed files are no longer removed if `--no-tempdir-cleanup` is
  specified (#395)

#### Documentation

* moved documentation to [readthedocs](https://bats-core.readthedocs.io/en/latest/)

### Fixed

#### Correctness

* fix internal failures due to unbound variables when test files use `set -u` (#392)
* fix internal failures due to changes to `$PATH` in test files (#387)
* fix test duration always being 0 on busybox installs (#363)
* fix hangs on CTRL+C (#354)
* make `BATS_TEST_NUMBER` count per file again (#326)
* include `lib/` in npm package (#352)

#### Performance

* don't fork bomb in parallel mode (#339)
* preprocess each file only once (#335)
* avoid running duplicate files n^2 times (#338)

#### Documentation

* fix documentation for `--formatter junit` (#334)
* fix documentation for `setup_file` variables (#333)
* fix link to examples page (#331)
* fix link to "File Descriptor 3" section (#301)

## [1.2.1] - 2020-07-06

### Added

* JUnit output and extensible formatter rewrite (#246)
* `load` function now reads from absolute and relative paths, and $PATH (#282)
* Beginner-friendly examples in /docs/examples (#243)
* @peshay's `bats-file` fork contributed to `bats-core/bats-file` (#276)

### Changed

* Duplicate test names now error (previous behaviour was to issue a warning) (#286)
* Changed default formatter in Docker to pretty by adding `ncurses` to
  Dockerfile, override with `--tap` (#239)
* Replace "readlink -f" dependency with Bash solution (#217)

## [1.2.0] - 2020-04-25

Support parallel suite execution and filtering by test name.

### Added

* docs/CHANGELOG.md and docs/releasing.md (#122)
* The `-f, --filter` flag to run only the tests matching a regular expression  (#126)
* Optimize stack trace capture (#138)
* `--jobs n` flag to support parallel execution of tests with GNU parallel (#172)

### Changed

* AppVeyor builds are now semver-compliant (#123)
* Add Bash 5 as test target (#181)
* Always use upper case signal names to avoid locale dependent err… (#215)
* Fix for tests reading from stdin (#227)
* Fix wrong line numbers of errors in bash < 4.4 (#229)
* Remove preprocessed source after test run (#232)

## [1.1.0] - 2018-07-08

This is the first release with new features relative to the original Bats 0.4.0.

### Added

* The `-r, --recursive` flag to scan directory arguments recursively for
  `*.bats` files (#109)
* The `contrib/rpm/bats.spec` file to build RPMs (#111)

### Changed

* Travis exercises latest versions of Bash from 3.2 through 4.4 (#116, #117)
* Error output highlights invalid command line options (#45, #46, #118)
* Replaced `echo` with `printf` (#120)

### Fixed

* Fixed `BATS_ERROR_STATUS` getting lost when `bats_error_trap` fired multiple
  times under Bash 4.2.x (#110)
* Updated `bin/bats` symlink resolution, handling the case on CentOS where
  `/bin` is a symlink to `/usr/bin` (#113, #115)

## [1.0.2] - 2018-06-18

* Fixed sstephenson/bats#240, whereby `skip` messages containing parentheses
  were truncated (#48)
* Doc improvements:
  * Docker usage (#94)
  * Better README badges (#101)
  * Better installation instructions (#102, #104)
* Packaging/installation improvements:
  * package.json update (#100)
  * Moved `libexec/` files to `libexec/bats-core/`, improved `install.sh` (#105)

## [1.0.1] - 2018-06-09

* Fixed a `BATS_CWD` bug introduced in #91 whereby it was set to the parent of
  `PWD`, when it should've been set to `PWD` itself (#98). This caused file
  names in stack traces to contain the basename of `PWD` as a prefix, when the
  names should've been purely relative to `PWD`.
* Ensure the last line of test output prints when it doesn't end with a newline
  (#99). This was a quasi-bug introduced by replacing `sed` with `while` in #88.

## [1.0.0] - 2018-06-08

`1.0.0` generally preserves compatibility with `0.4.0`, but with some Bash
compatibility improvements and a massive performance boost. In other words:

* all existing tests should remain compatible
* tests that might've failed or exhibited unexpected behavior on earlier
  versions of Bash should now also pass or behave as expected

Changes:

* Added support for Docker.
* Added support for test scripts that have the [unofficial strict
  mode](http://redsymbol.net/articles/unofficial-bash-strict-mode/) enabled.
* Improved stability on Windows and macOS platforms.
* Massive performance improvements, especially on Windows (#8)
* Workarounds for inconsistent behavior between Bash versions (#82)
* Workaround for preserving stack info after calling an exported function under
  Bash < 4.4 (#87)
* Fixed TAP compliance for skipped tests
* Added support for tabs in test names.
* `bin/bats` and `install.sh` now work reliably on Windows (#91)

## [0.4.0] - 2014-08-13

* Improved the display of failing test cases. Bats now shows the source code of
  failing test lines, along with full stack traces including function names,
  filenames, and line numbers.
* Improved the display of the pretty-printed test summary line to include the
  number of skipped tests, if any.
* Improved the speed of the preprocessor, dramatically shortening test and suite
  startup times.
* Added support for absolute pathnames to the `load` helper.
* Added support for single-line `@test` definitions.
* Added bats(1) and bats(7) manual pages.
* Modified the `bats` command to default to TAP output when the `$CI` variable
  is set, to better support environments such as Travis CI.

## [0.3.1] - 2013-10-28

* Fixed an incompatibility with the pretty formatter in certain environments
  such as tmux.
* Fixed a bug where the pretty formatter would crash if the first line of a test
  file's output was invalid TAP.

## [0.3.0] - 2013-10-21

* Improved formatting for tests run from a terminal. Failing tests are now
  colored in red, and the total number of failing tests is displayed at the end
  of the test run. When Bats is not connected to a terminal (e.g. in CI runs),
  or when invoked with the `--tap` flag, output is displayed in standard TAP
  format.
* Added the ability to skip tests using the `skip` command.
* Added a message to failing test case output indicating the file and line
  number of the statement that caused the test to fail.
* Added "ad-hoc" test suite support. You can now invoke `bats` with multiple
  filename or directory arguments to run all the specified tests in aggregate.
* Added support for test files with Windows line endings.
* Fixed regular expression warnings from certain versions of Bash.
* Fixed a bug running tests containing lines that begin with `-e`.

## [0.2.0] - 2012-11-16

* Added test suite support. The `bats` command accepts a directory name
  containing multiple test files to be run in aggregate.
* Added the ability to count the number of test cases in a file or suite by
  passing the `-c` flag to `bats`.
* Preprocessed sources are cached between test case runs in the same file for
  better performance.

## [0.1.0] - 2011-12-30

* Initial public release.

[Unreleased]: https://github.com/bats-core/bats-core/compare/v1.7.0...HEAD
[1.7.0]: https://github.com/bats-core/bats-core/compare/v1.6.1...v1.7.0
[1.6.1]: https://github.com/bats-core/bats-core/compare/v1.6.0...v1.6.1
[1.6.0]: https://github.com/bats-core/bats-core/compare/v1.5.0...v1.6.0
[1.5.0]: https://github.com/bats-core/bats-core/compare/v1.4.1...v1.5.0
[1.4.1]: https://github.com/bats-core/bats-core/compare/v1.4.0...v1.4.1
[1.4.0]: https://github.com/bats-core/bats-core/compare/v1.3.0...v1.4.0
[1.3.0]: https://github.com/bats-core/bats-core/compare/v1.2.1...v1.3.0
[1.2.1]: https://github.com/bats-core/bats-core/compare/v1.2.0...v1.2.1
[1.2.0]: https://github.com/bats-core/bats-core/compare/v1.1.0...v1.2.0
[1.1.0]: https://github.com/bats-core/bats-core/compare/v1.0.2...v1.1.0
[1.0.2]: https://github.com/bats-core/bats-core/compare/v1.0.1...v1.0.2
[1.0.1]: https://github.com/bats-core/bats-core/compare/v1.0.0...v1.0.1
[1.0.0]: https://github.com/bats-core/bats-core/compare/v0.4.0...v1.0.0
[0.4.0]: https://github.com/bats-core/bats-core/compare/v0.3.1...v0.4.0
[0.3.1]: https://github.com/bats-core/bats-core/compare/v0.3.0...v0.3.1
[0.3.0]: https://github.com/bats-core/bats-core/compare/v0.2.0...v0.3.0
[0.2.0]: https://github.com/bats-core/bats-core/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/bats-core/bats-core/commits/v0.1.0
