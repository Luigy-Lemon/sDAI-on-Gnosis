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
    uint256 public nextClaimEpoch;
    uint256 public currentEpochBalance;
    uint256 public lastClaimTimestamp;
    uint256 private _lastClaimDeposits;
    uint256 public epochLength = 30 hours;
    uint256 private _latestReceivedTimestamp;
    uint256 private _largeDepositTimestamp;
    uint256 public BridgedRate;

    event Claimed(uint256 indexed amount);

    /**
     * @dev Initialize receiver with the sDAI vault
     */
    function initialize(address _vault) public payable initializer {
        currentEpochBalance = _aggregateBalance();
        lastClaimTimestamp = block.timestamp;
        nextClaimEpoch = block.timestamp + epochLength;
        dripRate = currentEpochBalance / epochLength;
        vault = _vault;
        sDAI = SavingsXDai(payable(_vault));
    }

    function claim() public returns (uint256 claimed) {
        uint256 assets = sDAI.totalAssets();
        // If large deposit intto vault index claim timestamp
        if (assets > _lastClaimDeposits + 25000 ether) {
            _largeDepositTimestamp = block.timestamp;
        }
        // Update expected size of vault assets
        _lastClaimDeposits = assets;
        // if already claimed in this block or if a large deposit was made, skip it.
        if (lastClaimTimestamp == block.timestamp || _largeDepositTimestamp == block.timestamp) {
            return 0;
        }

        uint256 balance = _aggregateBalance();

        if (balance > 0) {
            (claimed) = _calcClaimable(balance);
            lastClaimTimestamp = block.timestamp;

            wxdai.transfer(vault, claimed);
            emit Claimed(claimed);
        }
        return claimed;
    }

    function _calcClaimable(uint256 balance) internal returns (uint256 claimable) {
        uint256 unclaimedTime = block.timestamp - lastClaimTimestamp;

        // If a full epoch has passed since last claim, claim the full balance
        if (unclaimedTime >= epochLength) {
            claimable = balance;
        } else {
            // otherwise release the amount dripped during that time
            claimable = unclaimedTime * dripRate;
            // update how much has already been claimed this epoch
            if (currentEpochBalance < claimable) {
                claimable = currentEpochBalance;
            } else {
                currentEpochBalance -= claimable;
            }
        }
        // If current time is past next epoch starting time update dripRate
        if (block.timestamp > nextClaimEpoch) {
            if ((balance - claimable) < epochLength) {
                // If post-claim balance too low wait for more deposits and set rate to 0
                dripRate = 0;
            } else {
                // If post-claim balance is significant set new dripRate and start a new Epoch
                dripRate = (balance - claimable) / epochLength;
                currentEpochBalance = balance;
                nextClaimEpoch = block.timestamp + epochLength;
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
        uint256 unclaimedTime = block.timestamp - lastClaimTimestamp;
        // If a full epoch has passed since last claim, claim the full amount
        if (unclaimedTime >= epochLength) {
            claimable = balance;
        } else {
            // otherwise release the amount dripped during that time
            claimable = unclaimedTime * dripRate;
            // update how much has already been claimed this epoch
            if (currentEpochBalance < claimable) {
                claimable = currentEpochBalance;
            }
        }
        return claimable;
    }

    /**
     * @dev Informs about approximate sDAI vault APY based on incoming bridged interest and vault deposits
     * @return amount of interest collected per year divided by amount of current deposits in vault
     */
    function vaultAPY() external view returns (uint256) {
        uint256 deposits = sDAI.totalAssets();
        // if the bridged interest rate is available, use it.
        // both rates are in wei, as xDAI per second
        uint256 bestRate = (BridgedRate > 0) ? BridgedRate : dripRate;
        uint256 annualYield = (bestRate * 365 days);
        return (1 ether * annualYield) / deposits;
    }

    /**
     * @dev handle raw xDAI transfers to the receiver
     */
    receive() external payable {
        // check if xDAI is being minted from the bridge and value is significant (more than 1 xDAI)
        if (msg.sender == address(0) && msg.value > 1 ether) {
            // should never happen since there's a minInterestPaid on mainnet, but just to be sure
            if (_latestReceivedTimestamp < block.timestamp) {
                BridgedRate = (msg.value / (block.timestamp - _latestReceivedTimestamp));
            }
            _latestReceivedTimestamp = block.timestamp;
        }
    }
}
