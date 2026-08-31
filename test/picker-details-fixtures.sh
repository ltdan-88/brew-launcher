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
# (pointed at the right subcommand) is checked as source-text
# assertions, same reasoning as rename-fixtures.sh. F9's own pane was
# later made unconditional (no F3 toggle at all — see
# actions-menu-fixtures.sh), so only F2's wiring still checks for an
# f3 key specifically.

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
# default_hidden. macmon's default_category ("System Info") is what
# section 3 below uses to test the bundled-only case — kept separate
# from fastfetch specifically because section 1 files fastfetch into
# a real category ("Morning") of its own, and section 3b's "already
# filed elsewhere" check would otherwise make fastfetch a moving
# target depending on what ran before it. A real rebuild_cache()
# output always carries these same two trailing fields (see the "9 —"
# comment near CACHE_FORMAT_VERSION in the real script).
cat > "$CACHE_FILE" <<'EOF'
fastfetch	Like neofetch, but much faster	fastfetch	2.67.1	1.7MB		fastfetch	/opt/homebrew/bin/fastfetch	100	-	0
newsboat	RSS/Atom feed reader	newsboat	2.44	15.7MB		newsboat	/opt/homebrew/bin/newsboat	200	-	0
tele	TUI Telegram client	tele	1.11.2	27.3MB		tele	/opt/homebrew/bin/tele	300	-	0
macmon	Sudoless performance monitoring	macmon	0.8.2	1.9MB		macmon	/opt/homebrew/bin/macmon	400	System Info	0
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
# 1b. Hidden entries are excluded, matching the category's own count
#     (compute_category_counts()). Raised live right after this
#     preview shipped without this filter: a category's count said 3,
#     the preview said 5 — a visible, confusing disagreement between
#     two things that both claim to describe the same category.
#     Covers both hiding mechanisms: an explicit F6 (IGNORE_FILE) and
#     a bundled-hidden command (CACHE_FILE field 11) without a
#     SHOWN_FILE override — tele stays visible either way once shown.
# ------------------------------------------------------------

mkdir -p "$XDG_CONFIG_HOME/brew-launcher"
printf 'newsboat\n' > "$XDG_CONFIG_HOME/brew-launcher/ignore"
printf 'tele\n' > "$XDG_CONFIG_HOME/brew-launcher/shown"

cat >> "$CACHE_FILE" <<'EOF'
tele	TUI Telegram client	tele	1.11.2	27.3MB		tele	/opt/homebrew/bin/tele	400	Morning	1
EOF

output="$("$LAUNCHER" --internal-preview-category Morning 2>&1)"

echo "$output" | grep -q "fastfetch" ||
    fail "hidden-filtering test: Morning should still list fastfetch, got: $output"
echo "$output" | grep -q "newsboat" &&
    fail "hidden-filtering test: Morning should drop newsboat (explicitly hidden via IGNORE_FILE), got: $output"
echo "$output" | grep -q "tele" ||
    fail "hidden-filtering test: Morning should keep tele (bundled-hidden but SHOWN_FILE overrides it), got: $output"

rm -f "$XDG_CONFIG_HOME/brew-launcher/ignore" "$XDG_CONFIG_HOME/brew-launcher/shown"

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

echo "$output" | grep -q "macmon" ||
    fail "bundled-only category preview should list macmon (its default_category is System Info), got: $output"
echo "$output" | grep -q "Sudoless performance monitoring" ||
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
# 3b. Default Categories turned off (Actions -> Default Categories):
#     bundled contributions stop showing up in the preview too, same
#     as they already stop counting in the real picker
#     (load_bundled_categories() itself skips entirely when this is
#     off). Raised live: a category with an empty real file (left
#     over from before this was turned off) still showed bundled tools
#     in the preview while its own count correctly said 0 — the
#     preview had no idea the setting existed. Also covers a command
#     that's manually filed into some *other* real category — it
#     shouldn't appear to double-belong here and there.
# ------------------------------------------------------------

mkdir -p "$XDG_CONFIG_HOME/brew-launcher"
printf 'DEFAULT_CATEGORIES=off\n' > "$XDG_CONFIG_HOME/brew-launcher/config"

output="$("$LAUNCHER" --internal-preview-category "System Info" 2>&1)"
echo "$output" | grep -qi "Empty" ||
    fail "with Default Categories off, a bundled-only category should preview as Empty, got: $output"

printf 'DEFAULT_CATEGORIES=on\n' > "$XDG_CONFIG_HOME/brew-launcher/config"
printf 'macmon\n' > "$CATEGORIES_DIR/Elsewhere"

output="$("$LAUNCHER" --internal-preview-category "System Info" 2>&1)"
echo "$output" | grep -q "macmon" &&
    fail "macmon is manually filed into \"Elsewhere\" — System Info's bundled preview should not also claim it, got: $output"

rm -f "$XDG_CONFIG_HOME/brew-launcher/config" "$CATEGORIES_DIR/Elsewhere"

# ------------------------------------------------------------
# 4. Empty category file: says so, not just a blank pane.
# ------------------------------------------------------------

: > "$CATEGORIES_DIR/EmptyCat"
output="$("$LAUNCHER" --internal-preview-category EmptyCat 2>&1)"
echo "$output" | grep -qi "Empty" ||
    fail "category preview for an empty category should say so, got: $output"

# ------------------------------------------------------------
# 5. Preset preview: lists its members in FILE order (the launch
#    order), not alphabetical, with descriptions, and numbered
#    explicitly — raised live: "Presets: show explicitly order of
#    TUIs."
# ------------------------------------------------------------

printf 'tele\nfastfetch\n' > "$PRESETS_DIR/morning"

output="$("$LAUNCHER" --internal-preview-preset morning 2>&1)"

echo "$output" | grep -q "tele" ||
    fail "preset preview should list tele, got: $output"
echo "$output" | grep -q "fastfetch" ||
    fail "preset preview should list fastfetch, got: $output"
echo "$output" | grep -q "TUI Telegram client" ||
    fail "preset preview should show tele's description from the cache, got: $output"

echo "$output" | grep -qE "^ *1\. tele" ||
    fail "tele should be badged 1 (first in file order), got: $output"
echo "$output" | grep -qE "^ *2\. fastfetch" ||
    fail "fastfetch should be badged 2 (second in file order), got: $output"

tele_line="$(echo "$output" | grep -nE "^ *[0-9]+\. tele" | cut -d: -f1)"
fastfetch_line="$(echo "$output" | grep -nE "^ *[0-9]+\. fastfetch" | cut -d: -f1)"
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
# 7. Wiring: F2 offers F3 and points it at the right subcommand — a
#    preview subcommand nobody calls is as good as none. F9's own pane
#    is unconditional now (no F3 toggle at all — see
#    actions-menu-fixtures.sh section 7, "Preset menu F9 should offer
#    same behavior as F4 menu"), so it's checked for the subcommand
#    only, not for an f3 key that no longer exists there.
# ------------------------------------------------------------

pick_view_block="$(sed -n '/^pick_view() {/,/^}/p' "$LAUNCHER")"
[[ "$pick_view_block" == *'f3'* ]] ||
    fail "pick_view (F2) should expect f3"
[[ "$pick_view_block" == *'--internal-preview-category'* ]] ||
    fail "pick_view (F2) should preview via --internal-preview-category"

launch_preset_block="$(sed -n '/^launch_preset() {/,/^}/p' "$LAUNCHER")"
[[ "$launch_preset_block" == *'--internal-preview-preset'* ]] ||
    fail "launch_preset (F9) should preview via --internal-preview-preset"

printf 'PASS: F2 previews category contents via F3, F9 always previews preset contents (alphabetical vs. launch order respectively), explains bundled-only/built-in/empty/missing cases instead of showing nothing\n'
