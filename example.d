#!/usr/bin/env rdmd

/**
 * xUnit Testing Framework for the D Programming Language - examples
 */

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

    mixin TestMixin;

    public void testEqualsFailure()
    {
        int expected = 42;
        int actual = 4 * 6;

        assertEquals(expected, actual);
    }

    public void testArrayEqualsFailure()
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

    mixin TestMixin;

    public this()
    {
        writeln("this()");
    }

    public void setUpClass()
    {
        writeln("setUpClass()");
    }

    public void tearDownClass()
    {
        writeln("tearDownClass()");
    }

    public void setUp()
    {
        writeln("setUp()");
    }

    public void tearDown()
    {
        writeln("tearDown()");
    }

    public void test1()
    {
        writeln("test1()");
    }

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

    mixin TestMixin;

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

    mixin TestMixin;

    // field name may start with "test"
    private int test;

    // test function can have default arguments
    public void testResult(bool actual = true)
    {
        assertTrue(actual);
    }

    // test function can even be private
    private void testSuccess()
    {
        testResult(true);
    }

    // disabled test function: name does not start with "test"
    public void ignore_testFailure()
    {
        testResult(false);
    }

    // failed contracts are errors, not failures
    public void testError()
    {
        assert(false);
    }

}

/**
 * This example demonstrates how to test asynchronous code.
 */
class TestingAsynchronousCode
{

    mixin TestMixin;

    private Thread thread;

    private bool done;

    public void setUp()
    {
        done = false;
        thread = new Thread(&threadFunction);
    }

    public void tearDown()
    {
        thread.join();
    }

    private void threadFunction()
    {
        Thread.sleep(dur!"msecs"(100));
        done = true;
    }

    public void test()
    {
        assertFalse(done);

        thread.start();

        assertEventually({ return done; });
    }

}

// either use the 'DUnitMain' mixin or call 'dunit_main(args)'
mixin DUnitMain;
