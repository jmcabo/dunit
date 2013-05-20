#!/usr/bin/env rdmd

//          Copyright Juan Manuel Cabo 2012.
//          Copyright Mario Kröplin 2013.
// Distributed under the Boost Software License, Version 1.0.
//    (See accompanying file LICENSE_1_0.txt or copy at
//          http://www.boost.org/LICENSE_1_0.txt)

module example;

import dunit.framework;
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
        int expected = 42;
        int actual = 4 * 6;

        assertEquals(expected, actual);
    }

    @Test
    public void assertArrayEqualsFailure()
    {
        int[] expected = [0, 1, 1, 2, 3];
        int[] actual = [0, 1, 2, 3];

        assertArrayEquals(expected, actual);
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
        writeln("this()");
    }

    @BeforeClass
    public void setUpClass()
    {
        writeln("setUpClass()");
    }

    @AfterClass
    public void tearDownClass()
    {
        writeln("tearDownClass()");
    }

    @Before
    public void setUp()
    {
        writeln("setUp()");
    }

    @After
    public void tearDown()
    {
        writeln("tearDown()");
    }

    @Test
    public void test1()
    {
        writeln("test1()");
    }

    @Test
    public void test2()
    {
        writeln("test2()");
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
        writeln("different setUp()");
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
    @Ignore
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
        Thread.sleep(dur!"msecs"(100));
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
