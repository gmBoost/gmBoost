# Contract Reference

Detailed documentation for all gmBoost smart contracts.

---

## FeeManager

**Purpose:** Single source of truth for GM fee, deployment fee, and payout policy (per chain).

**Location:** [contracts/FeeManager.sol](../contracts/FeeManager.sol)

### Admin Functions (Safe Multisig Only)

#### setEthFeeWei
```solidity
function setEthFeeWei(uint256 newEthFeeWei) external onlyOwner
```
Update the required GM fee in wei.

**Parameters:**
- `newEthFeeWei`: New fee amount in wei

**Emits:** `EthFeeUpdated(uint256 newEthFeeWei)`

---

#### setDeployFeeWei
```solidity
function setDeployFeeWei(uint256 newDeployFeeWei) external onlyOwner
```
Update the deployment fee for creating new GM contracts.

**Parameters:**
- `newDeployFeeWei`: New deployment fee in wei

**Emits:** `DeployFeeUpdated(uint256 newDeployFeeWei)`

---

#### setOwnerShareBps
```solidity
function setOwnerShareBps(uint16 newOwnerShareBps) external onlyOwner
```
Update the revenue split percentage (in basis points).

**Parameters:**
- `newOwnerShareBps`: Owner share in basis points (0-10,000, where 5000 = 50%)

**Emits:** `OwnerShareUpdated(uint16 newOwnerShareBps)`

---

#### setFeeRecipient
```solidity
function setFeeRecipient(address newRecipient) external onlyOwner
```
Update the platform treasury address.

**Parameters:**
- `newRecipient`: New treasury address

**Emits:** `RecipientUpdated(address indexed newRecipient)`

---

### View Functions

#### getConfig
```solidity
function getConfig() external view returns (
    uint256 ethFeeWei,
    uint16 ownerShareBps,
    address feeRecipient
)
```
Get the current GM configuration bundle.

**Returns:**
- `ethFeeWei`: Required GM fee in wei
- `ownerShareBps`: Owner share in basis points
- `feeRecipient`: Treasury address

---

#### getDeployConfig
```solidity
function getDeployConfig() external view returns (
    uint256 deployFeeWei,
    address feeRecipient
)
```
Get the deployment configuration.

**Returns:**
- `deployFeeWei`: Deployment fee in wei
- `feeRecipient`: Treasury address

---

## GmBoost

**Purpose:** Per-user GM contract deployed as an ERC-1167 minimal proxy clone.

**Location:** [contracts/GmBoost.sol](../contracts/GmBoost.sol)

### User Functions

#### onChainGM
```solidity
function onChainGM() external payable
```
Send a GM to the contract owner. Must send at least the required fee.

**Requirements:**
- Must send ETH value ≥ required fee from FeeManager
- Contract must be initialized

**Behavior:**
1. Reads fee config from FeeManager
2. Validates sent value
3. Calculates platform share and owner share
4. Forwards platform share immediately to treasury
5. Keeps owner share in contract for withdrawal
6. Emits OnChainGM event

**Emits:** `OnChainGM(address indexed sender, uint256 value, uint256 requiredWei, uint256 platformShare, uint256 ownerShare)`

---

#### withdrawOwner
```solidity
function withdrawOwner() external
```
Owner withdraws their accumulated balance.

**Requirements:**
- Must be called by contract owner
- Contract must have non-zero balance

**Behavior:**
1. Checks caller is owner
2. Checks balance > 0
3. Transfers entire balance to owner (with reentrancy protection)
4. Emits OwnerWithdrawn event

**Emits:** `OwnerWithdrawn(address indexed owner, uint256 amount)`

**Security:** Uses ReentrancyGuard to prevent reentrancy attacks.

---

### Internal Functions

#### initialize
```solidity
function initialize(address _owner, address _feeManager) external
```
Initialize the clone with owner and fee manager addresses.

**Requirements:**
- Can only be called once per clone
- Can only be called by the factory

**Note:** This is called automatically by GmBoostFactory during clone creation.

---

## GmBoostFactory

**Purpose:** Deploys cheap ERC-1167 clones for users with deployment fee collection.

**Location:** [contracts/GmBoostFactory.sol](../contracts/GmBoostFactory.sol)

### User Functions

#### createGmBoost
```solidity
function createGmBoost() external payable returns (address)
```
Deploy a new GM contract for the caller.

**Requirements:**
- Must send at least the deployment fee (read from FeeManager)
- Tips allowed (any amount >= deployment fee accepted)

**Behavior:**
1. Reads deployment fee from FeeManager
2. Validates sent value >= deployment fee (tips allowed)
3. Creates ERC-1167 clone of implementation
4. Initializes clone with msg.sender as owner
5. Forwards full payment amount to treasury (fee + any tip)
6. Emits GMContractCreated and DeploymentFeeReceived events

**Returns:** Address of the newly created GM contract

**Emits:**
- `GMContractCreated(address indexed owner, address indexed contractAddress)`
- `DeploymentFeeReceived(address indexed deployer, address indexed clone, uint256 fee)`

---

## IFeeManager

**Purpose:** Interface definition for FeeManager.

**Location:** [contracts/IFeeManager.sol](../contracts/IFeeManager.sol)

Interface used by GmBoost clones to read configuration without tight coupling.

---

## Security Features

All contracts include:
- ✅ **Solidity 0.8.30** - Built-in overflow/underflow protection
- ✅ **Custom errors** - Gas-efficient error handling
- ✅ **CEI pattern** - Checks-Effects-Interactions ordering
- ✅ **Access control** - Owner-only functions where appropriate
- ✅ **ReentrancyGuard** - Protection on withdrawal functions
- ✅ **Immutable clones** - Logic cannot be changed after deployment
- ✅ **Constructor lock** - Implementation contract cannot be initialized
- ✅ **Factory authorization** - Only authorized factory can initialize clones

See [security/](./security/) for detailed security analysis.
