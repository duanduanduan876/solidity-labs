# Capability Index

## Signatures / EIP-712 (demo)
- Source: `src/signatures/EIP712Auth.sol` (EIP712Storage)
- Tests: `test/signatures/EIP712.t.sol`
- Coverage:
  - Owner signs typed data for (spender, number)
  - Spender submits signature to write `number`
  - Negative tests: wrong spender / wrong number / wrong signer
  - Replay: allowed (no nonce/deadline in this demo)
- Run:
  - `forge test --match-path test/signatures/EIP712.t.sol -vvv`
 
 ## Tokens / ERC20Permit (EIP-2612)
- Source: `src/tokens/WTFPermit.sol` (WTFPermitToken, PermitSpender)
- Tests: `test/tokens/Permit.t.sol`
- Coverage:
  - Permit signature -> allowance set -> transferFrom success
  - Nonce increments (replay protection)
  - Expired signature rejected
  - Wrong signer/value rejected
- Run:
  - `forge test --match-path test/tokens/Permit.t.sol -vvv`
 
  - ## Proxies / Minimal Delegatecall Proxy (demo)
- Source: `src/proxies/MinimalProxy.sol` (Proxy, Logic, Caller)
- Tests: `test/proxies/MinimalProxy.t.sol`
- Coverage:
  - Direct call uses Logic storage (x=99 -> increment=100)
  - Proxy call uses Proxy storage (x=0 -> increment=1)
  - implementation stored in Proxy slot0
- Run:
  - `forge test --match-path test/proxies/MinimalProxy.t.sol -vvv`



