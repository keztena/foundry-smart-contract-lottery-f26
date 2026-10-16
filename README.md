# 🎟️ Foundry Smart Contract Lottery

A provably fair, fully decentralized lottery (raffle) built with [Foundry](https://book.getfoundry.sh/). Players enter by paying a ticket fee, and after a set interval a winner is picked **automatically** and **verifiably at random** using [Chainlink VRF](https://docs.chain.link/vrf) and [Chainlink Automation](https://docs.chain.link/chainlink-automation). The winner receives the entire prize pool, with no human intervention.

[![Solidity](https://img.shields.io/badge/Solidity-%5E0.8.19-363636.svg)](https://soliditylang.org)
[![Foundry](https://img.shields.io/badge/Built%20with-Foundry-orange.svg)](https://book.getfoundry.sh)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

---

## Table of Contents

- [About](#about)
- [How It Works](#how-it-works)
- [Features](#features)
- [Project Structure](#project-structure)
- [Getting Started](#getting-started)
- [Usage](#usage)
- [Testing](#testing)
- [Deployment](#deployment)
- [Chainlink Setup](#chainlink-setup)
- [Security Considerations](#security-considerations)
- [Contributing](#contributing)
- [License](#license)

---

## About

Traditional lotteries rely on a trusted operator to run the draw and pay out. This project removes that trust requirement:

1. **Entry** is open to anyone who pays the ticket price.
2. **Winner selection** uses Chainlink VRF, so randomness is verifiable on-chain and cannot be manipulated by miners, validators, or the contract owner.
3. **Automation** is handled by Chainlink Automation, which triggers the draw once the time interval has passed.

## How It Works

```
        ┌───────────────┐
        │  Players call │
        │  enterRaffle()│──── pay entrance fee ───┐
        └───────────────┘                         │
                                                  ▼
                                        ┌──────────────────┐
                                        │  Raffle (OPEN)   │
                                        └────────┬─────────┘
                                                 │ interval elapsed,
                                                 │ players > 0, balance > 0
                                                 ▼
                                    ┌─────────────────────────┐
                                    │ Chainlink Automation    │
                                    │ checkUpkeep → performUpkeep │
                                    └────────────┬────────────┘
                                                 │ state = CALCULATING
                                                 ▼
                                    ┌─────────────────────────┐
                                    │ Chainlink VRF           │
                                    │ requestRandomWords      │
                                    └────────────┬────────────┘
                                                 │ callback
                                                 ▼
                                    ┌─────────────────────────┐
                                    │ fulfillRandomWords      │
                                    │ pick winner → pay out   │
                                    │ reset players, state=OPEN │
                                    └─────────────────────────┘
```

**Upkeep conditions** (`checkUpkeep` returns `true` when all hold):

- The time interval has passed since the last draw
- The raffle is in the `OPEN` state
- The contract has a balance (and therefore at least one player)
- The subscription is funded with LINK

## Features

- 🎲 Verifiable randomness via Chainlink VRF
- ⏱️ Automated draws via Chainlink Automation
- 🏆 Winner takes the full prize pool
- 🔒 Raffle state machine (`OPEN` / `CALCULATING`) prevents entries during a draw
- 📢 Events emitted for entry, winner request, and winner pick
- 🧪 Unit, integration, and fork tests
- 🛠️ Network-aware deploy scripts (local Anvil, Sepolia, and more)
- ⛽ Custom errors and `immutable` / `constant` variables for gas efficiency

## Project Structure

```
.
├── src/
│   └── Raffle.sol              # Main lottery contract
├── script/
│   ├── DeployRaffle.s.sol      # Deployment script
│   ├── HelperConfig.s.sol      # Per-network configuration
│   └── Interactions.s.sol      # Create subscription, fund, add consumer
├── test/
│   ├── unit/
│   │   └── RaffleTest.t.sol    # Unit tests
│   ├── integration/
│   │   └── Interactions.t.sol  # Script/integration tests
│   └── mocks/
│       └── LinkToken.sol       # Mock LINK token for local testing
├── lib/                        # Dependencies (forge-std, chainlink, solmate)
├── foundry.toml                # Foundry configuration
├── Makefile                    # Handy command shortcuts
├── .env.example                # Environment variable template
└── README.md
```

> Adjust the tree above to match your actual layout.

## Getting Started

### Prerequisites

- [Git](https://git-scm.com/)
- [Foundry](https://book.getfoundry.sh/getting-started/installation)

Verify your install:

```bash
forge --version
```

### Installation

```bash
git clone https://github.com/<your-username>/foundry-smart-contract-lottery.git
cd foundry-smart-contract-lottery
forge install
forge build
```

### Environment Variables

Copy the template and fill in your values:

```bash
cp .env.example .env
```

```env
SEPOLIA_RPC_URL=https://eth-sepolia.g.alchemy.com/v2/<YOUR_KEY>
PRIVATE_KEY=<DEPLOYER_PRIVATE_KEY>   # use a throwaway/test wallet only
ETHERSCAN_API_KEY=<YOUR_ETHERSCAN_KEY>
```

> ⚠️ **Never commit your `.env` file or use a wallet that holds real funds for testing.** For better security, use Foundry's encrypted keystore (`cast wallet import`) instead of a raw private key.

## Usage

### Start a local node

```bash
anvil
```

### Deploy locally

```bash
forge script script/DeployRaffle.s.sol:DeployRaffle \
  --rpc-url http://127.0.0.1:8545 \
  --private-key <ANVIL_PRIVATE_KEY> \
  --broadcast
```

### Enter the raffle

```bash
cast send <RAFFLE_ADDRESS> "enterRaffle()" \
  --value 0.01ether \
  --rpc-url <RPC_URL> \
  --private-key <PRIVATE_KEY>
```

### Read contract state

```bash
cast call <RAFFLE_ADDRESS> "getEntranceFee()(uint256)" --rpc-url <RPC_URL>
cast call <RAFFLE_ADDRESS> "getRecentWinner()(address)" --rpc-url <RPC_URL>
cast call <RAFFLE_ADDRESS> "getNumberOfPlayers()(uint256)" --rpc-url <RPC_URL>
```

## Testing

Run the full suite:

```bash
forge test
```

Useful variations:

```bash
forge test -vvvv                         # verbose traces
forge test --match-test testName         # single test
forge test --fork-url $SEPOLIA_RPC_URL   # fork tests against Sepolia
forge coverage                           # coverage report
forge snapshot                           # gas snapshot
```

Tests cover:

- Initialization in the `OPEN` state
- Entry fee validation and player recording
- Event emission
- Blocking entries while `CALCULATING`
- `checkUpkeep` true/false conditions
- `performUpkeep` only running when upkeep is needed
- `fulfillRandomWords` only callable after a request, and by the VRF coordinator
- End-to-end winner selection, payout, and state reset

## Deployment

### Sepolia testnet

```bash
source .env

forge script script/DeployRaffle.s.sol:DeployRaffle \
  --rpc-url $SEPOLIA_RPC_URL \
  --account <KEYSTORE_ACCOUNT_NAME> \
  --broadcast \
  --verify \
  --etherscan-api-key $ETHERSCAN_API_KEY \
  -vvvv
```

Or use the Makefile shortcut:

```bash
make deploy-sepolia
```

## Chainlink Setup

For live networks, after deploying:

1. **VRF subscription:** Create a subscription at [vrf.chain.link](https://vrf.chain.link) and fund it with LINK (the deploy scripts can automate this).
2. **Add consumer:** Add the deployed Raffle contract address as a consumer of the subscription.
3. **Automation upkeep:** Register a custom-logic upkeep at [automation.chain.link](https://automation.chain.link) pointing to your Raffle contract and fund it with LINK.

On local Anvil, the scripts deploy a `VRFCoordinatorV2Mock` and `LinkToken` mock, so no setup is required.

## Security Considerations

- Randomness comes from Chainlink VRF, **never** from `block.timestamp`, `blockhash`, or `prevrandao`.
- The contract follows **Checks-Effects-Interactions**: state is reset before the winner is paid.
- Winner payout uses a low-level `call` and reverts on failure.
- Access to `fulfillRandomWords` is restricted to the VRF coordinator.
- State machine blocks new entries while a draw is in progress.
- **This project has not been audited.** Do not deploy to mainnet with real funds without a professional audit.
- Be aware of the legal and regulatory requirements for lotteries and gambling in your jurisdiction.

## Contributing

Contributions are welcome!

1. Fork the repo
2. Create a feature branch (`git checkout -b feature/my-feature`)
3. Run `forge fmt` and `forge test`
4. Commit your changes and open a pull request

## License

This project is licensed under the [MIT License](LICENSE).

## Acknowledgements

- [Foundry](https://github.com/foundry-rs/foundry)
- [Chainlink](https://chain.link)
- [Cyfrin Updraft](https://updraft.cyfrin.io) for the Foundry curriculum this style of project is based on
- [Solmate](https://github.com/transmissions11/solmate)

---

**Author:** [@<keztena>](https://github.com/keztena)