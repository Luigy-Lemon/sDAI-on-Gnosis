// SPDX-License-Identifier: agpl-3
pragma solidity ^0.8.20;

import "openzeppelin/interfaces/IERC4626.sol";
import "openzeppelin/proxy/utils/Initializable.sol";
import {IWXDAI} from "./interfaces/IWXDAI.sol";
import {SavingsXDai} from "./SavingsXDai.sol";

contract BridgeInterestReceiver is Initializable {
<<<<<<< HEAD
    IWXDAI public immutable wxdai = IWXDAI(0x18c8a7ec7897177E4529065a7E7B0878358B3BfF);

=======
    IWXDAI public immutable wxdai = IWXDAI(0xe91D153E0b41518A2Ce8Dd3D7944Fa863463a97d);
>>>>>>> 074b72e (add vaultAPY function that returns current sDAI vault APY based on current interest being relayed to the receiver and the amount of deposits)
    address public vault;
    SavingsXDai private sDAI;

    uint256 public dripRate;
    uint256 public _nextClaimEpoch;
    uint256 public _lastClaimTimestamp;
    uint256 public epochLength = 30 hours;
    uint256 private _latestReceivedTimestamp;
    uint256 public BridgedRate;

    event Claimed(uint256 indexed amount);


    function initialize(address _vault) public payable initializer {
        _nextClaimEpoch = block.timestamp;
        _lastClaimTimestamp = block.timestamp;
        vault = _vault;
        sDAI = SavingsXDai(payable(_vault));
    }

    function claim() external returns (uint256 claimed){
        if (_lastClaimTimestamp == block.timestamp){
            return 0;
        }
        uint256 xDAIbalance = address(this).balance;

        if (xDAIbalance > 0) {
            wxdai.deposit{value: xDAIbalance}();
        }

        uint256 balance = wxdai.balanceOf(address(this));

        // balance should be higher than 86400 to avoid underflow
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
        if (block.timestamp >= _nextClaimEpoch){
            if (balance < epochLength){
                dripRate = 0;
            }
            else{
                dripRate = balance / (epochLength + unclaimedTime);
                _nextClaimEpoch = block.timestamp + epochLength;
            }
        }
        if (unclaimedTime >= epochLength) {
                claimable = balance;
        }
        else {
            claimable = unclaimedTime * dripRate;
        }
        return claimable;
    }    

    function previewClaimable(uint256 balance) external view returns (uint256 claimable) {   
        uint256 _dripRate = dripRate;
        uint256 unclaimedTime = block.timestamp - _lastClaimTimestamp;
        if (block.timestamp >= _nextClaimEpoch){
            if (balance < epochLength){
                _dripRate = 0;
            }
            else{
                _dripRate = balance / (epochLength + unclaimedTime);
            }
        }
        if (unclaimedTime >= epochLength) {
                claimable = balance;
        }
        else {
            claimable = unclaimedTime * _dripRate;
        }
        return claimable;
    }

    function vaultAPY() external view returns (uint256){
        uint256 deposits = sDAI.totalAssets();
        uint256 bestRate  = (BridgedRate > 0) ? BridgedRate : dripRate;
        uint256 annualYield = (bestRate * 365 days);
        return (1 ether * annualYield ) / deposits;
    }

    receive() external payable{
        if(msg.sender == address(0)){
            if (_latestReceivedTimestamp > 0)
                BridgedRate = msg.value / (block.timestamp - _latestReceivedTimestamp);
            _latestReceivedTimestamp = block.timestamp;
        }
    }
}
