import re

with open("src/__main__.py", "r") as f:
    content = f.read()

# Instead of returning None when patching fails, we can throw a custom exception
# But wait, that requires a lot of refactoring.

# Let's just create a loop around the whole process!
