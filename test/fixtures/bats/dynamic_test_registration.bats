test1() {
    # dynamically registered tests must call bats_test_begin with their description
    bats_test_begin "Test 1"
}

parametrized_test() {
    bats_test_begin "Parametrized test $1"

    echo "$BATS_TEST_NAME: $1"
}

@test "normal test" {
    true
}


bats_test_function test1

for val in 1 2; do
    bats_test_function parametrized_test "$val"
done