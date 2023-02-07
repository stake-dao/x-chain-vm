include .env

default:; forge fmt && forge build

.EXPORT_ALL_VARIABLES:
FOUNDRY_ETH_RPC_URL?=$(ETH_RPC_URL)
#FOUNDRY_BLOCK_NUMBER?=15954694
ETHERSCAN_API_KEY?=${ETHERSCAN_KEY}

snapshot:; @forge snapshot  
test:; @forge test  --match-contract "PlatformXChainTest" --gas-report
node:; @anvil --fork-url ${ETH_RPC_URL} --steps-tracing

.PHONY: test default

deploy-mainnet:; @forge script script/DeployMainnet.sol --fork-url ${ETH_RPC_URL} --private-key ${PRIVATEKEY} --broadcast --etherscan-api-key ${ETHERSCAN_KEY} --verify # --resume