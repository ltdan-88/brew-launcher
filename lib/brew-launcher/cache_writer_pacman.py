#!/usr/bin/env python3
"""SPIKE: pacman-backed cache writer for brew-launcher.

Not wired into bin/brew-launcher or rebuild_cache() — this is a
standalone prototype proving that the existing cache format (see
CACHE_FORMAT_VERSION in bin/brew-launcher and cache_writer.py's own
docstring) can be populated from pacman instead of Homebrew, with zero
changes to the UI/interaction layer that actually reads it. Run this,
point XDG_CACHE_HOME at its output with a fresh state-file mtime (same
trick this project's own test suite already uses to skip a live
`brew`/here `pacman` re-check), and launch the real, unmodified
bin/brew-launcher against it.

Deliberately much smaller than cache_writer.py: no bundled-defaults
curation effort beyond a handful of entries copied over to prove the
idea carries across ecosystems too, no outdated-version tracking, no
size-string edge cases beyond what a fresh container actually produces.
This answers one question only — does the existing 11-column cache
schema and the UI built on it work unmodified against a different
package manager's data — not "is this a finished pacman backend."

Same schema, same column order, same "-" placeholder for an absent
default category (see cache_writer.py's own comment on the zsh `read`
tab-collapsing gotcha this sidesteps):

    command, description, formula, version, size, outdated_flag,
    full_name, resolved_path, install_time, default_category,
    default_hidden_flag

Usage: cache_writer_pacman.py <output_file> <preview_dir>
"""

import datetime
import os
import subprocess
import sys

output_file = sys.argv[1]
preview_dir = sys.argv[2]

# ------------------------------------------------------------
# A handful of entries lifted straight from cache_writer.py's own
# DEFAULT_CATEGORIES, for packages that happen to share the exact same
# name in pacman's official repos — not a claim that Homebrew's whole
# curated list transfers as-is (plenty of pacman package names differ,
# and this hasn't been audited command-by-command the way that list
# was), just enough to show the mechanism itself carries over.
# ------------------------------------------------------------

DEFAULT_CATEGORIES = {
    "btop": "System Monitoring",
    "htop": "System Monitoring",
    "ncdu": "Disk Usage",
    "neovim": "Editors",
    "tmux": "Terminal Utility",
    "git": "Git & Version Control",
}

# Meta-packages `pacman -Qe` always includes on a real install (base
# system selections made at install time) that are never something
# anyone launches — the pacman-side equivalent of cache_writer.py's own
# DEFAULT_HIDDEN, just filtering whole packages here instead of
# individual commands within one. Confirmed live: a fresh container
# already shows "base" in `-Qe` with nothing else installed.
NON_TOOL_PACKAGES = {"base", "base-devel", "linux", "linux-firmware", "linux-headers"}

# Real helper binaries found live while spiking this (see git's own
# `pacman -Ql` output: 8 files in /usr/bin, only 2 anyone would ever
# launch by hand) — hand-curated per package, same reasoning
# cache_writer.py's own DEFAULT_HIDDEN comment gives for why this isn't
# a generic naming-pattern rule.
DEFAULT_HIDDEN = {
    "git-cvsserver",
    "git-receive-pack",
    "git-shell",
    "git-upload-archive",
    "git-upload-pack",
    "scalar",
}


def run(*args):
    return subprocess.run(
        args, capture_output=True, text=True, check=False
    ).stdout


def format_size(kib_str):
    """pacman reports "Installed Size" in KiB, e.g. "1737.27 KiB" —
    matching Homebrew's own "1.7MB"/"317.2KB" cache-column style so the
    existing UI's size column and sort-by-size both work unmodified."""
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
    license, install date, and the install-reason signal that made
    `pacman -Qe` possible in the first place. Parsed as plain
    "Label   : value" lines, which is all `-Qi` ever produces."""
    info = {}
    for line in run("pacman", "-Qi", name).splitlines():
        if ":" not in line:
            continue
        label, _, value = line.partition(":")
        info[label.strip()] = value.strip()
    return info


# ------------------------------------------------------------
# Explicitly-installed packages — pacman's own direct equivalent of
# `brew leaves --installed-on-request`, confirmed live to need no
# further "was this really on purpose" filtering beyond the small
# known meta-package list above.
# ------------------------------------------------------------

leaves = [
    line.split()[0]
    for line in run("pacman", "-Qe").splitlines()
    if line.strip()
]

entries = []
previews = {}

for name in leaves:

    if name in NON_TOOL_PACKAGES:
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
        try:
            # Real pacman -Qi output, confirmed live:
            # "Fri Sep  4 11:31:01 2026" (note the double space before
            # a single-digit day) — glibc's own `date -d` handles this
            # natively without a fixed strptime format string, which
            # would otherwise have to special-case that spacing.
            install_time = run("date", "-d", install_date_str, "+%s").strip() or "0"
        except Exception:
            pass

    # --------------------------------------------------------
    # Which files this package actually puts on PATH — the pacman
    # equivalent of cache_writer.py's own opt/<formula>/bin walk.
    # --------------------------------------------------------

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
                    "0",  # outdated_flag — not tracked in this spike
                    name,  # full_name — no tap-qualification concept in pacman
                    path,
                    install_time,
                    default_category,
                    "0",  # default_hidden_flag — DEFAULT_HIDDEN above already filtered these out entirely
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
        previews[name] = "\n".join(lines) + "\n"

# ------------------------------------------------------------
# Write cache — same trailing-newline requirement cache_writer.py's own
# comment documents (bin/brew-launcher's `while IFS=... read` loop
# silently skips a final line with no newline terminator).
# ------------------------------------------------------------

with open(output_file, "w", encoding="utf-8") as f:
    for entry in sorted(entries):
        f.write(entry + "\n")

os.makedirs(preview_dir, exist_ok=True)
for name, text in previews.items():
    with open(os.path.join(preview_dir, name), "w", encoding="utf-8") as f:
        f.write(text)

print(f"wrote {len(entries)} entries from {len(leaves)} explicitly-installed packages", file=sys.stderr)
