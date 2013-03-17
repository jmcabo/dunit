/**
 * xUnit Testing Framework for the D Programming Language - framework
 */

//          Copyright Juan Manuel Cabo 2012.
//          Copyright Mario Kröplin 2013.
// Distributed under the Boost Software License, Version 1.0.
//    (See accompanying file LICENSE_1_0.txt or copy at
//          http://www.boost.org/LICENSE_1_0.txt)

module dunit.framework;

public import dunit.assertion;

import core.time;
import std.algorithm;
import std.array;
import std.conv;
import std.getopt;
import std.regex;
import std.stdio;

string[] testClasses;
string[][string] testNamesByClass;
void function(Object o, string testName)[string] testCallers;
Object function()[string] testCreators;

mixin template DUnitMain()
{
    int main (string[] args)
    {
        return dunit_main(args);
    }
}

public int dunit_main(string[] args)
{
    string[] filters = null;
    bool list = false;
    bool verbose = false;

    getopt(args, "filter|f", &filters, "list|l", &list, "verbose|v", &verbose);

    string[][string] selectedTestNamesByClass = null;

    if (filters is null)
        filters = [null];

    foreach (className; testNamesByClass.byKey)
    {
        foreach (testName; testNamesByClass[className])
        {
            string fullyQualifiedName = className ~ '.' ~ testName;

            foreach (filter; filters)
            {
                if (match(fullyQualifiedName, filter))
                {
                    selectedTestNamesByClass[className] ~= testName;
                    break;
                }
            }
        }
    }

    if (list)
    {
        foreach (className; selectedTestNamesByClass.byKey)
        {
            foreach (testName; selectedTestNamesByClass[className])
            {
                string fullyQualifiedName = className ~ '.' ~ testName;

                writeln(fullyQualifiedName);
            }
        }
        return 0;
    }

    if (verbose)
        return runTests_Tree(selectedTestNamesByClass);
    else
        return runTests_Progress(selectedTestNamesByClass);
}

/**
 * Runs all the unit tests.
 */
public static int runTests()
{
    return runTests_Progress(testNamesByClass);
}

/**
 * Runs all the unit tests, showing progress dots, and the results at the end.
 */
public static int runTests_Progress(string[][string] testNamesByClass)
{
    struct Entry
    {
        string testClass;
        string testName;
        Throwable throwable;

        this(string testClass, string testName, Throwable throwable)
        {
            this.testClass = testClass;
            this.testName = testName;
            this.throwable = throwable;
        }
    }

    Entry[] failures = null;
    Entry[] errors = null;
    int count = 0;

    foreach (string className; testNamesByClass.byKey)
    {
        // create test object
        Object testObject = null;

        try
        {
            testObject = testCreators[className]();
        }
        catch (AssertException exception)
        {
            failures ~= Entry(className, "this", exception);
            printF();
        }
        catch (Throwable throwable)
        {
            errors ~= Entry(className, "this", throwable);
            printF();
        }

        if (testObject is null)
            continue;

        // setUpClass
        try
        {
            testCallers[className](testObject, "setUpClass");
        }
        catch (AssertException exception)
        {
            failures ~= Entry(className, "setUpClass", exception);
            continue;
        }
        catch (Throwable throwable)
        {
            errors ~= Entry(className, "setUpClass", throwable);
            continue;
        }

        // run each test function of the class
        foreach (string testName; testNamesByClass[className])
        {
            ++count;

            // setUp
            bool success = true;

            try
            {
                testCallers[className](testObject, "setUp");
            }
            catch (AssertException exception)
            {
                failures ~= Entry(className, "setUp", exception);
                printF();
                continue;
            }
            catch (Throwable throwable)
            {
                errors ~= Entry(className, "setUp", throwable);
                printF();
                continue;
            }

            // test
            try
            {
                testCallers[className](testObject, testName);
            }
            catch (AssertException exception)
            {
                failures ~= Entry(className, testName, exception);
                success = false;
            }
            catch (Throwable throwable)
            {
                errors ~= Entry(className, testName, throwable);
                success = false;
            }

            // tearDown (even if test failed)
            try
            {
                testCallers[className](testObject, "tearDown");
            }
            catch (AssertException exception)
            {
                failures ~= Entry(className, "tearDown", exception);
                success = false;
            }
            catch (Throwable throwable)
            {
                errors ~= Entry(className, "tearDown", throwable);
                success = false;
            }

            if (success)
                printDot();
            else
                printF();
        }

        // tearDownClass
        try
        {
            testCallers[className](testObject, "tearDownClass");
        }
        catch (AssertException exception)
        {
            failures ~= Entry(className, "tearDownClass", exception);
        }
        catch (Throwable throwable)
        {
            errors ~= Entry(className, "tearDownClass", throwable);
        }
    }
    
    // report results
    writeln();
    if (failures.empty && errors.empty)
    {
        writeln();
        printOk();
        writefln(" (%d %s)", count, (count == 1) ? "Test" : "Tests");
        return 0;
    }

    // report errors
    if (!errors.empty)
    {
        if (errors.length == 1)
            writeln("There was 1 error:");
        else
            writefln("There were %d errors:", errors.length);

        foreach (i, entry; errors)
        {
            Throwable throwable = entry.throwable;

            writefln("%d) %s(%s)%s@%s(%d): %s", i + 1, 
                    entry.testName, entry.testClass, typeid(throwable).name,
                    throwable.file, throwable.line, throwable.toString);
        }
    }

    // report failures
    if (!failures.empty)
    {
        if (failures.length == 1)
            writeln("There was 1 failure:");
        else
            writefln("There were %d failures:", failures.length);

        foreach (i, entry; failures)
        {
            Throwable throwable = entry.throwable;

            writefln("%d) %s(%s)%s@%s(%d): %s", i + 1, 
                    entry.testName, entry.testClass, typeid(throwable).name,
                    throwable.file, throwable.line, throwable.msg);
        }
    }

    writeln();
    printFailures();
    writefln("Tests run: %d,  Failures: %d,  Errors: %d", count, failures.length, errors.length);
    return (errors.length > 0) ? 2 : (failures.length > 0) ? 1 : 0;
}

version (Posix)
{
    private static bool _useColor = false;

    private static bool _useColorWasComputed = false;

    private static bool canUseColor()
    {
        if (!_useColorWasComputed)
        {
            // disable colors if the results output is written to a file or pipe instead of a tty
            import core.sys.posix.unistd;

            _useColor = (isatty(stdout.fileno()) != 0);
            _useColorWasComputed = true;
        }
        return _useColor;
    }

    private static void startColorGreen()
    {
        if (canUseColor())
        {
            write("\x1B[1;37;42m");
            stdout.flush();
        }
    }

    private static void startColorRed()
    {
        if (canUseColor())
        {
            write("\x1B[1;37;41m");
            stdout.flush();
        }
    }

    private static void endColors()
    {
        if (canUseColor())
        {
            write("\x1B[0;;m");
            stdout.flush();
        }
    }
}
else
{
    private static void startColorGreen()
    {
    }

    private static void startColorRed()
    {
    }

    private static void endColors()
    {
    }
}

private static void printDot()
{
    startColorGreen();
    write(".");
    stdout.flush();
    endColors();
}

private static void printF()
{
    startColorRed();
    write("F");
    stdout.flush();
    endColors();
}
private static void printOk()
{
    startColorGreen();
    write("OK");
    endColors();
}

private static void printFailures()
{
    startColorRed();
    write("FAILURES!!!");
    endColors();
    writeln();
}

/**
 * Runs all the unit tests, showing the test tree as the tests run.
 */
public static int runTests_Tree(string[][string] testNamesByClass)
{
    int failureCount = 0;
    int errorCount = 0;

    writeln("Unit tests: ");
    foreach (string className; testNamesByClass.byKey)
    {
        writeln("    " ~ className);

        // create test object
        Object testObject = null;

        try
        {
            testObject = testCreators[className]();
        }
        catch (AssertException exception)
        {
            writefln("        FAILURE: this(): %s@%s(%d): %s",
                    typeid(exception).name, exception.file, exception.line, exception.msg);
            ++failureCount;
        }
        catch (Throwable throwable)
        {
            writefln("        ERROR: this(): %s@%s(%d): %s",
                    typeid(throwable).name, throwable.file, throwable.line, throwable.toString);
            ++errorCount;
        }
        if (testObject is null)
            continue;

        // setUpClass
        try
        {
            testCallers[className](testObject, "setUpClass");
        }
        catch (AssertException exception)
        {
            writefln("        FAILURE: setUpClass(): %s@%s(%d): %s",
                    typeid(exception).name, exception.file, exception.line, exception.msg);
            ++failureCount;
            continue;
        }
        catch (Throwable throwable)
        {
            writefln("        ERROR: setUpClass(): %s@%s(%d): %s",
                    typeid(throwable).name, throwable.file, throwable.line, throwable.toString);
            ++errorCount;
            continue;
        }

        // Run each test of the class:
        foreach (string testName; testNamesByClass[className])
        {
            // setUp
            try
            {
                testCallers[className](testObject, "setUp");
            }
            catch (AssertException exception)
            {
                writefln("        FAILURE: setUp(): %s@%s(%d): %s",
                        typeid(exception).name, exception.file, exception.line, exception.msg);
                ++failureCount;
                continue;
            }
            catch (Throwable throwable)
            {
                writefln("        ERROR: setUp(): %s@%s(%d): %s",
                        typeid(throwable).name, throwable.file, throwable.line, throwable.toString);
                ++errorCount;
                continue;
            }

            // test
            try
            {
                TickDuration startTime = TickDuration.currSystemTick();
                testCallers[className](testObject, testName);
                double elapsedMs = (TickDuration.currSystemTick() - startTime).usecs() / 1000.0;
                writefln("        OK: %6.2f ms  %s()", elapsedMs, testName);
            }
            catch (AssertException exception)
            {
                writefln("        FAILURE: " ~ testName ~ "(): %s@%s(%d): %s",
                        typeid(exception).name, exception.file, exception.line, exception.msg);
                ++failureCount;
            }
            catch (Throwable throwable)
            {
                writefln("        ERROR: " ~ testName ~ "(): %s@%s(%d): %s",
                        typeid(throwable).name, throwable.file, throwable.line, throwable.toString);
                ++errorCount;
            }

            // tearDown (call anyways if test failed)
            try
            {
                testCallers[className](testObject, "tearDown");
            }
            catch (AssertException exception)
            {
                writefln("        FAILURE: tearDown(): %s@%s(%d): %s",
                        typeid(exception).name, exception.file, exception.line, exception.msg);
                ++failureCount;
            }
            catch (Throwable throwable)
            {
                writefln("        ERROR: tearDown(): %s@%s(%d): %s",
                        typeid(throwable).name, throwable.file, throwable.line, throwable.toString);
                ++errorCount;
            }
        }

        // tearDownClass
        try
        {
            testCallers[className](testObject, "tearDownClass");
        }
        catch (AssertException exception)
        {
            writefln("        FAILURE: tearDownClass(): %s@%s(%d): %s",
                    typeid(exception).name, exception.file, exception.line, exception.msg);
            ++failureCount;
        }
        catch (Throwable throwable)
        {
            writefln("        ERROR: tearDownClass(): %s@%s(%d): %s",
                    typeid(throwable).name, throwable.file, throwable.line, throwable.toString);
            ++errorCount;
        }
    }
    return (errorCount > 0) ? 2 : (failureCount > 0) ? 1 : 0;
}


/**
 * Registers a class as a unit test.
 */
mixin template TestMixin()
{

    public static this()
    {
        // Names of test methods:
        immutable(string[]) _testMethods = _testMethodsList!(
                typeof(this), 
                __traits(allMembers, typeof(this))
        ).ret;

        // Factory method:
        static Object createFunction()
        { 
            mixin("return (new " ~ typeof(this).stringof ~ "());");
        }

        // Run method:
        // Generate a switch statement, that calls the method that matches the testName:
        static void runTest(Object o, string testName)
        {
            mixin(
                generateRunTest!(typeof(this), __traits(allMembers, typeof(this)))
            );
        }

        // Register UnitTest class:
        string className = this.classinfo.name;
        testClasses ~= className;
        testNamesByClass[className] = _testMethods.dup;
        testCallers[className] = &runTest;
        testCreators[className] = &createFunction;
    }
 
    private template _testMethodsList(T, args...)
    {
        static if (args.length == 0)
        {
            immutable(string[]) ret = [];
        }
        else
        {
            // Skip strings that don't start with "test":
            static if (args[0].length < 4 || args[0][0 .. 4] != "test"
                || !(__traits(compiles, mixin("(new " ~ T.stringof ~ "())." ~ args[0] ~ "()")) ))
            {
                static if(args.length == 1)
                {
                    immutable(string[]) ret = [];
                }
                else
                {
                    immutable(string[]) ret = _testMethodsList!(T, args[1..$]).ret;
                }
            }
            else
            {
                // Return the first argument and the rest:
                static if (args.length == 1)
                {
                    immutable(string[]) ret = [args[0]];
                }
                else
                {
                    static if (args.length > 1)
                    {
                        immutable(string[]) ret = [args[0]] ~ _testMethodsList!(T, args[1..$]).ret;
                    }
                    else
                    {
                        immutable(string[]) ret = [];
                    }
                }
            }
        }
    }

    /**
     * Generates the function that runs a method from its name. 
     */
    private template generateRunTest(T, args...)
    {
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
    private template generateRunTestImpl(T, args...)
    {
        static if (args.length == 0)
        {
            immutable(string) ret = "";
        }
        else
        {
            static if (!(args[0].length >= 4 && args[0][0 .. 4] == "test"
                || args[0] == "setUp" || args[0] == "tearDown"
                || args[0] == "setUpClass" || args[0] == "tearDownClass")
                || !(__traits(compiles, mixin("(new " ~ T.stringof ~ "())." ~ args[0] ~ "()")) ))
            {
                static if (args.length == 1)
                {
                    immutable(string) ret = "";
                }
                else
                {
                    immutable(string) ret = generateRunTestImpl!(T, args[1..$]).ret;
                }
            }
            else
            {
                // Create the case statement that calls that test:
                static if (args.length == 1)
                {
                    immutable(string) ret = 
                        "case \"" ~ args[0] ~ "\": testObject." ~ args[0] ~ "(); break; ";
                }
                else
                {
                    immutable(string) ret = 
                        "case \"" ~ args[0] ~ "\": testObject." ~ args[0] ~ "(); break; "
                        ~ generateRunTestImpl!(T, args[1..$]).ret;
                }
            }
        }
    }
}
