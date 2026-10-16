# -----------------------------------------------------------------------------
# Foundry Smart Contract Lottery - Makefile
# Usage: run `make help` to list all commands
# -----------------------------------------------------------------------------

-include .env

.PHONY: help all install update build test test-v test-fork coverage snapshot \
        format format-check lint anvil clean remove \
        deploy deploy-anvil deploy-sepolia check-sepolia-env \
        create-subscription fund-subscription add-consumer

.DEFAULT_GOAL := help

# ---- Configuration ----------------------------------------------------------

# Default Anvil account #0 (public test key - never use on a real network)
DEFAULT_ANVIL_KEY := 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
ANVIL_RPC_URL     := http://127.0.0.1:8545

# For live networks, PRIVATE_KEY, SEPOLIA_RPC_URL and ETHERSCAN_API_KEY are read from .env
# (use a throwaway test wallet only - never a wallet holding real funds)

DEPLOY_SCRIPT := script/DeployRaffle.s.sol:DeployRaffle

ANVIL_ARGS   := --rpc-url $(ANVIL_RPC_URL) --private-key $(DEFAULT_ANVIL_KEY) --broadcast --disable-code-size-limit
SEPOLIA_ARGS := --rpc-url $(SEPOLIA_RPC_URL) --private-key $(PRIVATE_KEY) --broadcast --verify --etherscan-api-key $(ETHERSCAN_API_KEY) --slow --gas-estimate-multiplier 700 -vvvv

# Default to Anvil; switch to Sepolia when called with ARGS="--network sepolia"
NETWORK_ARGS := $(ANVIL_ARGS)

ifeq ($(findstring --network sepolia,$(ARGS)),--network sepolia)
NETWORK_ARGS := $(SEPOLIA_ARGS)
endif

# ---- Help -------------------------------------------------------------------

help: ## Show this help message
	@echo "Foundry Smart Contract Lottery"
	@echo ""
	@echo "Usage: make <target>"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) | \
	    awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-22s\033[0m %s\n", $$1, $$2}'
	@echo ""
	@echo "Examples:"
	@echo "  make deploy-anvil"
	@echo "  make deploy-sepolia"
	@echo "  make deploy ARGS=\"--network sepolia\""
	@echo "  make test-fork"

# ---- Setup ------------------------------------------------------------------

all: clean install build ## Clean, install dependencies, and build

install: ## Install dependencies
	forge install smartcontractkit/chainlink-brownie-contracts
	forge install transmissions11/solmate
	forge install foundry-rs/forge-std

update: ## Update dependencies
	forge update

remove: ## DANGEROUS: remove git submodules and the lib folder
	rm -rf .gitmodules && rm -rf .git/modules/* && rm -rf lib && touch .gitmodules

clean: ## Remove build artifacts
	forge clean

# ---- Build & Test -----------------------------------------------------------

build: ## Compile contracts
	forge build

test: ## Run all tests
	forge test

test-v: ## Run all tests with verbose traces
	forge test -vvvv

test-fork: check-sepolia-env ## Run tests against a Sepolia fork
	forge test --fork-url $(SEPOLIA_RPC_URL)

coverage: ## Generate test coverage report
	forge coverage

snapshot: ## Create a gas snapshot
	forge snapshot

format: ## Format Solidity files
	forge fmt

format-check: ## Check formatting without changing files
	forge fmt --check

lint: format-check ## Alias for format-check

# ---- Local node -------------------------------------------------------------

anvil: ## Start a local Anvil node
	anvil -m 'test test test test test test test test test test test junk' --steps-tracing --block-time 1 --disable-code-size-limit

# ---- Deployment -------------------------------------------------------------

check-sepolia-env:
	@test -n "$(SEPOLIA_RPC_URL)" || (echo "SEPOLIA_RPC_URL is not set in .env" && exit 1)

deploy: ## Deploy Raffle (Anvil by default; add ARGS="--network sepolia" for Sepolia)
	@forge script $(DEPLOY_SCRIPT) $(NETWORK_ARGS)

deploy-anvil: ## Deploy Raffle to local Anvil
	@forge script $(DEPLOY_SCRIPT) $(ANVIL_ARGS)

deploy-sepolia: check-sepolia-env ## Deploy and verify Raffle on Sepolia
	@test -n "$(PRIVATE_KEY)" || (echo "PRIVATE_KEY is not set in .env" && exit 1)
	@test -n "$(ETHERSCAN_API_KEY)" || (echo "ETHERSCAN_API_KEY is not set in .env" && exit 1)
	@forge script $(DEPLOY_SCRIPT) $(SEPOLIA_ARGS)

# ---- Chainlink VRF subscription helpers (require script/Interactions.s.sol) --

create-subscription: ## Create a Chainlink VRF subscription
	@forge script script/Interactions.s.sol:CreateSubscription $(NETWORK_ARGS)

fund-subscription: ## Fund the VRF subscription with LINK
	@forge script script/Interactions.s.sol:FundSubscription $(NETWORK_ARGS)

add-consumer: ## Add the Raffle contract as a VRF consumer
	@forge script script/Interactions.s.sol:AddConsumer $(NETWORK_ARGS)