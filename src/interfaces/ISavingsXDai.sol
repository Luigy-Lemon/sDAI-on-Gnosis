// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.19;

import {IWXDAI} from "./IWXDAI.sol";

/// @title  ISavingsXDai
/// @notice Protocol-specific surface of the WXDAI-backed sDAI vault. Standard ERC-4626,
///         ERC-20 and EIP-2612 functions are inherited from OpenZeppelin and are not
///         re-declared here.
interface ISavingsXDai {
    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @dev Permit deadline has passed.
    error ERC2612ExpiredSignature(uint256 deadline);

    /// @dev Permit signature did not recover to (or validate against) `owner`.
    error ERC2612InvalidSigner(address signer, address owner);

    /// @dev Permit was issued for the zero address as owner.
    error InvalidOwner();

    /// @dev Vault does not accept native xDAI deposits; route through WXDAI/4626 instead.
    error NoXDaiDeposits();

    /*//////////////////////////////////////////////////////////////
                                CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @notice EIP-712 type hash of the EIP-2612 Permit struct.
    function PERMIT_TYPEHASH() external view returns (bytes32);

    /// @notice EIP-712 domain version string.
    function VERSION() external view returns (string memory);

    /*//////////////////////////////////////////////////////////////
                                  VIEW
    //////////////////////////////////////////////////////////////*/

    /// @notice WXDAI token wrapped by this vault (the ERC-4626 underlying asset).
    function wxdai() external view returns (IWXDAI);

    /// @notice Chain id captured at deployment; used to detect chain forks for the
    ///         EIP-712 domain separator.
    function deploymentChainId() external view returns (uint256);

    /*//////////////////////////////////////////////////////////////
                                MUTATIVE
    //////////////////////////////////////////////////////////////*/

    /// @notice Approve `spender` to spend `value` of `owner`'s vault shares using a raw
    ///         signature. Supports both EOA (ECDSA, 65-byte sig) and ERC-1271 contract
    ///         signers — the `(v, r, s)` overload is the standard EIP-2612 entry point
    ///         and is inherited from {IERC20Permit}.
    function permit(address owner, address spender, uint256 value, uint256 deadline, bytes memory signature) external;
}
