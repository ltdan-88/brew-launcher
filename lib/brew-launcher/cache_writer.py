#!/usr/bin/env python3
"""Cache writer for brew-launcher.

Reads Homebrew's own `brew info --json=v1 --installed` output plus a
couple of small companion files, and writes the tab-separated cache
bin/brew-launcher reads on every launch — see CACHE_FORMAT_VERSION in
bin/brew-launcher for what each column means and why it's bumped when
this file's output shape changes.

Invoked from rebuild_cache() in bin/brew-launcher as a plain script
with positional arguments (not sourced, not embedded inline) — this
used to be a shell heredoc inside bin/brew-launcher itself, pulled out
into its own file so it gets real Python tooling (syntax highlighting,
py_compile, a linter if one's ever added) instead of living as a
foreign language inside a zsh script. Nothing about how it's invoked
changed: same eight positional arguments, same stdin-free operation,
same output.

Positional arguments (all required, in this order):
    1. json_file       brew info --json=v1 --installed output
    2. sizes_file       brew info --installed --sizes --formula output
    3. outdated_file    tab-separated "name<TAB>new-version" lines
    4. brew_prefix      `brew --prefix` output
    5. output_file      where the tab-separated cache gets written
    6. preview_dir      per-formula details-pane text files go here
    7. category_marker  placeholder substituted at render time for the
                         live category list (see PREVIEW_CATEGORY_MARKER)
    8. preset_marker    same, for preset membership (see
                         PREVIEW_PRESET_MARKER)
"""

import datetime
import json
import os
import subprocess
import sys

json_file = sys.argv[1]
sizes_file = sys.argv[2]
outdated_file = sys.argv[3]
brew_prefix = sys.argv[4]
output_file = sys.argv[5]
preview_dir = sys.argv[6]
category_marker = sys.argv[7]
preset_marker = sys.argv[8]

# ------------------------------------------------------------
# Bundled curated data — see "Bundled defaults" in the README.
#
# DEFAULT_CATEGORIES: formula name -> category name, for well-known
# tools a beginner would otherwise have to discover and file away by
# hand. Applied at rebuild time regardless of the DEFAULT_CATEGORIES
# config setting — that switch is checked zsh-side instead, so turning
# it on doesn't require a rebuild to take effect.
#
# DEFAULT_HIDDEN: exact command names for genuinely auxiliary/minor
# commands a multi-command formula installs alongside its main one
# (e.g. age's own key-generation plugin helper, calcurse's one-time
# migration script, musikcube's headless daemon "musikcubed", visidata's
# "vd" alias for its own main binary and its "vd2to3.vdx" one-shot
# conversion script) — reviewed one at a time, not a blanket rule. A
# command belongs here only if it was actually checked, not guessed;
# see CONTRIBUTING.md for why a generic heuristic was rejected instead.
#
# Both are keyed independently of whatever the user has done by hand —
# see load_bundled_categories()/load_hidden_commands() in the main
# script for how a manual F3/F8 choice always overrides these.
# ------------------------------------------------------------

_DEFAULT_CATEGORIES_RAW = """
irssi\tChat
weechat\tChat
awscli\tCloud & DevOps
docker\tCloud & DevOps
k9s\tCloud & DevOps
lazydocker\tCloud & DevOps
litecli\tDatabases
mycli\tDatabases
pgcli\tDatabases
redis\tDatabases
act\tDev Tools
direnv\tDev Tools
entr\tDev Tools
grex\tDev Tools
httpie\tDev Tools
hyperfine\tDev Tools
jless\tDev Tools
just\tDev Tools
shellcheck\tDev Tools
tokei\tDev Tools
watchexec\tDev Tools
zoxide\tDev Tools
diskus\tDisk Usage
duf\tDisk Usage
dust\tDisk Usage
gdu\tDisk Usage
ncdu\tDisk Usage
helix\tEditors
kakoune\tEditors
micro\tEditors
neovim\tEditors
vim\tEditors
broot\tFile Manager
lf\tFile Manager
midnight-commander\tFile Manager
nnn\tFile Manager
ranger\tFile Manager
superfile\tFile Manager
vifm\tFile Manager
xplr\tFile Manager
yazi\tFile Manager
asciiquarium\tFun & Toys
astroterm\tFun & Toys
boxes\tFun & Toys
cbonsai\tFun & Toys
cmatrix\tFun & Toys
cowsay\tFun & Toys
daylight\tFun & Toys
figlet\tFun & Toys
lolcat\tFun & Toys
pipes-sh\tFun & Toys
satellite-tracker\tFun & Toys
sl\tFun & Toys
toilet\tFun & Toys
tty-clock\tFun & Toys
bastet\tGames
c2048\tGames
moon-buggy\tGames
nethack\tGames
ninvaders\tGames
nsnake\tGames
robotfindskitten\tGames
difftastic\tGit & Version Control
gh\tGit & Version Control
git-absorb\tGit & Version Control
git-delta\tGit & Version Control
git-quick-stats\tGit & Version Control
gitui\tGit & Version Control
lazygit\tGit & Version Control
onefetch\tGit & Version Control
tig\tGit & Version Control
cava\tMedia & Visuals
chafa\tMedia & Visuals
cmus\tMedia & Visuals
ffmpeg\tMedia & Visuals
kew\tMedia & Visuals
mpv\tMedia & Visuals
viu\tMedia & Visuals
yt-dlp\tMedia & Visuals
curlie\tNetworking
doggo\tNetworking
iperf3\tNetworking
mtr\tNetworking
ngrep\tNetworking
nmap\tNetworking
speedtest-cli\tNetworking
whois\tNetworking
calcurse\tProductivity
task\tProductivity
timewarrior\tProductivity
todo-txt\tProductivity
when\tProductivity
wordgrinder\tProductivity
cheat\tReading & Reference
glow\tReading & Reference
lynx\tReading & Reference
mdcat\tReading & Reference
navi\tReading & Reference
newsboat\tReading & Reference
pandoc\tReading & Reference
tldr\tReading & Reference
w3m\tReading & Reference
ack\tSearch & Text Tools
bat\tSearch & Text Tools
choose-rust\tSearch & Text Tools
eza\tSearch & Text Tools
fd\tSearch & Text Tools
fzf\tSearch & Text Tools
gron\tSearch & Text Tools
jq\tSearch & Text Tools
ripgrep\tSearch & Text Tools
sd\tSearch & Text Tools
the_silver_searcher\tSearch & Text Tools
tree\tSearch & Text Tools
visidata\tSearch & Text Tools
yq\tSearch & Text Tools
age\tSecurity
gnupg\tSecurity
pass\tSecurity
pwgen\tSecurity
sops\tSecurity
fastfetch\tSystem Info
inxi\tSystem Info
macmon\tSystem Info
bandwhich\tSystem Monitoring
bottom\tSystem Monitoring
btop\tSystem Monitoring
ctop\tSystem Monitoring
glances\tSystem Monitoring
gping\tSystem Monitoring
gtop\tSystem Monitoring
htop\tSystem Monitoring
iftop\tSystem Monitoring
lnav\tSystem Monitoring
mole\tSystem Monitoring
procs\tSystem Monitoring
screen\tTerminal Utility
tmux\tTerminal Utility
zellij\tTerminal Utility
"""

_DEFAULT_HIDDEN_RAW = """
age-inspect
age-plugin-batchpass
calcurse-caldav
calcurse-upgrade
calcurse-vdir
chkfont
figlist
showfigfonts
podboat
musikcubed
vd
vd2to3.vdx
"""

default_categories = {}
for _line in _DEFAULT_CATEGORIES_RAW.strip("\n").splitlines():
    _formula, _category = _line.split("\t", 1)
    default_categories[_formula] = _category

default_hidden = {
    _line.strip()
    for _line in _DEFAULT_HIDDEN_RAW.strip("\n").splitlines()
    if _line.strip()
}

# ------------------------------------------------------------
# Read Homebrew metadata.
# ------------------------------------------------------------

with open(json_file, "r", encoding="utf-8") as f:
    formulae = json.load(f)

# ------------------------------------------------------------
# Get formulae explicitly installed by the user.
# ------------------------------------------------------------

try:
    leaves = subprocess.check_output(
        ["brew", "leaves", "--installed-on-request"],
        text=True,
        stderr=subprocess.DEVNULL,
    ).splitlines()
except Exception:
    leaves = []

leaves = {x.strip() for x in leaves if x.strip()}

# ------------------------------------------------------------
# Read outdated formula names, mapped to the version that's actually
# available — used both for the outdated_flag below and, later, to
# show that version in the details pane. `name in outdated` still
# works exactly as it did when this was a set: dict membership checks
# keys the same way.
# ------------------------------------------------------------

outdated = {}

try:
    with open(outdated_file, "r", encoding="utf-8") as f:
        for line in f:
            line = line.rstrip("\n")
            if not line:
                continue
            parts = line.split("\t", 1)
            if len(parts) == 2:
                outdated[parts[0]] = parts[1]
except OSError:
    pass

# ------------------------------------------------------------
# Read installed formula sizes.
#
# Current Homebrew output is:
#
#   formula-name    12.4MB
#
# We only need the first and last whitespace-separated fields.
# ------------------------------------------------------------

sizes = {}

try:
    with open(sizes_file, "r", encoding="utf-8") as f:

        for raw_line in f:

            line = raw_line.strip()

            if not line:
                continue

            parts = line.split()

            if len(parts) < 2:
                continue

            formula_name = parts[0]
            size = parts[-1]

            sizes[formula_name] = size

except OSError:
    pass

entries = []

# ------------------------------------------------------------
# Discover executable commands.
# ------------------------------------------------------------

for formula in formulae:

    name = formula.get("name", "")
    full_name = formula.get("full_name", name)

    if not name:
        continue

    # Only include formulae explicitly installed by the user.
    if name not in leaves and full_name not in leaves:
        continue

    description = (
        formula.get("desc", "")
        or "Homebrew CLI application"
    )

    # A formula's description is free text a tap maintainer controls,
    # not something Homebrew's own naming rules constrain the way
    # formula/command names are — a tab or newline embedded in it
    # would otherwise land straight in a tab-separated cache row and
    # either shift every field after it (a tab) or terminate the row
    # early and start a bogus new one out of whatever text follows (a
    # newline), corrupting entries that have nothing to do with this
    # formula. Collapsed to a space rather than stripped outright, so
    # a description that legitimately used a tab for spacing still
    # reads sensibly.
    description = description.replace("\t", " ").replace("\n", " ")

    # --------------------------------------------------------
    # Installed version.
    # --------------------------------------------------------

    installed_versions = formula.get("installed", [])

    if installed_versions:
        version = installed_versions[-1].get("version", "")
        # Unix timestamp Homebrew itself recorded at install time —
        # already present in the same JSON this loop already reads,
        # so capturing it for the "Recently Added" view costs nothing
        # extra. Falls back to "0" (oldest possible) rather than "" so
        # it still sorts predictably if it's ever missing.
        install_time = str(installed_versions[-1].get("time", 0))
    else:
        version = ""
        install_time = "0"

    # --------------------------------------------------------
    # Installed size.
    # --------------------------------------------------------

    size = sizes.get(full_name)

    if size is None:
        size = sizes.get(name, "")

    # --------------------------------------------------------
    # Stable Homebrew opt path.
    # --------------------------------------------------------

    opt_bin = os.path.join(
        brew_prefix,
        "opt",
        name,
        "bin",
    )

    if not os.path.isdir(opt_bin):
        continue

    try:
        commands = os.listdir(opt_bin)
    except OSError:
        continue
    
    for command in commands:
    
        path = os.path.join(opt_bin, command)

        # Must be a regular file.
        if not os.path.isfile(path):
            continue

        # Must be executable.
        if not os.access(path, os.X_OK):
            continue

        # Ignore common helper/configuration binaries.
        if (
            command.endswith("-config")
            or command.endswith("-build")
            or command.endswith("-cmake")
            or command.endswith("-test")
            or command.endswith("-tests")
        ):
            continue

        # Make sure the command is reachable through PATH, and keep
        # the exact path this found it at (e.g. /opt/homebrew/bin/btop)
        # — not the opt_bin path above, which is homebrew-internal and
        # not necessarily what a shell would actually run.
        #
        # This is the same path `command -v` would return live, so
        # caching it doesn't risk going stale the way caching a fully
        # resolved Cellar path would: Homebrew re-points this exact
        # symlink on every upgrade, it only stops existing if the
        # formula is fully uninstalled — a case the launch-time check
        # already has to handle regardless.
        found_on_path = False
        resolved_path = ""

        for directory in os.environ.get("PATH", "").split(os.pathsep):

            if not directory:
                continue

            candidate = os.path.join(directory, command)

            if os.path.isfile(candidate) and os.access(candidate, os.X_OK):
                found_on_path = True
                resolved_path = candidate
                break

        if not found_on_path:
            continue

        outdated_flag = "1" if (
            name in outdated
            or full_name in outdated
        ) else "0"

        # "-" rather than "" for "no bundled category": zsh's `read`
        # collapses adjacent tabs the same way it collapses runs of
        # ordinary whitespace even with IFS explicitly set to a single
        # tab, so a genuinely empty field here (the common case — most
        # formulae have no bundled category) silently swallows the tab
        # on one side of it and shifts every field after it left by
        # one. A one-character placeholder sidesteps that entirely;
        # every zsh-side reader checks for "-" instead of emptiness.
        default_category = default_categories.get(
            name, default_categories.get(full_name, "")
        ) or "-"
        default_hidden_flag = "1" if command in default_hidden else "0"

        entries.append(
            "\t".join([
                command,
                description,
                name,
                version,
                size,
                outdated_flag,
                full_name,
                resolved_path,
                install_time,
                default_category,
                default_hidden_flag,
            ])
        )

# ------------------------------------------------------------
# Remove duplicate command names.
# ------------------------------------------------------------


def _entry_sort_key(entry):
    # (formula, command), not the raw joined string — sorting by the
    # string alone sorts by *command* first (it's the first field),
    # which silently disagrees with what's actually on screen: a row
    # displays as "$formula ($command)" whenever they differ, formula
    # first. A formula like `tdf`, whose second command is named
    # `for_profiling`, ended up filed under "F" (by "for_profiling")
    # while reading as "tdf (...)" on screen — alphabetical order that
    # didn't match the alphabet the row's own text suggested. Sorting
    # by formula first fixes that, and clusters every command a single
    # formula provides together as a side effect (mc/mcdiff/mcedit/
    # mcview, mole/mo, ...) instead of leaving that to coincidence.
    fields = entry.split("\t")
    formula = fields[2] if len(fields) > 2 else ""
    command = fields[0]
    return (formula.lower(), command.lower())


seen = set()
unique = []
duplicates = []

for entry in sorted(entries, key=_entry_sort_key):

    command = entry.split("\t", 1)[0]
    formula = entry.split("\t")[2]

    if command in seen:
        duplicates.append((command, formula))
        continue

    seen.add(command)
    unique.append(entry)

if duplicates:
    print(
        f"Note: {len(duplicates)} duplicate command name(s) hidden "
        "(first match kept):",
        file=sys.stderr,
    )
    for command, formula in duplicates:
        print(f"  {command}  (also provided by {formula})", file=sys.stderr)

# ------------------------------------------------------------
# Write cache.
# ------------------------------------------------------------

# The trailing newline matters: the shell reads this file with
# `while IFS=... read`, and a final line without a newline terminator
# is silently skipped by that loop — which made the alphabetically
# last entry invisible everywhere in the app.
with open(output_file, "w", encoding="utf-8") as f:
    for entry in unique:
        f.write(entry + "\n")

# ------------------------------------------------------------
# Per-formula preview text.
#
# Written here, from the JSON already fetched above, rather than
# shelling out to `brew info` when the preview is shown: that call
# takes ~0.64s, and fzf re-runs the preview command on every cursor
# move, so a live call would make scrolling unusable.
#
# One file per short formula name, which is what field 3 of the cache
# holds, so the preview command is a plain `cat`.
# ------------------------------------------------------------

# Only formulae that actually survived into the cache — no point
# writing previews for ones the list will never show.
kept_formulae = {e.split("\t")[2] for e in unique}

os.makedirs(preview_dir, exist_ok=True)

for old in os.listdir(preview_dir):
    try:
        os.remove(os.path.join(preview_dir, old))
    except OSError:
        pass


def wrap(text, width=64, indent=""):
    out, line = [], ""
    for word in text.split():
        if line and len(line) + 1 + len(word) > width:
            out.append(indent + line)
            line = word
        else:
            line = f"{line} {word}".strip()
    if line:
        out.append(indent + line)
    return out


for formula in formulae:

    name = formula.get("name", "")
    if not name or name not in kept_formulae:
        continue

    installed_versions = formula.get("installed", [])
    version = installed_versions[-1].get("version", "") if installed_versions else ""
    full_name = formula.get("full_name", name)

    # This is when *you* installed the current version, not when its
    # developers released it — Homebrew doesn't track the latter
    # anywhere locally, and getting it would mean a live network call
    # per formula to wherever each one's upstream release actually
    # lives, which has no single consistent source across formulae.
    # Labeled "Installed" rather than "Released" so it isn't read as
    # something it isn't.
    installed_date = ""
    if installed_versions:
        install_time = installed_versions[-1].get("time")
        if install_time:
            installed_date = datetime.datetime.fromtimestamp(
                install_time
            ).strftime("%b %d, %Y")

    # Same reasoning as the outdated_flag above: brew already has this
    # locally (this is what refresh_outdated_if_stale() itself fetches
    # to build `outdated`), so showing which version is available
    # costs nothing extra to compute here.
    available_version = outdated.get(name) or outdated.get(full_name)

    lines = [f"  {name}  {version}".rstrip(), ""]

    desc = formula.get("desc")
    if desc:
        lines += wrap(desc, indent="  ") + [""]

    for label, value in (
        ("Homepage", formula.get("homepage")),
        ("License", formula.get("license")),
        ("Size", sizes.get(full_name) or sizes.get(name)),
        ("Tap", formula.get("tap")),
        ("Installed", installed_date),
        ("Update available", available_version),
    ):
        if value:
            lines.append(f"  {label:<18}{value}")

    # Filled in at display time by --internal-preview. Sits here, with
    # the rest of the metadata, so it stays visible without scrolling
    # when a formula has long dependency or caveat sections.
    lines.append(category_marker)
    lines.append(preset_marker)

    deps = formula.get("dependencies") or []
    if deps:
        lines += ["", "  Dependencies"] + wrap(", ".join(deps), indent="    ")

    caveats = formula.get("caveats")
    if caveats:
        lines += ["", "  Caveats"]
        for raw in caveats.strip().splitlines():
            lines.append("    " + raw.strip() if raw.strip() else "")

    with open(os.path.join(preview_dir, name), "w", encoding="utf-8") as f:
        f.write("\n".join(lines) + "\n")
