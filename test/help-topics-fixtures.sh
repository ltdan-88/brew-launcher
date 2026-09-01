#!/bin/zsh
#
# F1 Help — split into a topic picker plus four shorter screens once
# the single scrolling list grew past 100 rows, the same "one level
# down, its own screen" restructuring Settings itself already went
# through for the same reason. pick_help() itself had no test coverage
# at all before this split; added here rather than left uncovered
# going forward.
#
# Everything here is source-text checks, same reasoning
# rename-fixtures.sh gives for the pickers themselves (they call fzf,
# driving them headlessly would need a real TTY or a drive-by refactor
# purely to make it testable) — plus content-preservation spot checks,
# since the real risk in a split like this isn't a crash, it's a fact
# quietly not making it into any of the four new screens.

set -u

SCRIPT_DIR="${0:A:h}"
LAUNCHER="$SCRIPT_DIR/../bin/brew-launcher"

fail() {
    printf 'FAIL: %s\n' "$1" >&2
    exit 1
}

[[ -x "$LAUNCHER" ]] || fail "launcher not found or not executable: $LAUNCHER"

full_source="$(cat "$LAUNCHER")"

pick_help_block="$(sed -n '/^pick_help() {/,/^}/p' "$LAUNCHER")"
[[ -n "$pick_help_block" ]] || fail "pick_help() not found"

# ------------------------------------------------------------
# 1. The topic picker offers exactly the four expected topics, and
#    dispatches each one to its own show_help_*() function.
# ------------------------------------------------------------

# Caught live: the printf field width these labels pad into needs to
# stay wider than the longest one, or that longest label runs straight
# into its own description with no separating space at all — a real
# regression the four topic rows' own tab-delimited real/display split
# alone doesn't catch, since it's only about visible spacing, not the
# underlying data. Extracted rather than hardcoded so this keeps
# working if a label or the field width itself changes later.
field_width="$(printf '%s\n' "$pick_help_block" | sed -n "s/.*printf '%-\\([0-9]*\\)s%s'.*/\\1/p" | sort -u)"
[[ "$field_width" =~ ^[0-9]+$ ]] || fail "could not read pick_help()'s own printf field width"

for topic_label in Keys 'Actions Menu' 'Settings Reference' 'Mouse & Good to Know'; do
    (( ${#topic_label} < field_width )) ||
        fail "topic label '$topic_label' (${#topic_label} chars) doesn't fit inside the $field_width-char field with room for a separating space"
done

for topic_id in keys actions settings mouse; do
    [[ "$pick_help_block" == *"\"$topic_id\"\$'\\t'"* ]] ||
        fail "pick_help() should offer a '$topic_id' topic row"
done

[[ "$pick_help_block" == *'keys)     show_help_keys ;;'* ]] ||
    fail "pick_help() should dispatch 'keys' to show_help_keys"
[[ "$pick_help_block" == *'actions)  show_help_actions_menu ;;'* ]] ||
    fail "pick_help() should dispatch 'actions' to show_help_actions_menu"
[[ "$pick_help_block" == *'settings) show_help_settings_reference ;;'* ]] ||
    fail "pick_help() should dispatch 'settings' to show_help_settings_reference"
[[ "$pick_help_block" == *'mouse)    show_help_mouse_and_notes ;;'* ]] ||
    fail "pick_help() should dispatch 'mouse' to show_help_mouse_and_notes"

# ------------------------------------------------------------
# 2. Esc from the topic picker returns (same as the old single screen
#    did) rather than looping forever or erroring.
# ------------------------------------------------------------

[[ "$pick_help_block" == *'[[ -z "$result" ]] && return 0'* ]] ||
    fail "pick_help() should return on Esc (empty fzf result), same as before the split"

# ------------------------------------------------------------
# 3. All four topic screens exist and actually render something —
#    checked as source text since each is one flat fzf list, same
#    reasoning as pick_help() itself.
# ------------------------------------------------------------

for fn in show_help_keys show_help_actions_menu show_help_settings_reference show_help_mouse_and_notes; do
    fn_block="$(sed -n "/^${fn}() {/,/^}/p" "$LAUNCHER")"
    [[ -n "$fn_block" ]] || fail "$fn() not found"
    [[ "$fn_block" == *'show_help_screen "${rows[@]}"'* ]] ||
        fail "$fn() should render its rows via the shared show_help_screen helper"
done

# ------------------------------------------------------------
# 4. Content-preservation spot checks — a handful of distinctive facts
#    from the old single-screen version, one per topic, confirmed to
#    still exist somewhere after the split rather than having quietly
#    fallen out of it.
# ------------------------------------------------------------

actions_menu_block="$(sed -n '/^show_help_actions_menu() {/,/^}/p' "$LAUNCHER")"

[[ "$full_source" == *'Ctrl-E rearranges it'* ]] ||
    fail "F9's Ctrl-E rearrange fact should have survived the split (expected in Keys)"
[[ "$actions_menu_block" == *'brew-launcher-backup.tar.gz'* ]] ||
    fail "Backup's file path should have survived the split into show_help_actions_menu() specifically (it also appears elsewhere in the file, e.g. BACKUP_FILE's own definition, so a plain full-file check wouldn't catch it going missing from here)"
[[ "$full_source" == *'e.g. \"3 of 10\"'* ]] ||
    fail "Themes' position-indicator example should have survived the split (expected in Settings Reference)"
[[ "$full_source" == *'click the same one again to reverse direction'* ]] ||
    fail "the header-click reverse-direction fact should have survived the split (expected in Mouse & Good to Know)"
[[ "$full_source" == *'can take up to 60s to appear'* ]] ||
    fail "the 60s cache-visibility fact should have survived the split (expected in Mouse & Good to Know)"

printf 'PASS: F1 Help'"'"'s topic picker offers Keys/Actions Menu/Settings Reference/Mouse & Good to Know, dispatches each correctly, Esc still returns the same way the old single screen did, all four topic screens render via the shared helper, and a spot check of distinctive facts from the pre-split screen survived the reorganization\n'
