#!/usr/bin/env dub
/+ dub.sdl:
name "example"
dependency "d-unit" version=">=0.8.0"
dependency "unit-threaded" version=">=0.6.35"
+/

//          Copyright Mario Kröplin 2017.
// Distributed under the Boost Software License, Version 1.0.
//    (See accompanying file LICENSE_1_0.txt or copy at
//          http://www.boost.org/LICENSE_1_0.txt)

module fluent_assertion;

import dunit;
import unit_threaded.should;

/**
 * This example demonstrates the reporting of test failures
 * with unit-threaded's fluent assertions.
 */
class Test
{
    mixin UnitTest;

    @Test
    public void shouldEqualFailure() @safe pure
    {
        "bar".shouldEqual("baz");
    }

    @Test
    public void shouldNotEqualFailure() @safe pure
    {
        "foo".shouldNotEqual("foo");
    }

    @Test
    public void shouldBeInFailure() @safe pure
    {
        42.shouldBeIn([0, 1, 2]);
    }
}

// either use the 'Main' mixin or call 'dunit_main(args)'
mixin Main;
