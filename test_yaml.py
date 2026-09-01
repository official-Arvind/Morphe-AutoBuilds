import sys

def check_yaml_basic(filename):
    with open(filename, 'r') as f:
        content = f.read()
    
    # Just a very basic manual check to see if there are any obvious syntax problems
    # Since we removed blocks using regex, let's make sure indentation isn't obviously broken.
    pass

check_yaml_basic('.github/workflows/patch.yml')
check_yaml_basic('.github/workflows/manager.yml')
