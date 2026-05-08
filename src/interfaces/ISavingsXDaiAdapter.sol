// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.19;

import {IBridgeInterestReceiver} from "./IBridgeInterestReceiver.sol";
import {IWXDAI} from "./IWXDAI.sol";

/// @title  ISavingsXDaiAdapter
/// @notice User-facing entrypoint for the sDAI vault on Gnosis. Each EOA-driven
///         deposit/withdraw triggers a {IBridgeInterestReceiver.claim} so vault
///         depositors always trade against an up-to-date asset/share ratio. Also
///         handles wrapping/unwrapping between native xDAI and WXDAI for the
///         `*XDAI` entrypoints.
interface ISavingsXDaiAdapter {
    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @dev Native xDAI transfer to the recipient failed (recipient reverted, ran out
    ///      of gas, or rejected the call).
    error XDaiSendFailed();

    /*//////////////////////////////////////////////////////////////
                                  VIEW
    //////////////////////////////////////////////////////////////*/

    /// @notice Bridge interest receiver this adapter pulls drips from.
    function interestReceiver() external view returns (IBridgeInterestReceiver);

    /// @notice ERC-4626 sDAI vault this adapter wraps.
    function sDAI() external view returns (address);

    /// @notice WXDAI token used to interface with the underlying ERC-4626 vault.
    function wxdai() external view returns (IWXDAI);

    /// @notice Pass-through to {IBridgeInterestReceiver.vaultAPY}.
    function vaultAPY() external view returns (uint256);

    /*//////////////////////////////////////////////////////////////
                          MUTATIVE -- WXDAI PATH
    //////////////////////////////////////////////////////////////*/

    /// @notice Deposit `assets` WXDAI into the vault on behalf of `receiver`.
    function deposit(uint256 assets, address receiver) external returns (uint256 shares);

    /// @notice Mint exactly `shares` of vault shares to `receiver`, pulling the required
    ///         WXDAI from the caller.
    function mint(uint256 shares, address receiver) external returns (uint256 assets);

    /// @notice Withdraw up to `assets` WXDAI from the caller's position to `receiver`.
    /// @dev    The amount actually withdrawn is `min(assets, maxWithdraw(caller))`.
    function withdraw(uint256 assets, address receiver) external returns (uint256 shares);

    /// @notice Redeem up to `shares` of the caller's vault shares to `receiver`.
    /// @dev    The amount actually redeemed is `min(shares, maxRedeem(caller))`.
    function redeem(uint256 shares, address receiver) external returns (uint256 assets);

    /// @notice Redeem the caller's full share balance to `receiver`.
    function redeemAll(address receiver) external returns (uint256 assets);

    /*//////////////////////////////////////////////////////////////
                       MUTATIVE -- NATIVE xDAI PATH
    //////////////////////////////////////////////////////////////*/

    /// @notice Deposit `msg.value` native xDAI on behalf of `receiver`. Wraps to WXDAI
    ///         internally before depositing into the vault.
    function depositXDAI(address receiver) external payable returns (uint256 shares);

    /// @notice Withdraw up to `assets` of value to `receiver` as native xDAI. Unwraps
    ///         WXDAI internally; reverts with {XDaiSendFailed} if the native transfer fails.
    function withdrawXDAI(uint256 assets, address receiver) external payable returns (uint256 shares);

    /// @notice Redeem `shares` and forward the proceeds to `receiver` as native xDAI.
    function redeemXDAI(uint256 shares, address receiver) external payable returns (uint256 assets);

    /// @notice Redeem the caller's full share balance and forward the proceeds to
    ///         `receiver` as native xDAI.
    function redeemAllXDAI(address receiver) external payable returns (uint256 assets);
}
