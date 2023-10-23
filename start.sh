#!/bin/bash
echo "installing flow cli..."
sh -ci "$(curl -fsSL https://raw.githubusercontent.com/onflow/flow-cli/master/install.sh)" -- v1.4.5
export PATH=$PATH:/root/.local/bin

echo "starting flow emulator"
nohup flow emulator &

sleep 3
echo "deploying contracts..."
flow project deploy --update

echo "starting dev wallet..."
flow dev-wallet