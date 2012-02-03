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
 * Source:    dunit.d
 */
/*          Copyright Juan Manuel Cabo 2012.
 * Distributed under the Boost Software License, Version 1.0.
 *    (See accompanying file LICENSE_1_0.txt or copy at
 *          http://www.boost.org/LICENSE_1_0.txt)
 */

module dunit;

import std.stdio;

/*
To_Do:

    @factory method
    @switch(testmethodName) { case "test1": refObj.test1(); }
    @register: struct {className, factoryMethodPointer, runMethodPointer}
    @fixtureSetup
    @fixtureTeardown
    @setup
    @tearDown
    @unittest that derive unittests.
    @var names that start with 'test'.
    @'test' methods with arguments.
    @'test' methods with overloads: only the first one is called
    @'test' methods that are private or protected: can be private/protected, it is run anyways.
    .Q: call tearDownClass anyways if a test fails?
    .Q: call tearDown anyways if a test fails?
    .list the kinds of asserts in classic unit test frameworks.
    .version unittests
    .ui
*/


string[] testClasses;
string[][string] testNamesByClass;
void function(Object o, string testName)[string] testCallers;
Object function()[string] testCreators;

public static void assertEquals(string s, string t, 
        string file = __FILE__, 
        size_t line = __LINE__)
{
    if (s is t) {
        return;
    }
    if (s != t) {
        throw new core.exception.AssertError(
                "Expected: '"~s~"', but was: '"~t~"'",
                file, line);
    }
}


/**
 * Runs all the unit tests.
 */
public static void runTests() {
    //List Test classes:
    writeln("Unit tests: ");
    foreach (string className; testClasses) {
        writeln("    " ~ className);

        //Create the class:
        Object testObject = null;
        try {
            testObject = testCreators[className]();
        } catch (Throwable t) {
            writefln("        ERROR IN CONSTRUCTOR: " ~ className ~ ".this(): " 
                    ~ "(): %s@%s(%d): %s", typeid(t).name, t.file, t.line, t.msg);
        }
        if (testObject is null) {
            continue;
        }

        //setUpClass
        try {
            testCallers[className](testObject, "setUpClass");
        } catch (Throwable t) {
            writefln("        ERROR IN setUpClass: " ~ className ~ ".setUpClass(): " 
                    ~ "(): %s@%s(%d): %s", typeid(t).name, t.file, t.line, t.msg);
        }

        //Run each test of the class:
        foreach (string testName; testNamesByClass[className]) {
            //setUp
            bool setUpOk = false;
            try {
                testCallers[className](testObject, "setUp");
                setUpOk = true;
            } catch (Throwable t) {
                writefln("        ERROR: setUp"
                    ~ "(): %s@%s(%d): %s", typeid(t).name, t.file, t.line, t.msg);
            }
            if (!setUpOk) {
                continue;
            }

            //test
            try {
                testCallers[className](testObject, testName);
                writefln("        OK: " ~ testName ~ "()");
            } catch (Throwable t) {
                writefln("        FAILED: " ~ testName 
                    ~ "(): %s@%s(%d): %s", typeid(t).name, t.file, t.line, t.msg);
            }

            //tearDown (call anyways if test failed)
            try {
                testCallers[className](testObject, "tearDown");
            } catch (Throwable t) {
                writefln("        ERROR: tearDown" 
                    ~ "(): %s@%s(%d): %s", typeid(t).name, t.file, t.line, t.msg);
            }
        }

        //tearDownClass
        try {
            testCallers[className](testObject, "tearDownClass");
        } catch (Throwable t) {
            writefln("        ERROR IN tearDownClass: " ~ className ~ ".tearDownClass(): " 
                    ~ "(): %s@%s(%d): %s", typeid(t).name, t.file, t.line, t.msg);
        }
    }
}


/**
 * Registers a class as a unit test.
 */
mixin template TestMixin() {
    public static this() {
        //Names of test methods:
        immutable(string[]) _testMethods = _testMethodsList!(
                __traits(parent, _testClass_), 
                __traits(allMembers, __traits(parent, _testClass_))
        ).ret;

        //Factory method:
        static Object createFunction() { 
            mixin("return (new " ~ __traits(parent, _testClass_).stringof ~ "());");
        }

        //Run method:
        //Generate a switch statement, that calls the method that matches the testName:
        static void runTest(Object o, string testName) {
            mixin(
                generateRunTest!(__traits(parent, _testClass_),
                                 __traits(allMembers, __traits(parent, _testClass_)))
            );
        }

        //Register UnitTest class:
        string className = __traits(parent, _testClass_).stringof;
        testClasses ~= className;
        testNamesByClass[className] = _testMethods.dup;
        testCallers[className] = &runTest;
        testCreators[className] = &createFunction;
    }
 
    private template _testMethodsList(T, args...) {
        static if (args.length == 0) {
            immutable(string[]) ret = [];
        } else {

            //Skip strings that don't start with "test":
            static if (args[0].length < 4 || args[0][0..4] != "test"
                  || !(__traits(compiles, mixin("(new " ~ T.stringof ~ "())." ~ args[0] ~ "()")) ))
            {
                static if(args.length == 1) {
                    immutable(string[]) ret = [];
                } else {
                    immutable(string[]) ret = _testMethodsList!(T, args[1..$]).ret;
                }
            } else {

                //Return the first argument and the rest:
                static if (args.length == 1) {
                    immutable(string[]) ret = [args[0]];
                } else {
                    static if (args.length > 1) {
                        immutable(string[]) ret = [args[0]] ~ _testMethodsList!(T, args[1..$]).ret;
                    } else {
                        immutable(string[]) ret = [];
                    }
                }
            }
        }
    }

    /**
     * Generates the function that runs a method from its name. 
     */
    private template generateRunTest(T, args...) {
        immutable(string) generateRunTest = 
            T.stringof ~ " testObject = cast("~T.stringof~")o; "
            ~"switch (testName) { "
            ~generateRunTestImpl!(T, args).ret
            ~"    default: break; "
            ~"}";
    }

    /** 
     * Generates the case statements. 
     */
    private template generateRunTestImpl(T, args...) {
        static if (args.length == 0) {
            immutable(string) ret = "";
        } else {
            //Skip method names that don't start with 'test':
            static if (((args[0].length < 4 || args[0][0..4] != "test") 
                && (args[0].length < 5 || args[0][0..5] != "setUp")
                && (args[0].length < 8 || args[0][0..8] != "tearDown")
                && (args[0].length < 10 || args[0][0..10] != "setUpClass")
                && (args[0].length < 13 || args[0][0..13] != "tearDownClass"))
                || !(__traits(compiles, mixin("(new " ~ T.stringof ~ "())." ~ args[0] ~ "()")) ))
            {
                static if (args.length == 1) {
                    immutable(string) ret = "";
                } else {
                    immutable(string) ret = generateRunTestImpl!(T, args[1..$]).ret;
                }
            } else {

                //Create the case statement that calls that test:
                static if (args.length == 1) {
                    immutable(string) ret = 
                        "case \"" ~ args[0] ~ "\": testObject." ~ args[0] ~ "(); break; ";
                } else {
                    immutable(string) ret = 
                        "case \"" ~ args[0] ~ "\": testObject." ~ args[0] ~ "(); break; "
                        ~ generateRunTestImpl!(T, args[1..$]).ret;
                }
            }
        }
    }

    private static void _testClass_() {
    }
}
