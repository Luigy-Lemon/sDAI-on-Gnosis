// SPDX-License-Identifier: agpl-3
pragma solidity ^0.8.18;

import "openzeppelin/interfaces/IERC4626.sol";
import "openzeppelin/proxy/transparent/TransparentUpgradeableProxy.sol";
import {IWXDAI} from "./interfaces/IWXDAI.sol";

contract BridgeInterestReceiver{

    IWXDAI public immutable WXDAI = IWXDAI(0xe91D153E0b41518A2Ce8Dd3D7944Fa863463a97d);

    address public vault;

    uint256 public dripRate;
    uint256 internal lastUpdate;

    /**
   * @dev Emitted on deposit()
   * @param amount The amount of the asset that has been claimed to the vault
   **/
    event Claimed(
        uint256 indexed amount
    );

    function claim() public virtual {

        uint256 balance = address(this).balance;

        require(balance != 0, "Balance is zero");

        WXDAI.deposit{value:balance}();

        uint256 claimable = _calculateClaimable(balance);

        WXDAI.transfer(vault, claimable);

        emit Claimed(claimable);
    }

    function _calculateClaimable(uint256 balance) internal pure returns(uint256 claimable) {

        claimable = balance;
        return claimable;
    }

    
}