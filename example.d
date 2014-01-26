#!/usr/bin/env rdmd -unittest

//          Copyright Juan Manuel Cabo 2012.
//          Copyright Mario Kröplin 2013.
// Distributed under the Boost Software License, Version 1.0.
//    (See accompanying file LICENSE_1_0.txt or copy at
//          http://www.boost.org/LICENSE_1_0.txt)

module example;

import dunit;
import core.thread;
import core.time;
import std.stdio;

/**
 * This example demonstrates the reporting of test failures.
 */
class Test
{
    mixin UnitTest;

    @Test
    public void assertEqualsFailure()
    {
        string expected = "bar";
        string actual = "baz";

        assertEquals(expected, actual);
    }

    @Test
    public void assertArrayEqualsFailure()
    {
        int[] expected = [0, 1, 1, 2, 3];
        int[] actual = [0, 1, 2, 3];

        assertArrayEquals(expected, actual);
    }

    @Test
    public void assertAssocArrayEqualsFailure()
    {
        string[int] expected = [1: "foo", 2: "bar"];
        string[int] actual = [1: "foo", 2: "baz"];

        assertArrayEquals(expected, actual);
    }

    @Test
    public void assertOpFailure()
    {
        assertLessThan(6 * 7, 42);
    }
}

/**
 * This example demonstrates the order in which the fixture functions run.
 * The functions 'setUp' and 'tearDown' run before and after each test.
 * The functions 'setUpClass' and 'tearDownClass' run once before and after
 * all tests in the class.
 */
class TestFixture
{
    mixin UnitTest;

    public this()
    {
        debug writeln("@this()");
    }

    @BeforeClass
    public static void setUpClass()
    {
        debug writeln("@BeforeClass");
    }

    @AfterClass
    public static void tearDownClass()
    {
        debug writeln("@AfterClass");
    }

    @Before
    public void setUp()
    {
        debug writeln("@Before");
    }

    @After
    public void tearDown()
    {
        debug writeln("@After");
    }

    @Test
    public void test1()
    {
        debug writeln("@test1()");
    }

    @Test
    public void test2()
    {
        debug writeln("@test2()");
    }
}

/**
 * This example demonstrates how to reuse tests and a test fixture.
 */
class TestReuse : TestFixture
{
    mixin UnitTest;

    @Before
    public override void setUp()
    {
        debug writeln("@Before override");
    }
}

/**
 * This example demonstrates various things to know about the test framework.
 */
class TestingThisAndThat
{
    mixin UnitTest;

    // test function can have default arguments
    @Test
    public void testResult(bool actual = true)
    {
        assertTrue(actual);
    }

    // test function can even be private
    @Test
    private void success()
    {
        testResult(true);
    }

    // disabled test function
    @Test
    @Ignore("not ready yet")
    public void failure()
    {
        testResult(false);
    }

    // failed contracts are errors, not failures
    @Test
    public void error()
    {
        assert(false);
    }
}

/**
 * This example demonstrates how to test asynchronous code.
 */
class TestingAsynchronousCode
{
    mixin UnitTest;

    private Thread thread;

    private bool done;

    @Before
    public void setUp()
    {
        done = false;
        thread = new Thread(&threadFunction);
    }

    @After
    public void tearDown()
    {
        thread.join();
    }

    private void threadFunction()
    {
        Thread.sleep(msecs(100));
        done = true;
    }

    @Test
    public void test()
    {
        assertFalse(done);

        thread.start();

        assertEventually({ return done; });
    }
}

// either use the 'Main' mixin or call 'dunit_main(args)'
mixin Main;
