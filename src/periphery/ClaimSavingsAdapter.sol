// SPDX-License-Identifier: agpl-3
pragma solidity ^0.8.20;

import "../interfaces/IBridgeInterestReceiver.sol";
import {IWXDAI} from "../interfaces/IWXDAI.sol";
import {GnosisSavingsDAI} from "../GnosisSavingsDAI.sol";

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
        wxdai.transferFrom(msg.sender, address(this), assets);
        uint256 shares = sDAI.deposit(assets, receiver);
        interestReceiver.claim();
        return shares;
    }

    function mint(uint256 shares, address receiver) public virtual returns (uint256) {
        wxdai.transferFrom(msg.sender, address(this), sDAI.convertToAssets(shares));
        uint256 assets = sDAI.mint(shares, receiver);
        interestReceiver.claim();
        return assets;
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
        uint256 shares = sDAI.depositXDAI{value:assets}(receiver);
        interestReceiver.claim();
        return shares;
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
