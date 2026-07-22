# Dusk

Private cross-chain dark pool for XRP on Flare.

Dusk enables confidential trading without exposing orders to the public before execution. Orders remain encrypted throughout the matching process and are only revealed as required for verifiable on-chain settlement.

By separating private execution from public settlement, Dusk eliminates visible order books while preserving the transparency and security of blockchain settlement.

---

## Overview

Traditional decentralized exchanges expose every order before execution. This transparency enables front-running, sandwich attacks, copy trading, and information leakage.

Dusk takes a different approach.

Orders are encrypted before submission, matched inside a Trusted Execution Environment (TEE), verified through Flare infrastructure, and settled on-chain without revealing trading intent during execution.

The result is a trading experience that combines institutional-grade confidentiality with decentralized settlement.

---

## Core Principles

### Confidential by Default

Orders remain private until execution. Trade size, price, and direction are never exposed through a public order book.

### Fair Execution

Because pending orders cannot be observed, external participants cannot front-run or manipulate execution.

### Verifiable Settlement

Completed trades are settled on-chain through Flare, providing transparent and auditable settlement without sacrificing execution privacy.

### Cross-Chain Liquidity

Dusk is designed for confidential trading of XRP supported assets using Flare as the coordination and settlement layer.

---

## Architecture

```
Trader
   │
Encrypted Order
   │
   ▼
Trusted Execution Environment (FCC)
   │
Private Order Matching
   │
   ▼
Flare Data Connector (FDC)
   │
Attestation & Verification
   │
   ▼
Dark Pool Orchestrator
   │
On-chain Settlement
```

---

## How It Works

1. A trader submits an encrypted order.

2. The encrypted payload is routed to a Trusted Execution Environment where orders are decrypted and matched privately.

3. External deposits and transaction data are verified through the Flare Data Connector.

4. The Dark Pool Orchestrator validates the match and executes settlement on-chain.

Throughout the process, unmatched orders remain confidential.

---

## Features

- Hidden order book
- Encrypted order submission
- Private order matching
- Protection against front-running
- Cross-chain asset support
- Verifiable on-chain settlement
- Trusted execution through confidential computing

---

## Technology

- Solidity
- Foundry
- Flare
- Flare Confidential Compute (FCC)
- Flare Data Connector (FDC)

---

## Repository Structure

```
contracts/
script/
src/
test/

DarkPoolOrchestrator.sol
MockFDC.sol
Deploy.s.sol
```

---

## Security Model

Dusk separates execution, verification, and settlement into independent layers.

**Users**
- Submit encrypted orders.

**Trusted Execution Environment**
- Decrypts and privately matches orders.

**Flare Data Connector**
- Verifies external data required for settlement.

**Dark Pool Orchestrator**
- Validates settlement instructions and executes final settlement on-chain.

No participant can inspect another trader's pending order.

---

## Development

### Install

```bash
curl -L https://foundry.paradigm.xyz | bash
foundryup
```

### Build

```bash
forge build
```

### Test

```bash
forge test -vvv
```

### Deploy

```bash
forge script script/Deploy.s.sol \
  --rpc-url coston2 \
  --broadcast
```

---

## Vision

Privacy should be a standard feature of decentralized markets.

Dusk brings confidential execution to cross-chain trading while preserving the transparency, security, and verifiability of blockchain settlement.

Private execution.

Transparent settlement.

Built on Flare.

---

## License

MIT
