#!/bin/bash

function _mod_complete() {
  local cur prev options

  # The current word being typed.
  cur="${COMP_WORDS[COMP_CWORD]}"

  # The previous word.
  prev="${COMP_WORDS[COMP_CWORD-1]}"

  if [[ ${COMP_CWORD} -eq 1 ]]; then
    options="address balance balance-full call config drain e2e help pk rpc script send tenderly trace upgrade verify wallet"
  elif [[ ${prev} == "balance" ||  ${prev} == "script" || ${prev} == "send" || ${prev} == "call" || ${prev} == "rpc" || ${prev} == "tenderly" ]]; then
    options="mainnet sepolia"
  elif [[ ${prev} == "mainnet" || ${prev} == "sepolia" ]]; then
    options="l1 l2"
  elif [[ ${prev} == "verify" ]]; then
    options="etherscan blastscan tenderly tenderly-fork"
  elif [[ ${prev} == "config" ]]; then
    options="edit path check password migrate"
  elif [[ ${prev} == "wallet" ]]; then
    options="create add address list remove sol"
  elif [[ ${prev} == "sol" ]]; then
    options="create add address list remove"
  fi

  # Use compgen to generate possible matches and assign to COMPREPLY.
  COMPREPLY=($(compgen -W "${options}" -- ${cur}))
  return 0
}

# Indicate that mod-cli has been initialized to other scripts
export _MOD_CLI_INIT=1

# Figure out where the mod-cli was installed
_MOD_CLI_PATH=""
if [[ "$0" == *bash* ]]; then
    # For bash
    _MOD_CLI_PATH="$(dirname "${BASH_SOURCE[0]}")"
elif [[ "$ZSH_VERSION" != "" ]]; then
    # For zsh
    _MOD_CLI_PATH="$(dirname "$0")"
else
    echo "Unsupported shell. Could not determine mod cli path."
    return 1
fi

# register the shell completions for all the mod-cli aliases
# (zsh does this automatically but bash doesn't)
complete -F _mod_complete "${_MOD_CLI_PATH}/mod.sh"
complete -F _mod_complete mod 
complete -F _mod_complete m

# convenient aliases. install.sh puts `mod` on PATH; the alias is only a
# fallback for checkouts that were never installed.
command -v mod >/dev/null 2>&1 || alias mod="${_MOD_CLI_PATH}/mod.sh"
alias m=mod

# cleanup
unset _MOD_CLI_PATH
