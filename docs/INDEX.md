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


