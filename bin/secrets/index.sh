#!/bin/bash
#
# mod-usage: mod secrets [edit|check|password|migrate]
# mod-description: edit or inspect the secrets file (~/.mod/env)
# mod-arg: edit      open the secrets file in $EDITOR (the default)
# mod-arg: check     list which keys are set, without printing their values
# mod-arg: password  prompt for the keystore password and store it in ETH_PASSWORD_FILE
# mod-arg: migrate   move a legacy .env from the checkout to the global location
# mod-note: Secrets live in ~/.mod/env (or MOD_HOME): keystore paths, Tenderly and
# mod-note: verifier keys. They are exported before every command, and any value
# mod-note: can be referenced from mod.config.json as ${NAME}.

source "$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/../../lib/help.sh"

TEMPLATE="${MOD_ROOT}/.env.config"
LEGACY="${MOD_ROOT}/.env"

function main() {
  if mod_is_help_flag "${1:-}"; then
    mod_print_help secrets
    exit 0
  fi

  case "${1:-edit}" in
    edit)     edit ;;
    check)    check ;;
    password) password ;;
    migrate)  migrate ;;
    *)
      echo "Error: unknown subcommand '${1}'"
      mod_missing_args secrets
      ;;
  esac
}

function ensure_exists() {
  if [ ! -f "${MOD_CONFIG}" ]; then
    mkdir -p "$(dirname "${MOD_CONFIG}")"
    cp "${TEMPLATE}" "${MOD_CONFIG}"
    chmod 600 "${MOD_CONFIG}"
    echo "Created ${MOD_CONFIG} from the template."
  fi
}

function edit() {
  ensure_exists
  "${EDITOR:-${VISUAL:-vi}}" "${MOD_CONFIG}"
}

# Every KEY the template declares, whether exported, commented out or bare.
function template_keys() {
  sed -nE 's/^#? *(export +)?([A-Z_][A-Z0-9_]*)=.*/\2/p' "${TEMPLATE}" | awk '!seen[$0]++'
}

function check() {
  local file="${MOD_CONFIG}"
  [ -f "${LEGACY}" ] && file="${LEGACY}"
  if [ ! -f "${file}" ]; then
    echo "No secrets file at ${MOD_CONFIG}. Run 'mod secrets' to create it."
    exit 1
  fi
  echo "Secrets: ${file}"
  [ "${file}" = "${LEGACY}" ] && echo "(legacy location; run 'mod secrets migrate' to move it)"
  echo
  local key value
  while IFS= read -r key; do
    eval "value=\${${key}:-}"
    if [ -n "${value}" ]; then
      printf '  %-24s set\n' "${key}"
    else
      printf '  %-24s %bempty%b\n' "${key}" "${MOD_ORANGE:-}" "${MOD_NC:-}"
    fi
  done <<< "$(template_keys)"
}

# Writes the keystore password to the file ETH_PASSWORD_FILE points to, which is
# what cast, forge and mod pk read, so the password itself never sits in ~/.mod.
function password() {
  local file="${ETH_PASSWORD_FILE:-$HOME/.foundry/keystore_password}"
  file="${file/#\~/$HOME}"
  local pw1 pw2
  printf 'Keystore password: '; read -r -s pw1; echo
  printf 'Confirm: '; read -r -s pw2; echo
  if [ "$pw1" != "$pw2" ]; then
    echo "Error: passwords do not match."
    exit 1
  fi
  if [ -z "$pw1" ]; then
    echo "Error: password is empty."
    exit 1
  fi
  mkdir -p "$(dirname "$file")"
  (umask 077 && printf '%s' "$pw1" > "$file")
  chmod 600 "$file"
  echo "Saved to ${file}"
  echo "Keystores in ${ETH_KEYSTORE_DIR:-~/.foundry/keystores} must be encrypted with this password."
}

function migrate() {
  if [ ! -f "${LEGACY}" ]; then
    echo "Nothing to migrate: no ${LEGACY} found."
    exit 0
  fi
  if [ -f "${MOD_CONFIG}" ] && ! cmp -s "${MOD_CONFIG}" "${TEMPLATE}"; then
    echo "Error: ${MOD_CONFIG} already exists and has been edited. Merge it by hand, then delete ${LEGACY}."
    exit 1
  fi
  mkdir -p "$(dirname "${MOD_CONFIG}")"
  mv "${LEGACY}" "${MOD_CONFIG}"
  chmod 600 "${MOD_CONFIG}"
  echo "Moved ${LEGACY} -> ${MOD_CONFIG}"
}

main "$@"
