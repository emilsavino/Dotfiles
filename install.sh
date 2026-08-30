#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
HOME_DIR="${HOME:?HOME is not set}"
BACKUP_ROOT="${HOME_DIR}/.dotfiles-backups"
BACKUP_DIR=""
BREW_BIN=""
DRY_RUN=0
SKIP_BREW=0
INSTALL_HOMEBREW=0

usage() {
    cat <<'EOF'
Usage: ./install.sh [options]

Install Homebrew dependencies and link this repository's macOS config files.

Options:
  --dry-run             Show actions without changing files or installing packages.
  --skip-brew           Skip Homebrew dependency installation and checks.
  --install-homebrew   Install Homebrew if it is not already available.
  -h, --help            Show this help.
EOF
}

log() {
    printf '[dotfiles] %s\n' "$*"
}

die() {
    printf '[dotfiles] error: %s\n' "$*" >&2
    exit 1
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --dry-run)
            DRY_RUN=1
            ;;
        --skip-brew)
            SKIP_BREW=1
            ;;
        --install-homebrew)
            INSTALL_HOMEBREW=1
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            usage >&2
            die "unknown option: $1"
            ;;
    esac
    shift
done

[ "$(uname -s)" = "Darwin" ] || die "this bootstrap is intended for macOS"

for required_file in \
    "${SCRIPT_DIR}/.zshrc" \
    "${SCRIPT_DIR}/.aerospace.toml" \
    "${SCRIPT_DIR}/.config/ghostty/config" \
    "${SCRIPT_DIR}/.config/cmux/cmux.json" \
    "${SCRIPT_DIR}/Brewfile"; do
    [ -f "$required_file" ] || die "required repository file is missing: $required_file"
done

find_brew() {
    BREW_BIN=""

    if command -v brew >/dev/null 2>&1; then
        BREW_BIN="$(command -v brew)"
    elif [ -x "/opt/homebrew/bin/brew" ]; then
        BREW_BIN="/opt/homebrew/bin/brew"
    elif [ -x "/usr/local/bin/brew" ]; then
        BREW_BIN="/usr/local/bin/brew"
    fi
}

find_brew

if [ "$SKIP_BREW" -eq 0 ]; then
    if [ -z "$BREW_BIN" ] && [ "$INSTALL_HOMEBREW" -eq 1 ]; then
        if [ "$DRY_RUN" -eq 1 ]; then
            log "would install Homebrew with the official installer"
        else
            log "installing Homebrew"
            /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
            find_brew
        fi
    fi

    if [ -z "$BREW_BIN" ]; then
        if [ "$DRY_RUN" -eq 1 ]; then
            if [ "$INSTALL_HOMEBREW" -eq 1 ]; then
                log "would run Homebrew Bundle after installing Homebrew"
            else
                log "Homebrew not found; a real run would stop here (use --install-homebrew)"
            fi
        else
            die "Homebrew was not found; install it or rerun with --install-homebrew"
        fi
    else
        if [ "$DRY_RUN" -eq 1 ]; then
            log "would run: $BREW_BIN bundle --file=$SCRIPT_DIR/Brewfile"
        else
            eval "$("$BREW_BIN" shellenv)"
            "$BREW_BIN" bundle --file="$SCRIPT_DIR/Brewfile"
            "$BREW_BIN" bundle check --file="$SCRIPT_DIR/Brewfile" >/dev/null
            log "Homebrew dependencies are installed"
        fi
    fi
else
    log "skipping Homebrew dependency installation"
fi

ensure_backup_dir() {
    [ -n "$BACKUP_DIR" ] && return

    local stamp candidate suffix
    stamp="$(date +%Y%m%d-%H%M%S)"
    candidate="${BACKUP_ROOT}/${stamp}"
    suffix=1

    while [ -e "$candidate" ]; do
        candidate="${BACKUP_ROOT}/${stamp}-${suffix}"
        suffix=$((suffix + 1))
    done

    BACKUP_DIR="$candidate"
    [ "$DRY_RUN" -eq 1 ] || mkdir -p "$BACKUP_DIR"
}

backup_destination() {
    local target="$1"
    local relative

    if [[ "$target" == "${HOME_DIR}/"* ]]; then
        relative="${target#${HOME_DIR}/}"
    else
        relative="$(basename "$target")"
    fi

    printf '%s/%s\n' "$BACKUP_DIR" "$relative"
}

migrate_existing_zshrc() {
    local current="${HOME_DIR}/.zshrc"
    local local_file="${HOME_DIR}/.zshrc.local"
    local classpath_line conda_block

    if [ ! -f "$current" ] || [ -L "$current" ] || [ -e "$local_file" ] || [ -L "$local_file" ]; then
        return
    fi

    classpath_line="$(sed -n '/^export CLASSPATH=/p' "$current" || true)"
    conda_block="$(sed -n '/^# >>> conda initialize >>>/,/^# <<< conda initialize <<</p' "$current" || true)"

    if [ -z "${classpath_line}${conda_block}" ]; then
        return
    fi

    if [ "$DRY_RUN" -eq 1 ]; then
        log "would migrate Miniconda/CLASSPATH settings from $current to $local_file"
        return
    fi

    umask 077
    {
        printf '%s\n' '# Machine-specific settings migrated by Dotfiles/install.sh.'
        if [ -n "$classpath_line" ]; then
            printf '%s\n\n' "$classpath_line"
        fi
        if [ -n "$conda_block" ]; then
            printf '%s\n' "$conda_block"
        fi
    } > "$local_file"
    chmod 600 "$local_file"
    log "migrated machine-specific shell settings to $local_file"
}

link_file() {
    local source="$1"
    local target="$2"
    local current_link backup

    [ -f "$source" ] || die "source file is missing: $source"

    if [ -L "$target" ]; then
        current_link="$(readlink "$target")"
        if [ "$current_link" = "$source" ]; then
            log "already linked: $target"
            return
        fi
    fi

    if [ -e "$target" ] || [ -L "$target" ]; then
        ensure_backup_dir
        backup="$(backup_destination "$target")"
        if [ "$DRY_RUN" -eq 0 ]; then
            log "backing up $target to $backup"
            mkdir -p "$(dirname "$backup")"
            mv "$target" "$backup"
        else
            log "would back up $target to $backup"
        fi
    fi

    if [ "$DRY_RUN" -eq 1 ]; then
        log "would link $target -> $source"
        return
    fi

    mkdir -p "$(dirname "$target")"
    ln -s "$source" "$target"
    log "linked $target -> $source"
}

validate_configs() {
    if command -v zsh >/dev/null 2>&1; then
        zsh -n "${SCRIPT_DIR}/.zshrc"
        log "validated .zshrc syntax"
    fi

    if command -v ghostty >/dev/null 2>&1; then
        ghostty +validate-config --config-file="${SCRIPT_DIR}/.config/ghostty/config" >/dev/null
        log "validated Ghostty configuration"
    else
        log "Ghostty CLI not found; skipped Ghostty validation"
    fi

    if command -v cmux >/dev/null 2>&1; then
        cmux config validate --path "${SCRIPT_DIR}/.config/cmux/cmux.json" >/dev/null
        log "validated cmux configuration"
    else
        log "cmux CLI not found; skipped cmux validation"
    fi
}

migrate_existing_zshrc

link_file "${SCRIPT_DIR}/.zshrc" "${HOME_DIR}/.zshrc"
link_file "${SCRIPT_DIR}/.aerospace.toml" "${HOME_DIR}/.aerospace.toml"
link_file "${SCRIPT_DIR}/.config/ghostty/config" "${HOME_DIR}/.config/ghostty/config"
link_file "${SCRIPT_DIR}/.config/cmux/cmux.json" "${HOME_DIR}/.config/cmux/cmux.json"

validate_configs

if [ -n "$BACKUP_DIR" ]; then
    if [ "$DRY_RUN" -eq 1 ]; then
        log "backups would be stored in $BACKUP_DIR"
    else
        log "backups are stored in $BACKUP_DIR"
    fi
fi

log "bootstrap complete; open a new shell and reload AeroSpace/Ghostty/cmux if needed"
