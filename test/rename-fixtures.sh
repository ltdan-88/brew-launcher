#!/bin/zsh
#
# Rename category / rename preset test.
#
# Raised live: "I would like to be able to rename categories and
# presets from the UI." Both are just a named file (CATEGORIES_DIR/
# PRESETS_DIR), so renaming either is prompt for a new name (fzf's own
# --print-query, the same "type a name" idiom toggle_category() already
# uses to accept a brand new category name) then `mv` the file.
#
# Same situation as category-fixtures.sh already documents for
# toggle_category(): the actual validation (reserved names, "/" and
# leading "." rejection, collision with an existing name) lives inside
# a function that calls fzf for the text entry itself, so it isn't
# something to drive headlessly without either a real TTY or a
# drive-by refactor of working code purely to make it testable — not
# attempted here, per the same project stance. This checks the source
# text for the guards actually being present and wired to the right
# key instead. The full interactive flow (F2/F9, Ctrl-R, clear the
# prefilled name, type a new one, Enter) was verified live instead, in
# a real tmux pane: renamed a real category and a real preset, watched
# both land on disk under the new name and the picker redraw with it,
# and confirmed "All" refuses with "can't be renamed" rather than
# silently doing something.

set -u

SCRIPT_DIR="${0:A:h}"
LAUNCHER="$SCRIPT_DIR/../bin/brew-launcher"

fail() {
    printf 'FAIL: %s\n' "$1" >&2
    exit 1
}

[[ -x "$LAUNCHER" ]] || fail "launcher not found or not executable: $LAUNCHER"

# ------------------------------------------------------------
# 1. rename_category(): guards and the actual mv.
# ------------------------------------------------------------

rename_category_block="$(sed -n '/^rename_category() {/,/^}/p' "$LAUNCHER")"

[[ -n "$rename_category_block" ]] ||
    fail "rename_category() not found"

[[ "$rename_category_block" == *'--print-query'* ]] ||
    fail "rename_category should use fzf's --print-query, the same typed-name idiom as toggle_category"

for reserved in 'All' 'Hidden' 'Favorites' 'Most Used' 'Recently Added'; do
    [[ "$rename_category_block" == *"\"$reserved\""* ]] ||
        fail "rename_category should refuse the built-in view name \"$reserved\""
done

[[ "$rename_category_block" == *'*/*'* ]] ||
    fail "rename_category should reject a new name containing \"/\""
[[ "$rename_category_block" == *'.*'* ]] ||
    fail "rename_category should reject a new name starting with \".\""
[[ "$rename_category_block" == *'already exists'* ]] ||
    fail "rename_category should refuse a name that collides with an existing category"
[[ "$rename_category_block" == *'mv "$CATEGORIES_DIR/$old_name" "$CATEGORIES_DIR/$new_name"'* ]] ||
    fail "rename_category should mv the file from its old name to its new one"

# ------------------------------------------------------------
# 2. rename_preset(): same shape, same checks.
# ------------------------------------------------------------

rename_preset_block="$(sed -n '/^rename_preset() {/,/^}/p' "$LAUNCHER")"

[[ -n "$rename_preset_block" ]] ||
    fail "rename_preset() not found"

[[ "$rename_preset_block" == *'--print-query'* ]] ||
    fail "rename_preset should use fzf's --print-query, same idiom as rename_category"

[[ "$rename_preset_block" == *'*/*'* ]] ||
    fail "rename_preset should reject a new name containing \"/\""
[[ "$rename_preset_block" == *'.*'* ]] ||
    fail "rename_preset should reject a new name starting with \".\""
[[ "$rename_preset_block" == *'already exists'* ]] ||
    fail "rename_preset should refuse a name that collides with an existing preset"
[[ "$rename_preset_block" == *'mv "$PRESETS_DIR/$old_name" "$PRESETS_DIR/$new_name"'* ]] ||
    fail "rename_preset should mv the file from its old name to its new one"

# ------------------------------------------------------------
# 3. Both pickers actually offer Ctrl-R and wire it up — a guard
#    function nobody calls is as good as no guard at all.
# ------------------------------------------------------------

pick_view_block="$(sed -n '/^pick_view() {/,/^}/p' "$LAUNCHER")"
[[ "$pick_view_block" == *'ctrl-r'* ]] ||
    fail "pick_view (F2) should expect ctrl-r"
[[ "$pick_view_block" == *'rename_category "$picked"'* ]] ||
    fail "pick_view (F2) should call rename_category on ctrl-r"

launch_preset_block="$(sed -n '/^launch_preset() {/,/^}/p' "$LAUNCHER")"
[[ "$launch_preset_block" == *'ctrl-r'* ]] ||
    fail "launch_preset (F9) should expect ctrl-r"
[[ "$launch_preset_block" == *'rename_preset "$preset_name"'* ]] ||
    fail "launch_preset (F9) should call rename_preset on ctrl-r"

printf 'PASS: rename_category()/rename_preset() guard against reserved/invalid/colliding names and mv the file, F2 and F9 both wire up Ctrl-R to call them\n'
