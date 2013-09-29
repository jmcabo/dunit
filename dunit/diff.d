//          Copyright Mario Kröplin 2013.
// Distributed under the Boost Software License, Version 1.0.
//    (See accompanying file LICENSE_1_0.txt or copy at
//          http://www.boost.org/LICENSE_1_0.txt)

module dunit.diff;

import std.algorithm;
import std.range;
import std.typecons;

/**
 * Returns a pair of strings that highlight the difference between lhs and rhs.
 */
Tuple!(string, string) diff(string)(string lhs, string rhs)
{
    const MAX_LENGTH = 20;

    if (lhs == rhs)
        return tuple(lhs, rhs);

    auto rest = mismatch(lhs, rhs);
    auto retroDiff = mismatch(retro(rest[0]), retro(rest[1]));
    auto diff = tuple(retro(retroDiff[0]), retro(retroDiff[1]));
    string prefix = lhs[0 .. $ - rest[0].length];
    string suffix = lhs[prefix.length + diff[0].length .. $];

    if (prefix.length > MAX_LENGTH)
        prefix = "..." ~ prefix[$ - MAX_LENGTH .. $];
    if (suffix.length > MAX_LENGTH)
        suffix = suffix[0 .. MAX_LENGTH] ~ "...";

    return tuple(
            prefix ~ '<' ~ diff[0] ~ '>' ~ suffix,
            prefix ~ '<' ~ diff[1] ~ '>' ~ suffix);
}

///
unittest
{
    assert(diff("abc", "abc") == tuple("abc", "abc"));
    // highlight difference
    assert(diff("abc", "Abc") == tuple("<a>bc", "<A>bc"));
    assert(diff("abc", "aBc") == tuple("a<b>c", "a<B>c"));
    assert(diff("abc", "abC") == tuple("ab<c>", "ab<C>"));
    assert(diff("abc", "") == tuple("<abc>", "<>"));
    assert(diff("abc", "abbc") == tuple("ab<>c", "ab<b>c"));
    // abbreviate long prefix or suffix
    assert(diff("_12345678901234567890a", "_12345678901234567890A")
            == tuple("...12345678901234567890<a>", "...12345678901234567890<A>"));
    assert(diff("a12345678901234567890_", "A12345678901234567890_")
            == tuple("<a>12345678901234567890...", "<A>12345678901234567890..."));
}
