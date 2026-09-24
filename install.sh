#!/bin/bash
#
# Installs mod by linking mod.sh onto your PATH. Safe to rerun.
#
#   ./install.sh                 # links into ~/.local/bin (or /usr/local/bin)
#   MOD_BIN_DIR=/opt/bin ./install.sh

set -u

MOD_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

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

# 2. Secrets file, kept outside the checkout so that it survives moves and
#    reinstalls. Copy the template if there is none yet; never overwrite.
MOD_CONFIG="${MOD_CONFIG:-$HOME/.mod}"
if [ -f "${MOD_DIR}/.env" ]; then
  echo "Note: using the legacy ${MOD_DIR}/.env. Run 'mod config migrate' to move it to ${MOD_CONFIG}."
elif [ ! -f "${MOD_CONFIG}" ]; then
  mkdir -p "$(dirname "${MOD_CONFIG}")"
  cp "${MOD_DIR}/.env.config" "${MOD_CONFIG}"
  chmod 600 "${MOD_CONFIG}"
  echo "Created ${MOD_CONFIG} from the template. Run 'mod config' to fill in your keys."
fi

# 3. Put `mod` on PATH via a symlink. mod.sh resolves the link back to this
#    directory, so lib/, bin/ and .env are found wherever the link lives.
if [ -n "${MOD_BIN_DIR:-}" ]; then
  BIN_DIR="$MOD_BIN_DIR"
elif [ -d /usr/local/bin ] && [ -w /usr/local/bin ]; then
  BIN_DIR=/usr/local/bin
else
  BIN_DIR="$HOME/.local/bin"
fi
mkdir -p "$BIN_DIR"
ln -sf "${MOD_DIR}/mod.sh" "${BIN_DIR}/mod"
echo "Linked ${BIN_DIR}/mod -> ${MOD_DIR}/mod.sh"

case ":$PATH:" in
  *":${BIN_DIR}:"*) ;;
  *)
    echo
    echo "${BIN_DIR} is not on your PATH. Add this line to your shell rc file:"
    echo "  export PATH=\"${BIN_DIR}:\$PATH\""
    ;;
esac

# 4. Optional: tab completion and the `m` alias, only once per rc file.
rc=""
case "$(basename "${SHELL:-}")" in
  bash) rc="$HOME/.bashrc" ;;
  zsh)  rc="$HOME/.zshrc" ;;
esac
line="source ${MOD_DIR}/shell.sh"
if [ -n "$rc" ]; then
  if ! grep -qsF "$line" "$rc"; then
    printf '\n# mod-cli completion and aliases\n%s\n' "$line" >> "$rc"
    echo "Added tab completion to ${rc}. Open a new shell or run: source ${rc}"
  fi
else
  echo "For tab completion, add to your shell rc: ${line}"
fi

echo
echo "Done. Try: mod help"
