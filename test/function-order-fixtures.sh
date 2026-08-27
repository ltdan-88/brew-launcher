#!/bin/zsh
#
# Function-definition-order check.
#
# Raised live via a screenshot: "bottom menu is missing when launching
# into view screen (toggle on)" — Actions -> Open to Categories, which
# calls pick_view() once, near the top of the script, before the main
# loop even starts. Root cause: zsh doesn't hoist function
# definitions — a function is only callable once the interpreter's
# top-to-bottom pass has actually reached its own "name() {" line.
# pick_view() (defined early) calls build_picker_footer() (defined
# much later, past the main loop's own functions), and that call only
# actually executes once Open to Categories triggers it — which
# happens BEFORE the script's linear execution ever reaches
# build_picker_footer()'s own definition. The call silently fails
# ("command not found", easy to miss since nothing else in that
# codepath prints to stderr) and the footer variable comes back empty,
# which is indistinguishable from "no footer" once handed to fzf.
#
# Confirmed live: checked out the previously-released binary and
# reproduced the exact blank-footer screenshot with
# OPEN_TO_CATEGORIES=on, then confirmed the fix (moving the footer-
# building functions earlier in the file, before pick_view()) resolves
# it, using a real tmux session both times.
#
# This is a whole class of bug (any top-level codepath that runs
# before the main loop, calling a function whose own dependencies
# happen to be defined even later), not just this one instance, so
# this test is a general static check rather than a single assertion:
# it builds a call graph (which function calls which, by scanning each
# function body for bare command words that match a known function
# name — good enough for this codebase's style of one statement per
# line, not a full shell parser) and then, for every TOP-LEVEL call
# site (a function invoked from outside any function body — the
# codepaths that actually run during startup, before the main loop),
# walks that function's transitive call graph and fails if anything
# it depends on, directly or indirectly, is defined later in the file
# than the top-level call site itself.
#
# Written in python3 (already a project dependency — rebuild_cache()
# itself is a python3 heredoc) since this needs real parsing, not
# something worth reimplementing in awk/sed.

SCRIPT_DIR="${0:A:h}"
LAUNCHER="$SCRIPT_DIR/../bin/brew-launcher"

fail() {
    printf 'FAIL: %s\n' "$1" >&2
    exit 1
}

[[ -x "$LAUNCHER" ]] || fail "launcher not found or not executable: $LAUNCHER"
command -v python3 >/dev/null 2>&1 || fail "python3 not found"

output="$(python3 - "$LAUNCHER" <<'PYEOF'
import re
import sys

path = sys.argv[1]
with open(path, encoding="utf-8") as f:
    lines = f.read().splitlines()

func_re = re.compile(r'^([A-Za-z_][A-Za-z0-9_]*)\(\)\s*\{$')

# Pass 1: record each function's (start_line, end_line), 1-indexed,
# and which lines belong to its body (for the call-graph scan below).
# Functions in this codebase never nest, so a simple depth flag is
# enough: a "name() {" at depth 0 opens one, a bare "}" at depth 0
# (relative to being inside that function) closes it.
functions = {}  # name -> (start_line, end_line)
body_lines = {}  # name -> list of (lineno, text)
depth = 0
current = None
for i, line in enumerate(lines, start=1):
    if depth == 0:
        m = func_re.match(line)
        if m:
            current = m.group(1)
            functions[current] = [i, None]
            body_lines[current] = []
            depth = 1
        continue
    else:
        if line == '}':
            functions[current][1] = i
            depth = 0
            current = None
        else:
            body_lines[current].append((i, line))

if current is not None:
    print(f"PARSE ERROR: function {current!r} (opened line {functions[current][0]}) never closed")
    sys.exit(1)

known = set(functions.keys())

def first_word_call(stripped):
    """Returns the bare function-name-shaped first word of a statement,
    or None if this line doesn't look like a plain call at all (a case
    label like 'create_preset)', an assignment like 'FOO=bar', a
    comment, etc). Heuristic, not a real parser — good enough for this
    codebase's one-statement-per-line style."""
    if not stripped or stripped.startswith('#'):
        return None
    m = re.match(r'^([A-Za-z_][A-Za-z0-9_]*)', stripped)
    if not m:
        return None
    word = m.group(1)
    rest = stripped[len(word):]
    if rest.startswith(')') or rest.startswith('='):
        return None  # case label or assignment, not a call
    return word

# Pass 2: build the call graph — for each function, which other known
# functions does its body call.
calls = {name: set() for name in known}
for name, lns in body_lines.items():
    for _, line in lns:
        w = first_word_call(line.strip())
        if w and w in known and w != name:
            calls[name].add(w)

# Pass 3: find top-level call sites — lines at depth 0 (outside every
# function body) that call a known function.
depth = 0
top_level_calls = []  # (lineno, func_name)
for i, line in enumerate(lines, start=1):
    if depth == 0:
        if func_re.match(line):
            depth = 1
            continue
        w = first_word_call(line.strip())
        if w and w in known:
            top_level_calls.append((i, w))
    else:
        if line == '}':
            depth = 0

# Pass 4: for each top-level call, walk the transitive call graph and
# make sure every function it (directly or indirectly) depends on is
# already defined by that line.
violations = []
for call_line, root in top_level_calls:
    seen = set()
    stack = [root]
    while stack:
        name = stack.pop()
        if name in seen:
            continue
        seen.add(name)
        start_line = functions[name][0]
        if start_line > call_line:
            violations.append((call_line, root, name, start_line))
        stack.extend(calls[name] - seen)

if violations:
    for call_line, root, dep, dep_line in violations:
        chain = f"{root}()" if root == dep else f"{root}() -> ... -> {dep}()"
        print(f"VIOLATION: top-level call to {root}() at line {call_line} transitively needs {chain}, "
              f"but {dep}() isn't defined until line {dep_line} — this call would fail at runtime "
              f"('command not found: {dep}') with an empty/blank result wherever that return value feeds into, "
              f"same shape as the empty-footer bug this test was written for")
    sys.exit(1)

print(f"OK: {len(top_level_calls)} top-level call sites checked against {len(known)} known functions, no forward references")
PYEOF
)"
py_exit=$?

printf '%s\n' "$output"
(( py_exit == 0 )) || fail "function-order check failed — see violations above"

printf 'PASS: every function reachable from a top-level (startup-path) call is defined before that call site — no forward references that would silently fail at runtime\n'
