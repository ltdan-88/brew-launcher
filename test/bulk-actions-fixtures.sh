#!/bin/zsh
#
# Bulk Hide/Favorite/Categorize test.
#
# Raised live: "I like the behavior of how we create presets (adding
# TUIs with tab). Would it be feasible to implement this behavior for
# Hide, Favorite, and Categorize as well?" Agreed: new Actions-only
# rows alongside the existing F6/F7/F8, and a bulk action moves every
# marked entry to the SAME end state rather than toggling each one
# individually based on its own prior state (a per-item toggle across
# a batch you just selected together would be a confusing surprise).
#
# add_to_favorites()/add_to_category() (the new "ensure membership,
# never remove" helpers a bulk action needs, as opposed to
# toggle_favorite()/toggle_category_direct()'s existing add-or-remove
# toggle) and pick_category_name() (the prompt toggle_category() used
# to build inline, pulled out so a bulk action can ask once for a
# whole batch) are all pure filesystem functions — no fzf — so they're
# sourced and run directly, same approach as ignore-fixtures.sh uses
# for hide_entry()/unhide_entry(). hide_entry()/unhide_entry()
# themselves are already proven idempotent by ignore-fixtures.sh
# (hiding/unhiding an already-hidden/-shown command is a no-op through
# either hidden-state mechanism) — that's exactly what lets bulk_hide()
# call either one unconditionally on every marked entry with no extra
# bookkeeping, so it isn't re-tested here.
#
# pick_multiple_entries()/bulk_hide()/bulk_favorite()/bulk_categorize()
# themselves all call fzf, so they're checked as source-text
# assertions instead, same reasoning as rename-fixtures.sh.
#
# Extended for a second live report: "in the view picker, when you
# select hide/favorite/categorize multiple, it shows 0 entries...
# I would prefer if menu entries like hide/favorite/categorize
# multiple only show up when usable. Also the create preset should
# only show what is actually listed in the current menu... this means
# that create preset should also disappear from view picker." All four
# rows (the three bulk ones plus Create Preset) moved inside the
# has_entry-gated block — has_entry is false only when Actions is
# opened from the view picker (F2), the one place $entries doesn't
# mean a real, currently-displayed tool list. Create Preset itself
# also stopped forcing CURRENT_VIEW to "All" — it now builds from
# whatever's actually on screen, same as the bulk actions.

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

CONFIG_DIR="$TEST_HOME/config"
CACHE_DIR="$TEST_HOME/cache"
CATEGORIES_DIR="$CONFIG_DIR/categories"
CATEGORY_EXCLUDE_FILE="$CONFIG_DIR/category-exclude"
mkdir -p "$CATEGORIES_DIR" "$CACHE_DIR"

typeset -A default_category_commands

source <(sed -n '/^add_to_favorites() {/,/^}/p' "$LAUNCHER")
source <(sed -n '/^add_to_category() {/,/^}/p' "$LAUNCHER")

# ------------------------------------------------------------
# 1. add_to_favorites(): adds a command not yet favorited.
# ------------------------------------------------------------

add_to_favorites "fastfetch"

favorites_file="$CATEGORIES_DIR/Favorites"
[[ -f "$favorites_file" ]] || fail "add_to_favorites did not create the Favorites file"
grep -qxF "fastfetch" "$favorites_file" || fail "fastfetch missing from Favorites after add_to_favorites"

# ------------------------------------------------------------
# 2. add_to_favorites() on an already-favorited command is a no-op —
#    the whole point versus toggle_favorite(), which would remove it.
# ------------------------------------------------------------

add_to_favorites "fastfetch"

fastfetch_count="$(grep -cxF "fastfetch" "$favorites_file")"
[[ "$fastfetch_count" == "1" ]] || fail "expected exactly 1 'fastfetch' line after add_to_favorites twice, got $fastfetch_count — it should never remove"

# ------------------------------------------------------------
# 3. add_to_category(): adds a command not yet in the category, to a
#    brand new category file.
# ------------------------------------------------------------

add_to_category "newsboat" "Reading"

reading_file="$CATEGORIES_DIR/Reading"
[[ -f "$reading_file" ]] || fail "add_to_category did not create the Reading category file"
grep -qxF "newsboat" "$reading_file" || fail "newsboat missing from Reading after add_to_category"

# ------------------------------------------------------------
# 4. add_to_category() on an already-real-member command is a no-op.
# ------------------------------------------------------------

add_to_category "newsboat" "Reading"

newsboat_count="$(grep -cxF "newsboat" "$reading_file")"
[[ "$newsboat_count" == "1" ]] || fail "expected exactly 1 'newsboat' line after add_to_category twice, got $newsboat_count"

# ------------------------------------------------------------
# 5. add_to_category() on a command that's already a member via the
#    bundled default (and not excluded) is also a no-op — it's
#    "virtually already there," same case toggle_category_direct()
#    treats as already-a-member for its own remove branch.
# ------------------------------------------------------------

default_category_commands=([glow]="Reading")
rm -f "$CATEGORY_EXCLUDE_FILE"

add_to_category "glow" "Reading"

grep -qxF "glow" "$reading_file" 2>/dev/null &&
    fail "add_to_category should not write a real line for a command already covered by the bundled default"
[[ ! -f "$CATEGORY_EXCLUDE_FILE" ]] ||
    { grep -qxF "glow" "$CATEGORY_EXCLUDE_FILE" 2>/dev/null &&
        fail "add_to_category should not touch CATEGORY_EXCLUDE_FILE — it only adds, never excludes"; }

# ------------------------------------------------------------
# 6. ...but if that bundled-default membership was already excluded
#    (F8 "removed" it once already), it's not actually a member
#    anymore, so add_to_category() should add a real line.
# ------------------------------------------------------------

printf 'glow\n' > "$CATEGORY_EXCLUDE_FILE"

add_to_category "glow" "Reading"

grep -qxF "glow" "$reading_file" ||
    fail "add_to_category should add a real line for a bundled-default command that's been excluded from that default"

# ------------------------------------------------------------
# 7. pick_category_name() exists and is what both toggle_category()
#    and bulk_categorize() actually use for the "type or pick a
#    category" prompt — pulled out specifically so bulk_categorize()
#    asks once per batch instead of once per marked entry.
# ------------------------------------------------------------

toggle_category_block="$(sed -n '/^toggle_category() {/,/^}/p' "$LAUNCHER")"
[[ -n "$toggle_category_block" ]] || fail "toggle_category() not found"
[[ "$toggle_category_block" == *'pick_category_name'* ]] ||
    fail "toggle_category should call pick_category_name for its prompt"

bulk_categorize_block="$(sed -n '/^bulk_categorize() {/,/^}/p' "$LAUNCHER")"
[[ -n "$bulk_categorize_block" ]] || fail "bulk_categorize() not found"
[[ "$bulk_categorize_block" == *'pick_category_name'* ]] ||
    fail "bulk_categorize should call pick_category_name once for the whole batch"
[[ "$bulk_categorize_block" == *'add_to_category'* ]] ||
    fail "bulk_categorize should apply membership via add_to_category (ensure-added), not a toggle"

# While already viewing a real category, every marked entry is
# necessarily already a member — bulk_categorize there should remove
# instantly (mirroring F8's own instant per-entry toggle in that same
# context) via toggle_category_direct, with no prompt at all.
[[ "$bulk_categorize_block" == *'toggle_category_direct'* ]] ||
    fail "bulk_categorize should remove via toggle_category_direct while viewing a real category"
[[ "$bulk_categorize_block" == *'CURRENT_VIEW" != "All" && "$CURRENT_VIEW" != "Hidden" && "$CURRENT_VIEW" != "Favorites"'* ]] ||
    fail "bulk_categorize should branch on the same All/Hidden/Favorites check F8's own dispatch uses"

# ------------------------------------------------------------
# 8. pick_multiple_entries() is a plain fzf --multi picker, not Create
#    Preset's custom ordered-badge mechanism — order doesn't matter for
#    any of Hide/Favorite/Categorize, only membership does.
# ------------------------------------------------------------

pick_multiple_block="$(sed -n '/^pick_multiple_entries() {/,/^}/p' "$LAUNCHER")"
[[ -n "$pick_multiple_block" ]] || fail "pick_multiple_entries() not found"
[[ "$pick_multiple_block" == *'--multi'* ]] ||
    fail "pick_multiple_entries should use fzf's own --multi"
[[ "$pick_multiple_block" != *'--internal-preset-tab'* ]] ||
    fail "pick_multiple_entries should not reuse Create Preset's ordered-badge mechanism — order doesn't matter here"

# ------------------------------------------------------------
# 9. bulk_hide()/bulk_favorite() relabel to their inverse while
#    viewing Hidden/Favorites respectively — same idea as F6's own
#    hide_label, and call the unconditional/ensure-added helper
#    appropriate to each direction.
# ------------------------------------------------------------

bulk_hide_block="$(sed -n '/^bulk_hide() {/,/^}/p' "$LAUNCHER")"
[[ -n "$bulk_hide_block" ]] || fail "bulk_hide() not found"
[[ "$bulk_hide_block" == *'CURRENT_VIEW" == "Hidden"'* ]] ||
    fail "bulk_hide should check CURRENT_VIEW for the Unhide-multiple relabel"
[[ "$bulk_hide_block" == *'unhide_entry'* && "$bulk_hide_block" == *'hide_entry'* ]] ||
    fail "bulk_hide should call both hide_entry and unhide_entry depending on direction"

bulk_favorite_block="$(sed -n '/^bulk_favorite() {/,/^}/p' "$LAUNCHER")"
[[ -n "$bulk_favorite_block" ]] || fail "bulk_favorite() not found"
[[ "$bulk_favorite_block" == *'CURRENT_VIEW" == "Favorites"'* ]] ||
    fail "bulk_favorite should check CURRENT_VIEW for the Unfavorite-multiple relabel"
[[ "$bulk_favorite_block" == *'add_to_favorites'* ]] ||
    fail "bulk_favorite should add via add_to_favorites (ensure-added), not a toggle, outside the Favorites view"
[[ "$bulk_favorite_block" == *'toggle_favorite'* ]] ||
    fail "bulk_favorite should remove via toggle_favorite while viewing Favorites (every marked entry is already a member there)"

# ------------------------------------------------------------
# 10. Wiring: all three bulk rows (plus Create Preset) are gated on
#     has_entry, grouped right under their single-entry counterpart,
#     and open_more_menu dispatches each to the right function. Raised
#     live: "in the view picker, when you select hide/favorite/
#     categorize multiple, it shows 0 entries... I would prefer if
#     menu entries like hide/favorite/categorize multiple only show up
#     when usable." Every has_entry=false call site is the view picker
#     (F2), which has no $entries of its own — see
#     pick_more_action()'s own comment.
# ------------------------------------------------------------

more_action_block="$(sed -n '/^pick_more_action() {/,/^}/p' "$LAUNCHER")"
open_menu_block="$(sed -n '/^open_more_menu() {/,/^}/p' "$LAUNCHER")"

for row_id in bulk_hide bulk_favorite bulk_categorize; do
    [[ "$more_action_block" == *"rows+=(\"$row_id\""* ]] ||
        fail "pick_more_action should offer a $row_id row"
    [[ "$open_menu_block" == *"            $row_id)"* ]] ||
        fail "open_more_menu should dispatch $row_id"
done

# Gated on has_entry, same as f6/f7/f8 — checked by confirming the
# row-producing lines sit INSIDE the "if has_entry" block, same
# positional-check idiom actions-menu-fixtures.sh already uses. Raised
# live: "in the view picker, when you select hide/favorite/categorize
# multiple, it shows 0 entries... I would prefer if menu entries like
# hide/favorite/categorize multiple only show up when usable." Every
# has_entry=false call site is the view picker (F2), which has no
# $entries of its own to act on — see pick_more_action()'s own comment.
has_entry_block="$(printf '%s\n' "$more_action_block" | sed -n '/if \[\[ "\$has_entry" == true \]\]; then/,/^    fi$/p')"
for row_id in bulk_hide bulk_favorite bulk_categorize create_preset; do
    [[ "$has_entry_block" == *"rows+=(\"$row_id\""* ]] ||
        fail "$row_id's row should be inside the has_entry-gated block — it needs \$entries to mean something, which the view picker doesn't have"
done

# ------------------------------------------------------------
# 11. create_preset() no longer forces CURRENT_VIEW to "All" — it
#     builds from whatever's already on screen, same as the bulk
#     actions. Checked as source text: no assignment to CURRENT_VIEW
#     anywhere in the function body at all anymore.
# ------------------------------------------------------------

create_preset_block="$(sed -n '/^create_preset() {/,/^}/p' "$LAUNCHER")"
[[ -n "$create_preset_block" ]] || fail "create_preset() not found"
[[ "$create_preset_block" != *'CURRENT_VIEW='* ]] ||
    fail "create_preset should no longer assign CURRENT_VIEW at all — it should build from whatever's already on screen, not force a switch to All"

printf 'PASS: add_to_favorites()/add_to_category() ensure membership without ever removing (including the bundled-default/excluded edge cases), pick_category_name() is shared between toggle_category() and bulk_categorize() for a single per-batch prompt, pick_multiple_entries() is a plain fzf --multi picker, all three bulk actions (plus Create Preset) are gated on has_entry — hidden from the view picker, which has no real entries to act on — and Create Preset builds from whatever view is actually on screen instead of forcing All\n'
