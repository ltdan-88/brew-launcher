#!/bin/zsh
#
# Two live reports fixed together:
#
#   1. "when you cancel/exit bulk categorize, it opens the 'new or
#      existing' prompt, instead of cancelling/exiting." Root cause: a
#      genuine zsh quirk — `selected=("${(@f)$(cmd)}")` where `cmd`
#      prints nothing (Esc pressed in pick_multiple_entries()) produces
#      a ONE-element array holding a single empty string, not a
#      zero-element array. `(( ${#selected[@]} == 0 ))` was therefore
#      always false after Esc, so bulk_hide()/bulk_favorite() silently
#      did nothing (their per-line loop skips the one empty line) but
#      bulk_categorize() fell all the way through to prompting for a
#      category name anyway. Confirmed live with a two-line repro
#      before fixing: capture the raw string first, only split it into
#      an array if it's actually non-empty.
#
#   2. "I often accidentally exit the brew-launcher with ESC. Can you
#      make a prompt similar to after when you quit a TUI?" Esc on
#      "All" now opens a Cancel/Quit confirm (confirm_quit()) instead
#      of exiting immediately — same idiom as
#      confirm_delete_category()/confirm_relaunch(), Cancel listed
#      first and Esc there also means Cancel.
#
# bulk_hide()/bulk_favorite()/bulk_categorize() are driven for real
# here (not just source-text) by stubbing pick_multiple_entries() (the
# only fzf call any of them make) to simulate "Esc pressed" (prints
# nothing) or "one row accepted" (prints one line) — same technique
# relaunch-fixtures.sh already uses to drive a real function past its
# one fzf/exec call. The per-entry action functions (hide_entry,
# add_to_favorites, ...) are stubbed too, as call counters, so this
# tests exactly the empty-selection guard itself, not the actions
# those other functions already have their own tests for
# (ignore-fixtures.sh, bulk-actions-fixtures.sh).
#
# confirm_quit() itself calls fzf, so it — and its wiring into the main
# loop's Esc handler — are checked as source text, same reasoning as
# rename-fixtures.sh.

set -u

SCRIPT_DIR="${0:A:h}"
LAUNCHER="$SCRIPT_DIR/../bin/brew-launcher"

fail() {
    printf 'FAIL: %s\n' "$1" >&2
    exit 1
}

[[ -x "$LAUNCHER" ]] || fail "launcher not found or not executable: $LAUNCHER"

# ------------------------------------------------------------
# Stub every function bulk_hide()/bulk_favorite()/bulk_categorize()
# call besides pick_multiple_entries() itself, as call counters/canary
# flags, before sourcing the real bulk_* functions.
# ------------------------------------------------------------

HIDE_CALLS=0; hide_entry() { HIDE_CALLS=$((HIDE_CALLS + 1)); }
UNHIDE_CALLS=0; unhide_entry() { UNHIDE_CALLS=$((UNHIDE_CALLS + 1)); }
load_hidden_commands() { :; }

FAVORITE_ADD_CALLS=0; add_to_favorites() { FAVORITE_ADD_CALLS=$((FAVORITE_ADD_CALLS + 1)); }
FAVORITE_TOGGLE_CALLS=0; toggle_favorite() { FAVORITE_TOGGLE_CALLS=$((FAVORITE_TOGGLE_CALLS + 1)); }

CATEGORY_ADD_CALLS=0; add_to_category() { CATEGORY_ADD_CALLS=$((CATEGORY_ADD_CALLS + 1)); }
CATEGORY_TOGGLE_CALLS=0; toggle_category_direct() { CATEGORY_TOGGLE_CALLS=$((CATEGORY_TOGGLE_CALLS + 1)); }
PICK_CATEGORY_NAME_CALLS=0; pick_category_name() { PICK_CATEGORY_NAME_CALLS=$((PICK_CATEGORY_NAME_CALLS + 1)); printf 'Reading'; }

refresh_category_state() { :; }
load_favorite_commands() { :; }
load_category_members() { :; }
build_entries() { :; }

source <(sed -n '/^bulk_hide() {/,/^}/p' "$LAUNCHER")
source <(sed -n '/^bulk_favorite() {/,/^}/p' "$LAUNCHER")
source <(sed -n '/^bulk_categorize() {/,/^}/p' "$LAUNCHER")

# ------------------------------------------------------------
# 1. Esc (pick_multiple_entries prints nothing) cancels cleanly — no
#    action function called, and (the actual bug) bulk_categorize does
#    NOT fall through to pick_category_name.
# ------------------------------------------------------------

pick_multiple_entries() { :; }

CURRENT_VIEW="All"

bulk_hide
(( $? == 1 )) || fail "bulk_hide should return 1 (cancelled) when Esc was pressed"
(( HIDE_CALLS == 0 && UNHIDE_CALLS == 0 )) ||
    fail "bulk_hide should not call hide_entry/unhide_entry at all after Esc, got hide=$HIDE_CALLS unhide=$UNHIDE_CALLS"

bulk_favorite
(( $? == 1 )) || fail "bulk_favorite should return 1 (cancelled) when Esc was pressed"
(( FAVORITE_ADD_CALLS == 0 && FAVORITE_TOGGLE_CALLS == 0 )) ||
    fail "bulk_favorite should not call add_to_favorites/toggle_favorite at all after Esc"

bulk_categorize
(( $? == 1 )) || fail "bulk_categorize should return 1 (cancelled) when Esc was pressed"
(( PICK_CATEGORY_NAME_CALLS == 0 )) ||
    fail "bulk_categorize should not prompt for a category after Esc — this is the exact bug reported live: \"when you cancel/exit bulk categorize, it opens the 'new or existing' prompt\""
(( CATEGORY_ADD_CALLS == 0 && CATEGORY_TOGGLE_CALLS == 0 )) ||
    fail "bulk_categorize should not touch any category membership after Esc"

# ------------------------------------------------------------
# 2. The legitimate "nothing marked, Enter accepts the highlighted
#    row" case still works — pick_multiple_entries returning exactly
#    one real line is not the same as returning nothing.
# ------------------------------------------------------------

HIDE_CALLS=0
pick_multiple_entries() { printf 'fastfetch\tfastfetch (fastfetch)\tfastfetch\tdesc\n'; }

bulk_hide
(( HIDE_CALLS == 1 )) ||
    fail "bulk_hide should still act on a single accepted row (nothing marked, just Enter) — got $HIDE_CALLS calls"

# ------------------------------------------------------------
# 3. confirm_quit(): exists, Cancel-first idiom matching
#    confirm_delete_category()/confirm_relaunch(), and is what the
#    main loop's own Esc handler calls before actually breaking out.
# ------------------------------------------------------------

confirm_quit_block="$(sed -n '/^confirm_quit() {/,/^}/p' "$LAUNCHER")"
[[ -n "$confirm_quit_block" ]] || fail "confirm_quit() not found"
[[ "$confirm_quit_block" == *'"Cancel" "Quit'* ]] ||
    fail "confirm_quit should list Cancel first, same safe-default convention as confirm_delete_category/confirm_relaunch"
[[ "$confirm_quit_block" == *"Esc  [Cancel]"* ]] ||
    fail "confirm_quit's own footer should say Esc means Cancel, not Quit"

esc_handler="$(grep -A20 '\[\[ "\$action" == "esc" \]\]; then' "$LAUNCHER" | head -20)"
[[ "$esc_handler" == *'confirm_quit'* ]] ||
    fail "the main list's Esc handler should call confirm_quit before actually quitting — raised live: \"I often accidentally exit the brew-launcher with ESC\""
[[ "$esc_handler" == *'if confirm_quit; then'$'\n''            break'* ]] ||
    fail "the main list should only break (quit) when confirm_quit returns true, got: $esc_handler"

printf 'PASS: bulk_hide()/bulk_favorite()/bulk_categorize() correctly do nothing on Esc (previously bulk_categorize fell through to its category prompt due to a zsh empty-array-splitting quirk), still act on a single accepted row with nothing marked, and Esc on the main list now confirms before quitting\n'
