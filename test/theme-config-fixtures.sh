#!/bin/zsh
#
# Theme and config-file test.
#
# Covers: every named theme is accepted, an unknown one is rejected
# (matching the fail-fast convention BREW_LAUNCHER_TERMINAL already
# has), the config file's persisted TERMINAL/THEME are picked up with
# no env var set, and an env var still wins over the config file when
# both are present.
#
# Uses the same fixture-cache trick as list-fixtures.sh (a state file
# whose mtime alone satisfies the freshness check) so this runs
# without needing any real installed formulae, and never calls brew.

set -u

SCRIPT_DIR="${0:A:h}"
LAUNCHER="$SCRIPT_DIR/../bin/brew-launcher"

fail() {
    printf 'FAIL: %s\n' "$1" >&2
    exit 1
}

[[ -x "$LAUNCHER" ]] || fail "launcher not found or not executable: $LAUNCHER"

for dependency in fzf python3; do
    if ! command -v "$dependency" >/dev/null 2>&1; then
        echo "SKIP: '$dependency' not available"
        exit 0
    fi
done

TEST_HOME="$(mktemp -d)"
trap 'rm -rf "$TEST_HOME"' EXIT

export XDG_CACHE_HOME="$TEST_HOME/cache"
export XDG_CONFIG_HOME="$TEST_HOME/config"

CACHE_DIR="$XDG_CACHE_HOME/brew-launcher"
CONFIG_DIR="$XDG_CONFIG_HOME/brew-launcher"
mkdir -p "$CACHE_DIR" "$CONFIG_DIR"

CACHE_FORMAT_VERSION="$(sed -n 's/^CACHE_FORMAT_VERSION=\([0-9]*\)/\1/p' "$LAUNCHER" | head -1)"
[[ -n "$CACHE_FORMAT_VERSION" ]] || fail "could not read CACHE_FORMAT_VERSION from $LAUNCHER"

cat > "$CACHE_DIR/entries" <<'EOF'
btop	Resource monitor	btop	1.4.7	1.5MB	0	btop	/usr/bin/btop	100
EOF

{
    print -r -- "$CACHE_FORMAT_VERSION"
    print -r -- "fixture-state-snapshot"
} > "$CACHE_DIR/state"

: > "$CACHE_DIR/outdated"

# ------------------------------------------------------------
# 1. Every documented theme name is accepted.
# ------------------------------------------------------------

for theme in catppuccin gruvbox tokyonight nord dracula green amber solarized-dark solarized-light red-sands; do
    if ! BREW_LAUNCHER_THEME="$theme" "$LAUNCHER" --list >/dev/null 2>"$TEST_HOME/stderr.txt"; then
        cat "$TEST_HOME/stderr.txt" >&2
        fail "theme '$theme' was rejected, but it's supposed to be valid"
    fi
done

# ------------------------------------------------------------
# 2. An unrecognized theme name is rejected, matching how
#    BREW_LAUNCHER_TERMINAL already fails on an invalid value —
#    silently falling back would hide a typo instead of surfacing it.
# ------------------------------------------------------------

# The launcher's own startup-error convention is to print to stdout,
# not stderr (see cache-roundtrip.sh's own note on this) — captured
# accordingly rather than assuming stderr the way most CLIs would.
if BREW_LAUNCHER_THEME="not-a-real-theme" "$LAUNCHER" --list >"$TEST_HOME/stdout.txt" 2>&1; then
    fail "an unrecognized theme name should have been rejected"
fi

grep -q "unknown theme" "$TEST_HOME/stdout.txt" ||
    fail "rejection message should explain what went wrong: $(cat "$TEST_HOME/stdout.txt")"

# ------------------------------------------------------------
# 3. The config file's persisted THEME/TERMINAL are used when no env
#    var overrides them.
# ------------------------------------------------------------

cat > "$CONFIG_DIR/config" <<'EOF'
# a comment, and blank lines below, should both be harmless
THEME=nord
TERMINAL=current
EOF

if ! "$LAUNCHER" --list >/dev/null 2>"$TEST_HOME/stderr.txt"; then
    cat "$TEST_HOME/stderr.txt" >&2
    fail "a valid config-file theme should not be rejected"
fi

# ------------------------------------------------------------
# 4. An env var still overrides the config file — same precedence
#    BREW_LAUNCHER_TERMINAL already had before this file existed.
# ------------------------------------------------------------

if BREW_LAUNCHER_THEME="not-a-real-theme" "$LAUNCHER" --list >/dev/null 2>"$TEST_HOME/stderr.txt"; then
    fail "the env var should override the config file's valid theme with an invalid one and fail"
fi

# ------------------------------------------------------------
# 5. set_config_value() — the function the in-app Theme picker uses
#    to write the config file. Pure with respect to the filesystem
#    (no fzf), so sourced and called directly, same approach as
#    hide_entry()/unhide_entry() in ignore-fixtures.sh.
# ------------------------------------------------------------

CONFIG_DIR="$TEST_HOME/set-config-dir"
CONFIG_FILE="$CONFIG_DIR/config"
CACHE_DIR="$TEST_HOME/set-config-cache"
mkdir -p "$CACHE_DIR"

source <(sed -n '/^set_config_value() {/,/^}/p' "$LAUNCHER")

# 5a. Writing into a config file that doesn't exist yet creates it.
set_config_value THEME nord
[[ "$(cat "$CONFIG_FILE")" == "THEME=nord" ]] ||
    fail "set_config_value should create the config file with the new line: $(cat "$CONFIG_FILE" 2>/dev/null)"

# 5b. Adding a second, different key appends rather than overwriting.
set_config_value TERMINAL current

if [[ "$(grep -c '' "$CONFIG_FILE")" != "2" ]]; then
    fail "expected 2 lines after adding a second key, got: $(cat "$CONFIG_FILE")"
fi
grep -qx "THEME=nord" "$CONFIG_FILE" || fail "THEME=nord should have survived adding TERMINAL"
grep -qx "TERMINAL=current" "$CONFIG_FILE" || fail "TERMINAL=current should have been added"

# 5c. Updating an existing key replaces its line in place — a hand-
#     written comment elsewhere in the file must survive untouched.
printf '# a note I wrote by hand\n' >> "$CONFIG_FILE"
set_config_value THEME dracula

if [[ "$(grep -c '' "$CONFIG_FILE")" != "3" ]]; then
    fail "updating an existing key should not change the line count: $(cat "$CONFIG_FILE")"
fi
grep -qx "THEME=dracula" "$CONFIG_FILE" || fail "THEME should have been updated to dracula"
grep -qx "THEME=nord" "$CONFIG_FILE" && fail "the old THEME=nord line should be gone, not duplicated"
grep -qx "# a note I wrote by hand" "$CONFIG_FILE" || fail "a hand-written comment should survive an update to a different concern"
grep -qx "TERMINAL=current" "$CONFIG_FILE" || fail "TERMINAL=current should still be there, untouched by a THEME update"

# ------------------------------------------------------------
# 6. theme_position_label() — the count math behind the Theme screen's
#    "(N of TOTAL)" header. Raised live: "show counter for themes?"
#    Pure (no fzf), so sourced and called directly, same approach as
#    set_config_value above.
# ------------------------------------------------------------

source <(sed -n '/^theme_position_label() {/,/^}/p' "$LAUNCHER")

fixture_choices=("aaa"$'\t'"AAA display" "bbb"$'\t'"BBB display" "ccc"$'\t'"CCC display")

out="$(theme_position_label "bbb" "${fixture_choices[@]}")" ||
    fail "theme_position_label should succeed for a name that's in the list"
[[ "$out" == "2 of 3" ]] || fail "expected '2 of 3' for the middle entry, got: $out"

out="$(theme_position_label "aaa" "${fixture_choices[@]}")" ||
    fail "theme_position_label should succeed for the first entry"
[[ "$out" == "1 of 3" ]] || fail "expected '1 of 3' for the first entry, got: $out"

if theme_position_label "not-a-real-theme" "${fixture_choices[@]}" >/dev/null; then
    fail "theme_position_label should fail (return 1) for a name not in the list"
fi


# ------------------------------------------------------------
# 7. Settings row: the counter belongs there, not (only) inside the
#    Theme screen itself. Raised live: "you misunderstood the theme
#    counter. It should show in the settings menu, e.g. Themes (9)."
#    Checked as source text (pick_settings_action() calls fzf), and
#    cross-checked against the real number of themes pick_theme()
#    itself offers, so a theme added later without updating this
#    row's hardcoded count fails loudly instead of just going stale.
# ------------------------------------------------------------

settings_action_block="$(sed -n '/^pick_settings_action() {/,/^}/p' "$LAUNCHER")"
[[ -n "$settings_action_block" ]] || fail "pick_settings_action() not found"

[[ "$settings_action_block" == *"rows+=(\"theme\""*"'Themes'"* ]] ||
    fail "the theme row's label should be 'Themes' (plural), got: $(echo "$settings_action_block" | grep 'rows+=("theme"')"

pick_theme_block="$(sed -n '/^pick_theme() {/,/^}/p' "$LAUNCHER")"
real_theme_count="$(printf '%s\n' "$pick_theme_block" | grep -cE '^\s+"[a-z-]+"\$.\\t.\"')"
(( real_theme_count > 0 )) || fail "could not count pick_theme()'s own choices array — test itself may be stale"

theme_row_hint="$(printf '%s\n' "$settings_action_block" | grep 'rows+=("theme"' | grep -oE "\([0-9]+\)")"
[[ "$theme_row_hint" == "($real_theme_count)" ]] ||
    fail "the theme row's hardcoded count ($theme_row_hint) doesn't match pick_theme()'s actual $real_theme_count choices — bump it"

printf 'PASS: all named themes accepted, unknown theme rejected, config file honored, env var still wins, set_config_value writes/updates correctly, theme_position_label counts correctly, and the Settings row shows the total theme count (matching pick_theme()'"'"'s real list) rather than only the position indicator inside the Theme screen\n'
