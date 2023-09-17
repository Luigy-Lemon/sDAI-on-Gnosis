// SPDX-License-Identifier: agpl-3
pragma solidity ^0.8.20;

import "../interfaces/IBridgeInterestReceiver.sol";
import {IWXDAI} from "../interfaces/IWXDAI.sol";
import {SavingsXDai} from "../SavingsXDai.sol";

contract SavingsXDaiAdapter {
    IBridgeInterestReceiver public immutable interestReceiver;
    SavingsXDai public immutable sDAI;
    IWXDAI public immutable wxdai =
        IWXDAI(0x18c8a7ec7897177E4529065a7E7B0878358B3BfF);

    /**
     * @dev Set the underlying asset contract. This must be an ERC20-compatible contract (ERC20 or ERC777).
     */
    constructor(address interestReceiver_, address payable sDAI_) {
        interestReceiver = IBridgeInterestReceiver(interestReceiver_);
        sDAI = SavingsXDai(sDAI_);
        wxdai.approve(sDAI_, type(uint256).max);
    }

    function deposit(
        uint256 assets,
        address receiver
    ) public returns (uint256) {
        wxdai.transferFrom(msg.sender, address(this), assets);
        uint256 shares = sDAI.deposit(assets, receiver);
        interestReceiver.claim();
        return shares;
    }

    function mint(
        uint256 shares,
        address receiver
    ) public virtual returns (uint256) {
        wxdai.transferFrom(
            msg.sender,
            address(this),
            sDAI.convertToAssets(shares)
        );
        uint256 assets = sDAI.mint(shares, receiver);
        interestReceiver.claim();
        return assets;
    }

    function withdraw(
        uint256 assets,
        address receiver,
        address owner
    ) public virtual returns (uint256) {
        interestReceiver.claim();
        return sDAI.withdraw(assets, receiver, owner);
    }

    function redeem(
        uint256 shares,
        address receiver,
        address owner
    ) public virtual returns (uint256) {
        interestReceiver.claim();
        return sDAI.redeem(shares, receiver, owner);
    }

    function depositXDAI(
        address receiver
    ) public payable virtual returns (uint256) {
        uint256 assets = msg.value;
        if (assets == 0) {
            return 0;
        }
        wxdai.deposit{value: assets}();
        uint256 shares = sDAI.deposit(assets, receiver);
        interestReceiver.claim();
        return shares;
    }

    function withdrawXDAI(
        uint256 assets,
        address receiver,
        address owner
    ) public payable virtual returns (uint256) {
        if (assets == 0) {
            return 0;
        }
        interestReceiver.claim();
        uint256 shares = sDAI.withdraw(assets, address(this), owner);
        uint256 balance = wxdai.balanceOf(address(this));
        wxdai.withdraw(balance);
        (bool sent, ) = receiver.call{value: balance}("");
        require(sent, "Failed to send xDAI");
        return shares;
    }

    function redeemAll(
        address receiver,
        address owner
    ) public virtual returns (uint256) {
        interestReceiver.claim();
        uint256 shares = sDAI.balanceOf(owner);
        return sDAI.redeem(shares, receiver, owner);
    }

    function redeemAllXDAI(
        address receiver,
        address owner
    ) public payable virtual returns (uint256) {
        interestReceiver.claim();
        uint256 shares = sDAI.balanceOf(owner);
        uint256 assets = sDAI.redeem(shares, address(this), owner);
        wxdai.withdraw(assets);
        (bool sent, ) = receiver.call{value: assets}("");
        require(sent, "Failed to send xDAI");
        return assets;
    }

    function vaultAPY() external returns (uint256){
        return interestReceiver.vaultAPY();
    }

    receive() external payable {
        if (msg.sender != address(wxdai)){
            depositXDAI(msg.sender);
        }
    }
}
