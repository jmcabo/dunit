#!/usr/bin/env dub
/+ dub.sdl:
name "example"
dependency "d-unit" version=">=0.8.0"
+/

//          Copyright Juan Manuel Cabo 2012.
//          Copyright Mario Kröplin 2016.
// Distributed under the Boost Software License, Version 1.0.
//    (See accompanying file LICENSE_1_0.txt or copy at
//          http://www.boost.org/LICENSE_1_0.txt)

module example;

import dunit;
import core.thread;
import core.time;
import std.range;
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
    public void assertAssocArrayEqualsFailure()
    {
        string[int] expected = [1: "foo", 2: "bar"];
        string[int] actual = [1: "foo", 2: "baz"];

        assertArrayEquals(expected, actual);
    }

    @Test
    public void assertRangeEqualsFailure()
    {
        int[] expected = [0, 1, 1, 2];
        auto actual = iota(0, 3);

        assertRangeEquals(expected, actual);
    }

    @Test
    public void assertAllFailure()
    {
        assertAll(
            assertLessThan(6 * 7, 42),
            assertGreaterThan(6 * 7, 42),
        );
    }
}

/**
 * This example demonstrates the order in which the fixture functions run.
 * The functions 'setUp' and 'tearDown' run before and after each test.
 * The functions 'setUpAll' and 'tearDownAll' run once before and after
 * all tests in the class.
 */
class TestFixture
{
    mixin UnitTest;

    public this()
    {
        debug writeln("@this()");
    }

    @BeforeAll
    public static void setUpAll()
    {
        debug writeln("@BeforeAll");
    }

    @AfterAll
    public static void tearDownAll()
    {
        debug writeln("@AfterAll");
    }

    @BeforeEach
    public void setUp()
    {
        debug writeln("@BeforeEach");
    }

    @AfterEach
    public void tearDown()
    {
        debug writeln("@AfterEach");
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

    @BeforeEach
    public override void setUp()
    {
        debug writeln("@BeforeEach override");
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
    // tagged test functions can be selected to be included or excluded
    @Test
    @Tag("fast")
    @Tag("smoke")
    private void success()
    {
        testResult(true);
    }

    // disabled test function
    @Test
    @Disabled("not ready yet")
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

    // expected exception can be further verified
    @Test
    public void testException()
    {
        import std.exception : enforce;

        auto exception = expectThrows(enforce(false));

        assertEquals("Enforcement failed", exception.msg);
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

    @BeforeEach
    public void setUp()
    {
        done = false;
        thread = new Thread(&threadFunction);
    }

    @AfterEach
    public void tearDown()
    {
        thread.join();
    }

    private void threadFunction()
    {
        Thread.sleep(100.msecs);
        done = true;
    }

    @Test
    @Tag("slow")
    public void test()
    {
        assertFalse(done);

        thread.start();

        assertEventually({ return done; });
    }
}

// either use the 'Main' mixin or call 'dunit_main(args)'
mixin Main;
