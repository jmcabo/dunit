//          Copyright Juan Manuel Cabo 2012.
//          Copyright Mario Kröplin 2015.
// Distributed under the Boost Software License, Version 1.0.
//    (See accompanying file LICENSE_1_0.txt or copy at
//          http://www.boost.org/LICENSE_1_0.txt)

module dunit.framework;

import dunit.assertion;
import dunit.attributes;
import dunit.color;

import core.runtime;
import core.time;
import std.algorithm;
import std.array;
import std.conv;
import std.stdio;
import std.string;
public import std.typetuple;

struct TestClass
{
    string name;
    string[] tests;
    Ignore[string] ignores;

    Object function() create;
    void function(Object o) beforeClass;
    void function(Object o) before;
    void delegate(Object o, string test) test;
    void function(Object o) after;
    void function(Object o) afterClass;
}

TestClass[] testClasses;

struct TestSelection
{
    TestClass testClass;
    string[] tests;
}

mixin template Main()
{
    int main (string[] args)
    {
        return dunit_main(args);
    }
}

public int dunit_main(string[] args)
{
    import std.getopt;
    import std.path;
    import std.regex;

    GetoptResult result;
    string[] filters = null;
    bool list = false;
    string report = null;
    bool verbose = false;
    bool xml = false;

    try
    {
        result = getopt(args,
                "list|l", "Display the test functions, then exit", &list,
                "filter|f", "Select test functions matching the regular expression", &filters,
                "verbose|v", "Display more information as the tests are run", &verbose,
                "xml", "Display progressive XML output", &xml,
                "report", "Write JUnit-style XML test report", &report,
                );
    }
    catch (Exception exception)
    {
        stderr.writeln("error: ", exception.msg);
        return 1;
    }

    if (result.helpWanted)
    {
        writefln("Usage: %s [options]", args.empty ? "testrunner" : baseName(args[0]));
        writeln("Run the functions with @Test attribute of all classes that mix in UnitTest.");
        defaultGetoptPrinter("Options:", result.options);
        return 0;
    }

    testClasses = unitTestFunctions ~ testClasses;

    TestSelection[] testSelections = null;

    if (filters is null)
    {
        foreach (testClass; testClasses)
            testSelections ~= TestSelection(testClass, testClass.tests);
    }
    else
    {
        foreach (filter; filters)
        {
            foreach (testClass; testClasses)
            {
                foreach (test; testClass.tests)
                {
                    string fullyQualifiedName = testClass.name ~ '.' ~ test;

                    if (match(fullyQualifiedName, filter))
                    {
                        auto foundTestSelections = testSelections.find!"a.testClass.name == b"(testClass.name);

                        if (foundTestSelections.empty)
                            testSelections ~= TestSelection(testClass, [test]);
                        else
                            foundTestSelections.front.tests ~= test;
                    }
                }
            }
        }
    }

    if (list)
    {
        foreach (testSelection; testSelections) with (testSelection)
        {
            foreach (test; tests)
            {
                string fullyQualifiedName = testClass.name ~ '.' ~ test;

                writeln(fullyQualifiedName);
            }
        }
        return 0;
    }

    if (xml)
    {
        testListeners ~= new XmlReporter();
    }
    else
    {
        if (verbose)
            testListeners ~= new DetailReporter();
        else
            testListeners ~= new IssueReporter();
    }

    if (!report.empty)
        testListeners ~= new ReportReporter(report);

    auto reporter = new ResultReporter();

    testListeners ~= reporter;
    runTests(testSelections, testListeners);
    if (!xml)
        reporter.write();
    return (reporter.errors > 0) ? 1 : (reporter.failures > 0) ? 2 : 0;
}

public static void runTests(TestSelection[] testSelections, TestListener[] testListeners)
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

    foreach (testSelection; testSelections) with (testSelection)
    {
        foreach (testListener; testListeners)
            testListener.enterClass(testClass.name);

        Object testObject = null;
        bool classSetUp = true;  // not yet failed

        // run each @Test of the class
        foreach (test; tests)
        {
            bool success = true;
            bool ignore = cast(bool)(test in testClass.ignores);

            foreach (testListener; testListeners)
                testListener.enterTest(test);
            scope (exit)
                foreach (testListener; testListeners)
                    testListener.exitTest(success);

            // create test object on demand
            if (!ignore && testObject is null)
            {
                if (classSetUp)
                {
                    classSetUp = tryRun("this",
                            { testObject = testClass.create(); });
                }
                if (classSetUp)
                {
                    classSetUp = tryRun("@BeforeClass",
                            { testClass.beforeClass(testObject); });
                }
            }

            if (ignore || !classSetUp)
            {
                string reason = testClass.ignores.get(test, Ignore.init).reason;

                foreach (testListener; testListeners)
                    testListener.skip(reason);
                success = false;
                continue;
            }

            success = tryRun("@Before",
                    { testClass.before(testObject); });

            if (success)
            {
                success = tryRun("@Test",
                        { testClass.test(testObject, test); });
                // run @After even if @Test failed
                success = tryRun("@After",
                        { testClass.after(testObject); })
                        && success;
            }
        }

        if (testObject !is null && classSetUp)
        {
            tryRun("@AfterClass",
                    { testClass.afterClass(testObject); });
        }
    }

    foreach (testListener; testListeners)
        testListener.exit();
}

private __gshared TestListener[] testListeners = null;

interface TestListener
{
    public void enterClass(string className);
    public void enterTest(string test);
    public void skip(string reason);
    public void addFailure(string phase, AssertException exception);
    public void addError(string phase, Throwable throwable);
    public void exitTest(bool success);
    public void exit();

    public static string prettyOrigin(string className, string test, string phase)
    {
        string origin = prettyOrigin(test, phase);

        if (origin.startsWith('@'))
            return className ~ origin;
        else
            return className ~ '.' ~ origin;
    }

    public static string prettyOrigin(string test, string phase)
    {
        switch (phase)
        {
            case "@Test":
                return test;
            case "this":
            case "@BeforeClass":
            case "@AfterClass":
                return phase;
            default:
                return test ~ phase;
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
        string test;
        string phase;
        Throwable throwable;
    }

    private Issue[] failures = null;
    private Issue[] errors = null;
    private string className;
    private string test;

    public void enterClass(string className)
    {
        this.className = className;
    }

    public void enterTest(string test)
    {
        this.test = test;
    }

    public void skip(string reason)
    {
        writec(Color.onYellow, "S");
    }

    public void addFailure(string phase, AssertException exception)
    {
        this.failures ~= Issue(this.className, this.test, phase, exception);
        writec(Color.onRed, "F");
    }

    public void addError(string phase, Throwable throwable)
    {
        this.errors ~= Issue(this.className, this.test, phase, throwable);
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
                        prettyOrigin(issue.testClass, issue.test, issue.phase));
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
                        prettyOrigin(issue.testClass, issue.test, issue.phase));
                writefln("%s: %s", description(throwable), throwable.msg);
            }
        }
    }
}

class DetailReporter : TestListener
{
    private string test;
    private TickDuration startTime;

    public void enterClass(string className)
    {
        writeln(className);
    }

    public void enterTest(string test)
    {
        this.test = test;
        this.startTime = TickDuration.currSystemTick();
    }

    public void skip(string reason)
    {
        writec(Color.yellow, "    SKIP: ");
        writeln(this.test);
        if (!reason.empty)
            writeln(indent(`"%s"`.format(reason)));
    }

    public void addFailure(string phase, AssertException exception)
    {
        writec(Color.red, "    FAILURE: ");
        writeln(prettyOrigin(this.test, phase));
        writeln(indent("%s: %s".format(description(exception), exception.msg)));
    }

    public void addError(string phase, Throwable throwable)
    {
        writec(Color.red, "    ERROR: ");
        writeln(prettyOrigin(this.test, phase));
        writeln("        ", throwable.toString);
        writeln("----------------");
    }

    public void exitTest(bool success)
    {
        if (success)
        {
            double elapsed = (TickDuration.currSystemTick() - this.startTime).usecs() / 1_000.0;

            writec(Color.green, "    OK: ");
            writefln("%6.2f ms  %s", elapsed, this.test);
        }
    }

    public void exit()
    {
        // do nothing
    }

    private string indent(string s, string indent = "        ")
    {
        return s.splitLines(KeepTerminator.yes).map!(line => indent ~ line).join;
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

    public void enterTest(string test)
    {
        ++this.tests;
    }

    public void skip(string reason)
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
        // do nothing
    }

    public void write()
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
    import std.xml;

    private Document testCase;
    private string className;
    private TickDuration startTime;

    public void enterClass(string className)
    {
        this.className = className;
    }

    public void enterTest(string test)
    {
        this.testCase = new Document(new Tag("testcase"));
        this.testCase.tag.attr["classname"] = this.className;
        this.testCase.tag.attr["name"] = test;
        this.startTime = TickDuration.currSystemTick();
    }

    public void skip(string reason)
    {
        auto element = new Element("skipped");

        element.tag.attr["message"] = reason;
        this.testCase ~= element;
    }

    public void addFailure(string phase, AssertException exception)
    {
        auto element = new Element("failure");
        string message = "%s %s: %s".format(phase,
                description(exception), exception.msg);

        element.tag.attr["message"] = message;
        this.testCase ~= element;
    }

    public void addError(string phase, Throwable throwable)
    {
        auto element = new Element("error", throwable.info.toString);
        string message = "%s %s: %s".format(phase,
                description(throwable), throwable.msg);

        element.tag.attr["message"] = message;
        this.testCase ~= element;
    }

    public void exitTest(bool success)
    {
        double elapsed = (TickDuration.currSystemTick() - this.startTime).msecs() / 1_000.0;

        this.testCase.tag.attr["time"] = "%.3f".format(elapsed);

        string report = join(this.testCase.pretty(4), "\n");

        writeln(report);
    }

    public void exit()
    {
        // do nothing
    }
}

class ReportReporter : TestListener
{
    import std.xml;

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

    public void enterTest(string test)
    {
        this.testCase = new Element("testcase");
        this.testCase.tag.attr["classname"] = this.className;
        this.testCase.tag.attr["name"] = test;
        this.testSuite ~= this.testCase;
        this.startTime = TickDuration.currSystemTick();
    }

    public void skip(string reason)
    {
        // avoid wrong interpretation of more than one child
        if (this.testCase.elements.empty)
        {
            auto element = new Element("skipped");

            element.tag.attr["message"] = reason;
            this.testCase ~= element;
        }
    }

    public void addFailure(string phase, AssertException exception)
    {
        // avoid wrong interpretation of more than one child
        if (this.testCase.elements.empty)
        {
            auto element = new Element("failure");
            string message = "%s %s: %s".format(phase,
                    description(exception), exception.msg);

            element.tag.attr["message"] = message;
            this.testCase ~= element;
        }
    }

    public void addError(string phase, Throwable throwable)
    {
        // avoid wrong interpretation of more than one child
        if (this.testCase.elements.empty)
        {
            auto element = new Element("error", throwable.info.toString);
            string message = "%s %s: %s".format(phase,
                    description(throwable), throwable.msg);

            element.tag.attr["message"] = message;
            this.testCase ~= element;
        }
    }

    public void exitTest(bool success)
    {
        double elapsed = (TickDuration.currSystemTick() - this.startTime).msecs() / 1_000.0;

        this.testCase.tag.attr["time"] = "%.3f".format(elapsed);
    }

    public void exit()
    {
        import std.file;

        string report = join(this.document.pretty(4), "\n") ~ "\n";

        write(this.fileName, report);
    }
}

shared static this()
{
    Runtime.moduleUnitTester = () => true;
}

private TestClass[] unitTestFunctions()
{
    TestClass[] testClasses = null;
    TestClass testClass;

    testClass.tests = ["unittest"];
    testClass.create = () => null;
    testClass.beforeClass = (o) {};
    testClass.before = (o) {};
    testClass.after = (o) {};
    testClass.afterClass = (o) {};

    foreach (moduleInfo; ModuleInfo)
    {
        if (moduleInfo)
        {
            auto unitTest = moduleInfo.unitTest;

            if (unitTest)
            {
                testClass.name = moduleInfo.name;
                testClass.test = (o, test) { unitTest(); };
                testClasses ~= testClass;
            }
        }
    }
    return testClasses;
}

/**
 * Registers a class as a unit test.
 */
mixin template UnitTest()
{
    private static this()
    {
        TestClass testClass;

        testClass.name = this.classinfo.name;
        testClass.tests = _members!(typeof(this), Test);
        testClass.ignores = _attributes!(typeof(this), Ignore);

        static Object create()
        {
            mixin("return new " ~ typeof(this).stringof ~ "();");
        }

        static void beforeClass(Object o)
        {
            mixin(_sequence(_members!(typeof(this), BeforeClass)));
        }

        static void before(Object o)
        {
            mixin(_sequence(_members!(typeof(this), Before)));
        }

        void test(Object o, string name)
        {
            mixin(_choice(_members!(typeof(this), Test)));
        }

        static void after(Object o)
        {
            mixin(_sequence(_members!(typeof(this), After)));
        }

        static void afterClass(Object o)
        {
            mixin(_sequence(_members!(typeof(this), AfterClass)));
        }

        testClass.create = &create;
        testClass.beforeClass = &beforeClass;
        testClass.before = &before;
        testClass.test = &test;
        testClass.after = &after;
        testClass.afterClass = &afterClass;

        testClasses ~= testClass;
    }

    private static string _choice(in string[] memberFunctions)
    {
        string block = "auto testObject = cast(" ~ typeof(this).stringof ~ ") o;\n";

        block ~= "switch (name)\n{\n";
        foreach (memberFunction; memberFunctions)
            block ~= `case "` ~ memberFunction ~ `": testObject.` ~ memberFunction ~ "(); break;\n";
        block ~= "default: break;\n}\n";
        return block;
    }

    private static string _sequence(in string[] memberFunctions)
    {
        string block = "auto testObject = cast(" ~ typeof(this).stringof ~ ") o;\n";

        foreach (memberFunction; memberFunctions)
            block ~= "testObject." ~ memberFunction ~ "();\n";
        return block;
    }

    template _members(T, Attribute)
    {
        static string[] helper()
        {
            string[] members;

            foreach (name; __traits(allMembers, T))
            {
                static if (__traits(compiles, __traits(getMember, T, name)))
                {
                    import std.typecons;

                    alias member = TypeTuple!(__traits(getMember, T, name));

                    static if (__traits(compiles, _hasAttribute!(member, Attribute)))
                    {
                        static if (_hasAttribute!(member, Attribute))
                            members ~= name;
                    }
                }
            }
            return members;
        }

        enum _members = helper;
    }

    template _attributes(T, Attribute)
    {
        static Attribute[string] helper()
        {
            Attribute[string] attributes;

            foreach (name; __traits(allMembers, T))
            {
                static if (__traits(compiles, __traits(getMember, T, name)))
                {
                    import std.typecons;

                    alias member = TypeTuple!(__traits(getMember, T, name));

                    static if (__traits(compiles, _hasAttribute!(member, Attribute)))
                    {
                        static if (_hasAttribute!(member, Attribute))
                            attributes[name] = _findAttribute!(member, Attribute);
                    }
                }
            }
            return attributes;
        }

        enum _attributes = helper;
    }

    template _findAttribute(alias member, Attribute)
    {
        static auto helper()
        {
            static if (__traits(compiles, __traits(getAttributes, member)))
            {
                foreach (attribute; __traits(getAttributes, member))
                {
                    static if (is(attribute == Attribute))
                        return Attribute.init;
                    static if (is(typeof(attribute) == Attribute))
                        return attribute;
                }
            }
            assert(0);
        }

        enum _findAttribute = helper;
    }

    template _hasAttribute(alias member, Attribute)
    {
        static bool helper()
        {
            foreach (attribute; __traits(getAttributes, member))
            {
                static if (is(attribute == Attribute))
                    return true;
                static if (is(typeof(attribute) == Attribute))
                    return true;
            }
            return false;
        }

        enum bool _hasAttribute = helper;
    }
}
