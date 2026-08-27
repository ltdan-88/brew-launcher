#!/bin/zsh
#
# Stale category-member pruning test.
#
# Raised live: a Favorites count of "0" despite two genuine entries in
# the file — both had been uninstalled since being favorited. Asked
# back what should happen (leave it, show the gap, or clean it up);
# "auto-clean on uninstall" was the answer. Since this launcher has no
# way to hook a live uninstall event, the real mechanism is
# prune_stale_category_members(), run once per real cache rebuild
# (rebuild_cache() just confirmed, definitively, what's still
# installed) rather than on every launch.
#
# Pure and self-contained (a directory of category files plus a
# fixture CACHE_FILE) — sourced and run directly, no fzf/brew/tmux
# needed.

set -u

SCRIPT_DIR="${0:A:h}"
LAUNCHER="$SCRIPT_DIR/../bin/brew-launcher"

fail() {
    printf 'FAIL: %s\n' "$1" >&2
    exit 1
}

[[ -x "$LAUNCHER" ]] || fail "launcher not found or not executable: $LAUNCHER"

TEST_HOME="$(mktemp -d)"
trap 'rm -rf "$TEST_HOME"' EXIT

CATEGORIES_DIR="$TEST_HOME/categories"
CACHE_DIR="$TEST_HOME/cache"
CACHE_FILE="$TEST_HOME/entries"
mkdir -p "$CATEGORIES_DIR" "$CACHE_DIR"

# Only fastfetch is "installed" in this fixture — calcurse and cava
# (the real names from the live report) are not, same as newsboat here.
cat > "$CACHE_FILE" <<'EOF'
fastfetch	Like neofetch, but much faster	fastfetch	2.67.1	1.7MB	0	fastfetch	/opt/homebrew/bin/fastfetch	100	-	0
EOF

printf 'fastfetch\ncalcurse\ncava\n' > "$CATEGORIES_DIR/Favorites"
printf '# a comment\n\nnewsboat\ntele\n' > "$CATEGORIES_DIR/Chat"
: > "$CATEGORIES_DIR/AlreadyEmpty"

source <(sed -n '/^prune_stale_category_members() {/,/^}/p' "$LAUNCHER")

prune_stale_category_members

# ------------------------------------------------------------
# 1. Favorites: the still-installed entry survives, the two
#    uninstalled ones are gone — the exact scenario reported live.
# ------------------------------------------------------------

favorites_content="$(<"$CATEGORIES_DIR/Favorites")"

[[ "$favorites_content" == *"fastfetch"* ]] ||
    fail "Favorites should keep fastfetch (still installed), got: $favorites_content"
[[ "$favorites_content" != *"calcurse"* ]] ||
    fail "Favorites should drop calcurse (no longer installed), got: $favorites_content"
[[ "$favorites_content" != *"cava"* ]] ||
    fail "Favorites should drop cava (no longer installed), got: $favorites_content"

# ------------------------------------------------------------
# 2. Comments and blank lines pass through untouched; only actual
#    stale command lines are removed.
# ------------------------------------------------------------

chat_content="$(<"$CATEGORIES_DIR/Chat")"

[[ "$chat_content" == *"# a comment"* ]] ||
    fail "a comment line should survive pruning untouched, got: $chat_content"
[[ "$chat_content" != *"newsboat"* ]] ||
    fail "Chat should drop newsboat (not in the fixture cache), got: $chat_content"

# ------------------------------------------------------------
# 3. An already-empty category file doesn't error and stays empty.
# ------------------------------------------------------------

[[ ! -s "$CATEGORIES_DIR/AlreadyEmpty" ]] ||
    fail "an already-empty category file should stay empty, not gain content"

# ------------------------------------------------------------
# 4. Wired into rebuild_cache() itself — a pruning function nobody
#    calls is as good as no fix at all. rebuild_cache() embeds a
#    multi-line Python heredoc containing its own "}" lines at column
#    0 (dict/set literals), which defeats a naive
#    /^rebuild_cache() {/,/^}/ sed extraction — it stops at the first
#    of those, not the function's real end — so this checks for a
#    second, real call site instead of just the one-line definition.
# ------------------------------------------------------------

prune_mentions="$(grep -c 'prune_stale_category_members' "$LAUNCHER")"
(( prune_mentions >= 2 )) ||
    fail "prune_stale_category_members should be called somewhere (rebuild_cache()), not just defined — found $prune_mentions mention(s)"

call_site="$(grep -n '^ *prune_stale_category_members$' "$LAUNCHER")"
[[ -n "$call_site" ]] ||
    fail "expected a bare prune_stale_category_members call site (no args) inside rebuild_cache()"

printf 'PASS: prune_stale_category_members() drops uninstalled commands from every category file (Favorites included), keeps comments/blank lines and still-installed ones, and is wired into rebuild_cache()\n'
