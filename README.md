Unit testing framework ('dunit')
================================

Allows to define unittests simply as methods which names start with 'test'.

The only thing necessary to create a unit test class, is to
declare the mixin TestMixin inside the class. This will register
the class and its test methods for the test runner.