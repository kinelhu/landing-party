"""Fails when a remote interface's table names one function twice (control.lua's remote.add_interface tables).

A Lua table literal keeps the last of two equal keys without a word: 0.2.472 added a test remote `debug_ladder` beside
tactics' own, and scenario farm's tactics checks read the ammunition ladder instead ("attempt to compare nil with number").
Usage: python3 -I scripts/lint_remotes.py landing-party/control.lua ...
"""
import re
import sys
from collections import Counter

bad = 0
for path in sys.argv[1:]:
    src = open(path).read()
    for m in re.finditer(r'remote\.add_interface\("([^"]+)",\s*\{', src):
        # The interface's table: from its brace to the brace that closes it, counting braces (strings and comments aside).
        i, depth = m.end() - 1, 0
        j = i
        while j < len(src):
            c = src[j]
            if c == "-" and src.startswith("--", j):
                j = src.find("\n", j)
                continue
            if c in "\"'":
                k = j + 1
                while k < len(src) and src[k] != c:
                    k += 2 if src[k] == "\\" else 1
                j = k + 1
                continue
            if c == "{":
                depth += 1
            elif c == "}":
                depth -= 1
                if depth == 0:
                    break
            j += 1
        body = src[i:j]
        top = re.findall(r"^  ([A-Za-z_][A-Za-z0-9_]*) = ", body, re.M)
        for name, n in Counter(top).items():
            if n > 1:
                print(f"{path}: remote interface {m.group(1)} names {name} {n} times (the last one wins, silently)")
                bad += 1
if bad:
    sys.exit(1)
print("remotes lint ok")
