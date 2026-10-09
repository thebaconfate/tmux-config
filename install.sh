#!/usr/bin/env bash
# Fresh tmux setup: installs tmux (if missing), TPM, links the config, installs plugins.
# Safe to re-run.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONF_SRC="$SCRIPT_DIR/.tmux.conf"
CONF_DEST="$HOME/.tmux.conf"
TPM_DIR="$HOME/.tmux/plugins/tpm"

log() { printf '==> %s\n' "$*"; }

# 1. Dependencies (tmux, git)
missing=()
command -v tmux >/dev/null 2>&1 || missing+=(tmux)
command -v git  >/dev/null 2>&1 || missing+=(git)

if (( ${#missing[@]} )); then
  log "Installing: ${missing[*]}"
  if command -v brew >/dev/null 2>&1; then
    brew install "${missing[@]}"
  elif command -v apt-get >/dev/null 2>&1; then
    sudo apt-get update && sudo apt-get install -y "${missing[@]}"
  elif command -v dnf >/dev/null 2>&1; then
    sudo dnf install -y "${missing[@]}"
  elif command -v pacman >/dev/null 2>&1; then
    sudo pacman -S --noconfirm "${missing[@]}"
  else
    echo "No supported package manager found; install ${missing[*]} manually." >&2
    exit 1
  fi
fi

# 2. TPM
if [[ ! -d "$TPM_DIR" ]]; then
  log "Cloning TPM"
  git clone https://github.com/tmux-plugins/tpm "$TPM_DIR"
else
  log "TPM already installed"
fi

# 3. Link the config (back up anything that isn't already our symlink)
[[ -f "$CONF_SRC" ]] || { echo "Missing $CONF_SRC" >&2; exit 1; }
if [[ -L "$CONF_DEST" && "$(readlink "$CONF_DEST")" == "$CONF_SRC" ]]; then
  log "Config already linked"
else
  if [[ -e "$CONF_DEST" || -L "$CONF_DEST" ]]; then
    backup="$CONF_DEST.bak.$(date +%Y%m%d%H%M%S)"
    log "Backing up existing config to $backup"
    mv "$CONF_DEST" "$backup"
  fi
  log "Linking $CONF_DEST -> $CONF_SRC"
  ln -s "$CONF_SRC" "$CONF_DEST"
fi

# 4. Install plugins. TPM needs a running server with the config loaded.
log "Installing plugins"
export TMUX_PLUGIN_MANAGER_PATH="$HOME/.tmux/plugins"
SESSION="tpm-install-$$"
tmux new-session -d -s "$SESSION"
"$TPM_DIR/bin/install_plugins"
tmux kill-session -t "$SESSION" 2>/dev/null || true

log "Done. Start tmux, or run 'tmux kill-server && tmux' if a server was already running."
