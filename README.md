xUnit Testing Framework for the D Programming Language
======================================================

[D Programming Language](http://dlang.org)  
D(2)

[xUnit Test Patterns](http://xunitpatterns.com)

Testing Functions vs. Interactions
----------------------------------

unittest functions: collection of one-liners documenting a function  
Python: `doctest`

xUnit tests: fixture setup, exercise SUT, result verification, fixture teardown  
Python: `unittest` (PyUnit)

Reporting Failures and Errors
-----------------------------

contracts

    assert(answer == 42);

stops at first failed assert (?)

    assertEquals(42, answer);

names of all failed test methods (as helpful as the naming of the test methods)

Examples
--------

example run

    ./example.d
    ./example.d --verbose

unittest functions testing the assertions

    dmd -unittest example.d dunit/assertion.d dunit/framework.d

selective test execution

    ./example.d --list
    ./example.d --filter testEqualsFailure
    ./example.d --filter testSuccess --filter testSuccess

comparing representations

    assertEquals(to!string(expected), to!string(actual))

forked from [jmcabo/dunit](https://github.com/jmcabo/dunit); fixed issues; restructured

not [D(1)Unit](http://www.dsource.org/projects/dmocks/wiki/DUnit) - allows to call (passed) test methods during setup

TODO: Hamcrest Matchers and `assertThat`
