# Event Reference

Complete reference for all events emitted by gmBoost contracts.

All contracts emit events for complete on-chain transparency and easy indexing.

---

## GmBoost Events

### OnChainGM

Emitted when someone sends a GM with ETH payment.

```solidity
event OnChainGM(
    address indexed sender,    // Who sent the GM
    uint256 value,            // Total ETH sent
    uint256 requiredWei,      // Required fee from config
    uint256 platformShare,    // Amount forwarded to treasury
    uint256 ownerShare        // Amount kept for owner
);
```

**Parameters:**
- `sender` (indexed): Address of the person sending the GM
- `value`: Total amount of ETH sent in the transaction
- `requiredWei`: The minimum required fee at time of transaction
- `platformShare`: Amount immediately forwarded to platform treasury
- `ownerShare`: Amount retained in contract for owner withdrawal

**Use Cases:**
- Build leaderboards showing most GMs sent/received
- Track revenue per user over time
- Determine airdrop eligibility based on GM activity
- Create analytics dashboards showing platform activity
- Calculate total platform revenue across all contracts

---

### OwnerWithdrawn

Emitted when contract owner withdraws their accrued balance.

```solidity
event OwnerWithdrawn(
    address indexed owner,    // Contract owner
    uint256 amount           // Amount withdrawn
);
```

**Parameters:**
- `owner` (indexed): Address of the contract owner who withdrew
- `amount`: Amount of ETH withdrawn

**Use Cases:**
- Track withdrawal history for accounting
- Monitor contract balance changes
- Verify owner claims

---

## FeeManager Events

### OwnershipTransferred

Emitted when contract ownership is transferred (OpenZeppelin Ownable).

```solidity
event OwnershipTransferred(
    address indexed previousOwner,
    address indexed newOwner
);
```

**Parameters:**
- `previousOwner` (indexed): Previous owner address
- `newOwner` (indexed): New owner address

---

### RecipientUpdated

Emitted when the platform treasury address is changed.

```solidity
event RecipientUpdated(
    address indexed newRecipient  // New treasury address
);
```

**Parameters:**
- `newRecipient` (indexed): New platform treasury address

---

### EthFeeUpdated

Emitted when the GM fee is changed.

```solidity
event EthFeeUpdated(
    uint256 newEthFeeWei         // New GM fee in wei
);
```

**Parameters:**
- `newEthFeeWei`: New required GM fee in wei

---

### OwnerShareUpdated

Emitted when the revenue split percentage is changed.

```solidity
event OwnerShareUpdated(
    uint16 newOwnerShareBps      // New owner share in basis points (0-10000)
);
```

**Parameters:**
- `newOwnerShareBps`: New owner share percentage in basis points (5000 = 50%)

---

### DeployFeeUpdated

Emitted when the deployment fee is changed.

```solidity
event DeployFeeUpdated(
    uint256 newDeployFeeWei      // New deployment fee in wei
);
```

**Parameters:**
- `newDeployFeeWei`: New deployment fee in wei

---

## GmBoostFactory Events

### GMContractCreated

Emitted when a new GM contract is deployed.

```solidity
event GMContractCreated(
    address indexed owner,           // Owner of new contract
    address indexed contractAddress  // Address of deployed clone
);
```

**Parameters:**
- `owner` (indexed): Address of the user who owns the new GM contract
- `contractAddress` (indexed): Address of the newly deployed clone

**Use Cases:**
- Track total number of GM contracts deployed
- Build a registry of all user GM contracts
- Monitor platform growth over time
- Associate users with their GM contract addresses

---

### DeploymentFeeReceived

Emitted when deployment fee is paid and forwarded to treasury.

```solidity
event DeploymentFeeReceived(
    address indexed deployer,  // User who deployed
    address indexed clone,     // Address of deployed clone
    uint256 fee               // Deployment fee paid
);
```

**Parameters:**
- `deployer` (indexed): Address of the user who paid the deployment fee
- `clone` (indexed): Address of the newly created clone
- `fee`: Amount of deployment fee paid in wei

**Use Cases:**
- Track platform revenue from deployments
- Verify deployment fee payments
- Audit financial flows

### Event Signatures

For manual indexing or subgraph development:

```
OnChainGM: 0x... (keccak256 hash)
OwnerWithdrawn: 0x... (keccak256 hash)
GMContractCreated: 0x... (keccak256 hash)
DeploymentFeeReceived: 0x... (keccak256 hash)
```

Use `ethers.utils.id("OnChainGM(address,uint256,uint256,uint256,uint256)")` to calculate event signatures.

---

## Analytics Use Cases

### Platform Metrics

Using events, you can calculate:
- Total GMs sent across platform
- Total revenue (platform + owner shares)
- Most active users (by GMs sent)
- Most popular recipients (by GMs received)
- Growth rate over time
- Average GM value
- Deployment rate

### User Profiles

For each user, you can build:
- Total GMs sent
- Total GMs received
- Total ETH spent on GMs
- Total ETH earned from GMs
- Withdrawal history
- Contract deployment date
- Activity timeline

See [CONTRACTS.md](./CONTRACTS.md) for function documentation.
