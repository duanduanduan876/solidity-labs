# Solidity Labs (Foundry)

A personal Solidity/Foundry lab repo focused on **reproducible** smart-contract demos with **tests** + CI.

[![CI](https://github.com/duanduanduan876/solidity-labs/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/duanduanduan876/solidity-labs/actions/workflows/ci.yml?query=branch%3Amain)

## Why this repo
- Each module is **small, isolated, and test-driven** (easy to review in interviews).
- Every module has a **single command** to reproduce results locally.
- CI runs `forge build` + `forge test` on every push.

## Quick start
```bash
forge build
forge test -vvv





