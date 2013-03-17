xUnit Testing Framework for the D Programming Language
======================================================

D Programming Language: http://dlang.org
D(2)

xUnit Test Patterns: http://xunitpatterns.com

1. functions vs. interactions

unittest functions: collection of one-liners documenting a function
Python: doctest

xUnit tests: fixture setup, exercise SUT, result verification, fixture teardown
Python: unittest (PyUnit)

2. reporting

    assert(answer == 42);
stops at first failed assert (?)

    assertEquals(42, answer);
names of all failed test methods (as helpful as the naming of the test methods)

example run
    ./example.d
    ./example.d --verbose
    ./example.d --list
unittest functions testing the assertions
    dmd -unittest example.d dunit/assertion.d dunit/framework.d

selective test execution
    ./example.d --filter testEqualsFailure

    assertEquals(to!string(expected), to!string(actual))

forked from jmcabo; fixed issues; restructured

not D(1)Unit - allows to call (passed) test methods during setup

TODO: Hamcrest Matchers and assertThat
