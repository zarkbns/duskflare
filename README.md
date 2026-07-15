# Dark Pool Orchestrator — Smart Contract Layer

Public coordination layer for the cross-chain (BTC/XRP) dark pool, targeting Flare's Coston2 testnet.

## Setup

I built this without network access, so you'll need to run the Foundry install steps yourself:

```bash
# 1. Install Foundry (if you haven't already)
curl -L https://foundry.paradigm.xyz | bash
foundryup

# 2. From this directory, install forge-std (needed for Script/Test/console)
forge init --force --no-git
# or, if forge init complains the dir isn't empty:
forge install foundry-rs/forge-std --no-git

# 3. Copy env template and fill in your deployer key
cp .env.example .env
# edit .env: add PRIVATE_KEY (funded with Coston2 testnet FLR from the faucet)
```

Coston2 faucet: https://faucet.flare.network/coston2

## Build & test

```bash
forge build
forge test -vvv
```

The test suite (`test/DarkPoolOrchestrator.t.sol`) covers:
- full submit → settle happy path
- rejecting orders without a verified deposit
- rejecting settlement calls from anyone but the enclave address

## Deploy to Coston2

```bash
source .env
forge script script/Deploy.s.sol --rpc-url coston2 --broadcast -vvvv
```

This deploys `MockFDC` (for testing — swap for Flare's real FDC verifier before mainnet)
and `DarkPoolOrchestrator`, with the deployer set as a placeholder enclave address.
Once you have a real FCC enclave's attested signing address, call:

```solidity
orchestrator.setEnclaveAddress(<real_enclave_address>);
```

## What's real vs. placeholder here

- **Contract logic**: real — order submission, cancellation, replay protection on deposit hashes, cross-asset match validation, access control. Ready to deploy today.
- **MockFDC**: a stand-in. Flare's real Flare Data Connector verifies deposits via attestation/Merkle proofs, not a manual owner flag. Swap this out once you're integrating actual FDC attestation types (`Payment`, `EVMTransaction`, etc.) — see `flare-foundation/fdc-client` on GitHub.
- **Enclave address**: as of writing, FCC is only live on Songbird (Flare's canary testnet) with TEE nodes still operated directly by the Flare Foundation — third-party enclave deployment isn't confirmed open yet. Until that's resolved, treat `settleDarkOrders()` as ready to receive calls from a real enclave, but you can't yet deploy your own custom enclave logic to Flare's infra. Worth confirming current status in Flare's dev Discord before assuming otherwise.

## Next steps

- [ ] Swap MockFDC for real FDC integration once you pick your attestation type
- [ ] Add order expiry (currently orders can sit open indefinitely)
- [ ] Add partial-fill support if you want matching beyond exact 1:1 pairs
- [ ] Confirm FCC enclave deployment access with Flare team
