// SPDX-License-Identifier: agpl-3
pragma solidity ^0.8.19;

import {IBridgeInterestReceiver} from "../interfaces/IBridgeInterestReceiver.sol";
import {ISavingsXDaiAdapter} from "../interfaces/ISavingsXDaiAdapter.sol";
import {IWXDAI} from "../interfaces/IWXDAI.sol";
import {SavingsXDai} from "../SavingsXDai.sol";

/// @title SavingsXDaiAdapter
/// @notice See {ISavingsXDaiAdapter}.
contract SavingsXDaiAdapter is ISavingsXDaiAdapter {
    /*//////////////////////////////////////////////////////////////
                               IMMUTABLES
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc ISavingsXDaiAdapter
    IBridgeInterestReceiver public immutable interestReceiver;

    /// @inheritdoc ISavingsXDaiAdapter
    address public immutable sDAI;

    /// @dev Typed handle to {sDAI}; kept private because external readers can use {sDAI}.
    SavingsXDai private immutable _sDAI;

    /// @inheritdoc ISavingsXDaiAdapter
    IWXDAI public immutable wxdai = IWXDAI(0xe91D153E0b41518A2Ce8Dd3D7944Fa863463a97d);

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(address interestReceiver_, address payable sDAI_) {
        interestReceiver = IBridgeInterestReceiver(interestReceiver_);
        sDAI = sDAI_;
        _sDAI = SavingsXDai(sDAI_);
        wxdai.approve(sDAI_, type(uint256).max);
    }

    /*//////////////////////////////////////////////////////////////
                                MODIFIERS
    //////////////////////////////////////////////////////////////*/

    /// @dev Trigger an upstream {IBridgeInterestReceiver.claim} only when the call
    ///      originates from an EOA so depositors do not trade against stale assets;
    ///      contract callers are not blocked.
    modifier pullInterestIfEoa() {
        if (msg.sender.code.length == 0) {
            interestReceiver.claim();
        }
        _;
    }

    /*//////////////////////////////////////////////////////////////
                          MUTATIVE -- WXDAI PATH
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc ISavingsXDaiAdapter
    function deposit(uint256 assets, address receiver) public pullInterestIfEoa returns (uint256) {
        wxdai.transferFrom(msg.sender, address(this), assets);
        return _sDAI.deposit(assets, receiver);
    }

    /// @inheritdoc ISavingsXDaiAdapter
    function mint(uint256 shares, address receiver) public pullInterestIfEoa returns (uint256) {
        wxdai.transferFrom(msg.sender, address(this), _sDAI.convertToAssets(shares));
        return _sDAI.mint(shares, receiver);
    }

    /// @inheritdoc ISavingsXDaiAdapter
    function withdraw(uint256 assets, address receiver) public pullInterestIfEoa returns (uint256) {
        uint256 maxAssets = _sDAI.maxWithdraw(msg.sender);
        assets = (assets > maxAssets) ? maxAssets : assets;
        return _sDAI.withdraw(assets, receiver, msg.sender);
    }

    /// @inheritdoc ISavingsXDaiAdapter
    function redeem(uint256 shares, address receiver) public pullInterestIfEoa returns (uint256) {
        uint256 maxShares = _sDAI.maxRedeem(msg.sender);
        shares = (shares > maxShares) ? maxShares : shares;
        return _sDAI.redeem(shares, receiver, msg.sender);
    }

    /// @inheritdoc ISavingsXDaiAdapter
    function redeemAll(address receiver) public pullInterestIfEoa returns (uint256) {
        uint256 shares = _sDAI.balanceOf(msg.sender);
        return _sDAI.redeem(shares, receiver, msg.sender);
    }

    /*//////////////////////////////////////////////////////////////
                       MUTATIVE -- NATIVE xDAI PATH
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc ISavingsXDaiAdapter
    function depositXDAI(address receiver) public payable pullInterestIfEoa returns (uint256) {
        uint256 assets = msg.value;
        if (assets == 0) {
            return 0;
        }
        wxdai.deposit{value: assets}();
        return _sDAI.deposit(assets, receiver);
    }

    /// @inheritdoc ISavingsXDaiAdapter
    function withdrawXDAI(uint256 assets, address receiver) public payable returns (uint256) {
        if (assets == 0) {
            return 0;
        }
        uint256 maxAssets = _sDAI.maxWithdraw(msg.sender);
        assets = (assets > maxAssets) ? maxAssets : assets;
        uint256 shares = _sDAI.withdraw(assets, address(this), msg.sender);
        uint256 balance = wxdai.balanceOf(address(this));
        wxdai.withdraw(balance);
        _sendNative(receiver, balance);
        return shares;
    }

    /// @inheritdoc ISavingsXDaiAdapter
    function redeemXDAI(uint256 shares, address receiver) public payable returns (uint256) {
        uint256 assets = _sDAI.redeem(shares, address(this), msg.sender);
        wxdai.withdraw(assets);
        _sendNative(receiver, assets);
        return assets;
    }

    /// @inheritdoc ISavingsXDaiAdapter
    function redeemAllXDAI(address receiver) public payable returns (uint256) {
        uint256 shares = _sDAI.balanceOf(msg.sender);
        uint256 assets = _sDAI.redeem(shares, address(this), msg.sender);
        wxdai.withdraw(assets);
        _sendNative(receiver, assets);
        return assets;
    }

    /// @notice Auto-deposit native xDAI sent to this contract, except WXDAI unwrap refunds.
    receive() external payable {
        if (msg.sender != address(wxdai)) {
            depositXDAI(msg.sender);
        }
    }

    /*//////////////////////////////////////////////////////////////
                                  VIEW
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc ISavingsXDaiAdapter
    function vaultAPY() external view returns (uint256) {
        return interestReceiver.vaultAPY();
    }

    /*//////////////////////////////////////////////////////////////
                                INTERNAL
    //////////////////////////////////////////////////////////////*/

    /// @dev Forwards `amount` of native xDAI to `to` via `call` and reverts with
    ///      {XDaiSendFailed} on failure.
    function _sendNative(address to, uint256 amount) internal {
        (bool sent,) = to.call{value: amount}("");
        if (!sent) revert XDaiSendFailed();
    }
}
