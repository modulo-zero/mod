#!/bin/bash
#
# mod-usage: mod upgrade
# mod-description: update mod to the latest version
# mod-note: Pulls the checkout that `mod` is linked from, then reruns install.sh
# mod-note: so that dependency checks, the PATH link and shell completion stay
# mod-note: current. Node packages are refreshed on the next `mod pk` if the
# mod-note: lockfile changed.

source "$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/../../lib/help.sh"

function main() {
  if mod_is_help_flag "${1:-}"; then
    mod_print_help upgrade
    exit 0
  fi

  cd "$MOD_ROOT" || exit 1

  if [ ! -d .git ]; then
    echo "Error: ${MOD_ROOT} is not a git checkout, so it cannot be upgraded automatically."
    exit 1
  fi

  if [ -n "$(git status --porcelain --untracked-files=no)" ]; then
    echo "Error: ${MOD_ROOT} has local changes. Commit or stash them before upgrading."
    exit 1
  fi

  BEFORE="$(git rev-parse HEAD)"
  echo "Updating ${MOD_ROOT}..."
  git pull --ff-only --quiet || exit 1
  AFTER="$(git rev-parse HEAD)"

  if [ "$BEFORE" = "$AFTER" ]; then
    echo "Already up to date."
  else
    echo
    git --no-pager log --oneline "${BEFORE}..${AFTER}"
    echo
  fi

  ./install.sh
}

main "$@"
