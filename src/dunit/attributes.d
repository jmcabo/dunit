module dunit.attributes;

enum AfterEach;
enum AfterAll;
enum BeforeEach;
enum BeforeAll;
enum Test;

struct Disabled
{
    string reason;
}

struct Tag
{
    string name;
}

deprecated("use AfterEach instead") alias After = AfterEach;
deprecated("use AfterAll instead") alias AfterClass = AfterAll;
deprecated("use BeforeEach instead") alias Before = BeforeEach;
deprecated("use BeforeAll instead") alias BeforeClass = BeforeAll;
deprecated("use Disabled instead") alias Ignore = Disabled;
