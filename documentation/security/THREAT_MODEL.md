# GmBoost - Threat Model & Security Analysis

## 1. System Overview

GmBoost is a per-user "GM" (good morning) contract system on Base L2. Users deploy minimal proxy clones (ERC-1167) that:
- Accept ETH payments from greeters
- Automatically split payments between platform treasury and contract owner
- Forward platform share immediately
- Allow owner to withdraw their accumulated share

## 2. Trust Boundaries & Roles

### Roles

| Role | Permissions | Trust Level |
|------|-------------|-------------|
| **Platform Safe (2-of-3)** | Update fees, splits, treasury address | TRUSTED |
| **Contract Owner** | Withdraw accumulated funds from their own contract | SEMI-TRUSTED |
| **Greeter (Any User)** | Send GM with payment to any contract | UNTRUSTED |
| **Factory** | Deploy new clones, one-time initialize | TRUSTED (immutable) |

### Trust Boundaries

```
┌─────────────────────────────────────────────────┐
│         TRUSTED ZONE (Immutable Logic)          │
│  - FeeManager (Safe-controlled config)          │
│  - GmBoost implementation (immutable)           │
│  - GmBoostFactory (immutable)                   │
└─────────────────────────────────────────────────┘
                     ↓
┌─────────────────────────────────────────────────┐
│      SEMI-TRUSTED ZONE (User Instances)         │
│  - Individual GmBoost clones (owner controls)   │
└─────────────────────────────────────────────────┘
                     ↓
┌─────────────────────────────────────────────────┐
│        UNTRUSTED ZONE (External Users)          │
│  - Greeters sending GMs (arbitrary callers)     │
└─────────────────────────────────────────────────┘
```

## 3. Assets at Risk

### Primary Assets
1. **ETH in user contracts** - Accumulated owner shares awaiting withdrawal
2. **Platform revenue** - ETH forwarded to treasury in real-time
3. **System integrity** - Correct fee enforcement and split calculations

### Secondary Assets
4. **Gas efficiency** - Preventing denial-of-service through gas exhaustion
5. **Event data** - Accurate on-chain receipts for scoring/analytics

## 4. Threat Analysis

### 4.1 Smart Contract Threats

#### T1: Reentrancy Attack on Withdrawal
- **Target**: `GmBoost.withdrawOwner()`
- **Attack**: Owner calls withdraw, reenters during ETH transfer
- **Impact**: Could drain contract multiple times
- **Likelihood**: Medium (owner is semi-trusted but could be compromised contract)
- **Mitigation**: ✅ **ReentrancyGuard** on `withdrawOwner()`
- **Status**: MITIGATED

#### T2: Integer Overflow/Underflow
- **Target**: Split calculation in `onChainGM()`
- **Attack**: Craft `msg.value` to cause overflow in `(msg.value * ownerShareBps) / 10_000`
- **Impact**: Incorrect splits, loss of funds
- **Likelihood**: Low (Solidity 0.8.30 has built-in checks)
- **Mitigation**: ✅ **Solidity 0.8.30** built-in overflow checks
- **Status**: MITIGATED

#### T3: Front-Running Fee Changes
- **Target**: `FeeManager.setEthFeeWei()` or `setOwnerShareBps()`
- **Attack**: Greeter sees fee decrease in mempool, front-runs with old lower payment
- **Impact**: Transaction reverts (greeter loses gas) or overpays
- **Likelihood**: Low (affects greeter only, not platform)
- **Mitigation**: ℹ️ Inherent to public blockchain; greeters can check current fee before sending
- **Status**: ACCEPTED RISK (no loss for platform/owner)

#### T4: Initialization Attack
- **Target**: `GmBoost.initialize()`
- **Attack**: Call initialize on implementation contract before Factory uses it
- **Impact**: Implementation contract becomes owned by attacker (but clones unaffected)
- **Likelihood**: None (implementation locked in constructor)
- **Mitigation**: ✅ **Constructor locks implementation** by setting `_initialized = true`
- **Additional**: ✅ One-time initialization check prevents double-init on clones
- **Status**: FULLY MITIGATED

#### T5: Denial of Service via Failed Transfer
- **Target**: `onChainGM()` platform share forwarding
- **Attack**: Treasury is a contract that reverts on receive
- **Impact**: All GMs fail, system unusable
- **Likelihood**: Very Low (platform controls treasury address)
- **Mitigation**: ✅ Platform Safe controls `feeRecipient` (will use EOA or tested contract)
- **Status**: MITIGATED (operational control)

#### T6: Precision Loss in Split Calculation
- **Target**: `(msg.value * ownerShareBps) / 10_000`
- **Attack**: Send amount that creates rounding errors
- **Impact**: 1 wei discrepancy (goes to owner)
- **Likelihood**: Certain (mathematical reality)
- **Mitigation**: ℹ️ Residual wei stays in contract (owner benefits); max loss = 9999 wei
- **Status**: ACCEPTED (negligible economic impact)

#### T7: Selfdestruct / DELEGATECALL Injection
- **Target**: All contracts
- **Attack**: Inject malicious selfdestruct or delegatecall
- **Impact**: Destroy contract or hijack logic
- **Likelihood**: None (no delegatecall, no selfdestruct in code)
- **Mitigation**: ✅ No dangerous opcodes present
- **Status**: NOT APPLICABLE

### 4.2 Access Control Threats

#### T8: Unauthorized FeeManager Changes
- **Target**: `FeeManager.setEthFeeWei()`, `setOwnerShareBps()`, `setFeeRecipient()`
- **Attack**: Non-owner calls admin functions
- **Impact**: Hijack fee configuration, redirect treasury
- **Likelihood**: None if proper checks exist
- **Mitigation**: ✅ **`onlyOwner` modifier** on all admin functions
- **Verification**: ✅ Tested in test suite (67/67 passing)
- **Status**: MITIGATED

#### T9: Unauthorized Withdrawal from User Contract
- **Target**: `GmBoost.withdrawOwner()`
- **Attack**: Non-owner attempts to withdraw
- **Impact**: Theft of accumulated owner share
- **Likelihood**: None if proper checks exist
- **Mitigation**: ✅ **`msg.sender == owner` check**
- **Verification**: ✅ Tested in test suite
- **Status**: MITIGATED

### 4.3 Economic & Game Theory Threats

#### T10: Insufficient Payment (GM Fee)
- **Target**: `onChainGM()`
- **Attack**: Send less than `ethFeeWei`
- **Impact**: Free GM spam
- **Likelihood**: None if enforced
- **Mitigation**: ✅ **`require(msg.value >= ethFeeWei)`**
- **Verification**: ✅ Tested with <, =, > fee amounts
- **Status**: MITIGATED

#### T10a: Insufficient Payment (Deployment Fee)
- **Target**: `GmBoostFactory.createGmBoost()`
- **Attack**: Send less than `deployFeeWei`
- **Impact**: Free contract deployments
- **Likelihood**: None if enforced
- **Mitigation**: ✅ **`require(msg.value >= deployFeeWei)`**
- **Verification**: ✅ Tested with insufficient, exact, and overpayment scenarios
- **Status**: MITIGATED

#### T11: Griefing via Dust Payments
- **Target**: `onChainGM()`
- **Attack**: Send exactly `ethFeeWei` repeatedly to inflate owner's unwithdrawable dust
- **Impact**: Gas costs for owner increase
- **Likelihood**: Low (attacker pays fee each time)
- **Mitigation**: ℹ️ Economic disincentive (attacker loses more)
- **Status**: ACCEPTED (not economically rational)

#### T12: Owner Refusal to Withdraw (Locked Funds)
- **Target**: `GmBoost.withdrawOwner()`
- **Attack**: Owner never calls withdraw
- **Impact**: Funds locked forever
- **Likelihood**: Low (owner's own loss)
- **Mitigation**: ℹ️ Owner's responsibility; no platform risk
- **Status**: ACCEPTED (user error)

### 4.4 Operational & Governance Threats

#### T13: Safe Multisig Compromise
- **Target**: FeeManager ownership
- **Attack**: 2 of 3 Safe signers collude or get compromised
- **Impact**: Malicious fee changes, treasury redirection, ownership transfer
- **Likelihood**: Very Low (requires 2 compromises)
- **Mitigation**: ✅ **2-of-3 Safe multisig** (industry best practice)
- **Recommendation**: Use hardware wallets for all 3 signers
- **Status**: MITIGATED (operational security)

#### T14: Malicious Factory Deployment
- **Target**: Clone creation
- **Attack**: User deploys their own malicious Factory with backdoored implementation
- **Impact**: User's own contract is compromised (no platform impact)
- **Likelihood**: Medium (user error)
- **Mitigation**: ℹ️ Frontend should hardcode official Factory address; users are responsible for using correct Factory
- **Status**: ACCEPTED (user responsibility)

#### T15: Fee Manipulation (Rug Pull)
- **Target**: `FeeManager.setOwnerShareBps(0)`
- **Attack**: Platform sets owner share to 0%, keeps 100%
- **Impact**: Users receive nothing
- **Likelihood**: Very Low (reputation risk for platform)
- **Mitigation**: ℹ️ Transparent on-chain governance; users can monitor changes
- **Recommendation**: Consider adding governance timelock in v2
- **Status**: ACCEPTED (trust in platform)

### 4.5 External Dependency Threats

#### T16: OpenZeppelin Contract Vulnerability
- **Target**: `ReentrancyGuard`, `Clones`
- **Attack**: Exploit in upstream library
- **Impact**: Depends on vulnerability
- **Likelihood**: Very Low (OpenZeppelin is well-audited)
- **Mitigation**: ✅ Using stable OpenZeppelin v5.4.0
- **Recommendation**: Monitor OpenZeppelin security advisories
- **Status**: ACCEPTED (industry standard)

#### T17: Base L2 Sequencer Downtime
- **Target**: All transactions
- **Attack**: Base sequencer is down or censoring transactions
- **Impact**: Cannot deploy, GM, or withdraw
- **Likelihood**: Low (Base has high uptime)
- **Mitigation**: ℹ️ Wait for sequencer recovery; no funds at risk
- **Status**: ACCEPTED (L2 operational risk)

### 4.6 Implementation & Integration Threats

#### T18: Incorrect Clone Initialization
- **Target**: `GmBoostFactory.createGmBoost()`
- **Attack**: Factory fails to initialize clone properly
- **Impact**: Clone is unusable or unconfigured
- **Likelihood**: None if tested
- **Mitigation**: ✅ Factory atomically creates + initializes in one tx
- **Verification**: ✅ Tested in integration tests
- **Status**: MITIGATED

#### T19: Frontend Misconfiguration
- **Target**: User interaction layer
- **Attack**: Frontend sends wrong addresses or parameters
- **Impact**: User confusion, failed transactions
- **Likelihood**: Medium (deployment/config error)
- **Mitigation**: ℹ️ Thorough frontend testing, use contract ABIs from verified sources
- **Recommendation**: Verify contracts on BaseScan before frontend launch
- **Status**: OPERATIONAL (not smart contract threat)

#### T20: Unauthorized Clone Deployment
- **Target**: `GmBoost.initialize()`
- **Attack**: Attacker directly clones implementation with malicious FeeManager
- **Impact**: Platform loses 100% revenue from unauthorized clones; deployment fee bypassed
- **Likelihood**: HIGH (easily exploitable, economically motivated)
- **Mitigation**: ✅ **Factory-only initialization check**
  - Implementation records factory address in constructor
  - Initialize reverts if `msg.sender != factory`
  - Unauthorized clones cannot be initialized
- **Verification**: ✅ Added 3 security tests for factory authorization
- **Status**: FULLY MITIGATED

#### T21: Zero-Balance Withdrawal Ambiguity
- **Target**: `GmBoost.withdrawOwner()`
- **Attack**: Not an attack, but operational clarity issue
- **Impact**: `TransferFailed` error used for both actual failures and zero balance
- **Likelihood**: N/A (not a security issue)
- **Mitigation**: ✅ **Dedicated `NothingToWithdraw()` error**
  - Clear distinction between "nothing to withdraw" and "transfer failed"
  - Better frontend/user experience
  - Easier debugging
- **Status**: FULLY MITIGATED

#### T22: EOA Raw Deploy Bypass (Future Feature)
- **Target**: Planned future feature - EOA Raw Deploy
- **Design**: Intentional feature allowing direct deployment without Factory
- **Requirements**:
  - Users skip deployment fee (pay gas instead)
  - MUST use official FeeManager (platform still gets revenue)
  - Separate contract OR whitelist logic required
- **Status**: PLANNED - requires careful implementation to prevent abuse

## 5. Attack Vectors Summary

| ID | Threat | Severity | Likelihood | Mitigation Status |
|----|--------|----------|------------|-------------------|
| T1 | Reentrancy on withdrawal | HIGH | Medium | ✅ MITIGATED |
| T2 | Integer overflow | HIGH | Low | ✅ MITIGATED |
| T3 | Front-running fee changes | LOW | Low | ℹ️ ACCEPTED |
| T4 | Initialization attack | MEDIUM | Low | ✅ FULLY MITIGATED |
| T5 | DoS via failed transfer | MEDIUM | Very Low | ✅ MITIGATED |
| T6 | Precision loss | LOW | Certain | ℹ️ ACCEPTED |
| T7 | Selfdestruct injection | HIGH | None | ✅ NOT APPLICABLE |
| T8 | Unauthorized FeeManager changes | CRITICAL | None | ✅ MITIGATED |
| T9 | Unauthorized withdrawal | CRITICAL | None | ✅ MITIGATED |
| T10 | Insufficient payment (GM fee) | MEDIUM | None | ✅ MITIGATED |
| T10a | Insufficient payment (Deploy fee) | MEDIUM | None | ✅ MITIGATED |
| T11 | Griefing via dust | LOW | Low | ℹ️ ACCEPTED |
| T12 | Owner never withdraws | LOW | Low | ℹ️ ACCEPTED |
| T13 | Safe compromise | CRITICAL | Very Low | ✅ MITIGATED |
| T14 | Malicious Factory | MEDIUM | Medium | ℹ️ ACCEPTED |
| T15 | Fee manipulation | MEDIUM | Very Low | ℹ️ ACCEPTED |
| T16 | OpenZeppelin vuln | MEDIUM | Very Low | ℹ️ ACCEPTED |
| T17 | L2 downtime | LOW | Low | ℹ️ ACCEPTED |
| T18 | Incorrect initialization | MEDIUM | None | ✅ MITIGATED |
| T19 | Frontend misconfiguration | LOW | Medium | OPERATIONAL |
| T20 | Unauthorized clone deployment | HIGH | High | ✅ FULLY MITIGATED |
| T21 | Zero-balance withdrawal ambiguity | LOW | N/A | ✅ FULLY MITIGATED |
| T22 | EOA Raw Deploy bypass (future) | TBD | TBD | PLANNED |

## 6. References

- [OpenZeppelin Security Best Practices](https://docs.openzeppelin.com/contracts/5.x/api/security)
- [ConsenSys Smart Contract Best Practices](https://consensys.github.io/smart-contract-best-practices/)
- [ERC-1167 Minimal Proxy Standard](https://eips.ethereum.org/EIPS/eip-1167)
- [Base L2 Security Docs](https://docs.base.org/)

---

**Last Updated**: November 2025
