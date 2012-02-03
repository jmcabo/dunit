#!/usr/bin/rdmd
module Main;
import std.stdio;
import std.string;
import dunit;

class TestBase {
}

class AbcTest : TestBase {
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

class BcdTest : AbcTest {
    public this() {
        //writeln("BcdTest constructor run", );
    }
    public void setUpClass() {
    }
    public void tearDownClass() {
    }
    public void setUp() {
    }
    public void tearDown() {
    }
    public void test3() {
        assertEquals("abc", "abc");
        //assertEquals("abc", "bcd");
        string s = "aa";
        assertEquals(s, s);
        s = null;
        assertEquals(s, s);
        assertEquals(null, "bcd");

        //writeln("test3 run");

        //int[4] a = [1,3,3,3];
        //int b = 5;
        //writeln(a[b]);
    }
    public void test4() {
        assert(false);
    }

    mixin TestMixin;
}

int main (string[] args) {
    writeln("");
    (new AbcTest()).test1();

    assert(typeid(AbcTest).name == "Main.AbcTest");
    assert(AbcTest.stringof == "AbcTest");

    try {
        assert (1 == 2);
    } catch (Throwable t) {
        assert(typeid(t).name == "core.exception.AssertError");
        assert(typeof(t).stringof == "Throwable");
        assert(t.msg == "Assertion failure");
    }

    dunit.runTests();


    return 0;
}

