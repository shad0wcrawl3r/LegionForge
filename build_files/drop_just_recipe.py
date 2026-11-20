#!/usr/bin/env python3
"""Remove one recipe (and its doc comment) from a justfile.

Usage: drop_just_recipe.py <file> <recipe>
Fails if the recipe isn't found, so an upstream rename breaks the build
instead of silently leaving a GNOME-only recipe in place.
"""
import re
import sys

path, name = sys.argv[1], sys.argv[2]
lines = open(path).read().split("\n")
start = next((i for i, l in enumerate(lines)
              if re.match(rf"^@?{re.escape(name)}(\s[^:]*)?:(?!=)", l)), None)
if start is None:
    sys.exit(f"drop_just_recipe: recipe '{name}' not found in {path}")
end = start + 1
while end < len(lines) and (lines[end] == "" or lines[end][:1] in (" ", "\t")):
    end += 1
while start > 0 and lines[start - 1].startswith(("#", "[")):  # doc comment / attributes
    start -= 1
del lines[start:end]
open(path, "w").write("\n".join(lines))
print(f"drop_just_recipe: removed '{name}' from {path}")
