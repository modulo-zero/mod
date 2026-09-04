#!/bin/bash

function blast() {
  $(dirname $0)/../../blast.sh $@
}

if [[ -z $1 ]] || [[ -z $2 ]] || [[ -z $3 ]] | [[ -z $4 ]]; then
  echo "Usage: mod e2e <env> <layer-sequence> <contract> <selector> [args...]"
  exit 1
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
