// SPDX-License-Identifier: agpl-3
pragma solidity ^0.8.18;

import "openzeppelin/token/ERC20/extensions/ERC4626.sol";
import "./interfaces/IBridgeInterestReceiver.sol";
import {IWXDAI} from "./interfaces/IWXDAI.sol";

contract GnosisSavingsDAI is ERC4626{

    IBridgeInterestReceiver immutable public interestReceiver;
    IWXDAI public immutable wxdai = IWXDAI(0xe91D153E0b41518A2Ce8Dd3D7944Fa863463a97d);

    /**
     * @dev Set the underlying asset contract. This must be an ERC20-compatible contract (ERC20 or ERC777).
     */
    constructor(address interestReceiver_) ERC20("Savings DAI on Gnosis", "sDAI") ERC4626(IERC20(address(wxdai))) {
        interestReceiver = IBridgeInterestReceiver(interestReceiver_);
    }

    function deposit(uint256 assets, address receiver) public override returns (uint256) {
        require(assets <= maxDeposit(receiver), "ERC4626: deposit more than max");
        interestReceiver.claim();
        uint256 shares = previewDeposit(assets);
        _deposit(_msgSender(), receiver, assets, shares);
        return shares;
    }

    function mint(uint256 shares, address receiver) public virtual override returns (uint256) {
        require(shares <= maxMint(receiver), "ERC4626: mint more than max");
        interestReceiver.claim();

        uint256 assets = previewMint(shares);
        _deposit(_msgSender(), receiver, assets, shares);

        return assets;
    }

    function withdraw(uint256 assets, address receiver, address owner) public virtual override returns (uint256) {
        require(assets <= maxWithdraw(owner), "ERC4626: withdraw more than max");
        interestReceiver.claim();

        uint256 shares = previewWithdraw(assets);
        _withdraw(_msgSender(), receiver, owner, assets, shares);

        return shares;
    }

    function redeem(uint256 shares, address receiver, address owner) public virtual override returns (uint256) {
        require(shares <= maxRedeem(owner), "ERC4626: redeem more than max");
        interestReceiver.claim();

        uint256 assets = previewRedeem(shares);
        _withdraw(_msgSender(), receiver, owner, assets, shares);

        return assets;
    }

    function depositXDAI(address receiver) public virtual payable returns (uint256) {
        uint256 assets = msg.value;
        interestReceiver.claim();
        uint256 shares = previewDeposit(assets);
        wxdai.deposit{value:assets}();
        _deposit(address(this), receiver, assets, shares);
        return shares;
    }

    function withdrawXDAI(uint256 assets, address receiver, address owner) public virtual payable returns (uint256) {
        interestReceiver.claim();
        uint256 shares = withdraw(assets, address(this), owner);
        wxdai.withdraw(assets);
        (bool sent, ) = receiver.call{value: assets}("");
        require(sent, "Failed to send Ether");
        return shares;
    }

}
