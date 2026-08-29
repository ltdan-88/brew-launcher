#!/bin/zsh
#
# Security regression tests.
#
# Not tied to one live-reported bug like most other test/*.sh files —
# these guard properties the project claims in SECURITY.md, so a
# regression here is a security regression, not just a UX one:
#
#   1. A formula description (free text a tap maintainer controls, not
#      constrained by Homebrew's own name-safety rules) can't corrupt
#      the tab-separated cache format by embedding a tab or newline.
#   2. The config file is parsed as inert data — a value containing
#      shell metacharacters is never executed, and an invalid value is
#      rejected cleanly rather than silently accepted or crashing.
#   3. Every mktemp call in the script uses a randomized template
#      (XXXXXX or -d), never a fixed/predictable name a concurrent
#      invocation could race.
#   4. Category/preset name entry — all four places a typed string
#      becomes a filename (F7/toggle_category via pick_category_name,
#      Create Preset, rename_category, rename_preset) — rejects "/"
#      and a leading "." before ever touching the filesystem.
#   5. Enter still prefers the cache's own resolved executable path
#      over a fresh PATH lookup (see the v0.9.1 fix this codifies).

set -u

SCRIPT_DIR="${0:A:h}"
LAUNCHER="$SCRIPT_DIR/../bin/brew-launcher"

fail() {
    printf 'FAIL: %s\n' "$1" >&2
    exit 1
}

[[ -x "$LAUNCHER" ]] || fail "launcher not found or not executable: $LAUNCHER"

command -v python3 >/dev/null 2>&1 || { echo "SKIP: python3 not available"; exit 0; }

TEST_HOME="$(mktemp -d)"
trap 'rm -rf "$TEST_HOME"' EXIT

# ==============================================================
# 1. Cache-writer sanitizes tab/newline in a formula description.
# ==============================================================

# Extracted the same way the rest of this file's static checks read
# bin/brew-launcher's own text: the cache-writer is a python3 heredoc
# inside rebuild_cache(), fully self-contained (argv in, one output
# file out) apart from one `brew leaves` call, which is stubbed below
# with a fake `brew` on PATH rather than needing a real install — the
# same "fake stand-in" technique relaunch-fixtures.sh already uses.
PY_START="$(grep -n "^        \"\$PREVIEW_PRESET_MARKER\" <<'PY'\$" "$LAUNCHER" | head -1 | cut -d: -f1)"
PY_END="$(awk 'NR>'"$PY_START"' && /^PY$/ { print NR; exit }' "$LAUNCHER")"

[[ -n "$PY_START" && -n "$PY_END" ]] ||
    fail "could not locate the cache-writer python3 heredoc in $LAUNCHER"

CACHE_WRITER_PY="$TEST_HOME/cache_writer.py"
sed -n "$((PY_START + 1)),$((PY_END - 1))p" "$LAUNCHER" > "$CACHE_WRITER_PY"

python3 -m py_compile "$CACHE_WRITER_PY" ||
    fail "extracted cache-writer script has a syntax error"

FAKE_BIN="$TEST_HOME/fake-bin"
mkdir -p "$FAKE_BIN"
cat > "$FAKE_BIN/brew" <<'FAKEBREW'
#!/bin/sh
if [ "$1" = "leaves" ]; then
    echo "evil-formula"
    exit 0
fi
exit 1
FAKEBREW
chmod +x "$FAKE_BIN/brew"

BREW_PREFIX="$TEST_HOME/prefix"
OPT_BIN="$BREW_PREFIX/opt/evil-formula/bin"
mkdir -p "$OPT_BIN"
printf '#!/bin/sh\n' > "$OPT_BIN/evil-tool"
chmod +x "$OPT_BIN/evil-tool"

# The description a malicious/compromised tap could publish: an
# embedded tab (would otherwise shift every field after it one column
# left) and an embedded newline (would otherwise terminate this row
# early and start a bogus new one out of whatever text follows).
EVIL_DESC="innocuous$(printf '\t')looking$(printf '\n')description"

JSON_FILE="$TEST_HOME/formulae.json"
python3 -c "
import json, sys
json.dump([{
    'name': 'evil-formula',
    'full_name': 'evil-formula',
    'desc': sys.argv[1],
    'installed': [{'version': '1.0', 'time': 1700000000}],
}], open(sys.argv[2], 'w'))
" "$EVIL_DESC" "$JSON_FILE"

: > "$TEST_HOME/sizes"
: > "$TEST_HOME/outdated"
ENTRIES_OUT="$TEST_HOME/entries"
PREVIEW_DIR="$TEST_HOME/previews"

PATH="$FAKE_BIN:$OPT_BIN:$PATH" python3 "$CACHE_WRITER_PY" \
    "$JSON_FILE" "$TEST_HOME/sizes" "$TEST_HOME/outdated" \
    "$BREW_PREFIX" "$ENTRIES_OUT" "$PREVIEW_DIR" \
    '@@CATEGORIES@@' '@@PRESETS@@' ||
    fail "cache-writer exited non-zero against a crafted description"

[[ -f "$ENTRIES_OUT" ]] || fail "cache-writer produced no output file"

entry_line_count="$(wc -l < "$ENTRIES_OUT" | tr -d ' ')"
(( entry_line_count == 1 )) ||
    fail "expected exactly 1 cache row from 1 formula, got $entry_line_count — the embedded tab/newline corrupted row structure
$(cat "$ENTRIES_OUT")"

field_count="$(awk -F'\t' '{ print NF; exit }' "$ENTRIES_OUT")"
(( field_count == 11 )) ||
    fail "expected 11 tab-separated fields (CACHE_FORMAT_VERSION 9 shape), got $field_count
$(cat "$ENTRIES_OUT")"

first_field="$(awk -F'\t' '{ print $1; exit }' "$ENTRIES_OUT")"
[[ "$first_field" == "evil-tool" ]] ||
    fail "expected field 1 (command) to be 'evil-tool', got '$first_field' — fields shifted
$(cat "$ENTRIES_OUT")"

resolved_path_field="$(awk -F'\t' '{ print $8; exit }' "$ENTRIES_OUT")"
[[ "$resolved_path_field" == "$OPT_BIN/evil-tool" ]] ||
    fail "expected field 8 (resolved path) to be the real executable path, got '$resolved_path_field'
$(cat "$ENTRIES_OUT")"

description_field="$(awk -F'\t' '{ print $2; exit }' "$ENTRIES_OUT")"
[[ "$description_field" != *$'\t'* && "$description_field" != *$'\n'* ]] ||
    fail "description field still contains a raw tab/newline after sanitization"

# ==============================================================
# 2. Config file is parsed as inert data, never executed.
# ==============================================================

CONFIG_XDG="$TEST_HOME/config-test/config"
CACHE_XDG="$TEST_HOME/config-test/cache"
CONFIG_DIR="$CONFIG_XDG/brew-launcher"
mkdir -p "$CONFIG_DIR"

CANARY="$TEST_HOME/canary"
rm -f "$CANARY"

# A config value crafted to look like a command a naive `eval`/sourcing
# of this file would run. If the launcher ever starts sourcing this
# file instead of parsing it as KEY=value text, this canary appears.
cat > "$CONFIG_DIR/config" <<EOF
TERMINAL=current; touch $CANARY; echo pwned
THEME=\$(touch $CANARY)
EOF

# --list is the real enforcement path (not --diagnose, which only
# reports): TERMINAL resolution/validation runs unconditionally right
# after the dependency check, before --list's own logic, and --list
# needs no interactive fzf session to reach it.
config_output="$(XDG_CONFIG_HOME="$CONFIG_XDG" XDG_CACHE_HOME="$CACHE_XDG" \
    "$LAUNCHER" --list 2>&1)"
config_status=$?

[[ -f "$CANARY" ]] &&
    fail "config file value was executed — canary file was created
$config_output"

(( config_status != 0 )) ||
    fail "expected a malformed TERMINAL value to fail, exited 0
$config_output"

echo "$config_output" | grep -qi "unsupported terminal" ||
    fail "expected the malformed TERMINAL value to be rejected as an unsupported terminal
$config_output"

# ==============================================================
# 3. Every mktemp call uses a randomized template, never a fixed name.
# ==============================================================

mktemp_lines="$(grep -n 'mktemp' "$LAUNCHER")"
[[ -n "$mktemp_lines" ]] || fail "no mktemp calls found — did the script change how temp files are made?"

bad_mktemp_lines="$(echo "$mktemp_lines" | grep -v -- '-d\b' | grep -v 'XXXXXX')"
[[ -z "$bad_mktemp_lines" ]] ||
    fail "found a mktemp call without a randomized template (no -d, no XXXXXX) — predictable temp file names are racy:
$bad_mktemp_lines"

# ==============================================================
# 4. Path-traversal guard present at all four name-entry sites.
# ==============================================================

# Two separate fixed-string checks rather than one alternation regex —
# both must appear in the block, in either order.
has_traversal_guard() {
    echo "$1" | grep -qF '== */*' && echo "$1" | grep -qF '== .*'
}

pick_category_name_block="$(sed -n '/^pick_category_name()/,/^}/p' "$LAUNCHER")"
[[ -n "$pick_category_name_block" ]] || fail "pick_category_name() not found"
has_traversal_guard "$pick_category_name_block" ||
    fail "pick_category_name() (used by F7/toggle_category and bulk_categorize) is missing its '/' and leading '.' guard"

create_preset_block="$(sed -n '/^create_preset()/,/^}/p' "$LAUNCHER")"
[[ -n "$create_preset_block" ]] || fail "create_preset() not found"
has_traversal_guard "$create_preset_block" ||
    fail "create_preset() is missing its '/' and leading '.' guard on the typed preset name"

rename_category_block="$(sed -n '/^rename_category()/,/^}/p' "$LAUNCHER")"
[[ -n "$rename_category_block" ]] || fail "rename_category() not found"
has_traversal_guard "$rename_category_block" ||
    fail "rename_category() is missing its '/' and leading '.' guard"

rename_preset_block="$(sed -n '/^rename_preset()/,/^}/p' "$LAUNCHER")"
[[ -n "$rename_preset_block" ]] || fail "rename_preset() not found"
has_traversal_guard "$rename_preset_block" ||
    fail "rename_preset() is missing its '/' and leading '.' guard"

# ==============================================================
# 5. Enter prefers the cache's resolved path over a fresh PATH lookup.
# ==============================================================

# Inline in the main loop (not its own function — an fzf-driven loop,
# same "no drive-by refactor purely for testability" reasoning
# rename-fixtures.sh already documents), so this is a source-text
# assertion: the resolved-path branch must be checked before falling
# back to a fresh `command -v`, guarding against a future refactor
# silently reintroducing the PATH-shadow gap v0.9.1 fixed.
enter_launch_block="$(awk '/# Enter = launch selected entry\./,/command -v \"\$command\" 2>\/dev\/null\)\"$/' "$LAUNCHER")"
[[ -n "$enter_launch_block" ]] || fail "could not locate the Enter-launch resolved-path check"
echo "$enter_launch_block" | grep -q '\-x "\$resolved_path"' ||
    fail "Enter-launch no longer checks the cached resolved_path is still executable before using it"
echo "$enter_launch_block" | grep -qF 'command_path="$resolved_path"' ||
    fail "Enter-launch no longer prefers \$resolved_path over a fresh PATH lookup"

echo "PASS: cache-writer sanitizes tab/newline in a formula description (no row corruption, correct field count/positions), a config file with shell-metacharacter values is never executed and a malformed value is cleanly rejected, every mktemp call uses a randomized template, path-traversal guards are present at all four category/preset name-entry sites, and Enter still prefers the cache's resolved path over a fresh PATH lookup"
