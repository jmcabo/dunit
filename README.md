xUnit Testing Framework for D
=============================

This is a simple implementation of the xUnit Testing Framework
for the [D Programming Language](http://dlang.org).
Being based on [JUnit](http://junit.org) it allows to organize tests
according to the [xUnit Test Patterns](http://xunitpatterns.com).

Looking for a replacement of
[DUnit](http://www.dsource.org/projects/dmocks/wiki/DUnit) for D1,
I found [jmcabo/dunit](https://github.com/jmcabo/dunit) promising.
First, I had to fix some issues, but by now the original implementation
has been largely revised.

The xUnit Testing Framework is known to work with versions D 2.062 and D 2.063.

Testing Functions vs. Interactions
----------------------------------

D's built-in support for unittests is best suited for testing functions,
when the test cases can be expressed as one-liners.
(Have a look at the documented unittests for the `dunit.assertion` functions.)

But you're on your own, when you have to write a lot more code per test case,
for example for testing interactions of objects.

So, here is what the xUnit Testing Framework has to offer:
- tests are organized in classes
- tests are always named
- tests can reuse a shared fixture
- you see the progress as the tests are run
- you see all failed tests at once
- you get more information about failures

Failures vs. Errors
-------------------

Specialized assertion functions provide more information about failures than
the built-in `assert` expression.

For example,

    assertEquals("bar", "baz");

will not only report the faulty value but will also highlight the difference:

    expected: <ba[r]> but was: <ba[z]>

Together with the expressive name of the test (that's your responsibility)
this should be enough information for failures. On the other hand, for
violated contracts and other exceptions from deep down the unit under test
you may wish for the stack trace.

That's why the xUnit Testing Framework distinguishes failures from errors,
and why `dunit.assertion` doesn't use `AssertError` but introduces its own
`AssertException`.

User Defined Attributes
-----------------------

Thanks to D's User Defined Attributes, test names no longer have to start with
"test".

Put `mixin UnitTest;` in your test class and attach `@Test`,
`@Before`, `@After`, `@BeforeClass`, `@AfterClass`, and `@Ignore`
(borrowed from JUnit 4) to the member functions to state their purpose.

Examples
--------

Run the included example to see the xUnit Testing Framework in action:

    ./example.d

(When you get one error and two failures, everything works fine.)

Have a look at the debug output of the example in "verbose" style:

    rdmd -debug example.d --verbose

Or just focus on the issues:

    ./example.d --filter Test.assert --filter error

Next Steps
----------

Integrate [Hamcrest](http://code.google.com/p/hamcrest/) Matchers
and `assertThat`.
