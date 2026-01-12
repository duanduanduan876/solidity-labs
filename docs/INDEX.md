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



