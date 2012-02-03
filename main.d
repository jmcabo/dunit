#!/usr/bin/rdmd

module main;

import std.stdio;
import std.string;
import dunit;

class AbcTest {
    public this() {
        //writeln("AbcTest constructor run", );
    }
    public void test1() {
        //writeln("test1 run");
    }
    public void test2() {
        //writeln("test2 run");
    }

    mixin TestMixin;
}

class BcdTest {
    public this() {
        //writeln("BcdTest constructor run", );
    }
    public void test3() {
        //writeln("test3 run");
        int[4] a = [1,3,3,3];
        int b = 5;
        writeln(a[b]);
        assert(false);
    }
    public void test4() {
        assert(false);
    }

    mixin TestMixin;
}

int main (string[] args) {
    dunit.runTests();
    return 0;
}

