
# include .env file and export its env vars
# (-include to ignore error if it does not exist)
-include .env

# deps
update:; forge update

# Build & test
build  :; forge build --sizes

test   :; forge test -vvv

deploy-chiado :; forge script script/GnosisSavingsDAI.s.sol:GnosisSavingsDAIDeployer --rpc-url chiado --broadcast -vvvv

deploy-gnosis :; forge script script/GnosisSavingsDAI.s.sol:GnosisSavingsDAIDeployer --rpc-url gnosis --broadcast --verify --etherscan-api-key ${ETHERSCAN_API_KEY_GNOSIS} -vvvv
