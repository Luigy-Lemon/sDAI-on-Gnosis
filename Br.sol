// SPDX-License-Identifier: agpl-3
pragma solidity ^0.8.19;

import "openzeppelin/interfaces/IERC4626.sol";
import "openzeppelin/proxy/utils/Initializable.sol";
import {IWXDAI} from "./interfaces/IWXDAI.sol";
import {SavingsXDai} from "./SavingsXDai.sol";

contract BridgeInterestReceiver is Initializable {
    IWXDAI public immutable wxdai = IWXDAI(0x18c8a7ec7897177E4529065a7E7B0878358B3BfF);
    address public vault;
    SavingsXDai private sDAI;

    uint256 public dripRate;
    uint256 public _nextClaimEpoch;
    uint256 public _currentEpochBalance;
    uint256 public _lastClaimTimestamp;
    uint256 public epochLength = 30 hours;
    uint256 private _latestReceivedTimestamp;
    uint256 public BridgedRate;

    event Claimed(uint256 indexed amount);

    /**
     * @dev Initialize receiver with the sDAI vault
     */
    function initialize(address _vault) public payable initializer {
        _currentEpochBalance = _aggregateBalance();
        _lastClaimTimestamp = block.timestamp;
        _nextClaimEpoch = block.timestamp + epochLength;
        dripRate = _currentEpochBalance / epochLength;
        vault = _vault;
        sDAI = SavingsXDai(payable(_vault));
    }

    function claim() public returns (uint256 claimed) {
        if (_lastClaimTimestamp == block.timestamp) {
            return 0;
        }
        uint256 balance = _aggregateBalance();

        if (balance > 0) {
            (claimed) = _calcClaimable(balance);
            _lastClaimTimestamp = block.timestamp;

            wxdai.transfer(vault, claimed);
            emit Claimed(claimed);
        }

        return claimed;
    }

    function _calcClaimable(uint256 balance) internal returns (uint256 claimable) {
        uint256 unclaimedTime = block.timestamp - _lastClaimTimestamp;

        // If a full epoch has passed since last claim, claim the full amount
        if (unclaimedTime >= epochLength) {
            claimable = balance;
        } else {
            // otherwise release the amount dripped during that time
            claimable = unclaimedTime * dripRate;
            // update how much has already been claimed this epoch
            if (_currentEpochBalance < claimable) {
                claimable = _currentEpochBalance;
            } else {
                _currentEpochBalance -= claimable;
            }
        }
        // If current time is past next epoch starting time update dripRate
        if (block.timestamp > _nextClaimEpoch) {
            if ((balance - claimable) < epochLength) {
                // If post-claim balance too low wait for more deposits and set rate to 0
                dripRate = 0;
            } else {
                // If post-claim balance is significant set new dripRate and start a new Epoch
                dripRate = (balance - claimable) / epochLength;
                _currentEpochBalance = balance;
                _nextClaimEpoch = block.timestamp + epochLength;
            }
        }
        return claimable;
    }

    /**
     * @dev Convert xDAI into wxdai and return the balanceOf this contract
     */
    function _aggregateBalance() internal returns (uint256 balance) {
        uint256 xDAIbalance = address(this).balance;
        if (xDAIbalance > 0) {
            wxdai.deposit{value: xDAIbalance}();
        }
        return wxdai.balanceOf(address(this));
    }

    function previewClaimable(uint256 balance) external view returns (uint256 claimable) {
        uint256 unclaimedTime = block.timestamp - _lastClaimTimestamp;
        // If a full epoch has passed since last claim, claim the full amount
        if (unclaimedTime >= epochLength) {
            claimable = balance;
        } else {
            // otherwise release the amount dripped during that time
            claimable = unclaimedTime * dripRate;
            // update how much has already been claimed this epoch
            if (_currentEpochBalance < claimable) {
                claimable = _currentEpochBalance;
            }
        }
        return claimable;
    }

    function vaultAPY() external view returns (uint256) {
        uint256 deposits = sDAI.totalAssets();
        uint256 bestRate = (BridgedRate > 0) ? BridgedRate : dripRate;
        uint256 annualYield = (bestRate * 365 days);
        return (1 ether * annualYield) / deposits;
    }

    receive() external payable {
        // check if xDAI is being minted from the bridge and value is significant (more than 1 xDAI)
        if (msg.sender == address(0) && msg.value > 1 ether) {
            if (_latestReceivedTimestamp > 0) {
                BridgedRate = msg.value / (block.timestamp - _latestReceivedTimestamp);
            }
            _latestReceivedTimestamp = block.timestamp;
        }
    }
}
