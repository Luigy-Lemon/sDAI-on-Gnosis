// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.19;

import {IWXDAI} from "./IWXDAI.sol";

/// @title  IBridgeInterestReceiver
/// @notice Streams bridged interest to the sDAI vault on a fixed-length epoch schedule.
/// @dev    Off-chain consumers should index {Claimed} by `vault` and listen to
///         {EpochRolled} / {DripPaused} for state-machine transitions. {ClaimerChanged}
///         and {ReceiverInitialized} cover the one-shot deployer→adapter handover.
interface IBridgeInterestReceiver {
    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted when interest is forwarded to the sDAI vault.
    /// @param vault  Recipient vault address.
    /// @param amount WXDAI transferred.
    event Claimed(address indexed vault, uint256 amount);

    /// @notice Emitted when {claim} crosses the epoch boundary and the contract enters
    ///         a new (still-funded) epoch.
    /// @param newDripRate     Per-second drip rate for the next epoch.
    /// @param newEpochBalance Balance allocated to the next epoch.
    /// @param nextEpoch       Timestamp at which the next epoch ends.
    event EpochRolled(uint256 newDripRate, uint256 newEpochBalance, uint256 nextEpoch);

    /// @notice Emitted when a rollover is attempted but the post-claim balance is below
    ///         {DRIP_PAUSE_THRESHOLD}, forcing the drip rate to zero.
    /// @param remainingBalance Balance held immediately after the triggering claim.
    event DripPaused(uint256 remainingBalance);

    /// @notice Emitted by the constructor (`address(0)` → deployer) and by {initialize}
    ///         (deployer → operational claimer). The role is set once and is non-rotatable.
    event ClaimerChanged(address indexed oldClaimer, address indexed newClaimer);

    /// @notice Emitted at the end of {initialize} with the bootstrap epoch parameters.
    event ReceiverInitialized(uint256 firstEpochBalance, uint256 firstDripRate, uint256 firstEpochEnd);

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @dev {claim} called before {initialize}.
    error NotInitialized();

    /// @dev Caller is not authorized: not the deployer during {initialize}, or a
    ///      contract caller that is not the configured `claimer` on {claim}.
    error InvalidSender();

    /// @dev `_claimer == address(0)` passed to {initialize}.
    error InvalidClaimer();

    /// @dev Receiver does not yet hold enough bridged balance to bootstrap.
    error InsufficientInitialBalance(uint256 actual, uint256 required);

    /*//////////////////////////////////////////////////////////////
                                CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Below this contract balance the drip is paused (dripRate forced to 0) to
    ///         avoid division-rounding to zero and to signal "stream depleted" to indexers.
    function DRIP_PAUSE_THRESHOLD() external view returns (uint256);

    /// @notice Minimum bridged balance required to bootstrap the first epoch with a
    ///         non-zero drip rate.
    function MIN_INITIAL_BALANCE() external view returns (uint256);

    /// @notice Length of every epoch (including the bootstrap one started in {initialize}).
    function EPOCH_LENGTH() external view returns (uint256);

    /*//////////////////////////////////////////////////////////////
                                  VIEW
    //////////////////////////////////////////////////////////////*/

    /// @notice WXDAI token used for bridged interest accounting.
    function wxdai() external view returns (IWXDAI);

    /// @notice sDAI vault that receives the periodic drip.
    function vault() external view returns (address);

    /// @notice Address authorized to call {claim} from a contract; in this deployment
    ///         the operational claimer is the SavingsXDaiAdapter.
    function claimer() external view returns (address);

    /// @notice Current epoch's per-second drip rate (0 while paused).
    function dripRate() external view returns (uint256);

    /// @notice Timestamp at which the current epoch ends and a rollover may occur.
    function nextClaimEpoch() external view returns (uint256);

    /// @notice WXDAI balance allocated to the current epoch.
    function currentEpochBalance() external view returns (uint256);

    /// @notice Timestamp of the last successful claim.
    function lastClaimTimestamp() external view returns (uint256);

    /// @notice Amount currently claimable by the vault.
    function previewClaimable() external view returns (uint256);

    /// @notice Approximate sDAI vault APY (1e18-scaled) based on the current drip rate
    ///         and vault deposits. Returns 0 when the vault has no deposits.
    function vaultAPY() external view returns (uint256);

    /*//////////////////////////////////////////////////////////////
                                  ADMIN
    //////////////////////////////////////////////////////////////*/

    /// @notice Bootstrap the receiver and atomically install the operational claimer.
    /// @dev    Restricted to the constructor-set claimer (the deployer) so a front-runner
    ///         cannot hijack the role once funding crosses the threshold; a hijack would
    ///         not steal funds (claim() always sends to `vault`), but would brick the
    ///         adapter, whose `claim()` modifier requires the adapter to BE the claimer.
    ///         Reverts {InsufficientInitialBalance} when native + WXDAI aggregate (after
    ///         wrapping) is **strictly below** {MIN_INITIAL_BALANCE}; equality is allowed.
    /// @param _claimer Operational claimer (typically the SavingsXDaiAdapter).
    function initialize(address _claimer) external payable;

    /*//////////////////////////////////////////////////////////////
                                MUTATIVE
    //////////////////////////////////////////////////////////////*/

    /// @notice Forward the currently claimable WXDAI to the sDAI vault and advance epoch
    ///         state. Callable by EOAs (anyone) or by the configured `claimer`.
    /// @return claimed WXDAI amount transferred to the vault (0 on a same-block reclaim).
    function claim() external returns (uint256 claimed);
}
