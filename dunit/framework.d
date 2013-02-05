/**
 * Unit testing framework ('dunit')
 *
 * Allows to define unittests simply as methods which names start
 * with 'test'.
 * The only thing necessary to create a unit test class, is to
 * declare the mixin TestMixin inside the class. This will register
 * the class and its test methods for the test runner.
 */

//          Copyright Juan Manuel Cabo 2012.
//          Copyright Mario Kröplin 2013.
// Distributed under the Boost Software License, Version 1.0.
//    (See accompanying file LICENSE_1_0.txt or copy at
//          http://www.boost.org/LICENSE_1_0.txt)

module dunit.framework;

public import dunit.assertion;
import std.algorithm;
import std.conv;
import std.getopt;
import std.regex;
import std.stdio;
import core.time;


string[] testClasses;
string[][string] testNamesByClass;
void function(Object o, string testName)[string] testCallers;
Object function()[string] testCreators;


mixin template DUnitMain() {
    int main (string[] args) {
        return dunit_main(args);
    }
}

public int dunit_main(string[] args)
{
    string[] filters = null;
    bool verbose = false;

    getopt(args, "filter|f", &filters, "verbose|v", &verbose);

    string[][string] pickedTestNamesByClass = null;

    if (filters is null)
    {
        filters = [null];
    }
    foreach (className; testNamesByClass.keys)
    {
        foreach (testName; testNamesByClass[className])
        {
            string fullyQualifiedName = className ~ '.' ~ testName;

            foreach (filter; filters)
            {
                if (match(fullyQualifiedName, filter))
                {
                    pickedTestNamesByClass[className] ~= testName;
                    break;
                }
            }
        }
    }
    if (verbose)
    {
        return runTests_Tree(pickedTestNamesByClass);
    }
    else
    {
        return runTests_Progress(pickedTestNamesByClass);
    }    
}

/**
 * Runs all the unit tests.
 */
public static int runTests() {
    return runTests_Progress(testNamesByClass);
}

/**
 * Runs all the unit tests, showing progress dots, and the results at the end.
 */
public static int runTests_Progress(string[][string] testNamesByClass) {
    struct TestError {
        string testClass;
        string testName;
        Throwable error;
        bool isAssertError;

        this(string tc, string tn, Throwable er) {
            this.testClass = tc;
            this.testName = tn;
            this.error = er;
            this.isAssertError = (typeid(er) is typeid(core.exception.AssertError));
        }
    }

    TestError[] errors;
    int testsRun = 0;

    foreach (string className; testNamesByClass.keys) {
        //Create the class:
        Object testObject = null;
        try {
            testObject = testCreators[className]();
        } catch (Throwable t) {
            errors ~= TestError(className, "CONSTRUCTOR", t);
            printF();
        }
        if (testObject is null) {
            continue;
        }

        //setUpClass
        try {
            testCallers[className](testObject, "setUpClass");
        } catch (Throwable t) {
            errors ~= TestError(className, "setUpClass", t);
        }

        //Run each test of the class:
        foreach (string testName; testNamesByClass[className]) {
            ++testsRun;

            printDot();

            //setUp
            bool setUpOk = false;
            bool allOk = true;
            try {
                testCallers[className](testObject, "setUp");
                setUpOk = true;
            } catch (Throwable t) {
                errors ~= TestError(className, "setUp", t);
                printF();
            }
            if (!setUpOk) {
                continue;
            }

            //test
            try {
                testCallers[className](testObject, testName);
            } catch (Throwable t) {
                errors ~= TestError(className, testName, t);
                allOk = false;
            }

            //tearDown (call anyways if test failed)
            try {
                testCallers[className](testObject, "tearDown");
            } catch (Throwable t) {
                errors ~= TestError(className, "tearDown", t);
                allOk = false;
            }

            if (!allOk) {
                printF();
            }
        }

        //tearDownClass
        try {
            testCallers[className](testObject, "tearDownClass");
        } catch (Throwable t) {
            errors ~= TestError(className, "tearDownClass", t);
        }
    }
    
    /* Count how many problems where asserts, and how many other exceptions. 
     */
    int failedCount = 0;
    int errorCount = 0;
    foreach (TestError te; errors) {
        if (te.isAssertError) {
            ++failedCount;
        } else {
            ++errorCount;
        }
    }

    /* Display results
     */
    writeln();
    if (failedCount == 0 && errorCount == 0) {
        writeln();
        printOk();
        writefln(" (%d Test%s)", testsRun, ((testsRun == 1) ? "" : "s"));
        return 0;
    }
    /* Errors
     */
    if (errorCount != 0) {
        if (errorCount == 1) {
            writeln("There was 1 error:");
        } else {
            writefln("There were %d errors:", errorCount);
        }
        int i = 0;
        foreach (TestError te; errors) {
            //Errors are any exception except AssertError;
            if (te.isAssertError) {
                continue;
            }
            Throwable t = te.error;
            writefln("%d) %s(%s)%s@%s(%d): %s", ++i, 
                    te.testName, te.testClass,
                    typeid(t).name, t.file, t.line, t.msg);
        }
    }
    /* Failures
     */
    if (failedCount != 0) {
        if (failedCount == 1) {
            writeln("There was 1 failure:");
        } else {
            writefln("There were %d failures:", failedCount);
        }
        int i = 0;
        foreach (TestError te; errors) {
            //Failures are only AssertError exceptions.
            if (!te.isAssertError) {
                continue;
            }
            Throwable t = te.error;
            writefln("%d) %s(%s)%s@%s(%d): %s", ++i, 
                    te.testName, te.testClass,
                    typeid(t).name, t.file, t.line, t.msg);
        }
    }

    writeln();
    printFailures();
    writefln("Tests run: %d,  Failures: %d,  Errors: %d", testsRun, failedCount, errorCount);
    return (errorCount > 0) ? 2 : (failedCount > 0) ? 1 : 0;
}

version (Posix) {
    private static bool _useColor = false;
    private static bool _useColorWasComputed = false;
    private static bool canUseColor() {
        if (!_useColorWasComputed) {
            //Disable colors if the results output is written 
            //to a file or pipe instead of a tty:
            import core.sys.posix.unistd;
            _useColor = (isatty(stdout.fileno()) != 0);
            _useColorWasComputed = true;
        }
        return _useColor;
    }

    private static void startColorGreen() {
        if (canUseColor()) {
            write("\x1B[1;37;42m"); stdout.flush();
        }
    }
    private static void startColorRed() {
        if (canUseColor()) {
            write("\x1B[1;37;41m"); stdout.flush();
        }
    }
    private static void endColors() {
        if (canUseColor()) {
            write("\x1B[0;;m"); stdout.flush();
        }
    }
} else {
    private static void startColorGreen() {
    }
    private static void startColorRed() {
    }
    private static void endColors() {
    }
}

private static void printDot() {
    startColorGreen();
    write("."); stdout.flush();
    endColors();
}
private static void printF() {
    startColorRed();
    write("F"); stdout.flush();
    endColors();
}
private static void printOk() {
    startColorGreen();
    write("OK");
    endColors();
}
private static void printFailures() {
    startColorRed();
    write("FAILURES!!!");
    endColors();
    writeln();
}

/**
 * Runs all the unit tests, showing the test tree as the tests run.
 */
public static int runTests_Tree(string[][string] testNamesByClass) {
    // FIXME runTests_Progress reports an error for any Throwable that is not an AssertError
    // FIXME runTests_Tree reports an error for any Throwable thrown by the test fixture
    int failedCount = 0;
    int errorCount = 0;

    //List Test classes:
    writeln("Unit tests: ");
    foreach (string className; testNamesByClass.keys) {
        writeln("    " ~ className);

        //Create the class:
        Object testObject = null;
        try {
            testObject = testCreators[className]();
        } catch (Throwable t) {
            writefln("        ERROR IN CONSTRUCTOR: " ~ className ~ ".this(): " 
                    ~ "(): %s@%s(%d): %s", typeid(t).name, t.file, t.line, t.msg);
            ++errorCount;
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
            ++errorCount;
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
                ++errorCount;
            }
            if (!setUpOk) {
                continue;
            }

            //test
            try {
                TickDuration startTime = TickDuration.currSystemTick();
                testCallers[className](testObject, testName);
                double elapsedMs = (TickDuration.currSystemTick() - startTime).usecs() / 1000.0;
                writefln("        OK: %6.2f ms  %s()", elapsedMs, testName);
            } catch (Throwable t) {
                writefln("        FAILED: " ~ testName 
                    ~ "(): %s@%s(%d): %s", typeid(t).name, t.file, t.line, t.msg);
                ++failedCount;
            }

            //tearDown (call anyways if test failed)
            try {
                testCallers[className](testObject, "tearDown");
            } catch (Throwable t) {
                writefln("        ERROR: tearDown" 
                    ~ "(): %s@%s(%d): %s", typeid(t).name, t.file, t.line, t.msg);
                ++errorCount;
            }
        }

        //tearDownClass
        try {
            testCallers[className](testObject, "tearDownClass");
        } catch (Throwable t) {
            writefln("        ERROR IN tearDownClass: " ~ className ~ ".tearDownClass(): " 
                    ~ "(): %s@%s(%d): %s", typeid(t).name, t.file, t.line, t.msg);
            ++errorCount;
        }
    }
    return (errorCount > 0) ? 2 : (failedCount > 0) ? 1 : 0;
}


/**
 * Registers a class as a unit test.
 */
mixin template TestMixin() {
    public static this() {
        //Names of test methods:
        immutable(string[]) _testMethods = _testMethodsList!(
                typeof(this), 
                __traits(allMembers, typeof(this))
        ).ret;

        //Factory method:
        static Object createFunction() { 
            mixin("return (new " ~ typeof(this).stringof ~ "());");
        }

        //Run method:
        //Generate a switch statement, that calls the method that matches the testName:
        static void runTest(Object o, string testName) {
            mixin(
                generateRunTest!(typeof(this),
                                 __traits(allMembers, typeof(this)))
            );
        }

        //Register UnitTest class:
        string className = this.classinfo.name;
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
            static if (!startsWith(args[0], "test")
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
            static if (!(startsWith(args[0], "test")
                || args[0] == "setUp" || args[0] == "tearDown"
                || args[0] == "setUpClass" || args[0] == "tearDownClass")
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
}
