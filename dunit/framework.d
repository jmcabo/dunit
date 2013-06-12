//          Copyright Juan Manuel Cabo 2012.
//          Copyright Mario Kröplin 2013.
// Distributed under the Boost Software License, Version 1.0.
//    (See accompanying file LICENSE_1_0.txt or copy at
//          http://www.boost.org/LICENSE_1_0.txt)

module dunit.framework;

public import dunit.assertion;
public import dunit.attributes;
import dunit.color;

import core.time;
import std.algorithm;
import std.array;
import std.conv;
import std.getopt;
import std.path;
import std.regex;
import std.stdio;
public import std.typetuple;

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
        writefln("Usage: %s [options]", args.empty ? "testrunner" : baseName(args[0]));
        writeln("Run the functions with @Test attribute of all classes that mix in UnitTest.");
        writeln();
        writeln("Options:");
        writeln("  -f, --filter REGEX    Select test functions matching the regular expression");
        writeln("                        Multiple selections are processed in sequence");
        writeln("  -h, --help            Display usage information, then exit");
        writeln("  -l, --list            Display the test functions, then exit");
        writeln("  -v, --verbose         Display more information as the tests are run");
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

    int result = 0;

    if (verbose)
    {
        auto reporter = new DetailReporter();

        result = runTests(selectedTestNamesByClass, reporter);
    }
    else
    {
        auto reporter = new ResultReporter();

        result = runTests(selectedTestNamesByClass, reporter);
        reporter.summarize;
    }
    return result;
}

public static int runTests(string[][string] testNamesByClass, TestListener testListener)
in
{
    assert(testListener !is null);
}
body
{
    bool failure = false;
    bool error = false;

    foreach (className; testClassOrder)
    {
        if (className !in testNamesByClass)
            continue;

        testListener.enterClass(className);

        // create test object
        Object testObject = null;

        try
        {
            testObject = testClasses[className].create();
        }
        catch (Throwable throwable)
        {
            testListener.addError("this", throwable);
            error = true;
            continue;
        }

        // set up class
        try
        {
            testClasses[className].beforeClass(testObject);
        }
        catch (AssertException exception)
        {
            testListener.addFailure("@BeforeClass", exception);
            failure = true;
            continue;
        }
        catch (Throwable throwable)
        {
            testListener.addError("@BeforeClass", throwable);
            error = true;
            continue;
        }

        // run each test function of the class
        foreach (testName; testNamesByClass[className])
        {
            if (canFind(testClasses[className].ignoredTests, testName))
            {
                testListener.skipTest(testName);
                continue;
            }

            bool success = true;

            testListener.enterTest(testName);

            // set up
            try
            {
                testClasses[className].before(testObject);
            }
            catch (AssertException exception)
            {
                testListener.addFailure("@Before", exception);
                failure = true;
                success = false;
            }
            catch (Throwable throwable)
            {
                testListener.addError("@Before", throwable);
                error = true;
                success = false;
            }

            if (success)
            {
                // test
                try
                {
                    testClasses[className].test(testObject, testName);
                }
                catch (AssertException exception)
                {
                    testListener.addFailure(testName, exception);
                    failure = true;
                    success = false;
                }
                catch (Throwable throwable)
                {
                    testListener.addError(testName, throwable);
                    error = true;
                    success = false;
                }

                // tear down (even if test failed)
                try
                {
                    testClasses[className].after(testObject);
                }
                catch (AssertException exception)
                {
                    testListener.addFailure("@After", exception);
                    failure = true;
                    success = false;
                }
                catch (Throwable throwable)
                {
                    testListener.addError("@After", throwable);
                    error = true;
                    success = false;
                }
            }
            testListener.exitTest(success);
        }

        // tear down class
        try
        {
            testClasses[className].afterClass(testObject);
        }
        catch (AssertException exception)
        {
            testListener.addFailure("@AfterClass", exception);
            failure = true;
        }
        catch (Throwable throwable)
        {
            testListener.addError("@AfterClass", throwable);
            error = true;
        }
    }

    return error ? 2 : failure ? 1 : 0;
}

interface TestListener
{

    public void enterClass(string className);

    public void enterTest(string testName);

    public void skipTest(string testName);

    public void addFailure(string subject, AssertException exception);

    public void addError(string subject, Throwable throwable);

    public void exitTest(bool success);

}

class ResultReporter : TestListener
{

    private struct Issue
    {
        string testClass;
        string testName;
        Throwable throwable;
    }

    private Issue[] failures = null;

    private Issue[] errors = null;

    private uint count = 0;

    private string className;

    public void enterClass(string className)
    {
        this.className = className;
    }

    public void enterTest(string testName)
    {
        ++this.count;
    }

    public void skipTest(string testName)
    {
        writec(Color.onYellow, "I");
    }

    public void addFailure(string subject, AssertException exception)
    {
        this.failures ~= Issue(this.className, subject, exception);
        writec(Color.onRed, "F");
    }

    public void addError(string subject, Throwable throwable)
    {
        this.errors ~= Issue(this.className, subject, throwable);
        writec(Color.onRed, "E");
    }

    public void exitTest(bool success)
    {
        if (success)
        {
            writec(Color.onGreen, ".");
        }
    }

    public void summarize()
    {
        writeln();

        // report errors
        if (!this.errors.empty)
        {
            writeln();
            if (this.errors.length == 1)
                writeln("There was 1 error:");
            else
                writefln("There were %d errors:", this.errors.length);

            foreach (i, issue; this.errors)
            {
                writefln("%d) %s(%s) %s", i + 1,
                        issue.testName, issue.testClass, issue.throwable.toString);
            }
        }

        // report failures
        if (!this.failures.empty)
        {
            writeln();
            if (this.failures.length == 1)
                writeln("There was 1 failure:");
            else
                writefln("There were %d failures:", this.failures.length);

            foreach (i, issue; this.failures)
            {
                Throwable throwable = issue.throwable;

                writefln("%d) %s(%s) %s@%s(%d): %s", i + 1,
                        issue.testName, issue.testClass, typeid(throwable).name,
                        throwable.file, throwable.line, throwable.msg);
            }
        }

        if (this.failures.empty && this.errors.empty)
        {
            writeln();
            writec(Color.onGreen, "OK");
            writefln(" (%d %s)", this.count, (this.count == 1) ? "Test" : "Tests");
        }
        else
        {
            writeln();
            writec(Color.onRed, "NOT OK");
            writeln();
            writefln("Tests run: %d, Failures: %d, Errors: %d",
                    this.count, this.failures.length, this.errors.length);
        }
    }

}

class DetailReporter : TestListener
{

    private string testName;

    private TickDuration startTime;

    public void enterClass(string className)
    {
        writeln(className);
    }

    public void enterTest(string testName)
    {
        this.testName = testName;
        this.startTime = TickDuration.currSystemTick();
    }

    public void skipTest(string testName)
    {
        writec(Color.yellow, "    IGNORE: ");
        writeln(testName);
    }

    public void addFailure(string subject, AssertException exception)
    {
        writec(Color.red, "    FAILURE: ");
        writefln("%s: %s@%s(%d): %s", subject,
                typeid(exception).name, exception.file, exception.line, exception.msg);
    }

    public void addError(string subject, Throwable throwable)
    {
        writec(Color.red, "    ERROR: ");
        writeln(subject, ": ", throwable.toString);
    }

    public void exitTest(bool success)
    {
        if (success)
        {
            double elapsed = (TickDuration.currSystemTick() - this.startTime).usecs() / 1000.0;

            writec(Color.green, "    OK: ");
            writefln("%6.2f ms  %s", elapsed, this.testName);
        }
    }

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
            static if (__traits(compiles, mixin("(new " ~ T.stringof ~ "())." ~ names[0] ~ "()"))
                    && _hasAttribute!(T, names[0], U))
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
