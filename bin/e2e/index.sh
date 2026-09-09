#!/bin/bash
#
# mod-usage: mod e2e <env> <layer-sequence> <contract> <selector> [args...]
# mod-description: run an end-to-end script sequence across l1 and l2
# mod-arg: <env>              environment named in the project's mod.config.json
# mod-arg: <layer-sequence>   digits picking the layer per step, e.g. 121
# mod-arg: <contract>         test contract to run
# mod-arg: <selector>         signature to invoke on the test contract
# mod-arg: [args...]          arguments to the function
# mod-note: Broken: shells out to ../../blast.sh, a leftover from the rename to
# mod-note: mod, which does not exist. See the known gaps in the README.

source "$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/../../lib/help.sh"

function blast() {
  $(dirname $0)/../../blast.sh $@
}

if mod_is_help_flag "${1:-}"; then
  mod_print_help e2e
  exit 0
fi

if [[ -z $1 ]] || [[ -z $2 ]] || [[ -z $3 ]] | [[ -z $4 ]]; then
  mod_missing_args e2e
fi

NETWORK=$1
TEST_CONTRACT=$3
TEST_NAME=$4
ARGS=${@:5}

function script {
  blast script $NETWORK $1 $2 $3 ${@:4}
  checkStatus
}

function checkStatus {
  if [ ! $? -eq 0 ]; then
    exit 1

    rm l1state.json
    rm l2state.json
  fi
}

cd "${OPTIMISM_MONOREPO_ROOT}/packages/contracts-bedrock"

echo "Creating L1 State"
script l1 E2EInitializer "createL1State(address)" $(blast wallet address $ACCOUNT)

echo "Creating L2 State"
script l2 E2EInitializer "createL2State(address)" $(blast wallet address $ACCOUNT)

counter=0
for char in `echo $2 | fold -w1`; do
    counter=$((counter+1))
    if [ $char == '1' ]; then
      echo "Running L1 test"
      script l1 $TEST_CONTRACT $TEST_NAME $ARGS --broadcast --slow
    elif [ $char == '2' ]; then
      echo "Running L2 test"
      script l2 $TEST_CONTRACT $TEST_NAME $ARGS --broadcast --slow
    else
      echo "Input must be 1 or 2"
      exit 1
    fi

    sleep 10

    if [ $counter != ${#2} ]; then
      check="false"
      while [ $check != "true" ]; do
        echo "Checking if ready to progress"
        result=$(script l1 $TEST_CONTRACT 'check() returns (bool)' | grep "0: bool")
        check=$(echo $result | sed 's:0\: bool::')
        sleep 5
      done
    fi
done

rm l1state.json
rm l2state.json
