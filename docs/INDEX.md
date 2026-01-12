# Capability Index

## Signatures / EIP-712 (demo)
- Source: `src/signatures/EIP712Auth.sol`
- Tests: `test/signatures/EIP712.t.sol`
- Run: `forge test --match-path test/signatures/EIP712.t.sol -vvv`

## Tokens / ERC20Permit (EIP-2612)
- Source: `src/tokens/WTFPermit.sol`
- Tests: `test/tokens/Permit.t.sol`
- Run: `forge test --match-path test/tokens/Permit.t.sol -vvv`

## Proxies (demos)
- Minimal Proxy (delegatecall + storage layout)
  - Source: `src/proxies/MinimalProxy.sol`
  - Tests: `test/proxies/MinimalProxy.t.sol`
  - Run: `forge test --match-path test/proxies/MinimalProxy.t.sol -vvv`

- Simple Upgrade Proxy (admin upgrade on proxy; demo limitation noted)
  - Source: `src/proxies/SimpleUpgrade.sol`
  - Tests: `test/proxies/SimpleUpgrade.t.sol`
  - Run: `forge test --match-path test/proxies/SimpleUpgrade.t.sol -vvv`

- Transparent Proxy (admin cannot fallback; selector collision avoidance)
  - Source: `src/proxies/TransparentProxy.sol`
  - Tests: `test/proxies/TransparentProxy.t.sol`
  - Run: `forge test --match-path test/proxies/TransparentProxy.t.sol -vvv`

- UUPS-style Upgrade (upgrade in logic; demo, not OZ UUPS)
  - Source: `src/proxies/DemoUUPS.sol`
  - Tests: `test/proxies/DemoUUPS.t.sol`
  - Run: `forge test --match-path test/proxies/DemoUUPS.t.sol -vvv`
 
## Randomness / Chainlink VRF v2.5 (demo)
- Source: `src/randomness/RandomVRFNFT.sol`
- Tests: `test/randomness/RandomVRFNFT.t.sol`
- Run: `forge test --match-path test/randomness/RandomVRFNFT.t.sol -vvv`
- Notes: local tests mock `requestRandomWords` and call `rawFulfillRandomWords` via coordinator prank.

## NFTs / NFTSwap (demo)
- Source: `src/nft/NFTSwap.sol`
- Tests: `test/nft/NFTSwap.t.sol`
- Run: `forge test --match-path test/nft/NFTSwap.t.sol -vvv`
- Notes: includes a test showing `transfer`-to-contract limitation (gas stipend).

## Utils / Multicall (demo)
- Source: `src/utils/Multicall.sol`
- Tests: `test/utils/Multicall.t.sol`
- Run: `forge test --match-path test/utils/Multicall.t.sol -vvv`
- What it proves: batched low-level calls, optional failure handling, revert-data capture, msg.sender semantics.

## DEX / SimpleSwap (demo)
- Source: `src/dex/SimpleSwap.sol`
- Tests: `test/dex/SimpleSwap.t.sol`
- Run: `forge test --match-path test/dex/SimpleSwap.t.sol -vvv`
- Notes: constant-product AMM without fees; subsequent liquidity can be imbalanced (educational simplification); slippage check uses strict `>`.

## Flashloan / UniswapV2 opposite-token repay (demo)
- Source: `src/flash/UniswapV2FlashloanOppositeRepay.sol`
- Tests: `test/flash/UniswapV2FlashloanOppositeRepay.t.sol`
- Run: `forge test --match-path test/flash/UniswapV2FlashloanOppositeRepay.t.sol -vvv`
- What it proves: UniswapV2 flash swap callback, opposite-token repayment math, optional V3 exact-output swap to source repay token.
- Notes: tests use local mocks via `vm.etch` to avoid mainnet forking/RPC.

## Wallet / MultiSig (2-of-3, demo)
- Source: `src/wallet/MultiSigWallet.sol`
- Tests: `test/wallet/MultiSigWallet.t.sol`
- Run: `forge test --match-path test/wallet/MultiSigWallet.t.sol -vvv`
- What it proves: off-chain ECDSA signatures (EIP-191), threshold validation, signer sorting, nonce replay protection, arbitrary call execution.

## Bridge / CrossChainToken (burn/mint demo)
- Source: `src/bridge/CrossChainToken.sol`
- Tests: `test/bridge/CrossChainToken.t.sol`
- Run: `forge test --match-path test/bridge/CrossChainToken.t.sol -vvv`
- What it proves: burn-on-bridge-out + owner-mint-on-bridge-in, supply accounting, event-driven off-chain relayer integration.

## Payments / PaymentSplitter (ETH pull-payment demo)
- Source: `src/payments/PaymentSplitter.sol`
- Tests: `test/payments/PaymentSplitter.t.sol`
- Run: `forge test --match-path test/payments/PaymentSplitter.t.sol -vvv`
- What it proves: pull-based revenue sharing, precise accounting with `totalReceived`, CEI pattern, `call` vs `transfer` gas-stipend resilience.








