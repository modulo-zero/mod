#!/bin/bash

main() {
  if [ $# -lt 1 ]; then
    echo "Usage: mod trace <tx-hash>"
    exit 1
  fi

  # The directory of the trace script
  TRACE_VIS_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/../../lib/trace-vis/index.js"

  RANDOM_NAME="$(hexdump -n 8 -v -e '/1 "%02X"' /dev/urandom).json"
  cast rpc debug_traceTransaction $1 '{"tracer":"callTracer","tracerConfig":{"withLog":true}}' --rpc-url http://localhost:9545 | jq > $RANDOM_NAME
  node "${TRACE_VIS_DIR}" visualize --traceFile=$RANDOM_NAME --buildArtifacts="${OPTIMISM_MONOREPO_ROOT}/packages/contracts-bedrock/deployments/devnetL1"
  rm $RANDOM_NAME
}

main $@
