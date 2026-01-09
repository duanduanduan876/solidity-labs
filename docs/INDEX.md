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

