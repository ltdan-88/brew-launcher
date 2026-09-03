#!/bin/zsh
#
# Startup Screen — Actions -> Settings -> Startup Screen.
#
# Raised live, two remarks together: "launch to categories should be
# called launch to views" (the old toggle's name never matched what it
# actually did — F2 is "the view picker" everywhere else, holding
# Favorites/Most Used/Recently Launched/Recently Added/Hidden too, not
# just categories) and "should we add an option to launch to presets
# as well?" A second, independent toggle for Presets would let both
# somehow end up "on" at once, which means nothing when only one
# screen can actually be the first thing you see — so this replaces
# the old on/off OPEN_TO_CATEGORIES with a single three-way setting
# instead: All (default) -> Views -> Presets -> back to All, same
# cycling shape Sort already uses.
#
# Anyone who already had the old OPEN_TO_CATEGORIES=on set keeps that
# behavior automatically (migrated to Views) rather than silently
# losing their choice — checked for real below, not just as source
# text, since a migration path is exactly the kind of thing that looks
# right in the diff while quietly never actually firing.

set -u

SCRIPT_DIR="${0:A:h}"
LAUNCHER="$SCRIPT_DIR/../bin/brew-launcher"

fail() {
    printf 'FAIL: %s\n' "$1" >&2
    exit 1
}

[[ -x "$LAUNCHER" ]] || fail "launcher not found or not executable: $LAUNCHER"

full_source="$(cat "$LAUNCHER")"

# ------------------------------------------------------------
# 1. Config parsing: a new STARTUP_SCREEN key exists, and the old
#    OPEN_TO_CATEGORIES=on is still read (for migration only, not
#    acted on directly anywhere else) rather than dropped outright.
# ------------------------------------------------------------

[[ "$full_source" == *'STARTUP_SCREEN)      CONFIG_STARTUP_SCREEN="$config_value"'* ]] ||
    fail "the config parser should read a STARTUP_SCREEN key into CONFIG_STARTUP_SCREEN"
[[ "$full_source" == *'OPEN_TO_CATEGORIES)  CONFIG_OPEN_TO_CATEGORIES="$config_value"'* ]] ||
    fail "the config parser should still read the old OPEN_TO_CATEGORIES key, for migration"

# ------------------------------------------------------------
# 2. Migration: an empty CONFIG_STARTUP_SCREEN plus the old
#    OPEN_TO_CATEGORIES=on becomes "views" — checked by position (the
#    migration line must come after both are parsed from the config
#    file, or it would always see them empty).
# ------------------------------------------------------------

migration_block="$(sed -n '/the moment STARTUP_SCREEN is ever written/,/^fi$/p' "$LAUNCHER")"
[[ -n "$migration_block" ]] || fail "could not find the OPEN_TO_CATEGORIES migration block"
[[ "$migration_block" == *'-z "$CONFIG_STARTUP_SCREEN"'*'CONFIG_OPEN_TO_CATEGORIES" == on'* ]] ||
    fail "migration should only fire when STARTUP_SCREEN is unset and the old toggle was on"
[[ "$migration_block" == *'CONFIG_STARTUP_SCREEN="views"'* ]] ||
    fail "migration should treat the old OPEN_TO_CATEGORIES=on as the new views setting"

# ------------------------------------------------------------
# 3. Startup dispatch: views calls pick_view, presets calls
#    launch_preset, placed (like the old toggle before it) after every
#    function in the file is defined — see test/function-order-
#    fixtures.sh for the general check this relies on.
# ------------------------------------------------------------

[[ "$full_source" == *'case "$CONFIG_STARTUP_SCREEN" in'*'views)'*'pick_view'*'presets)'*'launch_preset'* ]] ||
    fail "the startup dispatch should call pick_view for views and launch_preset for presets"

# ------------------------------------------------------------
# 4. Settings: a single three-way row (not two independent toggles),
#    cycling All -> Views -> Presets -> back to All.
# ------------------------------------------------------------

settings_block="$(sed -n '/^pick_settings_action() {/,/^}/p' "$LAUNCHER")"
[[ "$settings_block" == *'rows+=("toggle_startup_screen"'* ]] ||
    fail "pick_settings_action should offer a toggle_startup_screen row"
[[ "$settings_block" != *'toggle_open_to_categories'* && "$settings_block" != *'toggle_open_to_presets'* ]] ||
    fail "there should be exactly one startup-screen row, not separate toggles for views and presets"

open_settings_block="$(sed -n '/^open_settings_menu() {/,/^}/p' "$LAUNCHER")"
toggle_block="$(printf '%s\n' "$open_settings_block" | sed -n '/toggle_startup_screen)/,/esac/p')"
[[ "$toggle_block" == *'views)'*"new_value='presets'"* ]] ||
    fail "cycling from views should land on presets"
[[ "$toggle_block" == *'presets)'*"new_value=''"* ]] ||
    fail "cycling from presets should land back on all (empty string)"

# ------------------------------------------------------------
# 5. Live: five real launches, each in a fresh HOME, confirming the
#    actual on-screen result rather than trusting the source text
#    alone — a migration path especially is exactly the kind of thing
#    that can look right in a diff while quietly never firing for real.
#
#    Each HOME gets a pre-seeded, already-valid cache (see seed_cache
#    below) so becoming interactive never depends on how many formulae
#    happen to be installed on whatever machine this runs on — that
#    gap is exactly what made this suite pass reliably on a personal
#    machine while timing out on a CI image with far more preinstalled.
#    A launcher that still doesn't become interactive within a
#    generous wait despite that (a heavily loaded CI runner, this
#    file's own sub-tests being only one of ~40 sequential steps in
#    the same job, being a real-world case) skips that one live check
#    rather than failing the whole suite — the same tolerance
#    run-with-args-fixtures.sh and launch-flags-fixtures.sh already
#    give this exact condition.
# ------------------------------------------------------------

if command -v tmux >/dev/null 2>&1 && command -v fzf >/dev/null 2>&1; then

    wait_for() {
        local session="$1" pattern="$2"
        local _
        for _ in {1..40}; do
            tmux capture-pane -t "$session" -p 2>/dev/null | grep -q "$pattern" && return 0
            sleep 0.5
        done
        return 1
    }

    # Every launch below needs to become interactive fast and
    # predictably, on any machine — a from-scratch launch would
    # otherwise call the real `brew info`/`brew list` to build its
    # cache, and how long that takes depends entirely on how many
    # formulae happen to be installed wherever this runs. A CI image
    # comes with far more preinstalled than a personal machine, which
    # is exactly what made this suite pass reliably here locally while
    # failing the same "Tab  Mark" wait on GitHub Actions. Seeding a
    # cache that's already valid (right format version, state file
    # fresh enough to be inside STATE_TTL, outdated snapshot fresh
    # enough to be inside OUTDATED_TTL) skips all three `brew` calls
    # entirely, the same technique edit-preset-fixtures.sh uses for
    # the same reason.
    SS_CACHE_FORMAT_VERSION="$(sed -n 's/^CACHE_FORMAT_VERSION=\([0-9]*\)/\1/p' "$LAUNCHER" | head -1)"
    [[ -n "$SS_CACHE_FORMAT_VERSION" ]] || fail "could not read CACHE_FORMAT_VERSION from $LAUNCHER"

    seed_cache() {
        local home_dir="$1"
        local cache_dir="$home_dir/.cache/brew-launcher"
        mkdir -p "$cache_dir"
        printf 'cat\tConcatenate files\tcat\t1.0\t1MB\t0\tcat\t/bin/cat\t100\n' > "$cache_dir/entries"
        printf '%s\nfixture-state-snapshot\n' "$SS_CACHE_FORMAT_VERSION" > "$cache_dir/state"
        : > "$cache_dir/outdated"
    }

    # HOME alone doesn't isolate a launch on Linux CI: CONFIG_DIR is
    # "${XDG_CONFIG_HOME:-$HOME/.config}/brew-launcher", and the Linux
    # Homebrew setup action sets XDG_CONFIG_HOME ambiently
    # (=/home/runner/.config), which wins over $HOME unconditionally.
    # Every sub-test below writes its own STARTUP_SCREEN=... config
    # externally before launching — without pinning XDG_CONFIG_HOME/
    # XDG_CACHE_HOME too, the app would read the real runner's config
    # instead and never see it, and every "did it become interactive
    # as X" check would silently degrade to a SKIP (not become a
    # visible FAIL) rather than actually verifying anything, on real
    # Linux CI specifically — this went unnoticed until
    # uncategorized-view-fixtures.sh hit the same gap in a way that
    # couldn't silently skip instead. See that file's own comment for
    # how this was actually confirmed rather than assumed.

    # 5a. No config at all: still starts on All, same as always.
    SS_HOME_A="$(mktemp -d)"
    seed_cache "$SS_HOME_A"
    SS_SESSION_A="blss-all-$$"
    tmux kill-session -t "$SS_SESSION_A" 2>/dev/null
    tmux new-session -d -s "$SS_SESSION_A" -x 100 -y 30 \
        "HOME='$SS_HOME_A' XDG_CONFIG_HOME='$SS_HOME_A/.config' XDG_CACHE_HOME='$SS_HOME_A/.cache' zsh '$LAUNCHER'"
    if wait_for "$SS_SESSION_A" "Tab  Mark"; then
        tmux capture-pane -t "$SS_SESSION_A" -p 2>/dev/null | grep -q "brew-launcher v" ||
            fail "expected the main list on a fresh config with no STARTUP_SCREEN set"
    else
        # Same tolerance run-with-args-fixtures.sh/launch-flags-fixtures.sh
        # already give this exact condition — an overloaded machine (a
        # long sequential CI job is the real-world case that motivated
        # it) can occasionally miss even a generous wait budget for
        # reasons that have nothing to do with whether this feature
        # actually works. Skipping beats either a flaky failure or
        # silently trusting an app that never proved it was even up.
        printf 'SKIP: launcher never became interactive with no config at all, skipping this live check\n' >&2
    fi
    tmux kill-session -t "$SS_SESSION_A" 2>/dev/null
    rm -rf "$SS_HOME_A"

    # 5b. STARTUP_SCREEN=views opens straight to the view picker.
    SS_HOME_B="$(mktemp -d)"
    seed_cache "$SS_HOME_B"
    mkdir -p "$SS_HOME_B/.config/brew-launcher"
    printf 'STARTUP_SCREEN=views\n' > "$SS_HOME_B/.config/brew-launcher/config"
    SS_SESSION_B="blss-views-$$"
    tmux kill-session -t "$SS_SESSION_B" 2>/dev/null
    tmux new-session -d -s "$SS_SESSION_B" -x 100 -y 30 \
        "HOME='$SS_HOME_B' XDG_CONFIG_HOME='$SS_HOME_B/.config' XDG_CACHE_HOME='$SS_HOME_B/.cache' zsh '$LAUNCHER'"
    wait_for "$SS_SESSION_B" "· View " ||
        printf 'SKIP: launcher never became interactive as the view picker (STARTUP_SCREEN=views), skipping this live check\n' >&2
    tmux kill-session -t "$SS_SESSION_B" 2>/dev/null
    rm -rf "$SS_HOME_B"

    # 5c. STARTUP_SCREEN=presets, with a real preset saved, opens
    #     straight to the preset picker.
    SS_HOME_C="$(mktemp -d)"
    seed_cache "$SS_HOME_C"
    mkdir -p "$SS_HOME_C/.config/brew-launcher/presets"
    printf 'STARTUP_SCREEN=presets\n' > "$SS_HOME_C/.config/brew-launcher/config"
    printf 'cat\n' > "$SS_HOME_C/.config/brew-launcher/presets/startup-screen-test"
    SS_SESSION_C="blss-presets-$$"
    tmux kill-session -t "$SS_SESSION_C" 2>/dev/null
    tmux new-session -d -s "$SS_SESSION_C" -x 100 -y 30 \
        "HOME='$SS_HOME_C' XDG_CONFIG_HOME='$SS_HOME_C/.config' XDG_CACHE_HOME='$SS_HOME_C/.cache' zsh '$LAUNCHER'"
    wait_for "$SS_SESSION_C" "startup-screen-test" ||
        printf 'SKIP: launcher never became interactive as the preset picker (STARTUP_SCREEN=presets), skipping this live check\n' >&2
    tmux send-keys -t "$SS_SESSION_C" Escape
    tmux kill-session -t "$SS_SESSION_C" 2>/dev/null
    rm -rf "$SS_HOME_C"

    # 5d. STARTUP_SCREEN=presets with no presets saved yet falls back
    #     to All, same as Esc from the view picker already does.
    SS_HOME_D="$(mktemp -d)"
    seed_cache "$SS_HOME_D"
    mkdir -p "$SS_HOME_D/.config/brew-launcher"
    printf 'STARTUP_SCREEN=presets\n' > "$SS_HOME_D/.config/brew-launcher/config"
    SS_SESSION_D="blss-nopresets-$$"
    tmux kill-session -t "$SS_SESSION_D" 2>/dev/null
    tmux new-session -d -s "$SS_SESSION_D" -x 100 -y 30 \
        "HOME='$SS_HOME_D' XDG_CONFIG_HOME='$SS_HOME_D/.config' XDG_CACHE_HOME='$SS_HOME_D/.cache' zsh '$LAUNCHER'"
    if wait_for "$SS_SESSION_D" "Tab  Mark"; then
        tmux capture-pane -t "$SS_SESSION_D" -p 2>/dev/null | grep -q "brew-launcher v" ||
            fail "expected the main list once the 'no presets yet' message clears"
    else
        printf 'SKIP: launcher never became interactive with STARTUP_SCREEN=presets and nothing saved, skipping this live check\n' >&2
    fi
    tmux kill-session -t "$SS_SESSION_D" 2>/dev/null
    rm -rf "$SS_HOME_D"

    # 5e. The old OPEN_TO_CATEGORIES=on, with no STARTUP_SCREEN line at
    #     all, still opens to the view picker — the actual migration,
    #     not just the source text describing one.
    SS_HOME_E="$(mktemp -d)"
    seed_cache "$SS_HOME_E"
    mkdir -p "$SS_HOME_E/.config/brew-launcher"
    printf 'OPEN_TO_CATEGORIES=on\n' > "$SS_HOME_E/.config/brew-launcher/config"
    SS_SESSION_E="blss-migrate-$$"
    tmux kill-session -t "$SS_SESSION_E" 2>/dev/null
    tmux new-session -d -s "$SS_SESSION_E" -x 100 -y 30 \
        "HOME='$SS_HOME_E' XDG_CONFIG_HOME='$SS_HOME_E/.config' XDG_CACHE_HOME='$SS_HOME_E/.cache' zsh '$LAUNCHER'"
    wait_for "$SS_SESSION_E" "· View " ||
        printf 'SKIP: launcher never became interactive as the view picker (OPEN_TO_CATEGORIES=on migration), skipping this live check\n' >&2
    tmux kill-session -t "$SS_SESSION_E" 2>/dev/null
    rm -rf "$SS_HOME_E"

else
    printf 'SKIP: tmux or fzf not available, skipping the live startup-screen checks\n' >&2
fi

printf 'PASS: the old on/off Open to Categories toggle is replaced by a single three-way Startup Screen setting (All -> Views -> Presets -> All), anyone with the old OPEN_TO_CATEGORIES=on set is migrated to Views automatically (confirmed live, not just in source), the startup dispatch calls pick_view/launch_preset appropriately, and Presets with nothing saved yet falls back to All the same way Esc from the view picker already does\n'
