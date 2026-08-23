# brew-launcher

A fast, interactive launcher for your installed Homebrew CLI applications.

<p align="center">
  <img src="assets/demo.gif">
</p>

Works on macOS and Linux. Built on fzf, with optional Ghostty integration on macOS.

## Introduction

Homebrew makes it easy to install terminal tools — and just as easy to forget what you've installed and what they're called. `brew-launcher` gives you one command, `brew-launcher`, that lists everything with a description of what it does, so you can search and launch instead of trying to remember whether it was `bottom` or `btop`.

## Quick Start

```bash
brew install ltdan-88/brew-launcher/brew-launcher
brew-launcher
```

That's it — no configuration needed. Type to search, **Enter** to launch, **Esc** to quit.

## Features

- **Automatic Discovery** – Finds installed Homebrew CLI applications automatically
- **Metadata Display** – Shows application descriptions, installed versions, and disk size
- **Fast Startup** – Persistent metadata cache automatically refreshes when Homebrew changes
- **Outdated Indicator** – See which applications have updates available (`*` symbol)
- **Fuzzy Search** – Type to search applications by name or description
- **Hide Entries** – Temporarily hide applications you don't use
- **Restore Hidden** – View and restore hidden entries from within the launcher
- **Terminal Backends** – Choose where applications launch (current terminal or Ghostty)
- **macOS Shortcuts** – Create .command shortcuts for your favorite tools
- **Keyboard-Driven** – Fully navigable with keyboard shortcuts
- **Responsive UI** – Built on fzf for a snappy terminal experience

## Requirements

- macOS or Linux
- [Homebrew](https://brew.sh/)
- [python3](https://www.python.org/) – usually already on your system

[fzf](https://github.com/junegunn/fzf) is installed automatically as a dependency — no separate step needed.

Optional, macOS only:
- [Ghostty](https://ghostty.org/) – launches picked apps in a new tab instead of replacing the picker

## Usage

Refresh the application cache:

```bash
brew-launcher --refresh
```

Print entries as plain tab-separated text (for scripting or shell completion, not for humans) — `command  formula  version  size  outdated  description`:

```bash
brew-launcher --list
```

View version and help:

```bash
brew-launcher --version
brew-launcher --help
```

## Keyboard Shortcuts

| Key | Action |
|------|---------|
| **Enter** | Launch selected application |
| **F2** / **⌥H** | Hide selected entry |
| **F3** / **⌥V** | View and restore hidden entries |
| **F4** / **⌥S** | Create macOS shortcut |
| **Esc** | Quit or go back |

The ⌥ (Option) aliases work if F-keys need Fn on your keyboard. In stock Terminal.app, enable "Use Option as Meta Key" in the profile's Keyboard settings first; Ghostty supports it by default.

An entry with an update available is marked with `*`.

## Terminal Backends

By default, `brew-launcher` automatically selects the best terminal for your system. On macOS, it prefers Ghostty if available; on Linux, it uses the current terminal.

Override this behavior with the `BREW_LAUNCHER_TERMINAL` environment variable:

```bash
# Auto-detect (default)
BREW_LAUNCHER_TERMINAL=auto brew-launcher

# Launch in current terminal
BREW_LAUNCHER_TERMINAL=current brew-launcher

# Launch in Ghostty
BREW_LAUNCHER_TERMINAL=ghostty brew-launcher
```

Add to your shell configuration to make this permanent:

```bash
export BREW_LAUNCHER_TERMINAL=ghostty
```

## Hidden Entries

Hide applications you don't frequently use with **F2** (or **⌥H**). Hidden entries:

- Are **not removed** from Homebrew
- **Don't appear** in the launcher by default
- Can be **restored** by pressing **F3** (or **⌥V**) and selecting "Restore"

Configuration file location:

```
~/.config/brew-launcher/ignore
```

To manually clear all hidden entries, remove this file and restart the launcher.

## Application Shortcuts

Create macOS .command shortcuts for quick access to your favorite tools:

1. Select an application in the launcher
2. Press **F4** (or **⌥S**)
3. A shortcut is created in `/Applications/TUIs/`

Example shortcuts:

```
/Applications/TUIs/btop.command
/Applications/TUIs/superfile.command
/Applications/TUIs/linecast-weather.command
```

You can:

- **Run shortcuts directly** – Double-click them or run from terminal
- **Add to Dock** – Drag shortcuts to the Dock for one-click access
- **Assign keyboard shortcuts** – Use System Settings > Keyboard to trigger them globally
- **Organize by folder** – Move shortcuts around in `/Applications/TUIs/` as needed

## Automator Launcher

The repository includes an AppleScript for creating a macOS Automator launcher:

`extras/Brew Launcher.applescript`

To create the launcher:

1. Open Automator.
2. Choose **Application**.
3. Add a **Run AppleScript** action.
4. Replace the default AppleScript with the contents of `extras/Brew Launcher.applescript`.
5. Save the application as `Brew Launcher.app`.
6. Add it to the Dock or assign it a keyboard shortcut.

The launcher starts `brew-launcher` in the current Ghostty tab. When an application is selected, `brew-launcher` opens it in a new Ghostty tab.
