#!/bin/zsh
#
# Backup test.
#
# Raised live: "would a feature like brew bundle make sense... a
# backup of your brew apps, categories, and presets?" create_backup()
# is pure enough to run for real, unlike the rename/toggle pickers
# elsewhere in this app — no fzf, no interactivity, just `brew bundle
# dump` plus a plain directory copy and tar. Sourced directly and
# actually run against a fixture $CONFIG_DIR and a scratch
# $BACKUP_FILE, then the resulting archive is inspected for real.

set -u

SCRIPT_DIR="${0:A:h}"
LAUNCHER="$SCRIPT_DIR/../bin/brew-launcher"

fail() {
    printf 'FAIL: %s\n' "$1" >&2
    exit 1
}

[[ -x "$LAUNCHER" ]] || fail "launcher not found or not executable: $LAUNCHER"

if ! command -v brew >/dev/null 2>&1; then
    echo "SKIP: brew not available"
    exit 0
fi

TEST_HOME="$(mktemp -d)"
trap 'rm -rf "$TEST_HOME"' EXIT

source <(sed -n '/^create_backup() {/,/^}/p' "$LAUNCHER")

# ------------------------------------------------------------
# 1. A real run: fixture CONFIG_DIR in, archive out.
# ------------------------------------------------------------

CONFIG_DIR="$TEST_HOME/config/brew-launcher"
mkdir -p "$CONFIG_DIR/categories" "$CONFIG_DIR/presets"
printf 'fastfetch\n' > "$CONFIG_DIR/categories/TestCategory"
printf 'fastfetch\n' > "$CONFIG_DIR/presets/testpreset"
printf 'TERMINAL=current\n' > "$CONFIG_DIR/config"

BACKUP_FILE="$TEST_HOME/backup.tar.gz"

create_backup >"$TEST_HOME/backup-output.txt" 2>&1
backup_exit=$?

(( backup_exit == 0 )) ||
    fail "create_backup should succeed with a real brew and a fixture CONFIG_DIR, got exit $backup_exit: $(cat "$TEST_HOME/backup-output.txt")"

[[ -f "$BACKUP_FILE" ]] ||
    fail "create_backup should write an archive to \$BACKUP_FILE"

grep -q "$BACKUP_FILE" "$TEST_HOME/backup-output.txt" ||
    fail "create_backup should report where it saved the archive"

# ------------------------------------------------------------
# 2. The archive actually contains what it claims to.
# ------------------------------------------------------------

archive_listing="$(tar -tzf "$BACKUP_FILE")"

[[ "$archive_listing" == *"Brewfile"* ]] ||
    fail "archive should contain a Brewfile from brew bundle dump"

[[ "$archive_listing" == *"brew-launcher-config/categories/TestCategory"* ]] ||
    fail "archive should contain the fixture category file"

[[ "$archive_listing" == *"brew-launcher-config/presets/testpreset"* ]] ||
    fail "archive should contain the fixture preset file"

[[ "$archive_listing" == *"brew-launcher-config/config"* ]] ||
    fail "archive should contain the config file (theme/terminal settings)"

# Regression guard: an earlier version of this put brew-launcher's own
# staging log files (bundle output, tar's own stderr) inside the
# staging directory it then archived wholesale, so they leaked into
# every backup. Fixed by staging the actual payload one level deeper;
# checked here so it can't quietly come back.
[[ "$archive_listing" != *"bundle-output.txt"* ]] ||
    fail "archive should not contain brew-launcher's own staging log (bundle-output.txt) — see the payload/ subdirectory fix"
[[ "$archive_listing" != *"tar-error.txt"* ]] ||
    fail "archive should not contain brew-launcher's own staging log (tar-error.txt) — see the payload/ subdirectory fix"

# ------------------------------------------------------------
# 3. No brew on PATH: fails cleanly, no half-written archive.
# ------------------------------------------------------------

BACKUP_FILE="$TEST_HOME/no-brew-backup.tar.gz"

(
    PATH="/usr/bin:/bin"
    create_backup
) >"$TEST_HOME/no-brew-output.txt" 2>&1
no_brew_exit=$?

(( no_brew_exit != 0 )) ||
    fail "create_backup should fail without brew on PATH, not silently succeed"

[[ ! -f "$BACKUP_FILE" ]] ||
    fail "create_backup should not leave a partial archive behind when brew isn't found"

grep -qi "homebrew not found" "$TEST_HOME/no-brew-output.txt" ||
    fail "create_backup should explain why it refused, got: $(cat "$TEST_HOME/no-brew-output.txt")"

printf 'PASS: create_backup() writes a Brewfile + brew-launcher config archive, leaves no staging logs inside it, and fails cleanly without brew\n'
