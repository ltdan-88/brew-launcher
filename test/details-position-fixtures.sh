#!/bin/zsh
#
# Details Position — Settings -> Details Position, toggling whether the
# details/preview pane sits above or below the list.
#
# Raised live: "Toggle for details pane on the top or bottom." Every
# screen with a details/preview pane (main list, F2, F9, Actions,
# Settings) built its own --preview-window value inline, hardcoded to
# "down" (fzf's below-the-list position) — details_preview_window() is
# the shared helper that replaced all five, reading the new
# DETAILS_POSITION global. It's pure (no fzf), so sourced and called
# directly, same approach as theme_position_label() in
# theme-config-fixtures.sh. The Settings row/dispatch wiring is checked
# as source text, same reasoning as the rest of actions-menu-fixtures.sh
# — the picker itself calls fzf.

set -u

SCRIPT_DIR="${0:A:h}"
LAUNCHER="$SCRIPT_DIR/../bin/brew-launcher"

fail() {
    printf 'FAIL: %s\n' "$1" >&2
    exit 1
}

[[ -x "$LAUNCHER" ]] || fail "launcher not found or not executable: $LAUNCHER"

# ------------------------------------------------------------
# 1. details_preview_window() itself — bottom (default) vs top, each
#    with the pane visible and hidden.
# ------------------------------------------------------------

source <(sed -n '/^details_preview_window() {/,/^}/p' "$LAUNCHER")

DETAILS_POSITION="bottom"

out="$(details_preview_window)"
[[ "$out" == "down,35%,border-top,wrap" ]] ||
    fail "bottom position (visible, default arg) should be 'down,35%,border-top,wrap', got: $out"

out="$(details_preview_window true)"
[[ "$out" == "down,35%,border-top,wrap" ]] ||
    fail "bottom position (visible, explicit true) should be 'down,35%,border-top,wrap', got: $out"

out="$(details_preview_window false)"
[[ "$out" == "down,35%,border-top,wrap,hidden" ]] ||
    fail "bottom position, not visible, should append ',hidden', got: $out"

DETAILS_POSITION="top"

out="$(details_preview_window)"
[[ "$out" == "up,35%,border-bottom,wrap" ]] ||
    fail "top position should use fzf's 'up' and flip the border to border-bottom (facing the list), got: $out"

out="$(details_preview_window false)"
[[ "$out" == "up,35%,border-bottom,wrap,hidden" ]] ||
    fail "top position, not visible, should append ',hidden', got: $out"

# ------------------------------------------------------------
# 2. Every screen with a details/preview pane builds its
#    --preview-window value through the shared helper now, not a
#    hardcoded string — otherwise a screen could silently stop
#    respecting the setting.
# ------------------------------------------------------------

hardcoded_count="$(grep -c 'preview-window="down,35%,border-top,wrap' "$LAUNCHER")"
(( hardcoded_count == 0 )) ||
    fail "found $hardcoded_count leftover hardcoded preview-window string(s) — every screen should call details_preview_window() instead"

helper_call_count="$(grep -c 'preview-window="\$(details_preview_window' "$LAUNCHER")"
(( helper_call_count == 5 )) ||
    fail "expected 5 screens (main list, F2, F9, Actions, Settings) to call details_preview_window(), found $helper_call_count"

# ------------------------------------------------------------
# 3. Settings row + dispatch: persisted (unlike Details itself, a
#    per-session peek), cycling bottom <-> top.
# ------------------------------------------------------------

settings_action_block="$(sed -n '/^pick_settings_action() {/,/^}/p' "$LAUNCHER")"
open_settings_block="$(sed -n '/^open_settings_menu() {/,/^}/p' "$LAUNCHER")"

[[ "$settings_action_block" == *'rows+=("toggle_details_position"'* ]] ||
    fail "pick_settings_action should offer a toggle_details_position row"

[[ "$open_settings_block" == *'toggle_details_position)'* ]] ||
    fail "open_settings_menu should dispatch toggle_details_position"

toggle_block="$(printf '%s\n' "$open_settings_block" | sed -n '/toggle_details_position)/,/;;/p')"
[[ "$toggle_block" == *'set_config_value DETAILS_POSITION'* ]] ||
    fail "toggling Details Position should persist via set_config_value, got: $toggle_block"
[[ "$toggle_block" == *"new_value='top'"* && "$toggle_block" == *"new_value='bottom'"* ]] ||
    fail "toggle_details_position should cycle between 'top' and 'bottom', got: $toggle_block"

printf 'PASS: details_preview_window() flips fzf position (down/up) and border side (border-top/border-bottom) with DETAILS_POSITION, honors the visible flag, every one of the 5 details/preview screens uses it (no leftover hardcoded strings), and Settings -> Details Position toggles + persists it\n'
