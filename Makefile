include .env

default:; forge fmt && forge build

# .EXPORT_ALL_VARIABLES:
# FOUNDRY_ETH_RPC_URL?=$(ETH_RPC_URL)
# FOUNDRY_BLOCK_NUMBER?=16538627
# ETHERSCAN_API_KEY?=${ETHERSCAN_KEY}

snapshot:; @forge snapshot  
test:; @forge test 
test-extractor:; @forge test  --match-contract "ProofExtractorTest" --fork-url ${ETH_RPC_URL} --gas-report
test-claim:; @forge test  --match-contract "PlatformXChainTest" --gas-report
node:; @anvil --fork-url ${ETH_RPC_URL} --steps-tracing

.PHONY: test default

deploy-mainnet:; @forge script script/DeployMainnet.sol --fork-url ${ETH_RPC_URL} --private-key ${PRIVATEKEY} --broadcast --etherscan-api-key ${ETHERSCAN_KEY} --verify # --resume
deploy-arbitrum:; @forge script script/DeploySideChains.sol # --fork-url ${ARBITRUM_RPC_URL} # --private-key ${PRIVATEKEY} --broadcast # --etherscan-api-key ${ETHERSCAN_KEY} --verify # --resume
deploy-mock:; @forge script script/DeployMockArbitrum.sol --rpc-url https://arbitrum.llamarpc.com --private-key ${PRIVATE_KEY} --broadcast --etherscan-api-key ${ARBISCAN_KEY} --chain-id=42161 --verify

