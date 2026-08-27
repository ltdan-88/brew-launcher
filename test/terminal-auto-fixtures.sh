#!/bin/zsh
#
# resolve_auto_terminal() test — the decision behind "auto", covering
# exactly the case that's caused two live-reported hangs: launching
# something (a preset, then an individual tool) over SSH used to still
# reach for Ghostty, a GUI window with no display to open in over a
# text-only connection. Sourced and called directly against real env
# vars, the same technique category-fixtures.sh already uses for pure
# decision logic in this file — no fzf, no interactivity, nothing that
# needs a live tmux/Ghostty session to actually open.

set -u

SCRIPT_DIR="${0:A:h}"
LAUNCHER="$SCRIPT_DIR/../bin/brew-launcher"

fail() {
    printf 'FAIL: %s\n' "$1" >&2
    exit 1
}

[[ -x "$LAUNCHER" ]] || fail "launcher not found or not executable: $LAUNCHER"

# Sourced straight out of the real file rather than re-typed here, so
# this can't quietly drift out of sync with the actual logic.
source <(sed -n '/^is_ssh_session() {/,/^}/p' "$LAUNCHER")
source <(sed -n '/^resolve_auto_terminal() {/,/^}/p' "$LAUNCHER")

# ------------------------------------------------------------
# 1. Over SSH, already inside a tmux session -> tmux. The one case
#    that's a genuine behavior change from before: auto used to never
#    choose tmux at all.
# ------------------------------------------------------------

result="$(SSH_TTY=/dev/fake SSH_CONNECTION= SSH_CLIENT= TMUX="/tmp/fake,1,0" resolve_auto_terminal)"
[[ "$result" == "tmux" ]] ||
    fail "SSH + already in tmux should resolve to tmux, got: $result"

# ------------------------------------------------------------
# 2. Over SSH, not inside tmux -> current. Never Ghostty here even if
#    it's actually installed on this machine — this is the exact
#    scenario that hung before: reaching for a GUI window with no
#    display over a text-only SSH connection.
# ------------------------------------------------------------

result="$(SSH_TTY=/dev/fake SSH_CONNECTION= SSH_CLIENT= TMUX= resolve_auto_terminal)"
[[ "$result" == "current" ]] ||
    fail "SSH + not in tmux should resolve to current, got: $result"

# Same again via the other two SSH env vars individually, so this
# isn't only ever exercised through SSH_TTY.
result="$(SSH_TTY= SSH_CONNECTION="1.2.3.4 1 5.6.7.8 22" SSH_CLIENT= TMUX= resolve_auto_terminal)"
[[ "$result" == "current" ]] ||
    fail "SSH_CONNECTION alone should be enough to detect SSH, got: $result"

result="$(SSH_TTY= SSH_CONNECTION= SSH_CLIENT="1.2.3.4 1 22" TMUX= resolve_auto_terminal)"
[[ "$result" == "current" ]] ||
    fail "SSH_CLIENT alone should be enough to detect SSH, got: $result"

# ------------------------------------------------------------
# 3. Not over SSH, no Ghostty.app present -> current. Covers any
#    non-Ghostty machine (Linux, or a Mac without it installed) —
#    can't assume Ghostty is actually here on the runner, so this only
#    asserts the fallback, not the Ghostty branch itself.
# ------------------------------------------------------------

if [[ ! -d "/Applications/Ghostty.app" ]]; then
    result="$(SSH_TTY= SSH_CONNECTION= SSH_CLIENT= resolve_auto_terminal)"
    [[ "$result" == "current" ]] ||
        fail "no SSH and no Ghostty should resolve to current, got: $result"
else
    echo "SKIP: Ghostty.app present on this machine — case 3 needs its absence to test the fallback"
fi

# ------------------------------------------------------------
# 4. Not over SSH, Ghostty.app present -> ghostty. The inverse of (3),
#    only runs where Ghostty actually is installed (a CI runner won't
#    have it, so this skips there rather than failing).
# ------------------------------------------------------------

if [[ "$(uname -s)" == "Darwin" ]] &&
   command -v osascript >/dev/null 2>&1 &&
   [[ -d "/Applications/Ghostty.app" ]]; then
    result="$(SSH_TTY= SSH_CONNECTION= SSH_CLIENT= resolve_auto_terminal)"
    [[ "$result" == "ghostty" ]] ||
        fail "no SSH, Ghostty present, should resolve to ghostty, got: $result"
else
    echo "SKIP: Ghostty.app not present on this machine — case 4 needs it to test that branch"
fi

printf 'PASS: auto resolves to tmux over SSH when already in a session, to current over SSH otherwise (via any of the three SSH env vars), and to current or ghostty locally depending on whether Ghostty is actually installed\n'
