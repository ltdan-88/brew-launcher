#!/bin/zsh
#
# "*" on the border label when a newer brew-launcher is available.
#
# Raised live: "would it make sense to put an asterisk behind the
# brew-launcher version... whenever a newer version is available?"
# launcher_update_marker() is a pure hash lookup against
# outdated_formulas (the same snapshot every other "*" marker in this
# app already reads from) — sourced and called directly with that
# array populated by hand, no fzf/brew/tmux needed.

set -u

SCRIPT_DIR="${0:A:h}"
LAUNCHER="$SCRIPT_DIR/../bin/brew-launcher"

fail() {
    printf 'FAIL: %s\n' "$1" >&2
    exit 1
}

[[ -x "$LAUNCHER" ]] || fail "launcher not found or not executable: $LAUNCHER"

typeset -A outdated_formulas

source <(sed -n '/^launcher_update_marker() {/,/^}/p' "$LAUNCHER")
source <(sed -n '/^screen_border_label() {/,/^}/p' "$LAUNCHER")

VERSION="9.9.9"

# ------------------------------------------------------------
# 1. Not outdated: no marker, either directly or via the border label.
# ------------------------------------------------------------

outdated_formulas=()

[[ -z "$(launcher_update_marker)" ]] ||
    fail "launcher_update_marker should print nothing when brew-launcher isn't in outdated_formulas"

[[ "$(screen_border_label 'View')" != *'*'* ]] ||
    fail "screen_border_label should not include an asterisk when brew-launcher isn't outdated"

# ------------------------------------------------------------
# 2. Outdated: marker shows, in both the bare function and the label.
# ------------------------------------------------------------

outdated_formulas=(brew-launcher "99.0.0")

[[ "$(launcher_update_marker)" == "*" ]] ||
    fail "launcher_update_marker should print a bare * when brew-launcher is in outdated_formulas"

[[ "$(screen_border_label 'View')" == *"v${VERSION}*"* ]] ||
    fail "screen_border_label should show v\$VERSION* when brew-launcher is outdated, got: $(screen_border_label 'View')"

# ------------------------------------------------------------
# 3. Some other formula being outdated doesn't trigger it — this is
#    specifically about brew-launcher itself, not "anything outdated."
# ------------------------------------------------------------

outdated_formulas=(fastfetch "3.0.0")

[[ -z "$(launcher_update_marker)" ]] ||
    fail "launcher_update_marker should ignore other outdated formulae, only brew-launcher itself"

printf 'PASS: launcher_update_marker() and screen_border_label() show "*" only when brew-launcher itself is outdated\n'
