// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {IFeeManager} from "./IFeeManager.sol";

/// @title FeeManager
/// @author GmBoost Team
/// @notice Single source of truth for GM fee and payout policy (per chain).
/// @dev   Owned by your Safe (2-of-3). No ETH is held here; it's pure config.
contract FeeManager is IFeeManager {
    // -------------------------- Custom Errors --------------------------
    error NotOwner();
    error ZeroAddress();
    error InvalidBps();

    uint16 internal constant _BPS_DENOMINATOR = 10_000;

    // ---------------------------- Storage ------------------------------
    /// @notice Safe 2-of-3 multisig that controls config updates.
    address public owner;            // Safe 2-of-3
    /// @notice Platform treasury receiving the platform share.
    address public feeRecipient;     // Platform treasury (receives platform share)
    /// @notice Required ETH amount to call onChainGM (minimum; tips allowed).
    uint256 public ethFeeWei;        // Required ETH amount to call onChainGM (min; tips allowed)
    /// @notice Owner share in basis points (0..10_000).
    uint16  public ownerShareBps;    // Owner share in basis points (0..10_000)
    /// @notice Required ETH amount to deploy GM contract via Factory (minimum; tips allowed).
    uint256 public deployFeeWei;     // Required ETH amount to deploy GM contract via Factory (min; tips allowed)

    // ---------------------------- Events -------------------------------
    /// @notice Emitted when contract ownership changes.
    /// @param previousOwner Address of the previous owner.
    /// @param newOwner Address of the new owner.
    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    ); // solhint-disable-line gas-indexed-events

    /// @notice Emitted when the platform treasury address is updated.
    /// @param newRecipient New treasury address.
    event RecipientUpdated(address indexed newRecipient); // solhint-disable-line gas-indexed-events

    /// @notice Emitted when the GM fee is updated.
    /// @param newEthFeeWei New fee in wei.
    event EthFeeUpdated(uint256 newEthFeeWei); // solhint-disable-line gas-indexed-events

    /// @notice Emitted when the owner share basis points are updated.
    /// @param newOwnerShareBps New owner share in basis points.
    event OwnerShareUpdated(uint16 newOwnerShareBps); // solhint-disable-line gas-indexed-events

    /// @notice Emitted when the deployment fee is updated.
    /// @param newDeployFeeWei New deployment fee in wei.
    event DeployFeeUpdated(uint256 newDeployFeeWei); // solhint-disable-line gas-indexed-events

    // --------------------------- Constructor ---------------------------
    /// @notice Initializes fee manager configuration.
    /// @param initialOwner      The Safe address that will control this contract.
    /// @param initialRecipient  Platform treasury (non-zero).
    /// @param initialEthFeeWei  Initial ETH fee in wei (can be 0 if desired).
    /// @param initialOwnerShareBps Owner share BPS (0..10_000).
    /// @param initialDeployFeeWei Initial deployment fee in wei (can be 0 if desired).
    constructor(
        address initialOwner,
        address initialRecipient,
        uint256 initialEthFeeWei,
        uint16 initialOwnerShareBps,
        uint256 initialDeployFeeWei
    ) {
        if (initialOwner == address(0) || initialRecipient == address(0)) revert ZeroAddress();
        if (initialOwnerShareBps > _BPS_DENOMINATOR) revert InvalidBps();

        owner = initialOwner;
        feeRecipient = initialRecipient;
        ethFeeWei = initialEthFeeWei;
        ownerShareBps = initialOwnerShareBps;
        deployFeeWei = initialDeployFeeWei;

        emit OwnershipTransferred(address(0), initialOwner);
        emit RecipientUpdated(initialRecipient);
        emit EthFeeUpdated(initialEthFeeWei);
        emit OwnerShareUpdated(initialOwnerShareBps);
        emit DeployFeeUpdated(initialDeployFeeWei);
    }

    // --------------------------- Modifiers -----------------------------
    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    // --------------------------- Admin Ops -----------------------------
    /// @notice Transfers contract ownership to a new address.
    /// @dev Only callable by current owner. New owner receives all admin privileges.
    /// @param newOwner Address of the new owner (must be non-zero).
    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        if (newOwner == owner) return;
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    /// @notice Updates the platform treasury address.
    /// @dev Only callable by owner. Changes take effect immediately for all future GMs.
    /// @param newRecipient New treasury address (must be non-zero).
    function setFeeRecipient(address newRecipient) external onlyOwner {
        if (newRecipient == address(0)) revert ZeroAddress();
        if (newRecipient == feeRecipient) return;
        feeRecipient = newRecipient;
        emit RecipientUpdated(newRecipient);
    }

    /// @notice Updates the required ETH fee for sending GMs.
    /// @dev Only callable by owner. Changes take effect immediately for all future GMs.
    /// @param newEthFeeWei New fee amount in wei.
    function setEthFeeWei(uint256 newEthFeeWei) external onlyOwner {
        if (newEthFeeWei == ethFeeWei) return;
        ethFeeWei = newEthFeeWei;
        emit EthFeeUpdated(newEthFeeWei);
    }

    /// @notice Updates the owner revenue share percentage.
    /// @dev Only callable by owner. Must be <= 10_000 (100%). Changes take effect immediately.
    /// @param newOwnerShareBps New owner share in basis points (0-10000).
    function setOwnerShareBps(uint16 newOwnerShareBps) external onlyOwner {
        if (newOwnerShareBps > _BPS_DENOMINATOR) revert InvalidBps();
        if (newOwnerShareBps == ownerShareBps) return;
        ownerShareBps = newOwnerShareBps;
        emit OwnerShareUpdated(newOwnerShareBps);
    }

    /// @notice Updates the deployment fee for creating new GM contracts.
    /// @dev Only callable by owner. Changes take effect immediately for new deployments.
    /// @param newDeployFeeWei New deployment fee amount in wei.
    function setDeployFeeWei(uint256 newDeployFeeWei) external onlyOwner {
        if (newDeployFeeWei == deployFeeWei) return;
        deployFeeWei = newDeployFeeWei;
        emit DeployFeeUpdated(newDeployFeeWei);
    }

    // ---------------------------- Views --------------------------------
    /// @inheritdoc IFeeManager
    function getConfig()
        external
        view
        returns (uint256, uint16, address)
    {
        return (ethFeeWei, ownerShareBps, feeRecipient);
    }

    /// @inheritdoc IFeeManager
    function getDeployConfig()
        external
        view
        returns (uint256, address)
    {
        return (deployFeeWei, feeRecipient);
    }
}
