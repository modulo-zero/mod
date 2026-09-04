#!/bin/bash
#
# mod-usage: mod trace <tx-hash>
# mod-description: visualize a transaction trace
# mod-arg: <tx-hash>   hash of the transaction to trace
# mod-note: Broken: depends on lib/trace-vis, which is not in this repo, and
# mod-note: hardcodes the rpc url to http://localhost:9545.

source "$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/../../lib/help.sh"

main() {
  if mod_is_help_flag "${1:-}"; then
    mod_print_help trace
    exit 0
  fi

  if [ $# -lt 1 ]; then
    mod_missing_args trace
  fi

  # The directory of the trace script
  TRACE_VIS_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/../../lib/trace-vis/index.js"

  RANDOM_NAME="$(hexdump -n 8 -v -e '/1 "%02X"' /dev/urandom).json"
  cast rpc debug_traceTransaction $1 '{"tracer":"callTracer","tracerConfig":{"withLog":true}}' --rpc-url http://localhost:9545 | jq > $RANDOM_NAME
  node "${TRACE_VIS_DIR}" visualize --traceFile=$RANDOM_NAME --buildArtifacts="${OPTIMISM_MONOREPO_ROOT}/packages/contracts-bedrock/deployments/devnetL1"
  rm $RANDOM_NAME
}

main $@
