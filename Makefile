-include .env

.PHONY: all test clean deploy fund help install snapshot format anvil 

DEFAULT_ANVIL_KEY := 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80

help:
	@echo "Usage:"
	@echo "  make deploy [ARGS=...]\n    example: make deploy ARGS=\"--network sepolia\""
	@echo ""
	@echo "  make fund [ARGS=...]\n    example: make deploy ARGS=\"--network sepolia\""

test : 
	forge test 

build:
	forge build

install :
	forge install Cyfrin/foundry-devops@0.0.11 --no-commit && forge install smartcontractkit/chainlink-brownie-contracts@0.7.1 --no-commit && forge install foundry-rs/forge-std@v1.5.3 --no-commit && forge install transmissions11/solmate@v6 --no-commit

snapshot :
	forge snapshot

format :
	forge fmt

anvil :
	anvil -m 'test test test test test test test test test test test junk' --steps-tracing --block-time 1

NETWORK_ARGS := --rpc-url http://localhost:8545 --private-key $(PRIVATE_KEY_LOCAL) --broadcast

ifeq ($(findstring --network sepolia,$(ARGS)),--network sepolia)
	NETWORK_ARGS := --rpc-url $(SEPOLIA_RPC_URL) --private-key $(PRIVATE_KEY_SEPOLIA) --broadcast --verify --etherscan-api-key $(ETHERSCAN_API_KEY) -vvvv
endif

# if we pass --network sepolia the make deploy
deploy:
	@forge script script/DeployRaffle.s.sol:DeployRaffle $(NETWORK_ARGS)

deploy-anvil:
	forge script script/DeployRaffle.s.sol:DeployRaffle --rpc-url $(RPC_URL_LOCAL) --broadcast --private-key $(PRIVATE_KEY_LOCAL) 

deploy-sepolia:
	forge script script/DeployRaffle.s.sol:DeployRaffle --rpc-url $(RPC_SEPOLIA2) --private-key ${PRIVATE_KEY_SEPOLIA} --broadcast -vvvv

deploy-sepolia-verify:
	forge script script/DeployRaffle.s.sol:DeployRaffle --rpc-url $(RPC_SEPOLIA2) --private-key $(PRIVATE_KEY_SEPOLIA) --broadcast --verify --etherscan-api-key $(ETHERSCAN_API_KEY) -vvvv
