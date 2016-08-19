//          Copyright Mario Kröplin 2016.
// Distributed under the Boost Software License, Version 1.0.
//    (See accompanying file LICENSE_1_0.txt or copy at
//          http://www.boost.org/LICENSE_1_0.txt)

module dunit.ng.assertion;

public import dunit.assertion : assertTrue, assertFalse, assertEmpty, assertNotEmpty, assertNull, assertNotNull,
    assertAll, expectThrows, fail,
    assertGreaterThan, assertGreaterThanOrEqual, assertLessThan, assertLessThanOrEqual, assertOp,
    assertEventually;

/**
 * Asserts that the values are equal.
 * Throws: AssertException otherwise
 */
void assertEquals(T, U)(T actual, U expected, lazy string msg = null,
        string file = __FILE__,
        size_t line = __LINE__)
{
    import dunit.assertion : assertEquals;

    assertEquals(expected, actual, msg, file, line);
}

/**
 * Asserts that the arrays are equal.
 * Throws: AssertException otherwise
 */
void assertArrayEquals(T, U)(in T[] actual, in U[] expected, lazy string msg = null,
        string file = __FILE__,
        size_t line = __LINE__)
{
    import dunit.assertion : assertArrayEquals;

    assertArrayEquals(expected, actual, msg, file, line);
}

/**
 * Asserts that the associative arrays are equal.
 * Throws: AssertException otherwise
 */
void assertArrayEquals(T, U, V)(in T[V] actual, in U[V] expected, lazy string msg = null,
        string file = __FILE__,
        size_t line = __LINE__)
{
    import dunit.assertion : assertArrayEquals;

    assertArrayEquals(expected, actual, msg, file, line);
}

/**
 * Asserts that the ranges are equal.
 * Throws: AssertException otherwise
 */
void assertRangeEquals(R1, R2)(R1 actual, R2 expected, lazy string msg = null,
        string file = __FILE__,
        size_t line = __LINE__)
{
    import dunit.assertion : assertRangeEquals;

    assertRangeEquals(expected, actual, msg, file, line);
}

/**
 * Asserts that the values are the same.
 * Throws: AssertException otherwise
 */
void assertSame(T, U)(T actual, U expected, lazy string msg = null,
        string file = __FILE__,
        size_t line = __LINE__)
{
    import dunit.assertion : assertSame;

    assertSame(expected, actual, msg, file, line);
}

/**
 * Asserts that the values are not the same.
 * Throws: AssertException otherwise
 */
void assertNotSame(T, U)(T actual, U expected, lazy string msg = null,
        string file = __FILE__,
        size_t line = __LINE__)
{
    import dunit.assertion : assertNotSame;

    assertNotSame(expected, actual, msg, file, line);
}
