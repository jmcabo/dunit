#!/usr/bin/rdmd
module Main;
import std.stdio;
import std.string;
import dunit;

class TestBase {
}

class AbcTest : TestBase {
	mixin TestMixin;

	public int testN = 3;
	public int testM = 4;

	public this() {
		//writeln("AbcTest constructor run", );
	}
	public void test1() {
		//writeln("test1 run");
	}
	public void test2() {
		//writeln("test2 run");
	}
	private void test5(int a=4) {
		//writeln("test5-1 run");
	}
	public void test5(int a=4, int b=3) {
		//writeln("test5-2 run");
	}
}


class BcdTest : AbcTest {
	mixin TestMixin;

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

		//assertEquals(null, "bcd");

		//writeln("test3 run");

		int[4] a = [1,3,3,3];
		int b = 5;
		//writeln(a[b]);
	}

	public void test4() {
		//import core.thread;
		//Thread.sleep(dur!"msecs"(10000));

		//assert(false);
	}
	public override void test2() {
		//writeln("bcdtest2 run");
		assert(__traits(compiles, typeid(null)));
		auto s = typeid(null);
		assert(s is null);
	}
}

version(DUnit) {

	mixin DUnitMain;

} else {

	int main (string[] args) {
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

}



class DefTest {
	mixin TestMixin;

	public void testOneTest() {
		//writeln("bla" , __VERSION__ , ";" ~ __VENDOR__);
	}
}
