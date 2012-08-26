module dunit.assertion;

import core.exception;
import core.thread;
import std.algorithm;
import std.array;
import std.conv;
version (unittest) import std.exception;

/**
 * Asserts that a condition is true.
 * Throws: AssertError otherwise
 */
void assertTrue(bool condition,  string msg = null,
        string file = __FILE__,
        size_t line = __LINE__)
{
    if (condition)
        return;

    fail(msg, file, line);
}

/**
 * Asserts that a condition is false.
 * Throws: AssertError otherwise
 */
void assertFalse(bool condition,  string msg = null,
        string file = __FILE__,
        size_t line = __LINE__)
{
    if (!condition)
        return;

    fail(msg, file, line);
}

unittest
{
    assertTrue(true);
    assertEquals("Assertion failure",
            collectExceptionMsg!AssertError(assertTrue(false)));

    assertFalse(false);
    assertEquals("Assertion failure",
            collectExceptionMsg!AssertError(assertFalse(true)));
}

/**
 * Asserts that the values are equal.
 * Throws: AssertError otherwise
 */
void assertEquals(T, U)(T expected, U actual,  string msg = null,
        string file = __FILE__,
        size_t line = __LINE__)
{
    if (expected == actual)
        return;

    string header = (msg.empty) ? null : msg ~ "; ";

    fail(header ~ "expected: <" ~ to!string(expected) ~ "> but was: <"~ to!string(actual) ~ ">",
            file, line);
}

unittest
{
    assertEquals("foo", "foo");
    assertEquals("expected: <foo> but was: <bar>",
            collectExceptionMsg!AssertError(assertEquals("foo", "bar")));

    assertEquals(42, 42);
    assertEquals("expected: <42> but was: <23>",
            collectExceptionMsg!AssertError(assertEquals(42, 23)));

    assertEquals(42.0, 42.0);

    Object foo = new Object();
    Object bar = null;

    assertEquals(foo, foo);
    assertEquals(bar, bar);
    assertEquals("expected: <object.Object> but was: <null>",
            collectExceptionMsg!AssertError(assertEquals(foo, bar)));
}

/**
 * Asserts that the arrays are equal.
 * Throws: AssertError otherwise
 */
void assertArrayEquals(T, U)(T[] expecteds, U[] actuals, string msg = null,
        string file = __FILE__,
        size_t line = __LINE__)
{
    string header = (msg.empty) ? null : msg ~ "; ";

    for (size_t index = 0; index < min(expecteds.length, actuals.length); ++index)
    {
        assertEquals(expecteds[index], actuals[index],
                header ~ "array mismatch at index " ~ to!string(index),
                file, line);
    }
    assertEquals(expecteds.length, actuals.length,
            header ~ "array length mismatch",
            file, line);
}

unittest
{
    int[] expecteds = [1, 2, 3];
    double[] actuals = [1, 2, 3];

    assertArrayEquals(expecteds, actuals);
    assertEquals("array mismatch at index 1; expected: <2> but was: <2.3>",
            collectExceptionMsg!AssertError(assertArrayEquals(expecteds, [1, 2.3])));
    assertEquals("array length mismatch; expected: <3> but was: <2>",
            collectExceptionMsg!AssertError(assertArrayEquals(expecteds, [1, 2])));
    assertEquals("array mismatch at index 2; expected: <r> but was: <z>",
            collectExceptionMsg!AssertError(assertArrayEquals("bar", "baz")));
}

/**
 * Asserts that the value is null.
 * Throws: AssertError otherwise
 */
void assertNull(T)(T actual,  string msg = null,
        string file = __FILE__,
        size_t line = __LINE__)
{
    if (actual is null)
        return;

    fail(msg, file, line);
}

/**
 * Asserts that the value is not null.
 * Throws: AssertError otherwise
 */
void assertNotNull(T)(T actual,  string msg = null,
        string file = __FILE__,
        size_t line = __LINE__)
{
    if (actual !is null)
        return;

    fail(msg, file, line);
}

unittest
{
    Object foo = new Object();
    
    assertNull(null);
    assertEquals("Assertion failure",
            collectExceptionMsg!AssertError(assertNull(foo)));

    assertNotNull(foo);
    assertEquals("Assertion failure",
            collectExceptionMsg!AssertError(assertNotNull(null)));
}

/**
 * Asserts that the values are the same.
 * Throws: AssertError otherwise
 */
void assertSame(T, U)(T expected, U actual,  string msg = null,
        string file = __FILE__,
        size_t line = __LINE__)
{
    if (expected is actual)
        return;

    string header = (msg.empty) ? null : msg ~ "; ";

    fail(header ~ "expected same: <" ~ to!string(expected) ~ "> was not: <"~ to!string(actual) ~ ">",
            file, line);
}

/**
 * Asserts that the values are not the same.
 * Throws: AssertError otherwise
 */
void assertNotSame(T, U)(T expected, U actual,  string msg = null,
        string file = __FILE__,
        size_t line = __LINE__)
{
    if (expected !is actual)
        return;

    string header = (msg.empty) ? null : msg ~ "; ";

    fail(header ~ "expected not same",
            file, line);
}

unittest
{
    Object foo = new Object();
    Object bar = new Object();

    assertSame(foo, foo);
    assertEquals("expected same: <object.Object> was not: <object.Object>",
            collectExceptionMsg!AssertError(assertSame(foo, bar)));

    assertNotSame(foo, bar);
    assertEquals("expected not same",
            collectExceptionMsg!AssertError(assertNotSame(foo, foo)));
}

/**
 * Fails a test.
 * Throws: AssertError
 */
void fail(string msg = null,
        string file = __FILE__,
        size_t line = __LINE__)
{
    throw (msg.empty) ? new AssertError(file, line) : new AssertError(msg, file, line);
}

unittest
{
    assertEquals("Assertion failure",
            collectExceptionMsg!AssertError(fail()));
}

/**
 * Checks a probe until the timeout expires. The assert error is produced
 * if the probe fails to return 'true' before the timeout. 
 *
 * The parameter timeout determines the maximum timeout to wait before
 * asserting a failure (default is 500ms).
 *
 * The parameter delay determines how often the predicate will be
 * checked (default is 10ms).
 *
 * This kind of assertion is very useful to check on code that runs in another
 * thread. For instance, the thread that listens to a socket.
 *
 * Throws: AssertError when the probe fails to become true before timeout
 */
public static void assertEventually(bool delegate() probe, 
        Duration timeout = dur!"msecs"(500), Duration delay = dur!"msecs"(10), 
        string msg = null,
        string file = __FILE__, 
        size_t line = __LINE__)
{
    TickDuration startTime = TickDuration.currSystemTick();
   
    while (!probe()) {
        Duration elapsedTime = cast(Duration)(TickDuration.currSystemTick() - startTime);

        if (elapsedTime >= timeout) {
            if (msg.empty) {
                msg = "timed out";
            }
            fail(msg, file, line);
        }

        Thread.sleep(delay);
    }
}

unittest
{
    assertEventually({ static count = 0; return ++count > 42; });

    assertEquals("timed out",
            collectExceptionMsg!AssertError(assertEventually({ return false; })));
}
