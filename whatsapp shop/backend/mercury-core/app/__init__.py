# This file makes the app directory a Python package
# Extend package search path so sibling packages (e.g. core, db, documents)
# located at the project root can be imported as subpackages of `app`.
import os
__path__.insert(0, os.path.dirname(__path__[0]))

