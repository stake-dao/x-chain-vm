include .env

default:; forge fmt && forge build

snapshot:; @forge snapshot  
test:; @forge test 
node:; @anvil --fork-url ${ETH_RPC_URL} --steps-tracing

.PHONY: test default

