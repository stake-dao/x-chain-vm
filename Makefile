include .env


.PHONY: test 

test:; @forge test --fork-block-number 16041715 --fork-url ${ETH_RPC_URL} --match-contract "ProofTests" -vvvv