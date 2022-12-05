include .env

default:; forge fmt && forge build

.EXPORT_ALL_VARIABLES:
FOUNDRY_ETH_RPC_URL?=$(ETH_RPC_URL)
#FOUNDRY_BLOCK_NUMBER?=15954694
ETHERSCAN_API_KEY?=${ETHERSCAN_KEY}

test:; @forge test 
# test-optimism:; @forge test --fork-block-number 312752 --fork-url ${OPTIMISM_RPC_URL} --match-contract "ProofTests" -vvvv

.PHONY: test default