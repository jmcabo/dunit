//          Copyright Juan Manuel Cabo 2012.
//          Copyright Mario Kröplin 2013.
// Distributed under the Boost Software License, Version 1.0.
//    (See accompanying file LICENSE_1_0.txt or copy at
//          http://www.boost.org/LICENSE_1_0.txt)

module dunit.framework;

public import dunit.assertion;
public import dunit.attributes;

import core.time;
import std.algorithm;
import std.array;
import std.conv;
import std.getopt;
import std.regex;
import std.stdio;
public import std.typetuple;  // FIXME

struct TestClass
{
    string[] tests;
    string[] ignoredTests;

    Object function() create;
    void function(Object o) beforeClass;
    void function(Object o) before;
    void function(Object o, string testName) test;
    void function(Object o) after;
    void function(Object o) afterClass;
}

string[] testClassOrder;
TestClass[string] testClasses;

mixin template Main()
{
    int main (string[] args)
    {
        return dunit_main(args);
    }
}

public int dunit_main(string[] args)
{
    string[] filters = null;
    bool help = false;
    bool list = false;
    bool verbose = false;

    getopt(args,
            "filter|f", &filters,
            "help|h", &help,
            "list|l", &list,
            "verbose|v", &verbose);

    if (help)
    {
        // TODO display usage
        return 0;
    }

    string[][string] selectedTestNamesByClass = null;

    if (filters is null)
        filters = [null];

    foreach (filter; filters)
    {
        foreach (className; testClassOrder)
        {
            foreach (testName; testClasses[className].tests)
            {
                string fullyQualifiedName = className ~ '.' ~ testName;

                if (match(fullyQualifiedName, filter))
                    selectedTestNamesByClass[className] ~= testName;
            }
        }
    }

    if (list)
    {
        foreach (className; testClassOrder)
        {
            foreach (testName; selectedTestNamesByClass.get(className, null))
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

    foreach (className; testClassOrder)
    {
        if (className !in testNamesByClass)
            continue;

        // create test object
        Object testObject = null;

        try
        {
            testObject = testClasses[className].create();
        }
        catch (AssertException exception)
        {
            failures ~= Entry(className, "this", exception);
            write(red("F"));
            stdout.flush();
        }
        catch (Throwable throwable)
        {
            errors ~= Entry(className, "this", throwable);
            write(red("E"));
            stdout.flush();
        }

        if (testObject is null)
            continue;

        // setUpClass
        try
        {
            testClasses[className].beforeClass(testObject);
        }
        catch (AssertException exception)
        {
            failures ~= Entry(className, "beforeClass", exception);
            continue;
        }
        catch (Throwable throwable)
        {
            errors ~= Entry(className, "beforeClass", throwable);
            continue;
        }

        // run each test function of the class
        foreach (testName; testNamesByClass[className])
        {
            if (canFind(testClasses[className].ignoredTests, testName))
            {
                write(yellow("I"));
                stdout.flush();
                continue;
            }

            ++count;

            // setUp
            bool success = true;

            try
            {
                testClasses[className].before(testObject);
            }
            catch (AssertException exception)
            {
                failures ~= Entry(className, "before", exception);
                write(red("F"));
                stdout.flush();
                continue;
            }
            catch (Throwable throwable)
            {
                errors ~= Entry(className, "before", throwable);
                write(red("E"));
                stdout.flush();
                continue;
            }

            // test
            try
            {
                testClasses[className].test(testObject, testName);
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
                testClasses[className].after(testObject);
            }
            catch (AssertException exception)
            {
                failures ~= Entry(className, "after", exception);
                success = false;
            }
            catch (Throwable throwable)
            {
                errors ~= Entry(className, "after", throwable);
                success = false;
            }

            if (success)
                write(green("."));
            else
                write(red("F"));  // FIXME or "E"?
            stdout.flush();
        }

        // tearDownClass
        try
        {
            testClasses[className].afterClass(testObject);
        }
        catch (AssertException exception)
        {
            failures ~= Entry(className, "afterClass", exception);
        }
        catch (Throwable throwable)
        {
            errors ~= Entry(className, "afterClass", throwable);
        }
    }

    // report results
    writeln();
    if (failures.empty && errors.empty)
    {
        writeln();
        writefln("%s (%d %s)", green("OK"), count, (count == 1) ? "Test" : "Tests");
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

            writefln("%d) %s(%s) %s", i + 1,
                    entry.testName, entry.testClass, throwable.toString);
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

            writefln("%d) %s(%s) %s@%s(%d): %s", i + 1,
                    entry.testName, entry.testClass, typeid(throwable).name,
                    throwable.file, throwable.line, throwable.msg);
        }
    }

    writeln();
    writeln(red("NOT OK"));
    // FIXME Ignored
    writefln("Tests run: %d, Failures: %d, Errors: %d", count, failures.length, errors.length);
    return (errors.length > 0) ? 2 : (failures.length > 0) ? 1 : 0;
}

version (Posix)
{
    private static string CSI = "\x1B[";

    private static string red(string source)
    {
        return canUseColor() ? CSI ~ "37;41;1m" ~ source ~ CSI ~ "0m" : source;
    }

    private static string green(string source)
    {
        return canUseColor() ? CSI ~ "37;42;1m" ~ source ~ CSI ~ "0m" : source;
    }

    private static string yellow(string source)
    {
        return canUseColor() ? CSI ~ "37;43;1m" ~ source ~ CSI ~ "0m" : source;
    }

    private static bool canUseColor()
    {
        static bool useColor = false;
        static bool computed = false;

        if (!computed)
        {
            // disable colors if the results output is written to a file or pipe instead of a tty
            import core.sys.posix.unistd;

            useColor = isatty(stdout.fileno()) != 0;
            computed = true;
        }
        return useColor;
    }
}
else
{
    private static string red(string source)
    {
        return source;
    }

    private static string green(string source)
    {
        return source;
    }

    private static string yellow(string source)
    {
        return source;
    }
}

/**
 * Runs all the unit tests, showing the test tree as the tests run.
 */
public static int runTests_Tree(string[][string] testNamesByClass)
{
    int failureCount = 0;
    int errorCount = 0;

    writeln("Unit tests: ");
    foreach (className; testClassOrder)
    {
        if (className !in testNamesByClass)
            continue;

        writeln("    ", className);

        // create test object
        Object testObject = null;

        try
        {
            testObject = testClasses[className].create();
        }
        catch (AssertException exception)
        {
            writefln("        FAILURE: this(): %s@%s(%d): %s",
                    typeid(exception).name, exception.file, exception.line, exception.msg);
            ++failureCount;
        }
        catch (Throwable throwable)
        {
            writeln("        ERROR: this(): ", throwable.toString);
            ++errorCount;
        }
        if (testObject is null)
            continue;

        // setUpClass
        try
        {
            testClasses[className].beforeClass(testObject);
        }
        catch (AssertException exception)
        {
            writefln("        FAILURE: beforeClass(): %s@%s(%d): %s",
                    typeid(exception).name, exception.file, exception.line, exception.msg);
            ++failureCount;
            continue;
        }
        catch (Throwable throwable)
        {
            writeln("        ERROR: beforeClass(): ", throwable.toString);
            ++errorCount;
            continue;
        }

        // Run each test of the class:
        foreach (testName; testNamesByClass[className])
        {
            if (canFind(testClasses[className].ignoredTests, testName))
            {
                writeln("        IGNORE: ", testName, "()");
                continue;
            }

            // setUp
            try
            {
                testClasses[className].before(testObject);
            }
            catch (AssertException exception)
            {
                writefln("        FAILURE: before(): %s@%s(%d): %s",
                        typeid(exception).name, exception.file, exception.line, exception.msg);
                ++failureCount;
                continue;
            }
            catch (Throwable throwable)
            {
                writeln("        ERROR: before(): ", throwable.toString);
                ++errorCount;
                continue;
            }

            // test
            try
            {
                TickDuration startTime = TickDuration.currSystemTick();
                testClasses[className].test(testObject, testName);
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
                writeln("        ERROR: ", testName, "(): ", throwable.toString);
                ++errorCount;
            }

            // tearDown (call anyways if test failed)
            try
            {
                testClasses[className].after(testObject);
            }
            catch (AssertException exception)
            {
                writefln("        FAILURE: after(): %s@%s(%d): %s",
                        typeid(exception).name, exception.file, exception.line, exception.msg);
                ++failureCount;
            }
            catch (Throwable throwable)
            {
                writeln("        ERROR: after(): ", throwable.toString);
                ++errorCount;
            }
        }

        // tearDownClass
        try
        {
            testClasses[className].afterClass(testObject);
        }
        catch (AssertException exception)
        {
            writefln("        FAILURE: afterClass(): %s@%s(%d): %s",
                    typeid(exception).name, exception.file, exception.line, exception.msg);
            ++failureCount;
        }
        catch (Throwable throwable)
        {
            writeln("        ERROR: afterClass(): ", throwable.toString);
            ++errorCount;
        }
    }
    return (errorCount > 0) ? 2 : (failureCount > 0) ? 1 : 0;
}

/**
 * Registers a class as a unit test.
 */
mixin template UnitTest()
{

    public static this()
    {
        TestClass testClass;

        testClass.tests = _memberFunctions!(typeof(this), Test,
                __traits(allMembers, typeof(this))).result.dup;
        testClass.ignoredTests = _memberFunctions!(typeof(this), Ignore,
                __traits(allMembers, typeof(this))).result.dup;

        static Object create()
        {
            mixin("return new " ~ typeof(this).stringof ~ "();");
        }

        static void beforeClass(Object o)
        {
            mixin(_sequence(_memberFunctions!(typeof(this), BeforeClass,
                    __traits(allMembers, typeof(this))).result));
        }

        static void before(Object o)
        {
            mixin(_sequence(_memberFunctions!(typeof(this), Before,
                    __traits(allMembers, typeof(this))).result));
        }

        static void test(Object o, string name)
        {
            mixin(_choice(_memberFunctions!(typeof(this), Test,
              __traits(allMembers, typeof(this))).result));
        }

        static void after(Object o)
        {
            mixin(_sequence(_memberFunctions!(typeof(this), After,
                    __traits(allMembers, typeof(this))).result));
        }

        static void afterClass(Object o)
        {
            mixin(_sequence(_memberFunctions!(typeof(this), AfterClass,
                    __traits(allMembers, typeof(this))).result));
        }

        testClass.create = &create;
        testClass.beforeClass = &beforeClass;
        testClass.before = &before;
        testClass.test = &test;
        testClass.after = &after;
        testClass.afterClass = &afterClass;

        testClassOrder ~= this.classinfo.name;
        testClasses[this.classinfo.name] = testClass;
    }

    private static string _choice(const string[] memberFunctions)
    {
        string block = "auto testObject = cast(" ~ typeof(this).stringof ~ ") o;\n";

        block ~= "switch (name)\n{\n";
        foreach (memberFunction; memberFunctions)
        {
            block ~= `case "` ~ memberFunction ~ `": testObject.` ~ memberFunction ~ "(); break;\n";
        }
        block ~= "default: break;\n}\n";
        return block;
    }

    private static string _sequence(const string[] memberFunctions)
    {
        string block = "auto testObject = cast(" ~ typeof(this).stringof ~ ") o;\n";

        foreach (memberFunction; memberFunctions)
        {
            block ~= "testObject." ~ memberFunction ~ "();\n";
        }
        return block;
    }

    private template _memberFunctions(alias T, alias U, names...)
    {
        static if (names.length == 0)
        {
            immutable(string[]) result = [];
        }
        else
        {
            static if (_hasAttribute!(T, names[0], U) && __traits(compiles,
                    mixin("(new " ~ T.stringof ~ "())." ~ names[0] ~ "()")))
            {
                immutable(string[]) result = [names[0]] ~ _memberFunctions!(T, U, names[1 .. $]).result;
            }
            else
            {
                immutable(string[]) result = _memberFunctions!(T, U, names[1 .. $]).result;
            }
        }
    }

    template _hasAttribute(alias T, string name, attribute)
    {
        enum _hasAttribute = staticIndexOf!(attribute,
                __traits(getAttributes, __traits(getMember, T, name))) != -1;
    }

}
