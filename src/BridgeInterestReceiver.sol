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
    uint256 private _largeDepositTimestamp;

    event Claimed(uint256 indexed amount);

    constructor(address _vault) {
        vault = _vault;
        sDAI = SavingsXDai(payable(_vault));
    }

    modifier isInitialized() {
        require(_getInitializedVersion() > 0, "Not Initialized");
        _;
    }

    /**
     * @dev Initialize receiver, requires minimum balance to not set a dripRate of 0
     */
    function initialize() public payable initializer {
        currentEpochBalance = _aggregateBalance();
        //  require(currentEpochBalance > 10000 ether);
        lastClaimTimestamp = block.timestamp;
        nextClaimEpoch = block.timestamp + epochLength;
        dripRate = currentEpochBalance / epochLength;
    }

    function claim() public isInitialized returns (uint256 claimed) {
        uint256 assets = sDAI.totalAssets();
        // If large deposit into vault index claim timestamp
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
            claimable = currentEpochBalance;
        } else {
            // otherwise release the amount dripped during that time
            claimable = unclaimedTime * dripRate;
            // update how much has already been claimed this epoch
            if (currentEpochBalance < claimable) {
                claimable = currentEpochBalance;
                currentEpochBalance = 0;
            } else {
                currentEpochBalance -= claimable;
            }
        }
        // If current time is past next epoch starting time update dripRate
        if (block.timestamp > nextClaimEpoch) {
            if ((balance - claimable) < 1 ether) {
                // If post-claim balance too low wait for more deposits and set rate to 0
                dripRate = 0;
            } else {
                // If post-claim balance is significant set new dripRate and start a new Epoch
                dripRate = (balance - claimable) / epochLength;
                currentEpochBalance = balance - claimable;
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

    /**
     * @dev Emulates how much would be claimable given receiver address
     */
    function previewClaimable() external view returns (uint256 claimable) {
        uint256 unclaimedTime = block.timestamp - lastClaimTimestamp;
        // If a full epoch has passed since last claim, claim the full amount
        if (unclaimedTime >= epochLength) {
            claimable = currentEpochBalance;
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
        uint256 annualYield = (dripRate * 365 days);
        return (1 ether * annualYield) / deposits;
    }
}
