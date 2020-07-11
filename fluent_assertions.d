#!/usr/bin/env dub
/+ dub.sdl:
name "example"
dependency "d-unit" version=">=0.8.0"
dependency "dshould" version=">=1.3.2"
+/

//          Copyright Mario Kröplin 2020.
// Distributed under the Boost Software License, Version 1.0.
//    (See accompanying file LICENSE_1_0.txt or copy at
//          http://www.boost.org/LICENSE_1_0.txt)

module fluent_assertion;

import dunit;
import dshould;

/**
 * This example demonstrates the reporting of test failures
 * with dshould's fluent assertions.
 */
class Test
{
    mixin UnitTest;

    @Test
    public void shouldEqualFailure() @safe pure
    {
        "bar".should.equal("baz");
    }

    @Test
    public void shouldNotEqualFailure() @safe pure
    {
        "foo".should.not.equal("foo");
    }

    @Test
    public void shouldBeInFailure() @safe pure
    {
        [0, 1, 2].should.contain(42);
    }
}

// either use the 'Main' mixin or call 'dunit_main(args)'
mixin Main;
