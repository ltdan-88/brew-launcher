#!/bin/zsh
#
# Custom colors (THEME=custom) — config-file-only, not an in-app
# picker option. Deliberately not offered as a row in pick_theme()'s
# own list: there's no sensible display description for a palette
# only the user knows the contents of, and it fails fast (same
# convention as an unrecognized theme name) if THEME=custom is set but
# CUSTOM_COLORS itself is empty, rather than falling back to a default
# that would silently hide the missing line.
#
# Same fixture-cache trick as theme-config-fixtures.sh (a state file
# whose mtime alone satisfies the freshness check), so this runs
# without needing any real installed formulae or a real fzf render.

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

SAMPLE_COLORS='fg:#cdd6f4,bg:#1e1e2e,fg+:#f5e0e6,bg+:#313244,hl:#89b4fa,hl+:#89b4fa,info:#a6adc8,prompt:#89b4fa,pointer:#f38ba8,marker:#a6e3a1,spinner:#f5c2e7,header:#a6adc8,border:#45475a,label:#89b4fa,query:#f5e0e6'

# ------------------------------------------------------------
# 1. THEME=custom with a CUSTOM_COLORS line present is accepted.
# ------------------------------------------------------------

cat > "$CONFIG_DIR/config" <<EOF
THEME=custom
CUSTOM_COLORS=$SAMPLE_COLORS
EOF

if ! "$LAUNCHER" --list >/dev/null 2>"$TEST_HOME/stderr.txt"; then
    cat "$TEST_HOME/stderr.txt" >&2
    fail "THEME=custom with CUSTOM_COLORS set should not be rejected"
fi

# ------------------------------------------------------------
# 2. THEME=custom with no CUSTOM_COLORS line fails fast, same
#    convention as an unrecognized theme name — not a silent
#    fallback to some default palette.
# ------------------------------------------------------------

cat > "$CONFIG_DIR/config" <<'EOF'
THEME=custom
EOF

if "$LAUNCHER" --list >"$TEST_HOME/stdout.txt" 2>&1; then
    fail "THEME=custom with no CUSTOM_COLORS should have been rejected"
fi

grep -qi "CUSTOM_COLORS" "$TEST_HOME/stdout.txt" ||
    fail "rejection message should mention CUSTOM_COLORS: $(cat "$TEST_HOME/stdout.txt")"

# ------------------------------------------------------------
# 3. There's no BREW_LAUNCHER_CUSTOM_COLORS env var — CUSTOM_COLORS is
#    config-file-only by design, even when THEME itself comes from the
#    env var instead of the config file.
# ------------------------------------------------------------

cat > "$CONFIG_DIR/config" <<EOF
CUSTOM_COLORS=$SAMPLE_COLORS
EOF

if ! BREW_LAUNCHER_THEME="custom" "$LAUNCHER" --list >/dev/null 2>"$TEST_HOME/stderr.txt"; then
    cat "$TEST_HOME/stderr.txt" >&2
    fail "BREW_LAUNCHER_THEME=custom should still read CUSTOM_COLORS from the config file"
fi

rm -f "$CONFIG_DIR/config"

# ------------------------------------------------------------
# 4. The custom) case arm actually wires FZF_COLORS to
#    CONFIG_CUSTOM_COLORS, and fails fast on the same variable being
#    empty — source-text check, since the case statement above only
#    proves accept/reject, not which variable is actually behind it.
# ------------------------------------------------------------

theme_case_block="$(sed -n '/^case "\$THEME_NAME" in/,/^esac$/p' "$LAUNCHER")"
custom_arm="$(printf '%s\n' "$theme_case_block" | sed -n '/^    custom)/,/^        ;;$/p')"

[[ -n "$custom_arm" ]] || fail "could not find the custom) case arm in the THEME_NAME case statement"
[[ "$custom_arm" == *'-z "$CONFIG_CUSTOM_COLORS"'* ]] ||
    fail "the custom) arm should fail fast when CONFIG_CUSTOM_COLORS is empty"
[[ "$custom_arm" == *'FZF_COLORS="$CONFIG_CUSTOM_COLORS"'* ]] ||
    fail "the custom) arm should set FZF_COLORS from CONFIG_CUSTOM_COLORS"

# ------------------------------------------------------------
# 5. Deliberately not a pick_theme() row — config-file-only, no
#    in-app picker entry to scroll to and choose.
# ------------------------------------------------------------

pick_theme_block="$(sed -n '/^pick_theme() {/,/^}/p' "$LAUNCHER")"
[[ "$pick_theme_block" != *'"custom"$'"'"'\t'"'"''* ]] ||
    fail "custom should not be offered as a row in pick_theme()'s own list"

# Not a selectable row, but not invisible either — mentioned in the
# Theme screen's own header and the Settings row's own F3 preview, so
# someone actually browsing themes in-app has a way to discover it
# exists at all without having read the README first.
[[ "$pick_theme_block" == *'CUSTOM_COLORS'* ]] ||
    fail "pick_theme()'s own header should mention CUSTOM_COLORS as a config-file option"

preview_action_block="$(sed -n '/--internal-preview-action/,/^fi$/p' "$LAUNCHER")"
theme_preview="$(printf '%s\n' "$preview_action_block" | sed -n '/^        theme)$/,/^            ;;$/p')"
[[ "$theme_preview" == *'CUSTOM_COLORS'* ]] ||
    fail "the Settings row's own Theme preview should mention CUSTOM_COLORS too"

# ------------------------------------------------------------
# 6. The unrecognized-theme error message's supported-values list
#    mentions custom now that it's a real accepted value.
# ------------------------------------------------------------

[[ "$theme_case_block" == *'red-sands, custom.'* ]] ||
    fail "the unknown-theme error's supported-values list should mention custom"

printf 'PASS: THEME=custom reads its palette from a CUSTOM_COLORS config line (config-file-only, no BREW_LAUNCHER_ env var and no pick_theme() row, but mentioned in both the Theme screen'"'"'s own header and the Settings row'"'"'s preview so it'"'"'s discoverable in-app), fails fast with a CUSTOM_COLORS-specific message when that line is missing, wires FZF_COLORS from CONFIG_CUSTOM_COLORS, and the unknown-theme error mentions custom as a supported value\n'
