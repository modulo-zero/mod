#!/bin/bash
#
# mod-usage: mod wallet <subcommand> [args...]
# mod-description: manage keystore accounts
# mod-arg: add <private-key> <name>   import an existing key into the keystore
# mod-arg: create [name]              create a new keystore account
# mod-arg: address <account>          print the address of a keystore account
# mod-arg: list                       list the keystore accounts
# mod-arg: remove <account>           delete a keystore account
# mod-note: Subcommand aliases: a=add  c=create  addr=address  l=list  r=remove
# mod-note: Keystore location comes from ETH_KEYSTORE_DIR in the config.
# mod-note: create and add encrypt with the password file from `mod config
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

  cd "${OPTIMISM_MONOREPO_ROOT}"

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

  pw_file="$(keystore_password_file)"
  if [ -n "$pw_file" ]; then
    output=$(cast wallet import -k "$ETH_KEYSTORE_DIR" --private-key $1 --unsafe-password "$(cat "$pw_file")" $2 2>&1)
  else
    output=$(cast wallet import -k "$ETH_KEYSTORE_DIR" --private-key $1 $2 2>&1)
  fi
  address=$(echo "$output" | grep -oE '0x[0-9a-fA-F]{40}' | head -1)
  cp $ETH_KEYSTORE_DIR/$2 $ETH_KEYSTORE_DIR/$address
  echo $output
}

# keystore_password_file - the file `mod config password` wrote, if any. When it
# exists create/add encrypt with it instead of prompting, so the file always
# matches the keystores.
function keystore_password_file() {
  local file="${ETH_PASSWORD_FILE:-}"
  file="${file/#\~/$HOME}"
  [ -n "$file" ] && [ -f "$file" ] && echo "$file"
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
  pw_file="$(keystore_password_file)"
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
  cast wallet address --account $1
}

function list() {
  cast wallet list
}

function remove() {
  ADDRESS=$(mod wallet address $1)
  rm $ETH_KEYSTORE_DIR/$1
  rm $ETH_KEYSTORE_DIR/$ADDRESS
}

main $@
