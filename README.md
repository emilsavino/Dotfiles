# Dotfiles

Personal macOS configuration files managed in Git and exposed to applications
through symlinks.

## Install on a Mac

Install Homebrew first, then run:

```sh
git clone <repository-url> ~/Dotfiles
cd ~/Dotfiles
./install.sh
```

If Homebrew is not installed, use the explicit opt-in bootstrap:

```sh
./install.sh --install-homebrew
```

Use `./install.sh --dry-run` to inspect actions or
`./install.sh --skip-brew` when the applications are already installed.

## Managed paths

| Application | Live path |
| --- | --- |
| zsh | `~/.zshrc` |
| AeroSpace | `~/.aerospace.toml` |
| Ghostty | `~/.config/ghostty/config` |
| cmux | `~/.config/cmux/cmux.json` |

Edit the files in this repository. Existing live files are moved to a
timestamped directory under `~/.dotfiles-backups/` before linking.

cmux session state, credentials, databases, and restore snapshots are not
managed. Machine-specific shell settings belong in `~/.zshrc.local`; copy
`.zshrc.local.example` as a starting point. The installer automatically
migrates the current Miniconda and CLASSPATH blocks on its first run when that
local file does not yet exist.

## Dependencies

`Brewfile` installs AeroSpace, Ghostty, cmux, JankyBorders, and JetBrains
Mono. AeroSpace starts JankyBorders from its configuration.

Configuration references:

- [AeroSpace configuration](https://nikitabobko.github.io/AeroSpace/guide)
- [Ghostty configuration](https://ghostty.org/docs/config)
- [cmux settings](https://cmux.com/docs/getting-started)
