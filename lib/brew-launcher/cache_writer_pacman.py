#!/usr/bin/env python3
"""pacman-backed cache writer for brew-launcher.

Sibling of cache_writer.py, populating the exact same tab-separated
cache from `pacman -Qe`/`-Qi`/`-Ql`/`-Qu` instead of Homebrew's own
`brew info --json`. See cache_writer.py's own docstring for the column
schema (unchanged here) and CACHE_FORMAT_VERSION in bin/brew-launcher
for what each column means.

Grew out of a standalone spike (see git history) that first proved the
existing cache format and the UI built on it work against pacman's
data with no changes to that layer — this is the hardened version of
that prototype, wired into rebuild_cache_pacman() in bin/brew-launcher
the same way cache_writer.py is wired into rebuild_cache().

Real differences from Homebrew, confirmed live rather than assumed —
see cache_writer.py's own comments for the Homebrew side of each:

- `pacman -Qe` (explicitly installed) needs no dependency-vs-manual
  filtering beyond a small, fixed set of base-system meta-packages a
  real install always includes (see BASE_SYSTEM_NOISE below) — nowhere
  near WinGet's "no signal at all" problem this project looked at
  before choosing pacman as the first non-Homebrew backend to build.
- One `pacman -Qi` call already carries description, version, size,
  homepage, license, and install date together — Homebrew needs a
  separate `brew info --sizes` call for the one of those it doesn't
  already have.
- Multi-command packages produce the exact same "which of these does
  anyone actually launch" problem Homebrew's own DEFAULT_HIDDEN
  exists for — confirmed live per package below, not guessed. Several
  entries here are the exact same helper names Homebrew already
  hides for the same upstream project (calcurse's own migration/sync
  scripts, newsboat's podboat) — cross-ecosystem confirmation that the
  underlying software, not the package manager, is what creates this
  class of noise.

Usage: cache_writer_pacman.py <outdated_file> <output_file> <preview_dir> <category_marker> <preset_marker>
"""

import os
import subprocess
import sys

outdated_file = sys.argv[1]
output_file = sys.argv[2]
preview_dir = sys.argv[3]
category_marker = sys.argv[4]
preset_marker = sys.argv[5]

# ------------------------------------------------------------
# Bundled curated data — see "Bundled defaults" in the README and
# cache_writer.py's own DEFAULT_CATEGORIES/DEFAULT_HIDDEN for the
# Homebrew side of the same idea. Reviewed one package at a time,
# live, against real `pacman -Ql` output — not guessed, not a blanket
# naming-pattern rule (same reasoning CONTRIBUTING.md already gives
# for rejecting one on the Homebrew side). A starting set, meant to
# grow the same way Homebrew's own list did — not a claim of complete
# coverage across every package in the official repos.
# ------------------------------------------------------------

DEFAULT_CATEGORIES = {
    "btop": "System Monitoring",
    "htop": "System Monitoring",
    "glances": "System Monitoring",
    "ncdu": "Disk Usage",
    "yazi": "File Manager",
    "ranger": "File Manager",
    "nnn": "File Manager",
    "mc": "File Manager",  # Arch's own package name for Midnight Commander
    "tig": "Git & Version Control",
    "git": "Git & Version Control",
    "cmus": "Media & Visuals",
    "ncmpcpp": "Media & Visuals",
    "weechat": "Chat",
    "calcurse": "Productivity",
    "task": "Productivity",
    "newsboat": "Reading & Reference",
    "lynx": "Reading & Reference",
    "cmatrix": "Fun & Toys",
    "tmux": "Terminal Utility",
    "neovim": "Editors",
}

# Real, fixed meta-packages `pacman -Qe` includes on any real Arch
# install (choices made once, at install time, not something a user
# picks again later) — confirmed live that a stock container only
# ever adds "base" to this on top of whatever's actually installed;
# a real desktop would also select some of the others below.
BASE_SYSTEM_NOISE = {"base", "base-devel", "linux", "linux-firmware", "linux-headers"}

# Per-package helper binaries confirmed live via `pacman -Ql`, not a
# generic naming-pattern rule — see this file's own module docstring.
DEFAULT_HIDDEN = {
    "rifle",  # ranger's own internal file-opener, not launched directly
    "cmus-remote",  # controls an already-running cmus, not its own TUI
    "weechat-headless",  # explicitly non-interactive; weechat itself is the TUI
    "calcurse-caldav",  # same helper Homebrew's own DEFAULT_HIDDEN already hides
    "calcurse-upgrade",  # same helper Homebrew's own DEFAULT_HIDDEN already hides
    "calcurse-vdir",  # same helper Homebrew's own DEFAULT_HIDDEN already hides
    "podboat",  # same call Homebrew's own DEFAULT_HIDDEN already made for newsboat
    "git-cvsserver",
    "git-receive-pack",
    "git-shell",
    "git-upload-archive",
    "git-upload-pack",
    "scalar",
    "artist_to_albumartist",  # ncmpcpp's own one-shot library-migration script
}


def run(*args):
    return subprocess.run(
        args, capture_output=True, text=True, check=False
    ).stdout


def format_size(kib_str):
    """pacman reports installed size in KiB, e.g. "1737.27 KiB" —
    matching Homebrew's own "1.7MB"/"317.2KB" cache-column style so the
    size column and sort-by-size both work unmodified."""
    try:
        kib = float(kib_str.split()[0])
    except (ValueError, IndexError):
        return ""
    if kib >= 1024:
        return f"{kib / 1024:.1f}MB"
    return f"{kib:.1f}KB"


def parse_pacman_info(name):
    """One `pacman -Qi` call already carries everything this cache (and
    the details-pane preview) needs — description, size, homepage,
    license, and install date, all in "Label   : value" lines."""
    info = {}
    for line in run("pacman", "-Qi", name).splitlines():
        if ":" not in line:
            continue
        label, _, value = line.partition(":")
        info[label.strip()] = value.strip()
    return info


# ------------------------------------------------------------
# Outdated formulae, same tab-separated "name<TAB>new-version" shape
# fetch_outdated_formulae() already writes for Homebrew — written here
# rather than requiring a second pacman call from the caller, since
# `pacman -Qu` already needs a synced database the caller just
# refreshed for `-Qi`/`-Ql` above to be accurate anyway.
#
# Output format: "name oldver -> newver" (with "[ignored]" sometimes
# appended for held-back packages) — only the name and the version
# after "->" matter here.
# ------------------------------------------------------------

with open(outdated_file, "w", encoding="utf-8") as f:
    for line in run("pacman", "-Qu").splitlines():
        parts = line.split()
        if len(parts) >= 4 and parts[2] == "->":
            f.write(f"{parts[0]}\t{parts[3]}\n")

outdated = {}
try:
    with open(outdated_file, encoding="utf-8") as f:
        for line in f:
            name, _, new_version = line.rstrip("\n").partition("\t")
            if name and new_version:
                outdated[name] = new_version
except OSError:
    pass

# ------------------------------------------------------------
# Explicitly-installed packages — pacman's own direct equivalent of
# `brew leaves --installed-on-request`. Confirmed live to need no
# further "was this really on purpose" filtering beyond the small,
# fixed BASE_SYSTEM_NOISE set above.
# ------------------------------------------------------------

leaves = [line.split()[0] for line in run("pacman", "-Qe").splitlines() if line.strip()]

entries = []
previews = {}

for name in leaves:

    if name in BASE_SYSTEM_NOISE:
        continue

    info = parse_pacman_info(name)
    description = (info.get("Description", "") or "Arch Linux package").replace(
        "\t", " "
    ).replace("\n", " ")
    version = info.get("Version", "")
    size = format_size(info.get("Installed Size", ""))
    homepage = info.get("URL", "")
    license_ = info.get("Licenses", "")
    install_time = "0"

    install_date_str = info.get("Install Date", "")
    if install_date_str:
        # Real `pacman -Qi` output, confirmed live: "Fri Sep  4
        # 11:31:01 2026" (note the double space before a single-digit
        # day) — glibc's own `date -d` parses this natively, no fixed
        # strptime format string needed for that spacing quirk.
        install_time = run("date", "-d", install_date_str, "+%s").strip() or "0"

    outdated_flag = "1" if name in outdated else "0"

    for line in run("pacman", "-Ql", name).splitlines():

        parts = line.split(" ", 1)
        if len(parts) != 2:
            continue

        path = parts[1].strip()

        if not (path.startswith("/usr/bin/") or path.startswith("/usr/local/bin/")):
            continue

        command = os.path.basename(path)

        if not command or command in DEFAULT_HIDDEN:
            continue

        if not (os.path.isfile(path) and os.access(path, os.X_OK)):
            continue

        default_category = DEFAULT_CATEGORIES.get(name, "") or "-"

        entries.append(
            "\t".join(
                [
                    command,
                    description,
                    name,
                    version,
                    size,
                    outdated_flag,
                    name,  # full_name — no tap-qualification concept in pacman
                    path,
                    install_time,
                    default_category,
                    "0",  # DEFAULT_HIDDEN above already filtered these out entirely
                ]
            )
        )

    if name not in previews:

        lines = [f"  {name}  {version}".rstrip(), ""]
        if description:
            lines += [f"  {description}", ""]
        for label, value in (
            ("Homepage", homepage),
            ("License", license_),
            ("Size", size),
        ):
            if value:
                lines.append(f"  {label:<18}{value}")
        if name in outdated:
            lines.append(f"  {'Update available':<18}{outdated[name]}")

        # Filled in at display time by --internal-preview, same as
        # cache_writer.py's own preview text — this handler is already
        # backend-agnostic, it just looks for the marker string.
        lines.append(category_marker)
        lines.append(preset_marker)

        previews[name] = "\n".join(lines) + "\n"

# Same trailing-newline requirement cache_writer.py's own comment
# documents — bin/brew-launcher's `while IFS=... read` loop silently
# skips a final line with no newline terminator.
with open(output_file, "w", encoding="utf-8") as f:
    for entry in sorted(entries):
        f.write(entry + "\n")

os.makedirs(preview_dir, exist_ok=True)
for old in os.listdir(preview_dir):
    try:
        os.remove(os.path.join(preview_dir, old))
    except OSError:
        pass
for name, text in previews.items():
    with open(os.path.join(preview_dir, name), "w", encoding="utf-8") as f:
        f.write(text)
