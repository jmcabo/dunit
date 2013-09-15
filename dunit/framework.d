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
import std.file;
import std.path;
import std.regex;
import std.stdio;
import std.string;
public import std.typetuple;
import std.xml;

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
    string report = null;
    bool verbose = false;

    getopt(args,
            "filter|f", &filters,
            "help|h", &help,
            "list|l", &list,
            "report", &report,
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
        writeln("  --report FILE         Write JUnit-style XML test report");
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

    TestListener[] testListeners = null;

    if (verbose)
    {
        testListeners ~= new DetailReporter();
    }
    else
    {
        testListeners ~= new IssueReporter();
    }

    if (!report.empty)
    {
        testListeners ~= new XmlReporter(report);
    }

    auto reporter = new ResultReporter();

    testListeners ~= reporter;
    runTests(selectedTestNamesByClass, testListeners);
    return (reporter.errors > 0) ? 2 : (reporter.failures > 0) ? 1 : 0;
}

public static void runTests(string[][string] testNamesByClass, TestListener[] testListeners)
in
{
    assert(all!"a !is null"(testListeners));
}
body
{
    bool tryRun(string phase, void delegate() action)
    {
        try
        {
            action();
            return true;
        }
        catch (AssertException exception)
        {
            foreach (testListener; testListeners)
                testListener.addFailure(phase, exception);
            return false;
        }
        catch (Throwable throwable)
        {
            foreach (testListener; testListeners)
                testListener.addError(phase, throwable);
            return false;
        }
    }

    foreach (className; testClassOrder)
    {
        if (className !in testNamesByClass)
            continue;

        foreach (testListener; testListeners)
            testListener.enterClass(className);

        Object testObject = null;
        bool classSetUp = true;  // not yet failed

        // run each @Test of the class
        foreach (testName; testNamesByClass[className])
        {
            bool success = true;
            bool ignore = canFind(testClasses[className].ignoredTests, testName);

            foreach (testListener; testListeners)
                testListener.enterTest(testName);
            scope (exit)
                foreach (testListener; testListeners)
                    testListener.exitTest(success);

            // create test object on demand
            if (!ignore && testObject is null)
            {
                if (classSetUp)
                {
                    classSetUp = tryRun("this",
                            { testObject = testClasses[className].create(); });
                }
                if (classSetUp)
                {
                    classSetUp = tryRun("@BeforeClass",
                            { testClasses[className].beforeClass(testObject); });
                }
            }

            if (ignore || !classSetUp)
            {
                foreach (testListener; testListeners)
                    testListener.skip();
                success = false;
                continue;
            }

            success = tryRun("@Before",
                    { testClasses[className].before(testObject); });

            if (success)
            {
                success = tryRun("@Test",
                        { testClasses[className].test(testObject, testName); });
                // run @After even if @Test failed
                success = tryRun("@After",
                        { testClasses[className].after(testObject); })
                        && success;
            }
        }

        if (testObject !is null && classSetUp)
        {
            tryRun("@AfterClass",
                    { testClasses[className].afterClass(testObject); });
        }
    }

    foreach (testListener; testListeners)
        testListener.exit();
}

interface TestListener
{
    public void enterClass(string className);
    public void enterTest(string testName);
    public void skip();
    public void addFailure(string phase, AssertException exception);
    public void addError(string phase, Throwable throwable);
    public void exitTest(bool success);
    public void exit();

    public static string prettyOrigin(string className, string testName, string phase)
    {
        string origin = prettyOrigin(testName, phase);

        if (origin.startsWith('@'))
            return className ~ origin;
        else
            return className ~ '.' ~ origin;
    }

    public static string prettyOrigin(string testName, string phase)
    {
        switch (phase)
        {
            case "@Test":
                return testName;
            case "this":
            case "@BeforeClass":
            case "@AfterClass":
                return phase;
            default:
                return testName ~ phase;
        }
    }

    public static string description(Throwable throwable)
    {
        with (throwable)
        {
            if (file.empty)
                return typeid(throwable).name;
            else
                return "%s@%s(%d)".format(typeid(throwable).name, file, line);
        }
    }
}

class IssueReporter : TestListener
{
    private struct Issue
    {
        string testClass;
        string testName;
        string phase;
        Throwable throwable;
    }

    private Issue[] failures = null;
    private Issue[] errors = null;
    private string className;
    private string testName;

    public void enterClass(string className)
    {
        this.className = className;
    }

    public void enterTest(string testName)
    {
        this.testName = testName;
    }

    public void skip()
    {
        writec(Color.onYellow, "I");
    }

    public void addFailure(string phase, AssertException exception)
    {
        this.failures ~= Issue(this.className, this.testName, phase, exception);
        writec(Color.onRed, "F");
    }

    public void addError(string phase, Throwable throwable)
    {
        this.errors ~= Issue(this.className, this.testName, phase, throwable);
        writec(Color.onRed, "E");
    }

    public void exitTest(bool success)
    {
        if (success)
            writec(Color.onGreen, ".");
    }

    public void exit()
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
                writefln("%d) %s", i + 1,
                        prettyOrigin(issue.testClass, issue.testName, issue.phase));
                writeln(issue.throwable.toString);
                writeln("----------------");
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

                writefln("%d) %s", i + 1,
                        prettyOrigin(issue.testClass, issue.testName, issue.phase));
                writefln("%s: %s", description(throwable), throwable.msg);
            }
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

    public void skip()
    {
        writec(Color.yellow, "    IGNORE: ");
        writeln(this.testName);
    }

    public void addFailure(string phase, AssertException exception)
    {
        writec(Color.red, "    FAILURE: ");
        writeln(prettyOrigin(this.testName, phase));
        writefln("        %s: %s", description(exception), exception.msg);
    }

    public void addError(string phase, Throwable throwable)
    {
        writec(Color.red, "    ERROR: ");
        writeln(prettyOrigin(this.testName, phase));
        writeln("        ", throwable.toString);
        writeln("----------------");
    }

    public void exitTest(bool success)
    {
        if (success)
        {
            double elapsed = (TickDuration.currSystemTick() - this.startTime).usecs() / 1_000.0;

            writec(Color.green, "    OK: ");
            writefln("%6.2f ms  %s", elapsed, this.testName);
        }
    }

    public void exit()
    {
        // do nothing
    }
 }

class ResultReporter : TestListener
{
    private uint tests = 0;
    private uint failures = 0;
    private uint errors = 0;
    private uint skips = 0;

    public void enterClass(string className)
    {
        // do nothing
    }

    public void enterTest(string testName)
    {
        ++this.tests;
    }

    public void skip()
    {
        ++this.skips;
    }

    public void addFailure(string phase, AssertException exception)
    {
        ++this.failures;
    }

    public void addError(string phase, Throwable throwable)
    {
        ++this.errors;
    }

    public void exitTest(bool success)
    {
        // do nothing
    }

    public void exit()
    {
        writeln();
        writefln("Tests run: %d, Failures: %d, Errors: %d, Skips: %d",
                this.tests, this.failures, this.errors, this.skips);

        if (this.failures + this.errors == 0)
        {
            writec(Color.onGreen, "OK");
            writeln();
        }
        else
        {
            writec(Color.onRed, "NOT OK");
            writeln();
        }
    }
}

class XmlReporter : TestListener
{
    private string fileName;
    private Document document;
    private Element testSuite;
    private Element testCase;
    private string className;
    private TickDuration startTime;

    public this(string fileName)
    {
        this.fileName = fileName;
        this.document = new Document(new Tag("testsuites"));
        this.testSuite = new Element("testsuite");
        this.testSuite.tag.attr["name"] = "dunit";
        this.document ~= this.testSuite;
    }

    public void enterClass(string className)
    {
        this.className = className;
    }

    public void enterTest(string testName)
    {
        this.testCase = new Element("testcase");
        this.testCase.tag.attr["classname"] = this.className;
        this.testCase.tag.attr["name"] = testName;
        this.testSuite ~= this.testCase;
        this.startTime = TickDuration.currSystemTick();
    }

    public void skip()
    {
        // avoid wrong interpretation of more than one child
        if (this.testCase.elements.empty)
        {
            this.testCase ~= new Element("skipped");
        }
    }

    public void addFailure(string phase, AssertException exception)
    {
        // avoid wrong interpretation of more than one child
        if (this.testCase.elements.empty)
        {
            auto failure = new Element("failure");
            string message = "%s %s: %s".format(phase,
                    description(exception), exception.msg);

            // FIXME encoding will be fixed in D 2.064
            failure.tag.attr["message"] = encode(encode(message));
            this.testCase ~= failure;
        }
    }

    public void addError(string phase, Throwable throwable)
    {
        // avoid wrong interpretation of more than one child
        if (this.testCase.elements.empty)
        {
            auto error = new Element("error", throwable.info.toString);
            string message = "%s %s: %s".format(phase,
                    description(throwable), throwable.msg);

            // FIXME encoding will be fixed in D 2.064
            error.tag.attr["message"] = encode(encode(message));
            this.testCase ~= error;
        }
    }

    public void exitTest(bool success)
    {
        double elapsed = (TickDuration.currSystemTick() - this.startTime).msecs() / 1_000.0;

        this.testCase.tag.attr["time"] = "%.3f".format(elapsed);
    }

    public void exit()
    {
        string report = join(this.document.pretty(4), "\n") ~ "\n";

        std.file.write(this.fileName, report);
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
