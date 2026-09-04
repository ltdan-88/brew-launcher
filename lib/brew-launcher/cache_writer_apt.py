#!/usr/bin/env python3
"""SPIKE: apt-backed cache writer for brew-launcher.

Same purpose as cache_writer_pacman.py's own docstring — not wired
into bin/brew-launcher, a standalone prototype proving the existing
cache format and the UI built on it work against apt's data too, with
zero changes to the interaction layer. See that file for the shared
reasoning; only the apt-specific differences are called out here.

Two real differences from pacman/Homebrew, found live while writing
this:

- `dpkg -s`/`apt-cache show` carry no license field at all — Debian
  tracks that separately, per package, in a `/usr/share/doc/<pkg>/
  copyright` file, not simple metadata. Omitted here rather than
  faked.
- Neither carries an install date either. Reconstructed from
  /var/log/dpkg.log's own "install" lines instead (real, parseable,
  confirmed live) — but that log rotates, so a very old install on a
  long-lived machine could eventually fall out of it, unlike
  Homebrew's or pacman's own metadata, which doesn't decay this way.
  A real implementation would need to decide whether that's
  acceptable or worth a different source.

Usage: cache_writer_apt.py <output_file> <preview_dir>
"""

import os
import re
import subprocess
import sys

output_file = sys.argv[1]
preview_dir = sys.argv[2]

# A handful of entries lifted from cache_writer.py's own
# DEFAULT_CATEGORIES, same "proves the mechanism transfers, not a full
# audit" caveat as cache_writer_pacman.py's own copy.
DEFAULT_CATEGORIES = {
    "btop": "System Monitoring",
    "htop": "System Monitoring",
    "ncdu": "Disk Usage",
    "neovim": "Editors",
    "tmux": "Terminal Utility",
    "git": "Git & Version Control",
}

# The big, real difference from pacman: apt's baseline "manually
# installed" list already has ~87 base-system packages on a stock
# Ubuntu image before a user installs anything of their own — see the
# live count that surfaced this. Confirmed live, separately, that this
# baseline is fixed and every package a user explicitly installs
# afterward shows up cleanly on top of it, correctly separated from
# its own pulled-in dependencies — so this is a one-time list to
# maintain, not a sign the underlying signal is unreliable. This is
# the literal set found live on a stock ubuntu:24.04 container; a real
# implementation would need its own audit pass, the same way
# DEFAULT_HIDDEN above did for Homebrew.
BASE_IMAGE_NOISE = {
    "apt", "base-files", "base-passwd", "bash", "bsdutils", "coreutils",
    "dash", "debconf", "debianutils", "diffutils", "dpkg", "e2fsprogs",
    "findutils", "gcc-14-base", "gpgv", "grep", "gzip", "hostname",
    "init-system-helpers", "libacl1", "libapt-pkg6.0t64", "libassuan0",
    "libattr1", "libaudit-common", "libaudit1", "libblkid1", "libbz2-1.0",
    "libc-bin", "libc6", "libcap-ng0", "libcap2", "libcom-err2", "libcrypt1",
    "libdebconfclient0", "libext2fs2t64", "libffi8", "libgcc-s1",
    "libgcrypt20", "libgmp10", "libgnutls30t64", "libgpg-error0",
    "libhogweed6t64", "libidn2-0", "liblz4-1", "liblzma5", "libmd0",
    "libmount1", "libncursesw6", "libnettle8t64", "libnpth0t64",
    "libp11-kit0", "libpam-modules", "libpam-modules-bin", "libpam-runtime",
    "libpam0g", "libpcre2-8-0", "libproc2-0", "libseccomp2", "libselinux1",
    "libsemanage-common", "libsemanage2", "libsepol2", "libsmartcols1",
    "libss2", "libssl3t64", "libstdc++6", "libsystemd0", "libtasn1-6",
    "libtinfo6", "libudev1", "libunistring5", "libuuid1", "libxxhash0",
    "libzstd1", "login", "logsave", "mawk", "mount", "ncurses-base",
    "ncurses-bin", "passwd", "perl-base", "procps", "sed",
    "sensible-utils", "sysvinit-utils", "tar", "ubuntu-keyring",
    "unminimize", "util-linux", "zlib1g",
}

# Same class of problem as Homebrew's own multi-binary formulae and
# pacman's own git package — confirmed live: Ubuntu's `git` installs 6
# executables, only `git` itself is something anyone launches by hand.
DEFAULT_HIDDEN = {
    "git-shell",
    "git-receive-pack",
    "git-upload-archive",
    "git-upload-pack",
    "scalar",
}


def run(*args):
    return subprocess.run(
        args, capture_output=True, text=True, check=False
    ).stdout


def format_size(kb):
    """dpkg reports Installed-Size in whole KB — matching Homebrew's
    own "1.7MB"/"317.2KB" style so the size column and sort-by-size
    both work unmodified."""
    try:
        kb = float(kb)
    except (TypeError, ValueError):
        return ""
    if kb >= 1024:
        return f"{kb / 1024:.1f}MB"
    return f"{kb:.1f}KB"


def parse_dpkg_status(name):
    info = {}
    desc_lines = []
    in_description = False
    for line in run("dpkg", "-s", name).splitlines():
        if line.startswith(" ") and in_description:
            continue  # extended description body, not needed here
        in_description = False
        if ":" not in line:
            continue
        label, _, value = line.partition(":")
        label = label.strip()
        value = value.strip()
        if label == "Description":
            in_description = True
        info[label] = value
    return info


# Reconstructs install time from dpkg's own log rather than trusting a
# field that doesn't exist — see this file's own docstring for the
# rotation caveat. Keeps the LAST "install" line per package, since a
# reinstall/upgrade would otherwise be read from its first-ever install.
install_times = {}
_install_re = re.compile(
    r"^(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}) install (\S+):\S+ "
)
try:
    with open("/var/log/dpkg.log", encoding="utf-8", errors="replace") as f:
        for line in f:
            m = _install_re.match(line)
            if not m:
                continue
            ts, pkg = m.groups()
            epoch = run("date", "-d", ts, "+%s").strip()
            if epoch:
                install_times[pkg] = epoch
except OSError:
    pass

# ------------------------------------------------------------
# apt's own equivalent of `brew leaves --installed-on-request` /
# `pacman -Qe` — confirmed live that packages pulled in only as
# dependencies (python3-pynvim, xclip, ... via neovim's Recommends)
# correctly stay off this list.
# ------------------------------------------------------------

leaves = [
    line.strip() for line in run("apt-mark", "showmanual").splitlines() if line.strip()
]

entries = []
previews = {}

for name in leaves:

    if name in BASE_IMAGE_NOISE:
        continue

    info = parse_dpkg_status(name)
    if info.get("Status", "").split()[-1:] != ["installed"]:
        continue

    description = (info.get("Description", "") or "Debian/Ubuntu package").replace(
        "\t", " "
    )
    version = info.get("Version", "")
    size = format_size(info.get("Installed-Size", ""))
    homepage = info.get("Homepage", "")
    install_time = install_times.get(name, "0")

    for line in run("dpkg", "-L", name).splitlines():

        path = line.strip()

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
                    name,  # full_name — no tap-qualification concept in apt
                    path,
                    install_time,
                    default_category,
                    "0",  # already filtered out via DEFAULT_HIDDEN above
                ]
            )
        )

    if name not in previews:
        lines = [f"  {name}  {version}".rstrip(), ""]
        if description:
            lines += [f"  {description}", ""]
        for label, value in (("Homepage", homepage), ("Size", size)):
            if value:
                lines.append(f"  {label:<18}{value}")
        previews[name] = "\n".join(lines) + "\n"

with open(output_file, "w", encoding="utf-8") as f:
    for entry in sorted(entries):
        f.write(entry + "\n")

os.makedirs(preview_dir, exist_ok=True)
for name, text in previews.items():
    with open(os.path.join(preview_dir, name), "w", encoding="utf-8") as f:
        f.write(text)

print(
    f"wrote {len(entries)} entries from {len(previews)} kept packages "
    f"({len(leaves)} total in apt-mark showmanual, {len(BASE_IMAGE_NOISE)} filtered as base-image noise)",
    file=sys.stderr,
)
