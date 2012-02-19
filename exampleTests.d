#!/usr/bin/rdmd

/** Unit testing framework ('dunit')
 *
 * Allows to define unittests simply as methods which names start
 * with 'test'.
 * The only thing necessary to create a unit test class, is to
 * declare the mixin TestMixin inside the class. This will register
 * the class and its test methods for the test runner.
 *
 * License:   <a href="http://www.boost.org/LICENSE_1_0.txt">Boost License 1.0</a>.
 * Authors:   Juan Manuel Cabo
 * Version:   0.4
 * Source:    dunit.d
 * Last update: 2012-02-19
 */
/*          Copyright Juan Manuel Cabo 2012.
 * Distributed under the Boost Software License, Version 1.0.
 *    (See accompanying file LICENSE_1_0.txt or copy at
 *          http://www.boost.org/LICENSE_1_0.txt)
 */
module ExampleTests;
import std.stdio, std.string;
import dunit;


//Minimal example:
class ATestClass {
    mixin TestMixin;

    void testExample() {
        assertEquals("bla", "b"~"la");
    }
}


/**
 * Look!! no test base class needed!!
 */
class AbcTest {
    //This declaration here is the only thing needed to mark a class as a unit test class.
    mixin TestMixin;

    //Variable members that start with 'test' are allowed.
    public int testN = 3;
    public int testM = 4;

    //Any method whose name starts with 'test' is run as a unit test:
    //(NOTE: this is bound at compile time, there is no overhead).
    public void test1() {
        assert(true);
    }

    public void test2() {
        //You can use D's assert() function:
        assert(1 == 2 / 2);
        //Or dunit convenience asserts (just edit dunit.d to add more):
        assertEquals(1, 2/2);
        //The expected and actual values will be shown in the output:
        assertEquals("my string looks dazzling", "my dtring looks sazzling");
    }

    //Test methods with default arguments work, as long as they can 
    //be called without arguments, ie: as testDefaultArguments() for instance:
    public void testDefaultArguments(int a=4, int b=3) {
    }

    //Even if the method is private to the unit test class, it is still run.
    private void test5(int a=4) {
    }

    //This test was disabled just by adding an underscore to the name:
    public void _testAnother() {
        assert(false, "fails");
    }

    //Optional inicialization and de-initialization. 
    //  setUp() and tearDown() are called around each individual test.
    //  setUpClass() and tearDownClass() are called once around the whole unit test.
    public void setUp() {
    }
    public void tearDown() {
    }
    public void setUpClass() {
    }
    public void tearDownClass() {
    }
}


class DerivedTest : AbcTest {
    mixin TestMixin;

    //Base class tests will be run!!!!!!
    //You can for instance override setUpClass() and change the target implementation
    //of a family of classes that you are testing.
}


version = DUnit;

version(DUnit) {

    //-All you need to run the tests, is to declare
    //
    //      mixin DUnitMain.
    //
    //-You can alternatively call 
    //
    //      dunit.runTests_Progress();      for java style results output (SHOWS COLORS IF IN UNIX !!!)
    // or   dunit.runTests_Tree();          for a more verbose output
    //
    //from your main function.

    mixin DUnitMain;
    //void main() {dunit.runTests_Tree();}

} else {
    int main (string[] args) {
        writeln("production");
    }
}


/*

Run this file with (works in Windows/Linux):


    dmd exampleTests.d dunit.d
    ./exampleTests


The output will be (java style):


    ..F....F..
    There were 2 failures:
    1) test2(AbcTest)core.exception.AssertError@exampleTests.d(60): Expected: 'my string looks dazzling', but was: 'my dtring looks sazzling'
    2) test2(DerivedTest)core.exception.AssertError@exampleTests.d(60): Expected: 'my string looks dazzling', but was: 'my dtring looks sazzling'

    FAILURES!!!
    Tests run: 9,  Failures: 2,  Errors: 0


If you use the more verbose method dunit.runTests_Tree(), then the output is:


    Unit tests: 
        ATestClass
            OK: testExample()
        AbcTest
            OK: test1()
            FAILED: test2(): core.exception.AssertError@exampleTests.d(60): Expected: 'my string looks dazzling', but was: 'my dtring looks sazzling'
            OK: testDefaultArguments()
            OK: test5()
        DerivedTest
            OK: test1()
            FAILED: test2(): core.exception.AssertError@exampleTests.d(60): Expected: 'my string looks dazzling', but was: 'my dtring looks sazzling'
            OK: testDefaultArguments()
            OK: test5()

HAVE FUN!

*/
