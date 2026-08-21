# brew-launcher

A fast, interactive launcher for your installed Homebrew CLI applications.

Built for macOS + Ghostty + fzf.

## Features

- Automatically discovers installed Homebrew CLI applications
- Uses Homebrew's descriptions
- No hardcoded application list
- Persistent metadata cache for fast startup
- Automatically refreshes when Homebrew changes
- Fuzzy search
- Responsive terminal UI
- Launches selected applications in a new Ghostty tab
- Launcher remains available after launching an application
- Supports `--refresh`, `--help`, and `--version`

## Requirements

- macOS
- [Homebrew](https://brew.sh/)
- [Ghostty](https://ghostty.org/)
- [fzf](https://github.com/junegunn/fzf)

## Installation

Install with Homebrew:

```bash
brew install ltdan-88/brew-launcher/brew-launcher
```
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
