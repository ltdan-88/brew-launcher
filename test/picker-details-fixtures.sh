#!/bin/zsh
#
# F3 details pane for the view picker (F2) and preset picker (F9).
#
# Raised live: "would F2 and F9 benefit from an F3 details pane, where
# you could see at a glance what TUIs are within the categories or
# presets?" --internal-preview-category and --internal-preview-preset
# are plain CLI subcommands with no fzf/interactivity of their own —
# driven directly against a fixture cache/categories/presets dir, same
# technique preset-in-details-fixtures.sh already uses for the main
# list's own --internal-preview. pick_view()/launch_preset() wiring
# (the f3 key itself, pointed at the right subcommand) is checked as
# source-text assertions, same reasoning as rename-fixtures.sh.

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

CATEGORIES_DIR="$XDG_CONFIG_HOME/brew-launcher/categories"
PRESETS_DIR="$XDG_CONFIG_HOME/brew-launcher/presets"
CACHE_FILE="$XDG_CACHE_HOME/brew-launcher/entries"
mkdir -p "$CATEGORIES_DIR" "$PRESETS_DIR" "$XDG_CACHE_HOME/brew-launcher"

# Minimal fixture cache: command, description, formula, version, size,
# outdated, full_name, resolved_path, install_time, default_category,
# default_hidden. fastfetch's default_category ("System Info") is what
# section 3 below uses to test the bundled-only case — a real
# rebuild_cache() output always carries these same two trailing fields
# (see the "9 —" comment near CACHE_FORMAT_VERSION in the real script).
cat > "$CACHE_FILE" <<'EOF'
fastfetch	Like neofetch, but much faster	fastfetch	2.67.1	1.7MB		fastfetch	/opt/homebrew/bin/fastfetch	100	System Info	0
newsboat	RSS/Atom feed reader	newsboat	2.44	15.7MB		newsboat	/opt/homebrew/bin/newsboat	200	-	0
tele	TUI Telegram client	tele	1.11.2	27.3MB		tele	/opt/homebrew/bin/tele	300	-	0
EOF

# ------------------------------------------------------------
# 1. Category preview: a real category lists its members, sorted, with
#    descriptions from the cache.
# ------------------------------------------------------------

printf 'newsboat\nfastfetch\n' > "$CATEGORIES_DIR/Morning"

output="$("$LAUNCHER" --internal-preview-category Morning 2>&1)"

echo "$output" | grep -q "fastfetch" ||
    fail "category preview should list fastfetch, got: $output"
echo "$output" | grep -q "newsboat" ||
    fail "category preview should list newsboat, got: $output"
echo "$output" | grep -q "Like neofetch" ||
    fail "category preview should show fastfetch's description from the cache, got: $output"

# Alphabetical: fastfetch before newsboat, regardless of file order
# (the file lists newsboat first).
fastfetch_line="$(echo "$output" | grep -n "fastfetch" | cut -d: -f1)"
newsboat_line="$(echo "$output" | grep -n "newsboat" | cut -d: -f1)"
(( fastfetch_line < newsboat_line )) ||
    fail "category preview should be alphabetical, not file order — got fastfetch at line $fastfetch_line, newsboat at $newsboat_line"

# ------------------------------------------------------------
# 2. Built-in view: explains there's nothing to preview, doesn't error.
# ------------------------------------------------------------

for builtin_view in All Hidden "Most Used" "Recently Added"; do
    output="$("$LAUNCHER" --internal-preview-category "$builtin_view" 2>&1)"
    echo "$output" | grep -qi "not a stored category" ||
        fail "category preview for \"$builtin_view\" should explain it isn't a stored category, got: $output"
done

# ------------------------------------------------------------
# 3. Bundled-only category (no real file, members come purely from the
#    cache's default_category field): shows the actual tools, not an
#    explanation of why it can't. Raised live right after the F3
#    preview shipped: "I still want to see the tools, regardless of
#    who has categorized them" — first version refused this case with
#    a message instead.
# ------------------------------------------------------------

[[ ! -e "$CATEGORIES_DIR/System Info" ]] ||
    fail "test setup error: a real 'System Info' file would defeat this test"

output="$("$LAUNCHER" --internal-preview-category "System Info" 2>&1)"

echo "$output" | grep -q "fastfetch" ||
    fail "bundled-only category preview should list fastfetch (its default_category is System Info), got: $output"
echo "$output" | grep -q "Like neofetch" ||
    fail "bundled-only category preview should still show the description, got: $output"
echo "$output" | grep -qi "not one of yours yet" &&
    fail "bundled-only category preview should show the tools, not refuse with an explanation, got: $output"

# A category name matching neither a real file nor any cached
# default_category has genuinely nothing to show — that's the one case
# that should still say so.
output="$("$LAUNCHER" --internal-preview-category "NoSuchCategory" 2>&1)"
echo "$output" | grep -qi "Empty" ||
    fail "category preview for a name with no real file and no bundled members should say Empty, got: $output"

# ------------------------------------------------------------
# 4. Empty category file: says so, not just a blank pane.
# ------------------------------------------------------------

: > "$CATEGORIES_DIR/EmptyCat"
output="$("$LAUNCHER" --internal-preview-category EmptyCat 2>&1)"
echo "$output" | grep -qi "Empty" ||
    fail "category preview for an empty category should say so, got: $output"

# ------------------------------------------------------------
# 5. Preset preview: lists its members in FILE order (the launch
#    order), not alphabetical, with descriptions.
# ------------------------------------------------------------

printf 'tele\nfastfetch\n' > "$PRESETS_DIR/morning"

output="$("$LAUNCHER" --internal-preview-preset morning 2>&1)"

echo "$output" | grep -q "tele" ||
    fail "preset preview should list tele, got: $output"
echo "$output" | grep -q "fastfetch" ||
    fail "preset preview should list fastfetch, got: $output"
echo "$output" | grep -q "TUI Telegram client" ||
    fail "preset preview should show tele's description from the cache, got: $output"

tele_line="$(echo "$output" | grep -n "^  tele" | cut -d: -f1)"
fastfetch_line="$(echo "$output" | grep -n "^  fastfetch" | cut -d: -f1)"
(( tele_line < fastfetch_line )) ||
    fail "preset preview should preserve file/launch order (tele first), not sort alphabetically — got tele at line $tele_line, fastfetch at $fastfetch_line"

# ------------------------------------------------------------
# 6. Preset that doesn't exist: says so, doesn't error.
# ------------------------------------------------------------

output="$("$LAUNCHER" --internal-preview-preset does-not-exist 2>&1)"
exit_code=$?
(( exit_code == 0 )) ||
    fail "preset preview for a nonexistent preset should exit 0, got $exit_code"
echo "$output" | grep -qi "not found" ||
    fail "preset preview for a nonexistent preset should say so, got: $output"

# ------------------------------------------------------------
# 7. Wiring: F2 and F9 actually offer F3 and point it at the right
#    subcommand — a preview subcommand nobody calls is as good as none.
# ------------------------------------------------------------

pick_view_block="$(sed -n '/^pick_view() {/,/^}/p' "$LAUNCHER")"
[[ "$pick_view_block" == *'f3'* ]] ||
    fail "pick_view (F2) should expect f3"
[[ "$pick_view_block" == *'--internal-preview-category'* ]] ||
    fail "pick_view (F2) should preview via --internal-preview-category"

launch_preset_block="$(sed -n '/^launch_preset() {/,/^}/p' "$LAUNCHER")"
[[ "$launch_preset_block" == *'f3'* ]] ||
    fail "launch_preset (F9) should expect f3"
[[ "$launch_preset_block" == *'--internal-preview-preset'* ]] ||
    fail "launch_preset (F9) should preview via --internal-preview-preset"

printf 'PASS: F3 in F2/F9 previews category/preset contents (alphabetical vs. launch order respectively), explains bundled-only/built-in/empty/missing cases instead of showing nothing\n'
