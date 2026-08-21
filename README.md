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
