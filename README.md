xUnit Testing Framework for D
=============================

This is a simple implementation of the xUnit Testing Framework
for the [D Programming Language](http://dlang.org).
Being based on [JUnit](http://junit.org) it allows to organize tests
according to the [xUnit Test Patterns](http://xunitpatterns.com).

It's known to work with versions D 2.062 and D 2.063.

Testing Functions vs. Interactions
----------------------------------

D's built-in support for unit tests is best suited for testing functions,
when the test cases can be expressed as one-liners.

For testing interactions of objects, however, more support is required,
for example, for setting up a test fixture.
This is the responsibility of a testing framework.

Failures vs. Errors
-------------------

With no additional effort, specialized assertion functions report failures
more helpful than violated contracts.

For example,

    assertEquals("bar", "baz");

will report something like

    expected: <"ba[r]"> but was: <"ba[z]">

names of all failed test methods (as helpful as the names of the test methods are expressive)

User Defined Attributes
-----------------------

`@Test`, `@Before`, `@After`, `@BeforeClass`, `@AfterClass`, and `@Ignore`

instead of naming convention testLikeThis

Examples
--------

Run the included example to see the xUnit Testing Framework in action:

    ./example.d

(When you get one error and two failures, everything works fine.)

unittest functions testing the assertions

    dmd -debug example.d dunit/assertion.d dunit/attributes.d dunit/framework.d
    ./example --verbose

selective test execution

    ./example.d --list
    ./example.d --filter testEqualsFailure

display usage

    ./example.d --help

TODO
----

more helpful string difference

forked from [jmcabo/dunit](https://github.com/jmcabo/dunit); fixed issues; restructured

not [D(1)Unit](http://www.dsource.org/projects/dmocks/wiki/DUnit) - allows to call (passed) test methods during setup

won't fix [Issue 4653 - More unit test functions should be added](http://d.puremagic.com/issues/show_bug.cgi?id=4653)

TODO: [Hamcrest](http://code.google.com/p/hamcrest/) Matchers and `assertThat`
