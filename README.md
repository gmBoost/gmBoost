# gmBoost - On-Chain GM Contracts

![gmBoost Logo](./documentation/gmboost-logo.png)

[![Solidity 0.8.30](https://img.shields.io/badge/Solidity-0.8.30-blue)](https://soliditylang.org/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

**gmBoost** is a per-user "GM" contract system. Each user gets their own minimal on-chain contract that:
- ✅ Accepts ETH payments from anyone sending them a GM
- ✅ Automatically splits payments between platform treasury and contract owner
- ✅ Creates transparent on-chain receipts for builder/airdrop scoring
- ✅ Uses configurable fees/splits managed by a Safe multisig

**Status:** 88/88 Tests Passing | 100% Coverage | 0 Security Findings

---

## 🏗 Architecture

```
                   ┌───────────────────────────────────┐
                   │            FeeManager             │
                   │  - ethFeeWei (GM fee)             │
    Safe 2-of-3 ──►│  - ownerShareBps (split %)        │
     (platform)    │  - deployFeeWei (deploy fee)      │
                   │  - feeRecipient (treasury)        │
                   └───────────────┬───────────────────┘
                                   │ (read settings)
                                   │
                    ┌──────────────┴──────────────┐
                    │       gmBoostFactory        │
                    │  creates clones + collects  │
                    │     deployment fee          │
                    └───────┬───────────┬─────────┘
                            │           │
                            ▼           ▼
                 ┌────────────────┐ ┌────────────────┐
                 │  Alice's GM    │ │   Bob's GM     │
                 │  owner=Alice   │ │   owner=Bob    │
 forward now ───►│  split + send  │ │  split + send  │◄── forward now
 to treasury     │  to treasury   │ │  to treasury   │    to treasury
                 └────────────────┘ └────────────────┘
```

**How It Works:**
1. Users pay a deployment fee to create their personal GM contract (ERC-1167 clone)
2. Anyone can send ETH to a user's contract with `onChainGM()`
3. Payment is automatically split: platform share → treasury, owner share → contract
4. Contract owner can withdraw their accumulated balance anytime

---

## 📜 Contracts

### FeeManager
Configuration contract owned by Safe multisig. Stores GM fee, deployment fee, revenue split %, and treasury address.

### GmBoost
User's personal GM contract. Deployed as ERC-1167 minimal proxy (~128k gas vs ~400k for full deployment).

**Functions:**
- `onChainGM()` - Send a GM with ETH payment
- `withdrawOwner()` - Owner withdraws accumulated balance

### GmBoostFactory
Deploys new user contracts and collects deployment fees.

**Functions:**
- `createGmBoost()` - Deploy your GM contract (requires deployment fee)

**[→ Full Contract Documentation](documentation/CONTRACTS.md)**

---

## 📍 Deployments

**[→ View Deployment Addresses & Configuration](deployments/)**

---

## 🔒 Security

| Metric | Result |
|--------|--------|
| **Test Coverage** | **100%** (statements, branches, functions, lines) |
| **Slither Analysis** | 0 critical/high/medium findings |
| **Solhint Analysis** | 0 errors/warnings |
| **SolidityScan** | Score **93.69/100** (0 Critical/High; Medium/Low reviewed as design/operational) |

**Security Features:**
- ✅ Solidity 0.8.30 (built-in overflow protection)
- ✅ ReentrancyGuard on withdrawals
- ✅ Checks-Effects-Interactions pattern
- ✅ Safe multisig control
- ✅ Constructor lock on implementation
- ✅ Factory-only initialization

**[→ Security Documentation](documentation/security/)**

---

## 📚 Documentation

- **[ARCHITECTURE.md](documentation/ARCHITECTURE.md)** - Design decisions and system architecture
- **[CONTRACTS.md](documentation/CONTRACTS.md)** - Detailed contract API reference
- **[EVENTS.md](documentation/EVENTS.md)** - Event reference and indexing guide
- **[deployments/](deployments/)** - Deployment addresses and configuration
- **[security/](documentation/security/)** - Security analysis and threat model

---

## 📝 License

MIT License - see [LICENSE](LICENSE) file for details.

Open source, freely auditable, permissively licensed. ✅

---

## 📞 Support

For security issues, see [documentation/security/](documentation/security/) for security analysis and contact information.

---

**Built on Base 🔵**
