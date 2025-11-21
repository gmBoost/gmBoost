// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {IFeeManager} from "./IFeeManager.sol";

/// @title IGmBoostInit - Minimal initializer interface for GmBoost clones
/// @author GmBoost Team
/// @notice Used by the factory to initialize freshly cloned contracts.
interface IGmBoostInit {
    /// @notice Initialize the clone with owner and fee manager.
    /// @param owner_ Address of the clone owner.
    /// @param feeManager_ Address of the FeeManager used for config.
    function initialize(address owner_, address feeManager_) external;
}

/// @title GmBoostFactory - Deploys minimal-proxy GmBoost clones for users
/// @author GmBoost Team
/// @notice Emits events to attribute each deployed GM contract to its owner.
/// @dev Charges a deployment fee (configured in FeeManager) and forwards 100% to platform treasury.
contract GmBoostFactory {
    using Clones for address;

    // ---------------------------- Storage ------------------------------
    /// @notice Implementation contract address used for cloning.
    address public immutable GMBOOST_IMPLEMENTATION;
    /// @notice Shared FeeManager per chain.
    address public immutable FEE_MANAGER;

    // ---------------------------- Events -------------------------------
    /// @notice Emitted when a new user GM clone is deployed.
    /// @param owner           The user who owns the new GM contract.
    /// @param contractAddress The address of the deployed GM clone.
    event GMContractCreated(
        address indexed owner,
        address indexed contractAddress
    );

    /// @notice Emitted when deployment fee is received and forwarded to treasury.
    /// @param deployer The user who deployed the contract.
    /// @param clone    The address of the deployed clone.
    /// @param fee      The deployment fee paid.
    event DeploymentFeeReceived(
        address indexed deployer,
        address indexed clone,
        uint256 fee
    );

    // -------------------------- Custom Errors --------------------------
    error ZeroAddress();
    error InsufficientDeploymentFee();
    error TransferFailed();

    // --------------------------- Constructor ---------------------------
    /// @notice Creates the factory with implementation and fee manager addresses.
    /// @dev Both addresses are immutable after deployment.
    /// @param gmBoostImpl_   Address of the deployed GmBoost implementation (logic).
    /// @param feeManager_ Address of the shared FeeManager for this chain.
    constructor(address gmBoostImpl_, address feeManager_) {
        if (gmBoostImpl_ == address(0) || feeManager_ == address(0)) {
            revert ZeroAddress();
        }
        GMBOOST_IMPLEMENTATION = gmBoostImpl_;
        FEE_MANAGER = feeManager_;
    }

    // ----------------------------- API --------------------------------
    /// @notice Deploy a new GmBoost clone for the caller and initialize it.
    /// @dev Requires payment of deployFeeWei (from FeeManager). Tips allowed. Forwards 100% to treasury.
    /// @return clone Address of the newly deployed GM contract.
    function createGmBoost() external payable returns (address clone) {
        // Read deployment fee configuration
        (uint256 deployFee, address treasury) = IFeeManager(FEE_MANAGER).getDeployConfig();

        // Extra safety: treasury should never be zero (guarded in FeeManager) but validate here
        if (treasury == address(0)) revert ZeroAddress();

        // Validate payment (tips allowed)
        if (msg.value < deployFee) revert InsufficientDeploymentFee();

        // Create and initialize clone
        clone = GMBOOST_IMPLEMENTATION.clone();
        IGmBoostInit(clone).initialize(msg.sender, FEE_MANAGER);

        // Forward deployment fee to treasury (100%)
        if (msg.value > 0) {
            // Safe: treasury from FeeManager (Safe multisig controlled, not user input)
            // CEI pattern enforced, clone created before transfer, explicit error handling
            (bool success, ) = payable(treasury).call{value: msg.value}("");
            if (!success) revert TransferFailed();
        }

        // Emit events
        emit GMContractCreated(msg.sender, clone);
        emit DeploymentFeeReceived(msg.sender, clone, msg.value);
    }
}
