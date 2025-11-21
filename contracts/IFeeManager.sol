// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

/// @title IFeeManager - Interface for reading the current GM payout/fee config
/// @author GmBoost Team
/// @notice Exposes read-only accessors for GM fee and deployment settings.
interface IFeeManager {
    /// @notice Returns the current configuration used by GM contracts.
    /// @return ethFeeWei  The minimum ETH required to call onChainGM (tips allowed).
    /// @return ownerShareBps  The owner's share in basis points (0..10_000).
    /// @return feeRecipient  The platform treasury receiving the platform share.
    function getConfig()
        external
        view
        returns (uint256 ethFeeWei, uint16 ownerShareBps, address feeRecipient);

    /// @notice Returns deployment configuration used by the Factory.
    /// @return deployFeeWei  The ETH fee required to deploy a GM contract (tips allowed).
    /// @return feeRecipient  The platform treasury receiving deployment fees.
    function getDeployConfig()
        external
        view
        returns (uint256 deployFeeWei, address feeRecipient);
}
