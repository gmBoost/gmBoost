# Architecture & Design

Detailed architecture documentation and key design decisions for gmBoost.

---

## System Architecture

### Component Overview

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

### Three-Contract System

**1. FeeManager** (Singleton per chain)
- Central configuration contract
- Owned by Safe multisig
- Stores GM fee, deployment fee, split percentage, treasury address
- No funds held (pure configuration)

**2. GmBoostFactory** (Singleton per chain)
- Deploys ERC-1167 minimal proxy clones
- Collects deployment fees
- Prevents duplicate deployments per address
- Forwards fees immediately to treasury

**3. GmBoost** (One per user)
- ERC-1167 minimal proxy clone
- Accepts GM payments
- Splits payments between platform and owner
- Forwards platform share immediately
- Allows owner withdrawals

---

## Transaction Flows

### Creating a GM Contract

```
User
  │
  │ 1. Call createGmBoost() with deployment fee
  ▼
GmBoostFactory
  │
  │ 2. Validate fee payment
  │ 3. Create ERC-1167 clone
  │ 4. Initialize clone with user as owner
  │ 5. Forward fee to treasury
  ▼
New GmBoost Clone (owned by user)
```

### Sending a GM

```
Sender
  │
  │ 1. Call onChainGM() with ETH
  ▼
Recipient's GmBoost Contract
  │
  │ 2. Read config from FeeManager
  │ 3. Validate sent value ≥ required fee
  │ 4. Calculate platform share (e.g., 50%)
  │ 5. Calculate owner share (remaining)
  │ 6. Forward platform share → treasury (immediate)
  │ 7. Keep owner share in contract
  │ 8. Emit OnChainGM event
  ▼
Platform Treasury (receives share immediately)
Owner Balance (available for withdrawal)
```

### Owner Withdrawal

```
Contract Owner
  │
  │ 1. Call withdrawOwner()
  ▼
GmBoost Contract
  │
  │ 2. Check caller is owner
  │ 3. Check balance > 0
  │ 4. Transfer full balance to owner (with reentrancy guard)
  │ 5. Emit OwnerWithdrawn event
  ▼
Owner receives ETH
```

---

## Security Patterns

### Checks-Effects-Interactions (CEI)

All functions follow CEI pattern:
1. **Checks:** Validate inputs and conditions
2. **Effects:** Update state
3. **Interactions:** External calls (transfers, etc.)

Example from `onChainGM()`:
```solidity
// 1. Checks
require(msg.value >= requiredWei, InsufficientFee());

// 2. Effects
emit OnChainGM(...);

// 3. Interactions
(bool success, ) = feeRecipient.call{value: platformShare}("");
require(success, TransferFailed());
```

### Reentrancy Protection

`withdrawOwner()` uses OpenZeppelin's `ReentrancyGuard`:
```solidity
function withdrawOwner() external nonReentrant {
    // Safe from reentrancy attacks
}
```

### Access Control

Critical functions are protected:
- FeeManager admin functions: `onlyOwner` (Safe multisig)
- GmBoost withdrawals: `require(msg.sender == owner)`
- Clone initialization: `require(msg.sender == factory)`

---

## Gas Optimization

### ERC-1167 Savings

| Operation | Full Contract | ERC-1167 Clone | Savings |
|-----------|---------------|----------------|---------|
| Deploy | ~400k gas | ~128k gas | **~272k gas** |
| Per call | Base cost | Base + ~2k gas | Small overhead |

**Result:** Massively cheaper deployments, negligible overhead per transaction.

### Forward-Now vs Accumulate

| Pattern | Gas per GM | Pros | Cons |
|---------|------------|------|------|
| Forward now | ~45k gas | Simple accounting | Extra transfer |
| Accumulate | ~39k gas | Slightly cheaper | Complex withdrawal |

**Result:** ~6k gas difference (~$0.0001-0.001 on Base) is acceptable for simpler design.

---

## Upgrade Strategy

### Can Existing Clones Be Upgraded?

**No.** ERC-1167 clones are immutable. They delegate to a fixed implementation address.

### How to Upgrade?

**Option 1: New Factory + Migration**
1. Deploy new implementation contract (GmBoost v2)
2. Deploy new factory pointing to v2
3. Users voluntarily migrate by deploying new v2 clones
4. Old v1 clones continue working indefinitely

**Option 2: Proxy Factory**
Future versions could use a proxy factory pattern where the implementation address is upgradeable.

**Current Approach:** Start simple. Immutable clones are easier to audit and reason about.

---

## Contract Sizes

| Contract | Size | Limit | Status |
|----------|------|-------|--------|
| FeeManager | ~4 KB | 24 KB | ✅ Well under limit |
| GmBoost | ~5 KB | 24 KB | ✅ Well under limit |
| GmBoostFactory | ~3 KB | 24 KB | ✅ Well under limit |

All contracts are well under the 24 KB contract size limit.

---

## Related Documentation

- [CONTRACTS.md](./CONTRACTS.md) - Detailed contract API reference
- [EVENTS.md](./EVENTS.md) - Event reference and indexing guide
- [security/THREAT_MODEL.md](./security/THREAT_MODEL.md) - Security analysis
- [../deployments/](../deployments/) - Deployment addresses and config

---

**Questions or suggestions?** See [security/](./security/) for security documentation.
