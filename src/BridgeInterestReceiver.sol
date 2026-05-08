// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.19;

import "openzeppelin/proxy/utils/Initializable.sol";
import {IERC20} from "openzeppelin/token/ERC20/IERC20.sol";
import {SafeERC20} from "openzeppelin/token/ERC20/utils/SafeERC20.sol";
import {Gnosis} from "./constants/Gnosis.sol";
import {IWXDAI} from "./interfaces/IWXDAI.sol";
import {IBridgeInterestReceiver} from "./interfaces/IBridgeInterestReceiver.sol";
import {SavingsXDai} from "./SavingsXDai.sol";

/// @title BridgeInterestReceiver
/// @notice See {IBridgeInterestReceiver}.
contract BridgeInterestReceiver is IBridgeInterestReceiver, Initializable {
    using SafeERC20 for IERC20;

    /*//////////////////////////////////////////////////////////////
                                CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IBridgeInterestReceiver
    uint256 public constant DRIP_PAUSE_THRESHOLD = 100 ether;

    /// @inheritdoc IBridgeInterestReceiver
    uint256 public constant MIN_INITIAL_BALANCE = 1 ether;

    /// @inheritdoc IBridgeInterestReceiver
    uint256 public constant EPOCH_LENGTH = 3 days;

    /*//////////////////////////////////////////////////////////////
                               IMMUTABLES
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IBridgeInterestReceiver
    IWXDAI public immutable wxdai = IWXDAI(Gnosis.WXDAI);

    /// @inheritdoc IBridgeInterestReceiver
    address public immutable vault;

    /// @dev Typed handle to {vault}; kept private because callers can read {vault} directly.
    SavingsXDai private immutable sDAI;

    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IBridgeInterestReceiver
    address public claimer;

    /// @inheritdoc IBridgeInterestReceiver
    uint256 public dripRate;

    /// @inheritdoc IBridgeInterestReceiver
    uint256 public nextClaimEpoch;

    /// @inheritdoc IBridgeInterestReceiver
    uint256 public currentEpochBalance;

    /// @inheritdoc IBridgeInterestReceiver
    uint256 public lastClaimTimestamp;

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(address _vault) {
        vault = _vault;
        sDAI = SavingsXDai(payable(_vault));
        claimer = msg.sender;
        emit ClaimerChanged(address(0), msg.sender);
    }

    /*//////////////////////////////////////////////////////////////
                                MODIFIERS
    //////////////////////////////////////////////////////////////*/

    modifier isInitialized() {
        if (_getInitializedVersion() == 0) revert NotInitialized();
        _;
    }

    modifier isClaimer() {
        if (msg.sender.code.length != 0 && msg.sender != claimer) revert InvalidSender();
        _;
    }

    /*//////////////////////////////////////////////////////////////
                                  ADMIN
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IBridgeInterestReceiver
    function initialize(address _claimer) external payable initializer {
        if (msg.sender != claimer) revert InvalidSender();
        if (_claimer == address(0)) revert InvalidClaimer();

        address oldClaimer = claimer;
        claimer = _claimer;

        currentEpochBalance = _aggregateBalance();
        if (currentEpochBalance <= MIN_INITIAL_BALANCE) {
            revert InsufficientInitialBalance(currentEpochBalance, MIN_INITIAL_BALANCE);
        }
        lastClaimTimestamp = block.timestamp;
        nextClaimEpoch = block.timestamp + EPOCH_LENGTH;
        dripRate = currentEpochBalance / EPOCH_LENGTH;

        emit ClaimerChanged(oldClaimer, _claimer);
        emit ReceiverInitialized(currentEpochBalance, dripRate, nextClaimEpoch);
    }

    /*//////////////////////////////////////////////////////////////
                                MUTATIVE
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IBridgeInterestReceiver
    function claim() external isInitialized isClaimer returns (uint256 claimed) {
        if (lastClaimTimestamp == block.timestamp) {
            return 0;
        }
        uint256 balance = _aggregateBalance();
        if (balance > 0) {
            claimed = _settleClaim(balance);
            lastClaimTimestamp = block.timestamp;

            IERC20(address(wxdai)).safeTransfer(vault, claimed);
            emit Claimed(vault, claimed);
        }
    }

    receive() external payable {}

    /*//////////////////////////////////////////////////////////////
                                  VIEW
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IBridgeInterestReceiver
    function previewClaimable() external view returns (uint256) {
        return _computeClaimable(
            _elapsedSinceLastClaim(block.timestamp, lastClaimTimestamp),
            currentEpochBalance,
            dripRate,
            EPOCH_LENGTH
        );
    }

    /// @inheritdoc IBridgeInterestReceiver
    function vaultAPY() external view returns (uint256) {
        uint256 deposits = sDAI.totalAssets();
        if (deposits == 0) return 0;
        return (1 ether * dripRate * 365 days) / deposits;
    }

    /*//////////////////////////////////////////////////////////////
                                INTERNAL
    //////////////////////////////////////////////////////////////*/

    function _elapsedSinceLastClaim(uint256 timestamp, uint256 _lastClaimTimestamp)
        internal
        pure
        returns (uint256)
    {
        return timestamp - _lastClaimTimestamp;
    }

    /// @dev Pure read: how much is claimable now given the current epoch state.
    function _computeClaimable(
        uint256 unclaimedTime,
        uint256 _currentEpochBalance,
        uint256 _dripRate,
        uint256 _epochLength
    ) internal pure returns (uint256 claimable) {
        if (unclaimedTime >= _epochLength) {
            claimable = _currentEpochBalance;
        } else {
            claimable = unclaimedTime * _dripRate;
            if (_currentEpochBalance < claimable) {
                claimable = _currentEpochBalance;
            }
        }
    }

    /// @dev Pure rollover: returns `(newDripRate, newEpochBalance)` for the next epoch, or
    ///      `(0, 0)` if the post-claim balance is below {DRIP_PAUSE_THRESHOLD} (drip pauses)
    ///      or if no rollover should happen yet.
    function _computeNextEpochState(
        uint256 timestamp,
        uint256 balance,
        uint256 claimable,
        uint256 _nextClaimEpoch,
        uint256 _epochLength
    ) internal pure returns (uint256 newDrip, uint256 newEpochBal) {
        if (timestamp > _nextClaimEpoch) {
            uint256 postClaim = balance - claimable;
            if (postClaim < DRIP_PAUSE_THRESHOLD) return (0, 0);
            return (postClaim / _epochLength, postClaim);
        }
    }

    /// @dev Stateful: returns the claimable amount and advances epoch state (subtract within
    ///      epoch, roll over / pause across boundaries). Caller is responsible for transferring
    ///      `claimable` and updating `lastClaimTimestamp`.
    function _settleClaim(uint256 balance) internal returns (uint256 claimable) {
        uint256 unclaimedTime = _elapsedSinceLastClaim(block.timestamp, lastClaimTimestamp);
        claimable = _computeClaimable(unclaimedTime, currentEpochBalance, dripRate, EPOCH_LENGTH);

        if (unclaimedTime < EPOCH_LENGTH) {
            // Safe: _computeClaimable caps `claimable` at `currentEpochBalance`.
            currentEpochBalance -= claimable;
        }

        if (block.timestamp > nextClaimEpoch) {
            (uint256 newDrip, uint256 newEpochBal) = _computeNextEpochState(
                block.timestamp, balance, claimable, nextClaimEpoch, EPOCH_LENGTH
            );
            // Always rewrite epoch state on rollover, otherwise a sub-threshold pause leaves
            // `currentEpochBalance` stale and bricks future claims (insufficient wxDAI balance).
            dripRate = newDrip;
            currentEpochBalance = newEpochBal;
            nextClaimEpoch = block.timestamp + EPOCH_LENGTH;

            if (newEpochBal > 0) {
                emit EpochRolled(newDrip, newEpochBal, nextClaimEpoch);
            } else {
                emit DripPaused(balance - claimable);
            }
        }
    }

    /// @dev Wraps any native xDAI held by this contract into WXDAI and returns the total
    ///      WXDAI balance afterwards. WXDAI on Gnosis is non-upgradable and mints 1:1.
    function _aggregateBalance() internal returns (uint256) {
        uint256 xDAIbalance = address(this).balance;
        uint256 wxdaiBalance = wxdai.balanceOf(address(this));
        if (xDAIbalance > 0) {
            wxdai.deposit{value: xDAIbalance}();
        }
        return wxdaiBalance + xDAIbalance;
    }
}
