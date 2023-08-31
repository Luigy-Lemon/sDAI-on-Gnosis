
# include .env file and export its env vars
# (-include to ignore error if it does not exist)
-include .env

install	:; curl -L https://foundry.paradigm.xyz | bash && foundryup -v nightly-e05b9c75b4501d5880764948b61db787f3dd7fe0

# deps
update	:; forge update

# Build & test
build  :; forge build --sizes

tests	:; ./foundrySetup.sh

fork	:; ./forkSetup.sh

deploy-chiado :; forge script script/SavingsXDAI.s.sol:SavingsXDAIDeployer --rpc-url chiado --broadcast -vvvv

deploy-gnosis :; forge script script/SavingsXDAI.s.sol:SavingsXDAIDeployer --rpc-url gnosis --broadcast --verify --etherscan-api-key ${ETHERSCAN_API_KEY_GNOSIS} -vvvv
