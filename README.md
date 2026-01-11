# Solidity Labs (Foundry)

A personal Solidity/Foundry lab repo focused on **reproducible** smart-contract implementations with **tests** and (later) CI.
[![ci](https://github.com/duanduanduan876/solidity-labs/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/duanduanduan876/solidity-labs/actions/workflows/ci.yml)

## Quick start

```bash
forge build
forge test -vvv

### Proxies (demos)
- Minimal delegatecall proxy: `src/proxies/MinimalProxy.sol`
  - Run: `forge test --match-path test/proxies/MinimalProxy.t.sol -vvv`
- Simple upgrade proxy: `src/proxies/SimpleUpgrade.sol`
  - Run: `forge test --match-path test/proxies/SimpleUpgrade.t.sol -vvv`
- Transparent proxy: `src/proxies/TransparentProxy.sol`
  - Run: `forge test --match-path test/proxies/TransparentProxy.t.sol -vvv`
- UUPS-style upgrade (logic owns upgrade): `src/proxies/DemoUUPS.sol`
  - Run: `forge test --match-path test/proxies/DemoUUPS.t.sol -vvv`

### Tokens
- ERC20Permit (EIP-2612): `src/tokens/WTFPermit.sol`
  - Run: `forge test --match-path test/tokens/Permit.t.sol -vvv`

### Signatures
- EIP-712 auth demo: `src/signatures/EIP712Auth.sol`
  - Run: `forge test --match-path test/signatures/EIP712.t.sol -vvv`




