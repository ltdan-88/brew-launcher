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
#
# Extended later for a second live batch:
#   - "the bottom menu is inconsistent — All view shows Fn and
#     alternative keybinds, F2/F9 don't. I prefer a toggle switch that
#     switches between Fn and the alternative keybinds."
#   - "can we add a details pane to F4 that is always on by default,
#     describing what the toggles mean etc."
# The Alt Keybinds toggle is checked as source text, same reasoning as
# the rest of this file — it's read by build_footer()/
# build_picker_footer(), and running either means running
# footer_actions()/picker_footer_action_text(), which trip the same
# `${(l:...)}`-under-set -u quirk noted above. The Actions details
# pane's own content (--internal-preview-action) IS run directly,
# though — it's a plain CLI subcommand like --internal-preview-category,
# no fzf involved.
#
# Extended again for a third live batch, restructuring the menu itself:
#   - "I think that launch preset should be removed from this menu,
#     since it is redundant having F9 always shown."
#   - "Also i would move Create Preset and Create Shortcut up under
#     Categorize."
#   - "All other items are basically settings, so they should be
#     clustered together."
#   - "Preset menu F9 should offer same behavior as F4 menu (details
#     pane always on)."
# The row reorder is checked by position within pick_more_action()'s
# rows array (source text, same reasoning as ever). F9's own
# always-on pane is checked by running launch_preset()'s underlying
# --internal-preview-preset (already covered elsewhere) and by
# confirming its fzf call no longer conditions the preview window on
# DETAILS_VISIBLE or offers f3 at all.

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

# launch_preset (F9) no longer shares DETAILS_VISIBLE at all — see
# section 7 below, "Preset menu F9 should offer same behavior as F4
# menu (details pane always on)."
launch_preset_block="$(sed -n '/^launch_preset() {/,/^}/p' "$LAUNCHER")"

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

main_loop_f3_line="$(grep -n 'DETAILS_VISIBLE=false || DETAILS_VISIBLE=true' "$LAUNCHER" | tail -1 | cut -d: -f1)"
[[ -n "$main_loop_f3_line" ]] ||
    fail "could not find the main list's own F3 toggle line to check nearby"
main_loop_f3_context="$(sed -n "${main_loop_f3_line},$((main_loop_f3_line + 3))p" "$LAUNCHER")"
[[ "$main_loop_f3_context" == *'DETAILS_PINNED=false'* ]] ||
    fail "the main list's own F3 handler should clear DETAILS_PINNED — F3 is always a peek, got: $main_loop_f3_context"

esc_block="$(grep -A3 'action" == "esc" \]\]; then' "$LAUNCHER" | head -4)"
[[ "$esc_block" == *'DETAILS_PINNED'* ]] ||
    fail "the main list's Esc handler should check DETAILS_PINNED before auto-closing the details pane, got: $esc_block"

# ------------------------------------------------------------
# 5. Alt Keybinds: a persisted toggle (Actions -> Alt Keybinds) for
#    whether the footer ever shows a ⌥ alias next to an F-key, wired
#    into config parsing, the Actions row/dispatch, and both
#    footer-building functions.
# ------------------------------------------------------------

[[ "$(grep -c 'CONFIG_ALT_KEYBINDS=""' "$LAUNCHER")" -ge 1 ]] ||
    fail "CONFIG_ALT_KEYBINDS should be declared alongside the other CONFIG_* vars"
[[ "$(grep -c 'ALT_KEYBINDS)        CONFIG_ALT_KEYBINDS="\$config_value"' "$LAUNCHER")" -ge 1 ]] ||
    fail "the config-file parser should recognize an ALT_KEYBINDS line"

[[ "$more_action_block" == *'toggle_alt_keybinds'* ]] ||
    fail "pick_more_action should offer a toggle_alt_keybinds row"
[[ "$more_action_block" == *"'Alt Keybinds'"* ]] ||
    fail "pick_more_action's Alt Keybinds row should be labeled \"Alt Keybinds\""

[[ "$open_menu_block" == *'toggle_alt_keybinds)'* ]] ||
    fail "open_more_menu should dispatch toggle_alt_keybinds"
[[ "$open_menu_block" == *'set_config_value ALT_KEYBINDS'* ]] ||
    fail "open_more_menu's toggle_alt_keybinds case should persist via set_config_value"

build_footer_block="$(sed -n '/^build_footer() {/,/^}/p' "$LAUNCHER")"
[[ "$build_footer_block" == *'CONFIG_ALT_KEYBINDS" == off'* ]] ||
    fail "build_footer should skip the ⌥-alias attempt when CONFIG_ALT_KEYBINDS is off"

build_picker_footer_block="$(sed -n '/^build_picker_footer() {/,/^}/p' "$LAUNCHER")"
[[ "$build_picker_footer_block" == *'CONFIG_ALT_KEYBINDS" == off'* ]] ||
    fail "build_picker_footer should read the same CONFIG_ALT_KEYBINDS toggle as build_footer — see picker-footer-fixtures.sh for the behavior itself"

# ------------------------------------------------------------
# 6. Actions (F4) gets its own always-on F3 details pane, explaining
#    what each row/toggle actually does — run directly, since
#    --internal-preview-action is a plain CLI subcommand.
# ------------------------------------------------------------

[[ "$more_action_block" == *'--internal-preview-action'* ]] ||
    fail "pick_more_action's fzf call should wire up a preview via --internal-preview-action"
[[ "$more_action_block" != *"hidden')" ]] ||
    fail "pick_more_action's preview window should not be conditionally hidden — it's always on by default"

action_preview_output="$("$LAUNCHER" --internal-preview-action toggle_default_categories 2>&1)"
[[ "$action_preview_output" == *'Default Categories'* ]] ||
    fail "--internal-preview-action toggle_default_categories should explain the Default Categories setting, got: $action_preview_output"

action_preview_output="$("$LAUNCHER" --internal-preview-action toggle_alt_keybinds 2>&1)"
[[ "$action_preview_output" == *'Alt Keybinds'* ]] ||
    fail "--internal-preview-action toggle_alt_keybinds should explain the Alt Keybinds setting, got: $action_preview_output"

action_preview_output="$("$LAUNCHER" --internal-preview-action f6 2>&1)"
[[ "$action_preview_output" == *'Hide'* ]] ||
    fail "--internal-preview-action f6 should explain the Hide action, got: $action_preview_output"

action_preview_output="$("$LAUNCHER" --internal-preview-action nonexistent-row-id 2>&1)"
[[ -n "$action_preview_output" ]] ||
    fail "--internal-preview-action should print something even for a row id it doesn't recognize, not go silent"

# ------------------------------------------------------------
# 7. Actions menu restructure: Launch Preset removed (redundant with
#    the always-shown F9), Create Preset/Create Shortcut moved up
#    under Categorize, everything settings-like clustered together,
#    and F9's own details pane made unconditional like F4's.
# ------------------------------------------------------------

# Checked against the actual row-producing line, not a blanket
# substring search — the code's own explanatory comment about this
# removal legitimately says "Launch Preset" too.
[[ "$more_action_block" != *'rows+=("f9"'* ]] ||
    fail "pick_more_action should no longer offer an f9 row — Launch Preset is redundant with F9 already always shown"
[[ "$open_menu_block" != *$'\n            f9)'* ]] ||
    fail "open_more_menu should no longer dispatch f9 to launch_preset — the row is gone"

# Position, not just presence: Create Preset/Create Shortcut should
# come before the has_entry check that starts the settings cluster,
# i.e. right after Categorize (f8), not after Sort/Details/Alt
# Keybinds like before.
rows_order="$(printf '%s\n' "$more_action_block" | grep -oE 'rows\+=\("(f6|f7|f8|create_preset|shortcut|theme|toggle_default_categories|toggle_default_hidden|toggle_open_to_categories|toggle_sort|toggle_details|toggle_alt_keybinds|backup)"')"

f8_pos="$(echo "$rows_order" | grep -n '"f8"' | cut -d: -f1)"
create_preset_pos="$(echo "$rows_order" | grep -n '"create_preset"' | cut -d: -f1)"
shortcut_pos="$(echo "$rows_order" | grep -n '"shortcut"' | cut -d: -f1)"
theme_pos="$(echo "$rows_order" | grep -n '"theme"' | cut -d: -f1)"
backup_pos="$(echo "$rows_order" | grep -n '"backup"' | cut -d: -f1)"

(( f8_pos < create_preset_pos && create_preset_pos < shortcut_pos && shortcut_pos < theme_pos )) ||
    fail "expected row order Categorize -> Create Preset -> Create Shortcut -> Theme, got: $rows_order"
(( theme_pos < backup_pos )) ||
    fail "the settings cluster (starting at Theme) should still come before Backup, got: $rows_order"

# F9's own pane: no longer conditioned on DETAILS_VISIBLE, no f3 in
# --expect, no f3 in its footer spec, no DETAILS_PINNED to clear.
[[ "$launch_preset_block" != *"DETAILS_VISIBLE\" == false"* ]] ||
    fail "launch_preset's preview window should no longer be conditioned on DETAILS_VISIBLE — it's always on now"
[[ "$launch_preset_block" != *'f3'* ]] ||
    fail "launch_preset should no longer expect or offer f3 — its details pane has no toggle anymore"

printf 'PASS: F1/[Help] is in the footer and clickable, F9 works from the view picker, Actions offers a Details toggle mirroring F3, DETAILS_PINNED keeps Esc from undoing a Details choice made via Actions, Alt Keybinds is wired end to end, Actions has its own always-on details pane, Launch Preset is gone from Actions, Create Preset/Create Shortcut sit right under Categorize with settings clustered after, and F9 has its own unconditional details pane\n'
