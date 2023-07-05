// SPDX-License-Identifier: agpl-3
pragma solidity ^0.8.18;

import "openzeppelin/interfaces/IERC4626.sol";
import "openzeppelin/proxy/utils/Initializable.sol";
import {IWXDAI} from "./interfaces/IWXDAI.sol";

contract BridgeInterestReceiver is Initializable {
    IWXDAI public immutable wxdai = IWXDAI(0xe91D153E0b41518A2Ce8Dd3D7944Fa863463a97d);

    address public vault;

    uint256 public dripRate;
    uint256 internal _nextClaimEpoch;
    uint256 internal _lastClaimTimestamp;

    event Claimed(uint256 indexed amount);

    function initialize(address _vault) public payable initializer {
        _nextClaimEpoch = block.timestamp;
        _lastClaimTimestamp = block.timestamp;
        vault = _vault;
    }

    function claim() public {
        uint256 xDAIbalance = address(this).balance;

        if (xDAIbalance > 0) {
            wxdai.deposit{value: xDAIbalance}();
        }

        uint256 balance = wxdai.balanceOf(address(this));

        // balance should be higher than 86400 to avoid
        if (balance > 1 days) {
            uint256 claimable = _calculateClaimable(balance);
            _lastClaimTimestamp = block.timestamp;

            wxdai.transfer(vault, claimable);

            emit Claimed(claimable);
        }
    }

    function _calculateClaimable(uint256 balance) internal returns (uint256 claimable) {
        if (block.timestamp >= _nextClaimEpoch) {
            _nextClaimEpoch = block.timestamp + 1 days;
            uint256 unclaimedTime = (block.timestamp - _lastClaimTimestamp);
            dripRate = balance / (_nextClaimEpoch + unclaimedTime);
        }

        claimable = (block.timestamp - _lastClaimTimestamp) * dripRate;
        return claimable;
    }
}
