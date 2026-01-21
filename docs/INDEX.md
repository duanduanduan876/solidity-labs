# Capability Index
[![CI](https://github.com/duanduanduan876/solidity-labs/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/duanduanduan876/solidity-labs/actions/workflows/ci.yml?query=branch%3Amain)


## Signatures / EIP-712 (demo)
- Source: `src/signatures/EIP712Auth.sol`
- Tests: `test/signatures/EIP712.t.sol`
- Run: `forge test --match-path test/signatures/EIP712.t.sol -vvv`

## Tokens / Permit demo (EIP-2612)
- Source:
  - Token: `src/tokens/InterviewPermitToken.sol`
  - Checkout: `src/tokens/PermitCheckout.sol`
- Tests:
  - `test/tokens/InterviewPermitToken.t.sol`
  - `test/tokens/PermitCheckout.t.sol`
- Run:
  - `forge test --match-path test/tokens/InterviewPermitToken.t.sol -vvv`
  - `forge test --match-path test/tokens/PermitCheckout.t.sol -vvv`
  - `forge test --match-path test/tokens/*.t.sol -vvv`

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

- Source: `src/utils/Multicall.sol` (contract: `MulticallPlus`)
- Tests: `test/utils/Multicall.t.sol`
- Run: `forge test --match-path test/utils/Multicall.t.sol -vvv`
- What it proves:
  - Batched low-level calls (`call` + `staticcall`)
  - Per-call ETH `value` support + end-of-batch refund
  - Optional failure handling (`allowFailure`)
  - Revert-data capture for debugging
  - Target code guard (`target.code.length`)
  - `msg.sender` semantics: target sees caller as the multicall contract

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

## ERC721 / MyERC721 (minimal ERC721 + tokenURI + safeTransfer receiver check)

- Source: `src/ERC721/MyERC721.sol`
- Tests: `test/ERC721/MyERC721.t.sol`
- Run:
  - `forge test --match-path test/ERC721/MyERC721.t.sol -vvv`

### What it demonstrates

- **ERC721 core flows**
  - `mint(to, tokenId)` creates ownership and emits `Transfer(0x0, to, tokenId)`
  - `transferFrom` enforces `owner/approved/operator` via `_isApprovedOrOwner`
  - **Single-token approval is cleared on transfer** (`_approve(address(0), tokenId)` inside `_transfer`)

- **safeTransferFrom receiver check**
  - If `to` is a contract (`to.code.length > 0`), ERC721 calls:
    `IERC721Receiver(to).onERC721Received(operator, from, tokenId, data)`
  - Transfer is accepted only when the receiver returns the **magic value**
    `IERC721Receiver.onERC721Received.selector` (`0x150b7a02`)
  - If receiver reverts or returns a wrong selector, the transfer reverts:
    `"ERC721: transfer to non ERC721Receiver"`

- **tokenURI / off-chain metadata**
  - `tokenURI(tokenId)` returns `_baseTokenURI + tokenId`
  - Intended usage: `_baseTokenURI` points to a metadata folder gateway URL, e.g.
    - `https://<gateway-domain>/ipfs/<metadataCID>/`
  - Then `tokenURI(1)` becomes:
    - `https://<gateway-domain>/ipfs/<metadataCID>/1`

### Key notes (interview-ready)

- `operator` in `onERC721Received` is the **caller of the transfer** (the address that invoked `safeTransferFrom`), not necessarily the NFT owner.
- `from` is the previous owner, `tokenId` is the NFT id, `data` is arbitrary extra payload forwarded to the receiver.
- The selector check is a **handshake**: it proves the receiver contract explicitly supports ERC721 safe transfers.








