#!/bin/zsh
#
# "Which presets is this in?" in the F3 details pane.
#
# Raised live: "would it make sense to tell what presets are currently
# assigned to a TUI in F3 details pane?" Preset membership is filled in
# at --internal-preview render time from PRESETS_DIR, the same way
# category membership is already filled in from CATEGORIES_DIR — this
# drives that internal subcommand directly against a fixture preview
# file (containing the real @@PRESETS@@ marker a real cache build
# would embed) and a fixture PRESETS_DIR, no fzf/brew/tmux needed.

set -u

SCRIPT_DIR="${0:A:h}"
LAUNCHER="$SCRIPT_DIR/../bin/brew-launcher"

fail() {
    printf 'FAIL: %s\n' "$1" >&2
    exit 1
}

[[ -x "$LAUNCHER" ]] || fail "launcher not found or not executable: $LAUNCHER"

TEST_HOME="$(mktemp -d)"
trap 'rm -rf "$TEST_HOME"' EXIT

export XDG_CONFIG_HOME="$TEST_HOME/config"
export XDG_CACHE_HOME="$TEST_HOME/cache"

PRESETS_DIR="$XDG_CONFIG_HOME/brew-launcher/presets"
PREVIEW_DIR="$XDG_CACHE_HOME/brew-launcher/previews"
mkdir -p "$PRESETS_DIR" "$PREVIEW_DIR"

cat > "$PREVIEW_DIR/fastfetch" <<'EOF'
  fastfetch  2.67.1

  Like neofetch, but much faster because written mostly in C
  Homepage          https://github.com/fastfetch-cli/fastfetch
@@CATEGORIES@@
@@PRESETS@@
EOF

# ------------------------------------------------------------
# 1. In two presets: both listed, comma-separated.
# ------------------------------------------------------------

printf 'fastfetch\n' > "$PRESETS_DIR/briefing"
printf 'fastfetch\nnewsboat\n' > "$PRESETS_DIR/morning"
printf 'newsboat\n' > "$PRESETS_DIR/check-ins"

output="$("$LAUNCHER" --internal-preview fastfetch fastfetch 2>&1)"

echo "$output" | grep -q "Presets" ||
    fail "preview should show a Presets line when the command is in at least one, got: $output"

echo "$output" | grep -q "briefing" ||
    fail "preview should list \"briefing\" (fastfetch is in it), got: $output"

echo "$output" | grep -q "morning" ||
    fail "preview should list \"morning\" (fastfetch is in it too), got: $output"

echo "$output" | grep -q "check-ins" &&
    fail "preview should not list \"check-ins\" — fastfetch isn't in it, got: $output"

# ------------------------------------------------------------
# 2. In no preset at all: no Presets line, not an empty one.
# ------------------------------------------------------------

rm -f "$PRESETS_DIR/briefing" "$PRESETS_DIR/morning"

output="$("$LAUNCHER" --internal-preview fastfetch fastfetch 2>&1)"

echo "$output" | grep -q "Presets" &&
    fail "preview should not show a Presets line at all when the command isn't in any, got: $output"

# ------------------------------------------------------------
# 3. No presets directory yet at all: doesn't error out.
# ------------------------------------------------------------

rm -rf "$PRESETS_DIR"

output="$("$LAUNCHER" --internal-preview fastfetch fastfetch 2>&1)"
exit_code=$?

(( exit_code == 0 )) ||
    fail "preview should not fail just because PRESETS_DIR doesn't exist, got exit $exit_code: $output"

echo "$output" | grep -q "Presets" &&
    fail "preview should not show a Presets line when there's no presets directory at all, got: $output"

printf 'PASS: F3 details pane lists which presets a command belongs to, blank when none, no error when PRESETS_DIR is missing\n'
