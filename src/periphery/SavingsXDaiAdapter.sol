// SPDX-License-Identifier: agpl-3
pragma solidity ^0.8.19;

import "../interfaces/IBridgeInterestReceiver.sol";
import {IWXDAI} from "../interfaces/IWXDAI.sol";
import {SavingsXDai} from "../SavingsXDai.sol";

contract SavingsXDaiAdapter {
    IBridgeInterestReceiver public immutable interestReceiver;
    SavingsXDai public immutable sDAI;
    IWXDAI public immutable wxdai = IWXDAI(0x18c8a7ec7897177E4529065a7E7B0878358B3BfF);

    /**
     * @dev Set the underlying asset contract. This must be an ERC20-compatible contract (ERC20 or ERC777).
     */
    constructor(address interestReceiver_, address payable sDAI_) {
        interestReceiver = IBridgeInterestReceiver(interestReceiver_);
        sDAI = SavingsXDai(sDAI_);
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

    function withdraw(uint256 assets, address receiver) public virtual returns (uint256) {
        interestReceiver.claim();
        uint256 maxAssets = sDAI.maxWithdraw(msg.sender);
        assets = (assets > maxAssets) ? maxAssets : assets;
        return sDAI.withdraw(assets, receiver, msg.sender);
    }

    function redeem(uint256 shares, address receiver) public virtual returns (uint256) {
        interestReceiver.claim();
        uint256 maxShares = sDAI.maxRedeem(msg.sender);
        shares = (shares > maxShares) ? maxShares : shares;
        return sDAI.redeem(shares, receiver, msg.sender);
    }

    function depositXDAI(address receiver) public payable virtual returns (uint256) {
        uint256 assets = msg.value;
        if (assets == 0) {
            return 0;
        }
        wxdai.deposit{value: assets}();
        uint256 shares = sDAI.deposit(assets, receiver);
        interestReceiver.claim();
        return shares;
    }

    function withdrawXDAI(uint256 assets, address receiver) public payable virtual returns (uint256) {
        if (assets == 0) {
            return 0;
        }
        interestReceiver.claim();
        uint256 shares = sDAI.withdraw(assets, address(this), msg.sender);
        uint256 balance = wxdai.balanceOf(address(this));
        wxdai.withdraw(balance);
        (bool sent,) = receiver.call{value: balance}("");
        require(sent, "Failed to send xDAI");
        return shares;
    }

    function redeemAll(address receiver) public virtual returns (uint256) {
        interestReceiver.claim();
        uint256 shares = sDAI.balanceOf(msg.sender);
        return sDAI.redeem(shares, receiver, msg.sender);
    }

    function redeemAllXDAI(address receiver) public payable virtual returns (uint256) {
        interestReceiver.claim();
        uint256 shares = sDAI.balanceOf(msg.sender);
        uint256 assets = sDAI.redeem(shares, address(this), msg.sender);
        wxdai.withdraw(assets);
        (bool sent,) = receiver.call{value: assets}("");
        require(sent, "Failed to send xDAI");
        return assets;
    }

    function vaultAPY() external returns (uint256) {
        return interestReceiver.vaultAPY();
    }

    receive() external payable {
        if (msg.sender != address(wxdai)) {
            depositXDAI(msg.sender);
        }
    }
}
