"""Module fixture with Markdown-sensitive text: ```python and | tables |."""

from __future__ import annotations

CONSTANT = 1
mutable_value = 2
FIRST, SECOND = (1, 2)
locals()["DYNAMIC"] = 3

@decorator
def top_function(arg):
    local_value = 1

    def inner_function():
        return arg

    class InnerClass:
        pass

    return inner_function

@decorator
class Outer:
    class Nested:
        pass

    @decorator
    def method(self):
        def method_inner():
            return self
        return method_inner

def café():
    return "unicode"
