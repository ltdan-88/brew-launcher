#!/bin/zsh
#
# build_picker_footer() test — the F2/F9 pickers' own width-aware
# footer, added after their static one grew past 90 columns and fzf
# started truncating it mid-word instead of degrading gracefully like
# the main list's own footer does.
#
# Raised live: "the bottom menu is becoming too wide, would
# harmonizing it with All view make sense?" Confirmed live too, before
# writing this: even the tightest single-line (2-space gap) rung
# didn't fit F2's 6 actions below ~95 columns, which is why there's a
# third, two-line-wrap rung and a test for it here specifically.
#
# Extended later for a second live report: "the bottom menu is
# inconsistent — All view shows Fn and alternative keybinds, F2/F9
# don't. I prefer a toggle switch that switches between Fn and the
# alternative keybinds." build_picker_footer() now takes each action
# as a "FKEY<TAB>LETTER<TAB>[Label]" spec (LETTER empty for a
# Ctrl-combo, which has no ⌥ alias) instead of an already-built
# string, and tries an alias-bearing rung first, same as the main
# list's own footer_actions() — but only when CONFIG_ALT_KEYBINDS
# isn't "off" (Actions -> Alt Keybinds).
#
# Pure functions, no fzf/brew/tmux involved — sourced and called
# directly, with terminal_width() overridden after sourcing (the real
# one shells out to `stty size < /dev/tty`, meaningless outside a
# real terminal) the same way footer-width tests elsewhere in this
# project already do.
#
# Deliberately no `set -u` here, unlike most tests in this project:
# build_picker_footer() (like footer_actions() before it) uses
# `${(l:$width:: :)}` to pad an anonymous parameter, which reports
# "parameter not set" under strict mode even though the real script
# never runs under set -u and the line works fine there — confirmed
# live with a two-line repro when actions-menu-fixtures.sh hit the
# exact same thing for footer_actions(). That one worked around it
# with a source-text assertion instead of running the function; this
# one actually needs to run it (the whole point is validating the
# width arithmetic), so it just doesn't opt into strict mode.

SCRIPT_DIR="${0:A:h}"
LAUNCHER="$SCRIPT_DIR/../bin/brew-launcher"

fail() {
    printf 'FAIL: %s\n' "$1" >&2
    exit 1
}

[[ -x "$LAUNCHER" ]] || fail "launcher not found or not executable: $LAUNCHER"

source <(sed -n '/^picker_footer_action_text() {/,/^}/p' "$LAUNCHER")
source <(sed -n '/^build_picker_footer() {/,/^}/p' "$LAUNCHER")

NAV_FULL='  ↑ ↓  Navigate    Type  Search    Enter  [View]    Esc  [Back]'
NAV_SHORT='  ↑ ↓  Navigate    Enter  [View]    Esc  [Back]'

# F2's real 6 actions, as of this fix — each a "FKEY<TAB>LETTER<TAB>
# [Label]" spec, LETTER empty for the two Ctrl-combos.
ACTIONS=(
    $'F3\tD\t[Details]' $'F4\tM\t[Actions]' $'F5\tR\t[Refresh]'
    $'F9\tP\t[Presets]' $'Ctrl-R\t\t[Rename]' $'Ctrl-D\t\t[Delete]'
)

# CONFIG_ALT_KEYBINDS defaults to on (unset/anything but "off") — same
# convention as CONFIG_DEFAULT_CATEGORIES etc.
CONFIG_ALT_KEYBINDS=""

# ------------------------------------------------------------
# 1. Wide terminal: full nav, actions on one line with the roomier
#    4-space gap and — Alt Keybinds on (the default) — each F-key's
#    ⌥ alias.
# ------------------------------------------------------------

terminal_width() { echo 200; }

result="$(build_picker_footer "$NAV_FULL" "$NAV_SHORT" "${ACTIONS[@]}")"
lines=("${(@f)result}")

(( ${#lines[@]} == 2 )) ||
    fail "wide terminal: expected 2 lines, got ${#lines[@]}: $result"
[[ "${lines[1]}" == "$NAV_FULL" ]] ||
    fail "wide terminal: line 1 should be the full nav, got: ${lines[1]}"
[[ "${lines[2]}" == *'F3/⌥D  [Details]    F4/⌥M  [Actions]'* ]] ||
    fail "wide terminal: line 2 should show ⌥ aliases at the 4-space gap, got: ${lines[2]}"
[[ "${lines[2]}" == *'Ctrl-R  [Rename]'* ]] ||
    fail "wide terminal: Ctrl-R has no ⌥ alias and should render plain, got: ${lines[2]}"

for line in "${lines[@]}"; do
    (( ${#line} <= 194 )) ||
        fail "wide terminal: line exceeds the computed width (200-6): $line"
done

# ------------------------------------------------------------
# 1b. Same wide terminal, Alt Keybinds turned off: no aliases at all,
#     even though there'd be plenty of room to show them. This is the
#     toggle itself, not width degradation.
# ------------------------------------------------------------

CONFIG_ALT_KEYBINDS="off"

result="$(build_picker_footer "$NAV_FULL" "$NAV_SHORT" "${ACTIONS[@]}")"
lines=("${(@f)result}")

[[ "${lines[2]}" != *'/⌥'* ]] ||
    fail "Alt Keybinds off: line 2 should never show a ⌥ alias regardless of width, got: ${lines[2]}"
[[ "${lines[2]}" == *'F3  [Details]    F4  [Actions]'* ]] ||
    fail "Alt Keybinds off: line 2 should still use the roomy 4-space gap, got: ${lines[2]}"

CONFIG_ALT_KEYBINDS=""

# ------------------------------------------------------------
# 1c. A width where the alias rung alone doesn't fit but the plain
#     F-key rung at the same 4-space gap does — Alt Keybinds on should
#     fall through to that plain rung rather than jumping straight to
#     the tighter 2-space gap, same degradation order as before this
#     toggle existed.
# ------------------------------------------------------------

terminal_width() { echo 120; }

result="$(build_picker_footer "$NAV_FULL" "$NAV_SHORT" "${ACTIONS[@]}")"
lines=("${(@f)result}")

[[ "${lines[2]}" != *'/⌥'* ]] ||
    fail "120-column terminal: alias rung shouldn't fit here, expected the plain 4-space rung, got: ${lines[2]}"
[[ "${lines[2]}" == *'F3  [Details]    F4  [Actions]'* ]] ||
    fail "120-column terminal: expected the plain 4-space gap rung, got: ${lines[2]}"

# ------------------------------------------------------------
# 2. Medium terminal: neither the alias rung nor the plain 4-space
#    rung fits — falls to the tighter 2-space gap, same as before Alt
#    Keybinds existed (this rung has never shown aliases).
# ------------------------------------------------------------

terminal_width() { echo 110; }

result="$(build_picker_footer "$NAV_FULL" "$NAV_SHORT" "${ACTIONS[@]}")"
lines=("${(@f)result}")

(( ${#lines[@]} == 2 )) ||
    fail "medium terminal: expected 2 lines (actions still fit on one at 2-space gap), got ${#lines[@]}: $result"
[[ "${lines[2]}" == *'F3  [Details]  F4  [Actions]'* ]] ||
    fail "medium terminal: line 2 should use the tighter 2-space gap, got: ${lines[2]}"
[[ "${lines[2]}" != *'F3  [Details]    F4  [Actions]'* ]] ||
    fail "medium terminal: line 2 should not still be using the 4-space gap, got: ${lines[2]}"

for line in "${lines[@]}"; do
    (( ${#line} <= 104 )) ||
        fail "medium terminal: line exceeds the computed width (110-6): $line"
done

# ------------------------------------------------------------
# 3. Narrow terminal: no single-line rung fits 6 actions — wraps to
#    two action lines rather than handing fzf something to truncate
#    mid-word. This is the case confirmed live against the actual
#    reported screenshot's width. Always without aliases, even with
#    Alt Keybinds on — there's even less room here than the rung that
#    already dropped them.
# ------------------------------------------------------------

terminal_width() { echo 90; }

result="$(build_picker_footer "$NAV_FULL" "$NAV_SHORT" "${ACTIONS[@]}")"
lines=("${(@f)result}")

(( ${#lines[@]} == 3 )) ||
    fail "narrow terminal: expected 3 lines (nav + two wrapped action lines), got ${#lines[@]}: $result"

all_actions_text="${lines[2]} ${lines[3]}"
for spec in "${ACTIONS[@]}"; do
    plain="$(picker_footer_action_text "$spec" 0)"
    [[ "$all_actions_text" == *"$plain"* ]] ||
        fail "narrow terminal: \"$plain\" missing from the wrapped action lines: $all_actions_text"
done

[[ "$all_actions_text" != *'/⌥'* ]] ||
    fail "narrow terminal: wrapped action lines should never show ⌥ aliases, got: $all_actions_text"

for line in "${lines[@]}"; do
    (( ${#line} <= 84 )) ||
        fail "narrow terminal: line exceeds the computed width (90-6), got ${#line} chars: $line"
done

# ------------------------------------------------------------
# 4. Nav itself falls back to the short form when even that alone is
#    wider than the terminal.
# ------------------------------------------------------------

terminal_width() { echo 20; }

result="$(build_picker_footer "$NAV_FULL" "$NAV_SHORT" $'F3\tD\t[Details]')"
lines=("${(@f)result}")

[[ "${lines[1]}" == "$NAV_SHORT" ]] ||
    fail "very narrow terminal: line 1 should fall back to the short nav, got: ${lines[1]}"

printf 'PASS: build_picker_footer() degrades from an alias-bearing 4-space line, to plain-F-key 4-space, to plain-F-key 2-space, to a two-line action wrap, respects the Alt Keybinds toggle, and falls back to a shorter nav when needed — verified against the actual width that overflowed live\n'
