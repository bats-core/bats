Tutorial
========

This tutorial is intended for beginners with bats and possibly bash.
Make sure to also read the list of gotchas and the faq.

For this tutorial we are assuming you already have a project in a git repository and want to add tests.
Ultimately they should run in the CI environment but will also be started locally during development.

..
    TODO: link to example repository?

Quick installation
------------------

Since we already have an existing git repository, it is very easy to include bats and its libraries as submodules.
We are aiming for following filesystem structure:

.. code-block:: 

    src/
        project.sh
        ...
    test/
        bats/               <- submodule
        test_helper/
            bats-support/   <- submodule
            bats-assert/    <- submodule
        test.bats
        ...

So we start from the project root:

.. code-block:: console
    
    git submodule add https://github.com/bats-core/bats-core.git test/bats
    git submodule add https://github.com/bats-core/bats-support.git test/test_helper/bats-support
    git submodule add https://github.com/bats-core/bats-assert.git test/test_helper/bats-assert

Your first test
---------------

Now we want to add our first test.

In the tutorial repository, we want to build up our project in a TDD fashion.
Thus, we start with an empty project and our first test is to just run our (non existing) shell script.

We start by creating a new test file `test/test.bats`

.. code-block:: bash

    @test "can run our script" {
        ./project.sh
    }

and run it by

.. code-block:: console

    $ ./test/bats/bin/bats test/test.bats
     ✗ can run our script
       (in test file test/test.bats, line 2)
         `./project.sh' failed with status 127
       /tmp/bats-run-19605/bats.19627.src: line 2: ./project.sh: No such file or directory

    1 test, 1 failure

Okay, our test is red. Obviously, the project.sh doesn't exist, so we create the file `src/project.sh`:

.. code-block:: console

    mkdir src/
    echo '#!/usr/bin/env bash' > src/project.sh
    chmod a+x src/project.sh

A new test run gives us

.. code-block:: console

    $ ./test/bats/bin/bats test/test.bats
     ✗ can run our script
       (in test file test/test.bats, line 2)
         `./project.sh' failed with status 127
       /tmp/bats-run-19605/bats.19627.src: line 2: ./project.sh: No such file or directory

    1 test, 1 failure

Oh, we still used the wrong path. No problem, we just need to use the correct path to `project.sh`.
Since we're still in the same directory as when we started `bats`, we can simply do:

.. code-block:: bash

    @test "can run our script" {
        ./src/project.sh
    }

and get:

.. code-block:: console

    $ ./test/bats/bin/bats test/test.bats 
     ✓ can run our script

    1 test, 0 failures

Yesss! But that victory feels shallow: What if somebody less competent than us starts bats from another directory?

Let's do some setup
-------------------

The obvious solution to becoming independent of `$PWD` is using some fixed anchor point in the filesystem.
We can use the path to the test file itself as an anchor and rely on the internal project structure.
Since we are lazy people and want to treat our project's files as first class citizens in the executable world, we will also put them on the `$PATH`.
Our new `test/test.bats` now looks like this:

.. code-block:: bash

    setup() {
        # get the containing directory of this file
        # use $BATS_TEST_FILENAME instead of ${BASH_SOURCE[0]} or $0,
        # as those will point to the bats executable's location or the preprocessed file respectively
        DIR="$( cd "$( dirname "$BATS_TEST_FILENAME" )" >/dev/null 2>&1 && pwd )"
        # make executables in src/ visible to PATH
        PATH="$DIR/../src:$PATH"
    }

    @test "can run our script" {
        # notice the missing ./ 
        # As we added src/ to $PATH, we can omit the relative path to `src/project.sh`.
        project.sh
    }

still giving us:

.. code-block:: console

    $ ./test/bats/bin/bats test/test.bats 
     ✓ can run our script

    1 test, 0 failures

It still works as expected. This is because the newly added `setup` function put the absolute path to `src/` onto `$PATH`.
This setup function is automatically called before each test.
Therefore, our test could execute `project.sh` directly, without using a (relative) path.

.. important::

    The `setup` function will be called before each individual test in the file. 
    Each file can only define one setup function for all tests in the file.
    However, the setup functions can differ between different files.

Dealing with output
-------------------

Okay, we have a green test but our executable does not anything useful.
To keep things simple, let us start with an error message. Our new `src/project.sh` now reads:

.. code-block:: bash

    #!/usr/bin/env bash

    echo "Welcome to our project!"

    echo "NOT IMPLEMENTED!" >&2
    exit 1

And gives is this test output:

.. code-block:: console

    $ ./test/bats/bin/bats test/test.bats 
     ✗ can run our script
       (in test file test/test.bats, line 11)
         `project.sh' failed
       Welcome to our project!
       NOT IMPLEMENTED!

    1 test, 1 failure

Okay, our test failed, because we now exit with 1 instead of 0.
Additionally, we see the stdout and stderr of the failing program.

Our goal now is to retarget our test and check that we get the welcome message.
bats-assert gives us some help with this, so we should now load it (and its dependency bats-support),
so we change `test/test.bats` to

.. code-block:: bash

    setup() {
        load 'test_helper/bats-support/load'
        load 'test_helper/bats-assert/load'
        # ... the remaining setup is unchanged

        # get the containing directory of this file
        # use $BATS_TEST_FILENAME instead of ${BASH_SOURCE[0]} or $0,
        # as those will point to the bats executable's location or the preprocessed file respectively
        DIR="$( cd "$( dirname "$BATS_TEST_FILENAME" )" >/dev/null 2>&1 && pwd )"
        # make executables in src/ visible to PATH
        PATH="$DIR/../src:$PATH"
    }

    @test "can run our script" {
        run project.sh # notice `run`!
        assert_output 'Welcome to our project!'
    }

which gives us the following test output:

.. code-block:: console

    $ LANG=C ./test/bats/bin/bats test/test.bats 
     ✗ can run our script
       (from function `assert_output' in file test/test_helper/bats-assert/src/assert_output.bash, line 194,
        in test file test/test.bats, line 14)
         `assert_output 'Welcome to our project!'' failed
    
       -- output differs --
       expected (1 lines):
         Welcome to our project!
       actual (2 lines):
         Welcome to our project!
         NOT IMPLEMENTED!
       --
    

    1 test, 1 failure

The first change in this output is the failure description. We now fail on assert_output instead of the call itself.
We prefixed our call to `project.sh` with `run`, which is a function provided by bats that executes the command it gets passed as parameters.
Then, `run` sucks up the stdout and stderr of the command it ran and stores it in `$output`, stores the exit code in `$status` and returns 0.
This means `run` never fails the test and won't generate any context/output in the log of a failed test on its own.

Marking the test as failed and printing context information is up to the consumers of `$status` and `$output`. 
`assert_output` is such a consumer, it compares `$output` to the the parameter it got and tells us quite succinctly that it did not match in this case.

For our current test we don't care about any other output or the error message, so we want it gone.
`grep` is always at our fingertips, so we tape together this ramshackle construct

.. code-block:: bash

    run project.sh 2>&1 | grep Welcome

which gives us the following test result:

.. code-block:: console

    $ ./test/bats/bin/bats test/test.bats 
     ✗ can run our script
       (in test file test/test.bats, line 13)
         `run project.sh | grep Welcome' failed

    1 test, 1 failure

Huh, what is going on? Why does it fail the `run` line again?

This is a common mistake that can happen when our mind parses the file differently than the bash parser.
`run` is just a function, so the pipe won't actually be forwarded into the function. Bash reads this as `(run project.sh) | grep Welcome`, 
instead of our intended `run (project.sh | grep Welcome)`.

Unfortunately, the latter is no valid bash syntax, so we have to work around it, e.g. by using a function:

.. code-block:: bash

    get_projectsh_welcome_message() {
        project.sh  2>&1 | grep Welcome
    }

    @test "Check welcome message" {
        run get_projectsh_welcome_message
        assert_output 'Welcome to our project!'
    }

Now our test passes again but having to write a function each time we want only a partial match does not accommodate our laziness.
Isn't there an app for that? Maybe we should look at the documentation?

    Partial matching can be enabled with the --partial option (-p for short). When used, the assertion fails if the expected substring is not found in $output.

    -- the documentation for `assert_output <https://github.com/bats-core/bats-assert#partial-matching>`_

Okay, so maybe we should try that:

.. code-block:: bash

    @test "Check welcome message" {
        run project.sh
        assert_output --partial 'Welcome to our project!'
    }

Aaannnd ... the test stays green. Yay!

There are many other asserts and options but this is not the place for all of them.
Skimming the documentation of `bats-assert <https://github.com/bats-core/bats-assert>`_ will give you a good idea what you can do.
You should also have a look at the other helper libraries `here <https://github.com/bats-core>`_ like `bats-file <https://github.com/bats-core/bats-file>`_, 
to avoid reinventing the wheel.


Cleaning up your mess
---------------------

Often our setup or tests leave behind some artifacts that clutter our test environment.
You can define a `teardown` function which will be called after each test, regardless whether it failed or not.

For example, we now want our project.sh to only show the welcome message on the first invocation.
So we change our test to this:

.. code-block:: bash

    @test "Show welcome message on first invocation" {
        run project.sh
        assert_output --partial 'Welcome to our project!'

        run project.sh
        refute_output --partial 'Welcome to our project!'
    }

This test fails as expected:

.. code-block:: console

    $ ./test/bats/bin/bats test/test.bats 
     ✗ Show welcome message on first invocation
       (from function `refute_output' in file test/test_helper/bats-assert/src/refute_output.bash, line 189,
        in test file test/test.bats, line 17)
         `refute_output --partial 'Welcome to our project!'' failed
    
       -- output should not contain substring --
       substring (1 lines):
         Welcome to our project!
       output (2 lines):
         Welcome to our project!
         NOT IMPLEMENTED!
       --
    

    1 test, 1 failure

Now, to get the test green again, we want to store the information that we already ran in the file `/tmp/bats-tutorial-project-ran`,
so our `src/project.sh` becomes:

.. code-block:: bash

    #!/usr/bin/env bash

    FIRST_RUN_FILE=/tmp/bats-tutorial-project-ran

    if [[ ! -e "$FIRST_RUN_FILE" ]]; then
        echo "Welcome to our project!"
        touch "$FIRST_RUN_FILE"
    fi

    echo "NOT IMPLEMENTED!" >&2
    exit 1

And our test says:

.. code-block:: console

    $ ./test/bats/bin/bats test/test.bats 
     ✓ Show welcome message on first invocation

    1 test, 0 failures

Nice, we're done, or are we? Running the test again now gives:

.. code-block:: console

    $ ./test/bats/bin/bats test/test.bats 
     ✗ Show welcome message on first invocation
       (from function `assert_output' in file test/test_helper/bats-assert/src/assert_output.bash, line 186,
        in test file test/test.bats, line 14)
         `assert_output --partial 'Welcome to our project!'' failed
    
       -- output does not contain substring --
       substring : Welcome to our project!
       output    : NOT IMPLEMENTED!
       --
    

    1 test, 1 failure

Now the first assert failed, because of the leftover `$FIRST_RUN_FILE` from the last test run.

Luckily, bats offers the `teardown` function, which can take care of that, we add the following code to `test/test.bats`:

.. code-block:: bash

    teardown() {
        rm -f /tmp/bats-tutorial-project-ran
    }

Now running the test again first give us the same error, as the teardown has not run yet. 
On the second try we get a clean `/tmp` folder again and our test passes consistently now.

It is worth noting that we could do this `rm` in the test code itself but it would get skipped on failures.

.. important::

    A test ends at its first failure. None of the subsequent commands in this test will be executed.
    The `teardown` function runs after each individual test in a file, regardless of test success or failure.
    Similarly to `setup`, each `.bats` file can have its own `teardown` function which will be the same for all tests in the file.

Test what you can
-----------------

Sometimes tests rely on the environment to provide infrastructure that is needed for the test.
If not all test environments provide this infrastructure but we still want to test on them,
it would be unhelpful to get errors on parts that are not testable.

Bats provides you with the `skip` command which can be used in `setup` and `test`.

.. tip::    
    
    You should `skip` as early as you know it does not make sense to continue.

In our example project we rewrite the welcome message test to `skip` instead of doing cleanup:

.. code-block:: bash

    teardown() {
        : # Look Ma! No cleanup!
    } 

    @test "Show welcome message on first invocation" {
        if [[ -e /tmp/bats-tutorial-project-ran ]]; then
            skip 'The FIRST_RUN_FILE already exists'
        fi
        
        run project.sh
        assert_output --partial 'Welcome to our project!'

        run project.sh
        refute_output --partial 'Welcome to our project!'
    }

The first test run still works due to the cleanup from the last round. However, our second run gives us:

.. code-block:: console

    $ ./test/bats/bin/bats test/test.bats 
     - Show welcome message on first invocation (skipped: The FIRST_RUN_FILE already exists)

    1 test, 0 failures, 1 skipped

.. important::

    Skipped tests won't fail a test suite and are counted separately.
    No test command after `skip` will be executed. If an error occurs before `skip`, the test will fail.
    An optional reason can be passed to `skip` and will be printed in the test output.

Setting up a multifile test suite
---------------------------------

With a growing project, putting all tests into one file becomes unwieldy.
For our example project, we will extract functionality into the additional file `src/helper.sh`:

.. code-block:: bash

    #!/usr/bin/env bash

    _is_first_run() {
        local FIRST_RUN_FILE=/tmp/bats-tutorial-project-ran
        if [[ ! -e "$FIRST_RUN_FILE" ]]; then
            touch "$FIRST_RUN_FILE"
            return 0
        fi
        return 1
    }

This allows for testing it separately in a new file `test/helper.bats`:

.. code-block:: bash

    setup() {
        load 'test_helper/common-setup'
        _common_setup

        source "$PROJECT_ROOT/src/helper.sh"
    }

    teardown() {
        rm -f "$NON_EXISTANT_FIRST_RUN_FILE"
        rm -f "$EXISTING_FIRST_RUN_FILE"
    }

    @test "Check first run" {
        NON_EXISTANT_FIRST_RUN_FILE=$(mktemp -u) # only create the name, not the file itself

        assert _is_first_run
        refute _is_first_run
        refute _is_first_run

        EXISTING_FIRST_RUN_FILE=$(mktemp)
        refute _is_first_run
        refute _is_first_run
    }

Since the setup function would have duplicated much of the other files', we split that out into the file `test/test_helper/common-setup.bash`:

.. code-block:: bash

    #!/usr/bin/env bash

    _common_setup() {
        load 'test_helper/bats-support/load'
        load 'test_helper/bats-assert/load'
        # get the containing directory of this file
        # use $BATS_TEST_FILENAME instead of ${BASH_SOURCE[0]} or $0,
        # as those will point to the bats executable's location or the preprocessed file respectively
        PROJECT_ROOT="$( cd "$( dirname "$BATS_TEST_FILENAME" )/.." >/dev/null 2>&1 && pwd )"
        # make executables in src/ visible to PATH
        PATH="$PROJECT_ROOT/src:$PATH"
    }

with the following `setup` in `test/test.bats`:

.. code-block:: bash

    setup() {
        load 'test_helper/common-setup'
        _common_setup
    }

Please note, that we gave our helper the extension `.bash`, which is automatically appended by `load`.

.. important:: 

    `load` automatically tries to append `.bash` to its argument.

In our new `test/helper.bats` we can see, that loading `.sh` is simply done via `source`.

.. tip::

    Avoid using `load` and `source` outside of any functions.
    If there is an error in the test file's "free code", the diagnostics are much worse than for code in `setup` or `@test`.

With the new changes in place, we can run our tests again. However, our previous run command does not include the new file.
You could add the new file to the parameter list, e.g. by running `./test/bats/bin/bats test/*.bats`.
However, bats also can handle directories:

.. code-block:: console

    $ ./test/bats/bin/bats test/
     ✓ Check first run
     - Show welcome message on first invocation (skipped: The FIRST_RUN_FILE already exists)

    2 tests, 0 failures, 1 skipped

In this mode, bats will pick up all `.bats` files in the directory it was given. There is an additional `-r` switch that will recursively search for more `.bats` files.
However, in our project layout this would pick up the test files of bats itself from `test/bats/test`. We don't have test subfolders anyways, so we can do without `-r`.


Avoiding costly repeated setups
-------------------------------

We already have seen the `setup` function in use, which is called before each test.
Sometimes our setup is very costly, such as booting up a service just for testing. 
If we can reuse the same setup across multiple tests, we might want to do only one setup before all these tests.

This usecase is exactly what the `setup_file` function was created for.
It can be defined per file and will run before all tests of the respective file.
Similarly, we have `teardown_file`, which will run after all tests of the file, even when you abort a test run or a test failed.

As an example, we want to add an echo server capability to our project. First, we add the following `server.bats` to our suite:

.. code-block:: bash

    setup_file() {
        load 'test_helper/common-setup'
        _common_setup
        PORT=$(project.sh start-echo-server >/dev/null 2>&1)
        export PORT
    }

    @test "server is reachable" {
        nc -z localhost "$PORT"
    }

Which will obviously fail:

Note that `export PORT` to make it visible to the test!
Running this gives us:

..
    TODO: Update this example with fixed test name reporting from setup_file? (instead of "✗ ")

.. code-block:: console

   $ ./test/bats/bin/bats test/server.bats 
     ✗ 
       (from function `setup_file' in test file test/server.bats, line 4)
         `PORT=$(project.sh start-echo-server >/dev/null 2>&1)' failed

    1 test, 1 failure 

Now that we got our red test, we need to get it green again.
Our new `project.sh` now ends with:

.. code-block:: bash

    case $1 in
        start-echo-server)
            echo "Starting echo server"
            PORT=2000
            ncat -l $PORT -k -c 'xargs -n1 echo' 2>/dev/null & # don't keep open this script's stderr
            echo $! > /tmp/project-echo-server.pid
            echo "$PORT" >&2
        ;;
        *)
            echo "NOT IMPLEMENTED!" >&2
            exit 1
        ;;
    esac

and the tests now say

.. code-block:: console

    $ LANG=C ./test/bats/bin/bats test/server.bats 
     ✓ server is reachable

    1 test, 0 failures

However, running this a second time gives:

.. code-block:: console

    $ ./test/bats/bin/bats test/server.bats
     ✗ server is reachable
       (in test file test/server.bats, line 14)
         `nc -z -w 2 localhost "$PORT"' failed
       2000
       Ncat: bind to :::2000: Address already in use. QUITTING.
       nc: port number invalid: 2000
       Ncat: bind to :::2000: Address already in use. QUITTING.

    1 test, 1 failure

Obviously, we did not turn off our server after testing.
This is a task for `teardown_file` in `server.bats`:

.. code-block:: bash

    teardown_file() {
        project.sh stop-echo-server
    }

Our `project.sh` should also get the new command:

.. code-block:: bash

    stop-echo-server)
        kill "$(< "/tmp/project-echo-server.pid")"
        rm /tmp/project-echo-server.pid
    ;;

Now starting our tests again will overwrite the .pid file with the new instance's, so we have to do manual cleanup once.
From now on, our test should clean up after itself.

.. note:: 

    `teardown_file` will run regardless of tests failing or succeeding.
