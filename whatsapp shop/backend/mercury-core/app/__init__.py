# This file makes the app directory a Python package
# Extend package search path so packages placed at the project root (e.g. `core`, `api`)
# can be imported as `app.core` or `app.api` without requiring an installed package.
import os
project_root = os.path.dirname(__path__[0])
if project_root not in __path__:
    # Append (not prepend) so that the nested `app` package contents take precedence
    __path__.append(project_root)

