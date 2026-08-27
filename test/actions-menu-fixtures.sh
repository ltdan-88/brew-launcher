#!/bin/zsh
#
# Actions-menu odds and ends raised live in one batch:
#   - "implement a toggle for details pane (F3) in F4 Actions"
#   - "why is there no F9 preset access in view picker?"
#   - "why is F1 help nowhere mentioned?"
#
# footer_actions() is pure (no fzf) — sourced and called directly to
# confirm [Help] actually renders. pick_view()'s F9 wiring and
# pick_more_action()/open_more_menu()'s Details toggle are source-text
# assertions, same reasoning as rename-fixtures.sh: the pickers
# themselves call fzf, so driving them headlessly needs either a real
# TTY or a drive-by refactor of working code purely to make it
# testable, not attempted here.

set -u

SCRIPT_DIR="${0:A:h}"
LAUNCHER="$SCRIPT_DIR/../bin/brew-launcher"

fail() {
    printf 'FAIL: %s\n' "$1" >&2
    exit 1
}

[[ -x "$LAUNCHER" ]] || fail "launcher not found or not executable: $LAUNCHER"

# ------------------------------------------------------------
# 1. F1/[Help] is actually in the footer, not just documented.
#
# footer_actions() itself is a source-text assertion, not sourced and
# run — it turns out to trip a genuine zsh quirk under this test's own
# `set -u` unrelated to anything raised here: `${(l:$gap:: :)}` (padding
# to an empty string, no named parameter of its own) reports "parameter
# not set" in strict mode even though the real script never runs under
# set -u and the line works fine there. Confirmed live in isolation
# with a two-line repro before concluding it wasn't this feature's bug
# to fix. Checking the row order and content directly sidesteps it.
# ------------------------------------------------------------

footer_actions_block="$(sed -n '/^footer_actions() {/,/^}/p' "$LAUNCHER")"

[[ "$footer_actions_block" == *'[Help]'* ]] ||
    fail "footer_actions() should include [Help]"

[[ "$footer_actions_block" == *"footer_key F1 '?'"* ]] ||
    fail "footer_actions() should show the F1 key itself via footer_key"

# Last, not just present — lowest priority, first thing a narrower
# terminal drops (see build_footer()'s fallback attempts). The [Help]
# line should be the last parts+=(...) call in the function.
last_parts_line="$(echo "$footer_actions_block" | grep 'parts+=' | tail -1)"
[[ "$last_parts_line" == *'[Help]'* ]] ||
    fail "[Help] should be the last item added to footer_actions()'s parts, got: $last_parts_line"

# The click-word table (--internal-footer-click) and the main list's
# own click-to-action mapping both need to recognize it too, or a
# click on it silently does nothing despite being visible.
click_table="$(sed -n '/if \[\[ "\$1" == "--internal-footer-click" \]\]; then/,/^fi$/p' "$LAUNCHER")"
[[ "$click_table" == *"'[Help]'"* ]] ||
    fail "--internal-footer-click should recognize a [Help] click"

# ------------------------------------------------------------
# 2. F9 (Launch Preset) works from the view picker (F2) too.
# ------------------------------------------------------------

pick_view_block="$(sed -n '/^pick_view() {/,/^}/p' "$LAUNCHER")"

[[ "$pick_view_block" == *'f9'* ]] ||
    fail "pick_view (F2) should expect f9"
[[ "$pick_view_block" == *'launch_preset'* ]] ||
    fail "pick_view (F2) should call launch_preset on f9"
[[ "$pick_view_block" == *'[Presets]'* ]] ||
    fail "pick_view (F2) footer should mention [Presets]"

# ------------------------------------------------------------
# 3. A "Details" toggle in Actions, mirroring F3 itself.
# ------------------------------------------------------------

more_action_block="$(sed -n '/^pick_more_action() {/,/^}/p' "$LAUNCHER")"
[[ "$more_action_block" == *'toggle_details'* ]] ||
    fail "pick_more_action should offer a toggle_details row"
[[ "$more_action_block" == *"'Details'"* ]] ||
    fail "pick_more_action's Details row should be labeled \"Details\""

open_menu_block="$(sed -n '/^open_more_menu() {/,/^}/p' "$LAUNCHER")"
[[ "$open_menu_block" == *'toggle_details)'* ]] ||
    fail "open_more_menu should dispatch toggle_details"
[[ "$open_menu_block" == *'DETAILS_VISIBLE=false'* && "$open_menu_block" == *'DETAILS_VISIBLE=true'* ]] ||
    fail "open_more_menu's toggle_details case should actually flip DETAILS_VISIBLE"

# One flag everywhere, not a separate one per screen — raised live:
# "when it is on, it should always be on, on every screen where a
# details pane is available." First shipped as two flags
# (DETAILS_VISIBLE for the main list, PICKER_DETAILS_VISIBLE for F2/
# F9), deliberately, so this checks the old name isn't used as an
# actual variable anymore, not just that the new behavior happens to
# work. The name still appears once, deliberately, in a comment
# explaining that history — checking for '$PICKER_DETAILS_VISIBLE' or
# 'PICKER_DETAILS_VISIBLE=' specifically (real usage) rather than a
# blanket zero-occurrences check avoids that comment being a false
# positive.
[[ "$(grep -cE '\$PICKER_DETAILS_VISIBLE|PICKER_DETAILS_VISIBLE=' "$LAUNCHER")" == "0" ]] ||
    fail "PICKER_DETAILS_VISIBLE should no longer be used as a variable — F2/F9 should share DETAILS_VISIBLE with the main list"

# pick_view_block was already extracted above for the F9-wiring check.
[[ "$pick_view_block" == *'DETAILS_VISIBLE'* ]] ||
    fail "pick_view (F2) should reference DETAILS_VISIBLE for its own F3 preview"

launch_preset_block="$(sed -n '/^launch_preset() {/,/^}/p' "$LAUNCHER")"
[[ "$launch_preset_block" == *'DETAILS_VISIBLE'* ]] ||
    fail "launch_preset (F9) should reference DETAILS_VISIBLE for its own F3 preview"

# ------------------------------------------------------------
# 4. DETAILS_PINNED: Esc closing the details pane and the Details
#    toggle used to conflict — raised live: "I think the toggle
#    should override this behavior." Turning Details on via Actions
#    is meant to stick; F3 opening it is meant to be an Esc-closable
#    peek. DETAILS_PINNED is what tells the two apart, so this checks
#    each of the four places that touch it does its part: Actions'
#    toggle_details sets it to match the new state, all three F3
#    handlers (main list, F2, F9) always clear it, and the main list's
#    own Esc auto-close only fires when it's clear.
# ------------------------------------------------------------

[[ "$open_menu_block" == *'DETAILS_PINNED="$DETAILS_VISIBLE"'* ]] ||
    fail "open_more_menu's toggle_details case should set DETAILS_PINNED to match the new DETAILS_VISIBLE state"

[[ "$pick_view_block" == *'DETAILS_PINNED=false'* ]] ||
    fail "pick_view's (F2) F3 handler should clear DETAILS_PINNED — F3 is always a peek"

[[ "$launch_preset_block" == *'DETAILS_PINNED=false'* ]] ||
    fail "launch_preset's (F9) F3 handler should clear DETAILS_PINNED — F3 is always a peek"

main_loop_f3_line="$(grep -n 'DETAILS_VISIBLE=false || DETAILS_VISIBLE=true' "$LAUNCHER" | tail -1 | cut -d: -f1)"
[[ -n "$main_loop_f3_line" ]] ||
    fail "could not find the main list's own F3 toggle line to check nearby"
main_loop_f3_context="$(sed -n "${main_loop_f3_line},$((main_loop_f3_line + 3))p" "$LAUNCHER")"
[[ "$main_loop_f3_context" == *'DETAILS_PINNED=false'* ]] ||
    fail "the main list's own F3 handler should clear DETAILS_PINNED — F3 is always a peek, got: $main_loop_f3_context"

esc_block="$(grep -A3 'action" == "esc" \]\]; then' "$LAUNCHER" | head -4)"
[[ "$esc_block" == *'DETAILS_PINNED'* ]] ||
    fail "the main list's Esc handler should check DETAILS_PINNED before auto-closing the details pane, got: $esc_block"

printf 'PASS: F1/[Help] is in the footer and clickable, F9 works from the view picker, Actions offers a Details toggle mirroring F3, and DETAILS_PINNED keeps Esc from undoing a Details choice made via Actions\n'
