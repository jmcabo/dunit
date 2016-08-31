//          Copyright Mario Kröplin 2016.
// Distributed under the Boost Software License, Version 1.0.
//    (See accompanying file LICENSE_1_0.txt or copy at
//          http://www.boost.org/LICENSE_1_0.txt)

module fluent_assertion;

import dunit;
import unit_threaded.should : shouldBeIn, shouldEqual, shouldNotEqual;

class Test
{
    mixin UnitTest;

    @Test
    public void shouldEqualFailure()
    {
        "bar".shouldEqual("baz");
    }

    @Test
    public void shouldNotEqualFailure()
    {
        "foo".shouldNotEqual("foo");
    }

    @Test
    public void shouldBeInFailure()
    {
        42.shouldBeIn([0, 1, 2]);
    }
}

// either use the 'Main' mixin or call 'dunit_main(args)'
mixin Main;
