xUnit Testing Framework for D
=============================

This is a simple implementation of the xUnit Testing Framework
for the [D Programming Language](http://dlang.org).
It's based on [JUnit](http://junit.org) and it allows to organize tests
according to the [xUnit Test Patterns](http://xunitpatterns.com).

It's known to work with version D 2.062.

Testing Functions vs. Interactions
----------------------------------

The built-in support for unit tests in D is best suited for testing functions,
when the individual test cases can be expressed as one-liners.

For testing interactions of objects, however, more support is required,
for example, for setting up a test fixture.
This is the responsibility of a testing framework.

Reporting Failures and Errors
-----------------------------

With no additional effort, specialized assertion functions report failures
more helpful than violated contracts.

For example,

    assertEquals(42, answer);

will report something like

    expected: <42> but was: <24>

names of all failed test methods (as helpful as the names of the test methods are expressive)

User Defined Attributes
-----------------------

`@Test`, `@Before`, `@After`, `@BeforeClass`, `@AfterClass`, and `@Ignore`

instead of naming convention testLikeThis

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

display usage

    ./example.d --help

comparing representations

    assertEquals(to!string(expected), to!string(actual))

forked from [jmcabo/dunit](https://github.com/jmcabo/dunit); fixed issues; restructured

not [D(1)Unit](http://www.dsource.org/projects/dmocks/wiki/DUnit) - allows to call (passed) test methods during setup

won't fix [Issue 4653 - More unit test functions should be added](http://d.puremagic.com/issues/show_bug.cgi?id=4653)

TODO: [Hamcrest](http://code.google.com/p/hamcrest/) Matchers and `assertThat`
