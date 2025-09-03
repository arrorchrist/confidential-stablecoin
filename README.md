# Confidential Stablecoin — Privacy-Preserving Payments with FHEVM

A minimal stablecoin demo that keeps balances and transfer amounts encrypted using Zama’s FHEVM.  
Includes allow-list (KYC gating), fail-closed transfers, and TypeScript tests.

## ✨ Features
- Encrypted balances (`euint64`)
- Confidential transfers with ZKPoK input verification
- Fail-closed: if amount > balance → executed = 0
- Optional allow-list for compliance
- EVM compatible, Hardhat tests

## 🚀 Quickstart
```bash
npm i
npx hardhat test
