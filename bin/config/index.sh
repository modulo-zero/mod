#!/bin/bash
#
# mod-usage: mod config [edit|path|check|migrate]
# mod-description: edit or inspect the global config file
# mod-arg: edit      open the config in $EDITOR (the default)
# mod-arg: path      print the location of the config file
# mod-arg: check     list which keys are set, without printing their values
# mod-arg: migrate   move a legacy .env from the checkout to the global location
# mod-note: The config lives at ~/.mod, or wherever MOD_CONFIG points.
# mod-note: It is created from .env.config by install.sh and is never committed.

source "$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/../../lib/help.sh"

TEMPLATE="${MOD_ROOT}/.env.config"
LEGACY="${MOD_ROOT}/.env"

function main() {
  if mod_is_help_flag "${1:-}"; then
    mod_print_help config
    exit 0
  fi

  case "${1:-edit}" in
    edit)    edit ;;
    path)    echo "${MOD_CONFIG}" ;;
    check)   check ;;
    migrate) migrate ;;
    *)
      echo "Error: unknown subcommand '${1}'"
      mod_missing_args config
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
    echo "No config found at ${MOD_CONFIG}. Run 'mod config' to create it."
    exit 1
  fi
  echo "Config: ${file}"
  [ "${file}" = "${LEGACY}" ] && echo "(legacy location; run 'mod config migrate' to move it)"
  echo
  local key value
  while IFS= read -r key; do
    eval "value=\${${key}:-}"
    if [ -n "${value}" ]; then
      printf '  %-20s set\n' "${key}"
    else
      printf '  %-20s %bempty%b\n' "${key}" "${MOD_ORANGE:-}" "${MOD_NC:-}"
    fi
  done <<< "$(template_keys)"
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
