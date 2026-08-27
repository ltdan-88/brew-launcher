#!/bin/zsh
#
# build_picker_footer() test — the F2/F9 pickers' own width-aware
# footer, added after their static one grew past 90 columns and fzf
# started truncating it mid-word instead of degrading gracefully like
# the main list's own footer already does.
#
# Raised live: "the bottom menu is becoming too wide, would
# harmonizing it with All view make sense?" Confirmed live too, before
# writing this: even the tightest single-line (2-space gap) rung
# didn't fit F2's 6 actions below ~95 columns, which is why there's a
# third, two-line-wrap rung and a test for it here specifically.
#
# Pure function, no fzf/brew/tmux involved — sourced and called
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

source <(sed -n '/^build_picker_footer() {/,/^}/p' "$LAUNCHER")

NAV_FULL='  ↑ ↓  Navigate    Type  Search    Enter  [View]    Esc  [Back]'
NAV_SHORT='  ↑ ↓  Navigate    Enter  [View]    Esc  [Back]'

# F2's real 6 actions, as of this fix.
ACTIONS=('F3  [Details]' 'F4  [Actions]' 'F5  [Refresh]' 'F9  [Presets]' 'Ctrl-R  [Rename]' 'Ctrl-D  [Delete]')

# ------------------------------------------------------------
# 1. Wide terminal: full nav, actions on one line with the roomier
#    4-space gap.
# ------------------------------------------------------------

terminal_width() { echo 200; }

result="$(build_picker_footer "$NAV_FULL" "$NAV_SHORT" "${ACTIONS[@]}")"
lines=("${(@f)result}")

(( ${#lines[@]} == 2 )) ||
    fail "wide terminal: expected 2 lines, got ${#lines[@]}: $result"
[[ "${lines[1]}" == "$NAV_FULL" ]] ||
    fail "wide terminal: line 1 should be the full nav, got: ${lines[1]}"
[[ "${lines[2]}" == *'F3  [Details]    F4  [Actions]'* ]] ||
    fail "wide terminal: line 2 should use the 4-space gap, got: ${lines[2]}"

for line in "${lines[@]}"; do
    (( ${#line} <= 194 )) ||
        fail "wide terminal: line exceeds the computed width (200-6): $line"
done

# ------------------------------------------------------------
# 2. Medium terminal: full nav still fits, but actions need the
#    tighter 2-space gap to stay on one line.
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
# 3. Narrow terminal: neither single-line rung fits 6 actions — wraps
#    to two action lines rather than handing fzf something to
#    truncate mid-word. This is the case confirmed live against the
#    actual reported screenshot's width.
# ------------------------------------------------------------

terminal_width() { echo 90; }

result="$(build_picker_footer "$NAV_FULL" "$NAV_SHORT" "${ACTIONS[@]}")"
lines=("${(@f)result}")

(( ${#lines[@]} == 3 )) ||
    fail "narrow terminal: expected 3 lines (nav + two wrapped action lines), got ${#lines[@]}: $result"

all_actions_text="${lines[2]} ${lines[3]}"
for action in "${ACTIONS[@]}"; do
    [[ "$all_actions_text" == *"$action"* ]] ||
        fail "narrow terminal: \"$action\" missing from the wrapped action lines: $all_actions_text"
done

for line in "${lines[@]}"; do
    (( ${#line} <= 84 )) ||
        fail "narrow terminal: line exceeds the computed width (90-6), got ${#line} chars: $line"
done

# ------------------------------------------------------------
# 4. Nav itself falls back to the short form when even that alone is
#    wider than the terminal.
# ------------------------------------------------------------

terminal_width() { echo 20; }

result="$(build_picker_footer "$NAV_FULL" "$NAV_SHORT" 'F3  [Details]')"
lines=("${(@f)result}")

[[ "${lines[1]}" == "$NAV_SHORT" ]] ||
    fail "very narrow terminal: line 1 should fall back to the short nav, got: ${lines[1]}"

printf 'PASS: build_picker_footer() degrades from a 4-space single line, to a 2-space single line, to a two-line action wrap, and falls back to a shorter nav when needed — verified against the actual width that overflowed live\n'
