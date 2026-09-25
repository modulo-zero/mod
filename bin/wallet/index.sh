#!/bin/bash
#
# mod-usage: mod wallet <subcommand> [args...]
# mod-description: manage keystore accounts
# mod-arg: add <private-key> <name>   import an existing key into the keystore
# mod-arg: create [name]              create a new keystore account
# mod-arg: address <account>          print the address of a keystore account
# mod-arg: list                       list the keystore accounts
# mod-arg: remove <account>           delete a keystore account
# mod-arg: sol <subcommand> [args...] the same subcommands for solana keypairs
# mod-note: Subcommand aliases: a=add  c=create  addr=address  l=list  r=remove
# mod-note: Solana keypairs live in SOL_KEYPAIR_DIR (default ~/.config/solana/keys)
# mod-note: and are managed with solana-keygen. `sol add` takes a keypair json
# mod-note: file. solana-keygen does not encrypt keypair files, so the keystore
# mod-note: password does not apply; the files are protected by permissions.
# mod-note: Keystore location comes from ETH_KEYSTORE_DIR in the config.
# mod-note: create and add encrypt with the password file from `mod secrets
# mod-note: password` when it exists, and prompt for one otherwise.

source "$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/../../lib/help.sh"

function main() {
  if mod_is_help_flag "${1:-}"; then
    mod_print_help wallet
    exit 0
  fi

  if [ $# -lt 1 ]; then
    mod_missing_args wallet
  fi

  if [ "${1}" = "sol" ]; then
    sol "${@:2}"
    exit $?
  fi

  # Apply aliases for convenience
  CMD="${1}"
  case $CMD in
    a) CMD=add ;;
    c) CMD=create ;;
    addr) CMD=address ;;
    l) CMD=list ;;
    r) CMD=remove ;;
  esac

  $CMD ${@:2}
}

function add() {
  if [ ! -z "$1" ]; then
    if [ -f $ETH_KEYSTORE_DIR/$1 ]; then
      echo "Named account already exists"
      exit 1
    fi
  fi

  pw_file="$(mod_password_file)"
  if [ -n "$pw_file" ]; then
    output=$(cast wallet import -k "$ETH_KEYSTORE_DIR" --private-key $1 --unsafe-password "$(cat "$pw_file")" $2 2>&1)
  else
    output=$(cast wallet import -k "$ETH_KEYSTORE_DIR" --private-key $1 $2 2>&1)
  fi
  address=$(echo "$output" | grep -oE '0x[0-9a-fA-F]{40}' | head -1)
  cp $ETH_KEYSTORE_DIR/$2 $ETH_KEYSTORE_DIR/$address
  echo $output
}

function create() {
  DIR="$(dirname "$(realpath "$0")")"

  if [ ! -d $ETH_KEYSTORE_DIR ]; then
    mkdir $ETH_KEYSTORE_DIR
  fi

  if [ ! -z "$1" ]; then
    if [ -f $ETH_KEYSTORE_DIR/$1 ]; then
      echo "Named account already exists"
      exit 1
    fi
  fi

  # Newer cast versions print the human readable lines on stderr and only the
  # address on stdout, so capture both streams and grep the pieces out rather
  # than depending on the ordering or the stream.
  pw_file="$(mod_password_file)"
  if [ -n "$pw_file" ]; then
    output=$(cast wallet new "$ETH_KEYSTORE_DIR" --unsafe-password "$(cat "$pw_file")" 2>&1)
  else
    output=$(cast wallet new "$ETH_KEYSTORE_DIR" 2>&1)
  fi
  file=$(echo "$output" | grep -o 'keystore file: [^ ]*' | sed 's/keystore file: *//' | head -1)
  address=$(echo "$output" | grep -oE '0x[0-9a-fA-F]{40}' | head -1)
  if [ -z "$file" ] || [ -z "$address" ]; then
    echo "$output"
    echo "Error: could not parse the output of 'cast wallet new'"
    exit 1
  fi
  if [ ! -z "$1" ]; then
    cp $file $ETH_KEYSTORE_DIR/$1
  fi
  mv $file $ETH_KEYSTORE_DIR/$address
  echo "Created new wallet: $1"
  echo "Address: $address"
}

function address() {
  cast wallet address $(mod_account_args $1)
}

function list() {
  cast wallet list
}

function remove() {
  local file="${ETH_KEYSTORE_DIR/#\~/$HOME}/$1"
  if [ ! -f "$file" ]; then
    echo "Error: no keystore named '$1' in ${ETH_KEYSTORE_DIR}"
    exit 1
  fi
  # The address is stored unencrypted in the keystore, so no password needed.
  ADDRESS="$(grep -oE '"address" *: *"(0x)?[0-9a-fA-F]{40}"' "$file" | grep -oE '[0-9a-fA-F]{40}' | head -1)"
  if [ -z "$ADDRESS" ]; then
    echo "Error: could not read the address from ${file}; nothing removed."
    exit 1
  fi
  rm -f "$file" "${ETH_KEYSTORE_DIR/#\~/$HOME}/0x${ADDRESS}"
  echo "Removed wallet: $1 (0x$ADDRESS)"
}

# ---------------------------------------------------------------------------
# Solana keypairs. One json file per name, as solana-keygen writes them.

function sol() {
  if [ $# -lt 1 ]; then
    mod_missing_args wallet
  fi
  if ! command -v solana-keygen >/dev/null 2>&1; then
    echo "Error: solana-keygen is not installed. See https://solana.com/docs/intro/installation"
    exit 1
  fi
  SOL_DIR="${SOL_KEYPAIR_DIR:-$HOME/.config/solana/keys}"
  SOL_DIR="${SOL_DIR/#\~/$HOME}"
  CMD="${1}"
  case $CMD in
    a) CMD=add ;;
    c) CMD=create ;;
    addr) CMD=address ;;
    l) CMD=list ;;
    r) CMD=remove ;;
  esac
  case $CMD in
    add|create|address|list|remove) "sol_${CMD}" "${@:2}" ;;
    *) echo "Error: unknown wallet sol subcommand '${CMD}'"; mod_missing_args wallet ;;
  esac
}

function sol_file() {
  echo "${SOL_DIR}/${1}.json"
}

function sol_require_name() {
  if [ -z "${1:-}" ]; then
    echo "Error: a keypair name is required."
    exit 1
  fi
}

function sol_create() {
  sol_require_name "${1:-}"
  local file; file="$(sol_file "$1")"
  if [ -f "$file" ]; then
    echo "Named keypair already exists: $file"
    exit 1
  fi
  mkdir -p "$SOL_DIR" && chmod 700 "$SOL_DIR"
  solana-keygen new --no-bip39-passphrase --silent -o "$file" || exit 1
  chmod 600 "$file"
  echo "Created new solana keypair: $1"
  echo "Address: $(solana-keygen pubkey "$file")"
}

function sol_add() {
  if [ $# -lt 2 ]; then
    echo "Usage: mod wallet sol add <keypair.json> <name>"
    exit 1
  fi
  local file; file="$(sol_file "$2")"
  if [ -f "$file" ]; then
    echo "Named keypair already exists: $file"
    exit 1
  fi
  if [ ! -f "$1" ]; then
    echo "Error: no such file: $1"
    exit 1
  fi
  # Validate before copying so a bad file is never stored.
  solana-keygen pubkey "$1" >/dev/null || exit 1
  mkdir -p "$SOL_DIR" && chmod 700 "$SOL_DIR"
  cp "$1" "$file" && chmod 600 "$file"
  echo "Added solana keypair: $2"
  echo "Address: $(solana-keygen pubkey "$file")"
}

function sol_address() {
  sol_require_name "${1:-}"
  local file; file="$(sol_file "$1")"
  if [ ! -f "$file" ]; then
    echo "Error: no keypair named '$1' in ${SOL_DIR}"
    exit 1
  fi
  solana-keygen pubkey "$file"
}

function sol_list() {
  local f
  [ -d "$SOL_DIR" ] || return 0
  for f in "$SOL_DIR"/*.json; do
    [ -f "$f" ] || continue
    printf '%s  %s\n' "$(basename "$f" .json)" "$(solana-keygen pubkey "$f")"
  done
}

function sol_remove() {
  sol_require_name "${1:-}"
  local file; file="$(sol_file "$1")"
  if [ ! -f "$file" ]; then
    echo "Error: no keypair named '$1' in ${SOL_DIR}"
    exit 1
  fi
  rm -f "$file"
  echo "Removed solana keypair: $1"
}

main $@
