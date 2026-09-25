#!/bin/bash
#
# Installs mod by linking mod.sh onto your PATH. Safe to rerun.
#
#   curl -fsSL https://raw.githubusercontent.com/modulo-zero/mod/master/install.sh | bash
#   ./install.sh                 # from an existing checkout
#
#   MOD_DIR=~/src/mod            # where to clone (default ~/mod-cli)
#   MOD_REPO=<git url>           # what to clone (default github modulo-zero/mod)
#   MOD_BIN_DIR=~/.local/bin      # where to link mod (default /usr/local/bin)

set -u

# Everything is installed per user. Run as root it would create ~/.mod and the
# checkout owned by root, locking the real user out of their own config.
if [ "$(id -u)" -eq 0 ] && [ -n "${SUDO_USER:-}" ]; then
  echo "Error: do not run the installer with sudo. Run it as ${SUDO_USER}; it asks for sudo itself"
  echo "only for the symlink into /usr/local/bin."
  exit 1
fi

# 0. Locate or fetch the checkout. When piped from curl there is no script
#    file on disk, so BASH_SOURCE is empty and the repo is cloned first.
if [ -n "${BASH_SOURCE[0]:-}" ] && [ -f "$(dirname "${BASH_SOURCE[0]}")/mod.sh" ]; then
  MOD_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
else
  MOD_DIR="${MOD_DIR:-$HOME/mod-cli}"
  MOD_REPO="${MOD_REPO:-git@github.com:modulo-zero/mod.git}"
  if ! command -v git >/dev/null 2>&1; then
    echo "Error: git is not installed."
    exit 1
  fi
  if [ -f "${MOD_DIR}/mod.sh" ]; then
    echo "Using existing checkout at ${MOD_DIR}"
  else
    echo "Cloning ${MOD_REPO} into ${MOD_DIR}..."
    git clone --quiet "${MOD_REPO}" "${MOD_DIR}" || exit 1
  fi
fi

# 1. Runtime dependencies. Node is only needed by `mod pk`, and is checked
#    lazily by mod.sh the first time that command runs.
missing=0
need() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Error: '$1' is not installed. $2"
    missing=1
  fi
}
need cast "Install Foundry: curl -L https://foundry.paradigm.xyz | bash && foundryup"
need forge "Install Foundry: curl -L https://foundry.paradigm.xyz | bash && foundryup"
need jq   "Install jq: brew install jq  (or apt install jq)"
if [ "$missing" -ne 0 ]; then
  echo "Install the missing tools above and rerun ./install.sh"
  exit 1
fi

# 2. Config directory, kept outside the checkout so that it survives moves
#    and reinstalls:
#      ~/.mod/env              secrets, from .env.config
#      ~/.mod/mod.config.json  global networks and envs, from mod.config.example.json
#    Existing files are never overwritten.
MOD_HOME="${MOD_HOME:-$HOME/.mod}"
if [ -f "${MOD_HOME}" ]; then
  # Earlier installs kept the secrets in a file at ~/.mod itself.
  mv "${MOD_HOME}" "${MOD_HOME}.tmp" && mkdir -p "${MOD_HOME}" && mv "${MOD_HOME}.tmp" "${MOD_HOME}/env"
  echo "Moved ${MOD_HOME} -> ${MOD_HOME}/env"
fi
mkdir -p "${MOD_HOME}" && chmod 700 "${MOD_HOME}"
MOD_CONFIG="${MOD_CONFIG:-${MOD_HOME}/env}"
if [ -f "${MOD_DIR}/.env" ]; then
  echo "Note: using the legacy ${MOD_DIR}/.env. Run 'mod config migrate' to move it to ${MOD_CONFIG}."
elif [ ! -f "${MOD_CONFIG}" ]; then
  cp "${MOD_DIR}/.env.config" "${MOD_CONFIG}"
  chmod 600 "${MOD_CONFIG}"
  echo "Created ${MOD_CONFIG} from the template. Run 'mod config' to fill in your keys."
fi
if [ ! -f "${MOD_HOME}/mod.config.json" ]; then
  cp "${MOD_DIR}/mod.config.example.json" "${MOD_HOME}/mod.config.json"
  echo "Created ${MOD_HOME}/mod.config.json. Run 'mod config networks' to add your networks."
fi

# 3. Put `mod` on PATH by linking into /usr/local/bin, which every shell
#    already searches, so no rc file needs editing. mod.sh resolves the link
#    back to this directory, so lib/, bin/ and the config are found from there.
BIN_DIR="${MOD_BIN_DIR:-/usr/local/bin}"
if [ -w "$BIN_DIR" ]; then
  ln -sf "${MOD_DIR}/mod.sh" "${BIN_DIR}/mod"
else
  echo "Linking into ${BIN_DIR} needs sudo:"
  sudo ln -sf "${MOD_DIR}/mod.sh" "${BIN_DIR}/mod" || exit 1
fi
echo "Linked ${BIN_DIR}/mod -> ${MOD_DIR}/mod.sh"

case ":$PATH:" in
  *":${BIN_DIR}:"*) ;;
  *) echo "Note: ${BIN_DIR} is not on your PATH." ;;
esac

# 4. Clean up rc lines left by the previous installer, which sourced shell.sh
#    from a checkout that may no longer exist. Completion is now opt-in; see
#    the README.
for rc in "$HOME/.bashrc" "$HOME/.zshrc"; do
  [ -f "$rc" ] || continue
  if grep -qE '^source .*/shell\.sh$' "$rc"; then
    sed -i.mod-bak -E '/^# mod-cli completion and aliases$/d; /^source .*\/shell\.sh$/d' "$rc"
    rm -f "${rc}.mod-bak"
    echo "Removed the old 'source .../shell.sh' line from ${rc}. Start a new shell to drop the stale alias."
  fi
done

echo
echo "Done. Try: mod help"
