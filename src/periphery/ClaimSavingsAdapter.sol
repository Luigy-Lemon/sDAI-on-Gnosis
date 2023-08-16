// SPDX-License-Identifier: agpl-3
pragma solidity ^0.8.20;

import "openzeppelin/token/ERC20/extensions/ERC4626.sol";
import "../interfaces/IBridgeInterestReceiver.sol";
import {IWXDAI} from "../interfaces/IWXDAI.sol";
import {GnosisSavingsDAI} from "../GnosisSavingsDAI.sol";
import {IERC20Permit} from "openzeppelin/token/ERC20/extensions/IERC20Permit.sol";
import {ECDSA} from "openzeppelin/utils/cryptography/ECDSA.sol";
import {EIP712} from "openzeppelin/utils/cryptography/EIP712.sol";
import {Nonces} from "openzeppelin/utils/Nonces.sol";

contract ClaimSavingsAdapter {

    IBridgeInterestReceiver immutable public interestReceiver;
    GnosisSavingsDAI immutable public sDAI;
    IWXDAI public immutable wxdai = IWXDAI(0xe91D153E0b41518A2Ce8Dd3D7944Fa863463a97d);
    
    /**
     * @dev Set the underlying asset contract. This must be an ERC20-compatible contract (ERC20 or ERC777).
     */
    constructor(address interestReceiver_, address payable sDAI_) {
        interestReceiver = IBridgeInterestReceiver(interestReceiver_);
        sDAI = GnosisSavingsDAI(sDAI_);
        wxdai.approve(sDAI_, type(uint256).max);
    }

    function deposit(uint256 assets, address receiver) public returns (uint256) {
        interestReceiver.claim();
        return sDAI.deposit(assets, receiver);
    }

    function mint(uint256 shares, address receiver) public virtual returns (uint256) {
        interestReceiver.claim();
        return sDAI.mint(shares, receiver);
    }

    function withdraw(uint256 assets, address receiver, address owner) public virtual returns (uint256) {
        interestReceiver.claim();
        return sDAI.withdraw(assets, receiver, owner);
    }

    function redeem(uint256 shares, address receiver, address owner) public virtual returns (uint256) {
        interestReceiver.claim();
        return sDAI.redeem(shares, receiver, owner);
    }

    function depositXDAI(address receiver) public virtual payable returns (uint256) {
        uint256 assets = msg.value;
        if (assets == 0){
            return 0;
        }
        interestReceiver.claim();
        return sDAI.depositXDAI{value:assets}(receiver);
    }

    function withdrawXDAI(uint256 assets, address receiver, address owner) public virtual returns (uint256) {
        interestReceiver.claim();
        return sDAI.withdrawXDAI(assets, receiver, owner);
    }

    function redeemAll(address receiver, address owner) public virtual returns (uint256) {
        interestReceiver.claim();
        uint256 shares = sDAI.balanceOf(owner);
        return sDAI.redeem(shares, receiver, owner);
    }

    function redeemAllXDAI(address receiver, address owner) public virtual returns (uint256) {
        interestReceiver.claim();
        uint256 assets = sDAI.maxWithdraw(owner);
        return sDAI.withdrawXDAI(assets, receiver, owner);
    }

    receive() external payable {
        revert("No xDAI deposits");
    }

}
