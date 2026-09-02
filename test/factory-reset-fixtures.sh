#!/bin/zsh
#
# Factory Reset — Actions -> Factory Reset.
#
# Raised live: wanting a clean way to undo months of accumulated
# organizing (categories, favorites, hidden entries, presets, launch
# flags, recorded launches, and every preference) without hand-
# deleting each one individually.
#
# Wipes CONFIG_DIR wholesale and relaunches via `exec "$SCRIPT_PATH"`,
# rather than resetting each of the dozen or so in-memory tables by
# hand — a real fresh `exec` runs the exact startup sequence a real
# fresh install would, so there's nothing left to reset piecemeal and
# no way to miss one. Live end-to-end coverage of that relaunch lives
# in this file's own manual verification (favoriting/hiding a tool,
# confirming Factory Reset, and checking both markers cleared after
# relaunch, plus CONFIG_DIR genuinely gone from disk) — not repeated
# here as an automated test, since `exec` replacing the whole process
# mid-test doesn't fit this suite's process model any better than it
# does confirm_quit()'s own real fzf interaction (see
# bulk-cancel-and-quit-confirm-fixtures.sh's own comment for why that
# one is source-text only too). This is source text for the same
# reason: confirm_factory_reset() calls a real fzf, so it — and its
# wiring into the menu/dispatch — is checked as source text instead.

set -u

SCRIPT_DIR="${0:A:h}"
LAUNCHER="$SCRIPT_DIR/../bin/brew-launcher"

fail() {
    printf 'FAIL: %s\n' "$1" >&2
    exit 1
}

[[ -x "$LAUNCHER" ]] || fail "launcher not found or not executable: $LAUNCHER"

# ------------------------------------------------------------
# 1. The Actions menu offers a Factory Reset row, not gated on
#    has_entry (nothing about it concerns any one row, same reasoning
#    as Backup/Launch History right above it), landing after both —
#    the one genuinely destructive row here shouldn't sit any closer
#    to the top than it has to.
# ------------------------------------------------------------

more_action_block="$(sed -n '/^pick_more_action() {/,/^}/p' "$LAUNCHER")"
[[ "$more_action_block" == *'"factory_reset"'*'Factory Reset'* ]] ||
    fail "pick_more_action should offer a Factory Reset row"

# Comes after both backup and launch_history rows in the source,
# matching "landing after both" above — a plain substring position
# check on the whole function body.
backup_pos="${more_action_block%%'"backup"'*}"
launch_history_pos="${more_action_block%%'"launch_history"'*}"
factory_reset_pos="${more_action_block%%'"factory_reset"'*}"

[[ "${#factory_reset_pos}" -gt "${#backup_pos}" ]] ||
    fail "Factory Reset should be listed after Backup in pick_more_action()"
[[ "${#factory_reset_pos}" -gt "${#launch_history_pos}" ]] ||
    fail "Factory Reset should be listed after Launch History in pick_more_action()"

# ------------------------------------------------------------
# 2. open_more_menu() dispatches the row to a real factory_reset()
#    function, same shape as backup/launch_history right above it.
# ------------------------------------------------------------

open_menu_block="$(sed -n '/^open_more_menu() {/,/^}/p' "$LAUNCHER")"
[[ "$open_menu_block" == *'factory_reset)'*'factory_reset'* ]] ||
    fail "open_more_menu should dispatch the factory_reset row to a factory_reset function"

# ------------------------------------------------------------
# 3. confirm_factory_reset(): Cancel-first, same safe-default idiom as
#    confirm_quit()/confirm_delete_preset(), shows real counts (not a
#    generic "everything") in the confirming row itself so the stakes
#    are concrete before choosing, and says up front that this can't
#    be undone.
# ------------------------------------------------------------

confirm_block="$(sed -n '/^confirm_factory_reset() {/,/^}/p' "$LAUNCHER")"
[[ -n "$confirm_block" ]] || fail "confirm_factory_reset() not found"
[[ "$confirm_block" == *'"Cancel" "Reset everything'* ]] ||
    fail "confirm_factory_reset should list Cancel first, same safe-default convention as confirm_quit/confirm_delete_preset"
[[ "$confirm_block" == *'category_count'* && "$confirm_block" == *'preset_count'* \
   && "$confirm_block" == *'hidden_count'* && "$confirm_block" == *'favorite_count'* \
   && "$confirm_block" == *'history_count'* ]] ||
    fail "confirm_factory_reset should show real counts for categories, presets, hidden entries, favorites, and history, not a vague 'everything'"
[[ "$confirm_block" == *"can't be undone"* ]] ||
    fail "confirm_factory_reset should say up front that this can't be undone"
[[ "$confirm_block" == *'Backup'* ]] ||
    fail "confirm_factory_reset should point at Backup as a way to keep a copy first"
[[ "$confirm_block" == *"Esc  [Cancel]"* ]] ||
    fail "confirm_factory_reset should let Esc cancel, same as confirm_quit/confirm_delete_preset"

# ------------------------------------------------------------
# 4. factory_reset(): gated on confirm_factory_reset (a "no" must
#    prevent the delete — checked by position, not just presence, so a
#    future refactor can't move the delete ahead of the gate), wipes
#    CONFIG_DIR wholesale rather than resetting tables by hand, and
#    relaunches via exec rather than falling through to a stale
#    in-memory state or a plain shell.
# ------------------------------------------------------------

factory_reset_block="$(sed -n '/^factory_reset() {/,/^}/p' "$LAUNCHER")"
[[ -n "$factory_reset_block" ]] || fail "factory_reset() not found"

confirm_call_pos="${factory_reset_block%%'confirm_factory_reset'*}"
rm_pos="${factory_reset_block%%'rm -rf "$CONFIG_DIR"'*}"
exec_pos="${factory_reset_block%%'exec "$SCRIPT_PATH"'*}"

[[ "$factory_reset_block" == *'confirm_factory_reset || return 1'* ]] ||
    fail "factory_reset should return early when confirm_factory_reset says no, not delete unconditionally"
[[ "${#confirm_call_pos}" -lt "${#rm_pos}" ]] ||
    fail "factory_reset should check confirm_factory_reset BEFORE deleting CONFIG_DIR, not after"
[[ "$factory_reset_block" == *'rm -rf "$CONFIG_DIR"'* ]] ||
    fail "factory_reset should delete CONFIG_DIR wholesale"
[[ "${#rm_pos}" -lt "${#exec_pos}" ]] ||
    fail "factory_reset should delete CONFIG_DIR BEFORE relaunching, not after"
[[ "$factory_reset_block" == *'exec "$SCRIPT_PATH"'* ]] ||
    fail "factory_reset should relaunch via exec, same technique used elsewhere in this file for relaunching in place — see this function's own comment for why resetting a dozen in-memory tables by hand is the wrong alternative"

# CACHE_DIR (the installed-tools cache, unrelated to anything a person
# organized) should never be touched — only CONFIG_DIR.
[[ "$factory_reset_block" != *'CACHE_DIR'* ]] ||
    fail "factory_reset should not touch CACHE_DIR — that's just the installed-tools cache, and rebuilds on its own regardless"

# ------------------------------------------------------------
# 5. The always-on Actions details pane (--internal-preview-action)
#    has a real entry for the row, same as every other Actions row —
#    otherwise it would silently fall through to the "No description
#    available" catch-all.
# ------------------------------------------------------------

preview_action_block="$(sed -n '/^if \[\[ "\$1" == "--internal-preview-action" \]\]; then/,/^fi/p' "$LAUNCHER")"
[[ "$preview_action_block" == *'factory_reset)'*'Factory Reset'* ]] ||
    fail "--internal-preview-action should have a real description for the factory_reset row, not fall through to the catch-all"

printf 'PASS: Factory Reset is offered in Actions (not gated on has_entry, landing after Backup/Launch History), dispatches to a real factory_reset() function, confirm_factory_reset() lists Cancel first with real counts and a cannot-be-undone warning, factory_reset() checks the confirm gate before deleting CONFIG_DIR and relaunches via exec afterward without ever touching CACHE_DIR, and the Actions details pane describes the row\n'
