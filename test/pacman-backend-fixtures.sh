#!/bin/zsh
#
# pacman backend — BREW_LAUNCHER_BACKEND detection, every place that
# used to unconditionally mean "the brew command" branching on it
# instead, and a real end-to-end run against actual pacman data.
#
# The live section below only actually exercises real pacman commands
# on a machine that has pacman at all — everywhere else (every real
# CI runner today except the dedicated Arch container this was built
# for) it skips gracefully, same convention every other
# optional-dependency live check in this suite already follows.

set -u

SCRIPT_DIR="${0:A:h}"
LAUNCHER="$SCRIPT_DIR/../bin/brew-launcher"
CACHE_WRITER_PACMAN_PY="$SCRIPT_DIR/../lib/brew-launcher/cache_writer_pacman.py"

fail() {
    printf 'FAIL: %s\n' "$1" >&2
    exit 1
}

[[ -x "$LAUNCHER" ]] || fail "launcher not found or not executable: $LAUNCHER"
[[ -f "$CACHE_WRITER_PACMAN_PY" ]] || fail "cache_writer_pacman.py not found: $CACHE_WRITER_PACMAN_PY"

python3 -m py_compile "$CACHE_WRITER_PACMAN_PY" ||
    fail "cache_writer_pacman.py has a syntax error"

full_source="$(cat "$LAUNCHER")"

# ------------------------------------------------------------
# 1. BACKEND resolution: auto prefers Homebrew when it's on PATH,
#    only falls back to pacman when brew genuinely isn't there —
#    never the reverse — and BREW_LAUNCHER_BACKEND overrides both.
# ------------------------------------------------------------

[[ "$full_source" == *'BACKEND="$BREW_LAUNCHER_BACKEND"'* ]] ||
    fail "an explicit BREW_LAUNCHER_BACKEND should override auto-detection"
[[ "$full_source" == *'elif command -v brew >/dev/null 2>&1; then'*$'\n'*'BACKEND="homebrew"'* ]] ||
    fail "auto-detection should check for brew before pacman"

# Run for real: BACKEND should resolve to whichever of brew/pacman is
# actually on PATH in this exact environment, with no override set.
detected_backend="$(BREW_LAUNCHER_BACKEND= zsh -c "
    source <(sed -n '1,/^VERSION=/p' '$LAUNCHER' | sed '\$d')
    print -r -- \$BACKEND
")"

if command -v brew >/dev/null 2>&1; then
    [[ "$detected_backend" == "homebrew" ]] ||
        fail "expected auto-detection to pick homebrew when brew is on PATH, got: $detected_backend"
elif command -v pacman >/dev/null 2>&1; then
    [[ "$detected_backend" == "pacman" ]] ||
        fail "expected auto-detection to pick pacman when brew isn't on PATH but pacman is, got: $detected_backend"
fi

# ------------------------------------------------------------
# 2. Every place that used to unconditionally mean "the brew command"
#    now branches on $BACKEND — checked as source text, since each of
#    these either shells out for real or launches an interactive
#    picker, neither practical to run for real here.
# ------------------------------------------------------------

[[ "$full_source" == *'[[ "$dependency" == "brew" && "$BACKEND" == "pacman" ]] && dependency="pacman"'* ]] ||
    fail "the startup dependency check should require pacman instead of brew when that's the resolved backend"

get_state_block="$(sed -n '/^get_state() {/,/^}/p' "$LAUNCHER")"
[[ "$get_state_block" == *'pacman -Qe'* ]] ||
    fail "get_state() should use pacman -Qe for the pacman backend"

fetch_outdated_block="$(sed -n '/^fetch_outdated_formulae() {/,/^}/p' "$LAUNCHER")"
[[ "$fetch_outdated_block" == *'pacman -Qu'* ]] ||
    fail "fetch_outdated_formulae() should use pacman -Qu for the pacman backend"

[[ "$full_source" == *'rebuild_cache_pacman()'* ]] ||
    fail "rebuild_cache_pacman() should exist"
rebuild_cache_block="$(sed -n '/^rebuild_cache() {/,/^}/p' "$LAUNCHER")"
[[ "$rebuild_cache_block" == *'rebuild_cache_pacman'* ]] ||
    fail "rebuild_cache() should dispatch to rebuild_cache_pacman() for the pacman backend"

update_all_block="$(sed -n '/^update_all() {/,/^}/p' "$LAUNCHER")"
[[ "$update_all_block" == *'needs root on this backend'* ]] ||
    fail "update_all() should refuse cleanly on the pacman backend rather than attempting pacman -Syu"

update_tool_block="$(sed -n '/^update_tool() {/,/^}/p' "$LAUNCHER")"
[[ "$update_tool_block" == *'needs root on this backend'* ]] ||
    fail "update_tool() should refuse cleanly on the pacman backend rather than attempting pacman -S"

# ------------------------------------------------------------
# 3. Live: a real, cold-start launch against real pacman data — only
#    where pacman is actually available (the dedicated CI container
#    this was built for; skipped everywhere else, same convention as
#    every other optional-dependency live check in this suite).
# ------------------------------------------------------------

if ! command -v pacman >/dev/null 2>&1; then
    printf 'SKIP: pacman not available, skipping the live backend test\n' >&2
    printf 'PASS: pacman backend wiring verified as source text (BACKEND resolution, dependency check, get_state/fetch_outdated_formulae/rebuild_cache dispatch, Update/Update All root guards)\n'
    exit 0
fi

if ! command -v fzf >/dev/null 2>&1 || ! command -v zsh >/dev/null 2>&1; then
    printf 'SKIP: fzf or zsh not available, skipping the live backend test\n' >&2
    printf 'PASS: pacman backend wiring verified as source text (BACKEND resolution, dependency check, get_state/fetch_outdated_formulae/rebuild_cache dispatch, Update/Update All root guards)\n'
    exit 0
fi

PB_HOME="$(mktemp -d)"
trap 'rm -rf "$PB_HOME"' EXIT

# A real diagnose, cold — no pre-seeded cache, no fixture, nothing.
# This is the same thing a genuinely first-ever launch on a real Arch
# machine does.
diagnose_output="$(
    HOME="$PB_HOME" \
    XDG_CONFIG_HOME="$PB_HOME/.config" \
    XDG_CACHE_HOME="$PB_HOME/.cache" \
    BREW_LAUNCHER_TERMINAL=current \
    zsh "$LAUNCHER" --diagnose 2>&1
)"

[[ "$diagnose_output" == *'backend — pacman'* ]] ||
    fail "expected --diagnose to detect the pacman backend, got: $diagnose_output"
[[ "$diagnose_output" == *'No problems found.'* ]] ||
    fail "expected a clean --diagnose on a real machine with pacman/fzf/python3 present, got: $diagnose_output"

# A real cache build, through the real rebuild_cache_pacman() path —
# --list is fully backend-agnostic (it only ever reads the cache file
# already on disk), so it doubles as a fast, non-interactive way to
# prove the whole pacman cache-building pipeline actually worked,
# without needing a real tmux/fzf session for this part.
list_output="$(
    HOME="$PB_HOME" \
    XDG_CONFIG_HOME="$PB_HOME/.config" \
    XDG_CACHE_HOME="$PB_HOME/.cache" \
    BREW_LAUNCHER_TERMINAL=current \
    zsh "$LAUNCHER" --list 2>&1
)"

[[ -n "$list_output" ]] ||
    fail "--list produced no output after a real pacman-backed cache build — expected at least fzf/python3/zsh's own commands"

bad_field_count="$(printf '%s\n' "$list_output" | awk -F'\t' 'NF != 6 { c++ } END { print c+0 }')"
[[ "$bad_field_count" == "0" ]] ||
    fail "$bad_field_count row(s) from a real pacman-backed --list did not have exactly 6 tab-separated fields"

printf 'PASS: pacman backend wiring verified as source text, and a real cold-start launch (no fixture, no pre-seeded cache) against real pacman data correctly detects the backend and builds a working cache through rebuild_cache_pacman()\n'
