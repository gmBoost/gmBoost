// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {IFeeManager} from "./IFeeManager.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/// @title GmBoost - Per-user GM contract (clone) that accepts ETH, splits value,
///         forwards platform share immediately, and accrues owner share for withdrawal.
/// @author GmBoost Team
/// @notice Deploy via Factory as an ERC-1167 minimal proxy pointing to this implementation.
contract GmBoost is ReentrancyGuard {
    // -------------------------- Custom Errors --------------------------
    error AlreadyInitialized();
    error ZeroAddress();
    error NotOwner();
    error InsufficientEth();
    error TransferFailed();
    error UnauthorizedCaller();
    error NothingToWithdraw();

    // ---------------------------- Storage ------------------------------
    /// @notice The user who owns this GM contract.
    address public owner;
    /// @notice Address of FeeManager providing config.
    address public feeManager;
    /// @notice Factory that deployed this implementation.
    address public immutable FACTORY;
    uint16 private constant _BPS_DENOMINATOR = 10_000;
    bool private _initialized;   // One-time initializer guard

    // ---------------------------- Events -------------------------------
    /// @notice Emitted whenever a GM is sent on-chain.
    /// @param sender        The caller who sent the GM (pays msg.value)
    /// @param value         The total ETH sent with the call (tips included)
    /// @param requiredWei   The required minimum at the time of call (from FeeManager)
    /// @param platformShare The amount forwarded to the platform treasury
    /// @param ownerShare    The amount retained in this contract for the owner
    event OnChainGM(
        address indexed sender,
        uint256 value,
        uint256 requiredWei,
        uint256 platformShare,
        uint256 ownerShare
    ); // solhint-disable-line gas-indexed-events

    /// @notice Emitted when owner withdraws accumulated funds
    /// @param owner Address of the owner who withdrew
    /// @param amount Amount withdrawn in wei
    event OwnerWithdrawn(address indexed owner, uint256 amount); // solhint-disable-line gas-indexed-events

    // -------------------------- Constructor ----------------------------
    /// @notice Locks the implementation contract and records the factory address.
    /// @dev Clones use their own storage, so this only affects the implementation.
    ///      The factory address is used to authorize clone initialization.
    /// @param factory_ The address of the GmBoostFactory that will create clones
    constructor(address factory_) {
        if (factory_ == address(0)) revert ZeroAddress();
        _initialized = true;
        FACTORY = factory_;
    }

    // --------------------------- Initializer ---------------------------
    /// @notice Must be called exactly once by the Factory right after cloning.
    /// @dev Custom initialization guard (equivalent to OpenZeppelin Initializable):
    ///      - Implementation locked in constructor (prevents initialization attack on implementation)
    ///      - _initialized flag prevents double initialization on clones
    ///      - Factory-only authorization provides ADDITIONAL protection beyond standard OZ pattern
    ///      - Only the factory can initialize clones to prevent unauthorized deployments
    ///        that could bypass deployment fees or use malicious FeeManager contracts
    ///      - No external dependencies, lower gas costs than inherited Initializable
    /// @param owner_ Address of the contract owner
    /// @param feeManager_ Address of the FeeManager contract
    function initialize(address owner_, address feeManager_) external {
        if (msg.sender != FACTORY) revert UnauthorizedCaller();
        if (_initialized) revert AlreadyInitialized();
        if (owner_ == address(0) || feeManager_ == address(0)) revert ZeroAddress();
        owner = owner_;
        feeManager = feeManager_;
        _initialized = true;
    }

    // --------------------------- Core Logic ----------------------------
    /// @notice Send a GM. Requires at least the configured ETH fee; tips allowed.
    /// @dev No reentrancy guard needed - follows CEI pattern strictly:
    ///      1. Checks (fee validation)
    ///      2. Effects (state is already finalized before external call)
    ///      3. Interactions (external call to feeRecipient)
    ///      Reentrancy cannot exploit as no state writes occur after the call.
    /// Splits full msg.value into platformShare (forwarded now) and ownerShare (retained).
    function onChainGM() external payable {
        // 1) Read config from FeeManager (single STATICCALL)
        (uint256 requiredWei, uint16 ownerShareBps, address feeRecipient) =
            IFeeManager(feeManager).getConfig();

        // Extra safety: feeRecipient should never be zero (guarded in FeeManager) but validate here
        if (feeRecipient == address(0)) revert ZeroAddress();

        // 2) Enforce minimum fee (tips allowed)
        if (msg.value < requiredWei) revert InsufficientEth();

        // 3) Compute split
        //    ownerShare = floor(msg.value * bps / 10_000)
        uint256 ownerShare = (msg.value * ownerShareBps) / _BPS_DENOMINATOR;
        uint256 platformShare = msg.value - ownerShare;

        // 4) Forward platform share now (single external call)
        if (platformShare != 0) {
            // Safe: feeRecipient from FeeManager (Safe multisig controlled, not user input)
            // CEI pattern enforced, explicit success check, no state writes after external call
            (bool ok, ) = payable(feeRecipient).call{value: platformShare}("");
            if (!ok) revert TransferFailed();
        }

        // 5) Owner share is intentionally left in this contract (no transfer here)

        // 6) Emit event (transparent on-chain receipt)
        emit OnChainGM(msg.sender, msg.value, requiredWei, platformShare, ownerShare);
    }

    /// @notice Owner withdraws entire accrued balance (pull model).
    function withdrawOwner() external nonReentrant {
        if (msg.sender != owner) revert NotOwner();
        uint256 bal = address(this).balance;
        if (bal == 0) revert NothingToWithdraw();
        // Safe: owner withdrawing to self (onlyOwner check above, nonReentrant guard on function)
        // ReentrancyGuard + owner validation + balance check before external call
        (bool ok, ) = payable(owner).call{value: bal}("");
        if (!ok) revert TransferFailed();
        emit OwnerWithdrawn(owner, bal);
    }

    // ------------------------- Receive Fallback ------------------------
    /// @notice Accepts ETH sent directly (counted toward owner's balance).
    receive() external payable {}
}
