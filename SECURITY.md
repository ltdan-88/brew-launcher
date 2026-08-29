# Security Policy

brew-launcher is a personal, one-person open-source project — this policy is
intentionally short and matches that scale, not a formal enterprise process.

## Supported versions

Only the latest released version is supported. There's no long-term-support
branch; a fix ships as a new release (`brew upgrade brew-launcher` picks it
up) rather than being backported.

## Scope

In scope: `bin/brew-launcher` itself — how it resolves and launches
executables, handles filenames typed into categories/presets/renames, writes
and reads its own cache/config files, and parses its config file.

Out of scope: vulnerabilities in Homebrew itself, in the formulae/tools this
launcher discovers and launches, or in third-party terminals it integrates
with (Ghostty, tmux, etc.) — please report those to the relevant upstream
project instead.

## Reporting a vulnerability

Preferred: open a [private security advisory](https://github.com/ltdan-88/brew-launcher/security/advisories/new)
via GitHub's "Report a vulnerability" (repo → Security tab) so nothing
exploitable is public before a fix ships.

If it isn't sensitive — a hardening idea, a "this looks unsafe but I don't
have a working exploit" observation — a normal [issue](https://github.com/ltdan-88/brew-launcher/issues)
is fine and is often faster.

Please include: the version (`brew-launcher --version`), your OS, and
concrete steps to reproduce (or the specific input/config that triggers it).

## What to expect

Best-effort, not a formal SLA — there's no dedicated security team behind
this. In practice, real reported bugs in this project have typically shipped
as a fix the same day they were confirmed; see [CHANGELOG.md](CHANGELOG.md)
for that track record. You'll get a response acknowledging the report, and
credit in the changelog/release notes once a fix ships, unless you'd rather
stay anonymous.

## Design choices already in place

Context for anyone auditing the script — not a claim that it's bug-free:

- Every config-directory file the launcher writes and later reads back
  (`ignore`, `categories/*`, `presets/*`, `config`, `launch-history`) is
  parsed as plain inert data, never sourced or `eval`'d as shell code.
- Temp files use `mktemp` with cleanup traps, not fixed predictable names.
- Category/preset/rename input is validated against path traversal (`/` and
  a leading `.` are rejected) before being used as a filename.
- The cache stores each command's resolved executable path (captured during
  a cache rebuild) rather than doing a fresh, independently-triggerable
  `PATH` lookup at launch time.
- A formula's description — free text a tap maintainer controls, not
  constrained by Homebrew's own name-safety rules — has embedded tabs and
  newlines collapsed to spaces before being written into the cache's
  tab-separated format, so it can't shift or split a row.
