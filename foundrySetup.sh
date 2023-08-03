#!/usr/bin/env bash
source .env

forge test --fork-url "http://localhost:8545" -vvv
#forge snapshot --fork-url "http://localhost:8545" --silent
#cat .gas-snapshot