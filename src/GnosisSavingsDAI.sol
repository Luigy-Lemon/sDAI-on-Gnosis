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

    function deposit(uint256 assets, address receiver) public virtual override returns (uint256) {
        interestReceiver.claim();
        return this.deposit(assets, receiver);
    }

    function depositXDAI(uint256 assets, address receiver) public virtual payable returns (uint256) {
        interestReceiver.claim();
        wxdai.deposit{value:msg.value}();
        return this.deposit(assets, receiver);
    }

    function mint(uint256 shares, address receiver) public virtual override returns (uint256) {
        interestReceiver.claim();
        return this.mint(shares, receiver);
    }

    function withdrawXDAI(uint256 assets, address receiver, address owner) public virtual payable returns (uint256) {
        uint256 shares = this.withdraw(assets, address(this), owner);
        wxdai.withdraw(assets);
        (bool sent, ) = receiver.call{value: msg.value}("");
        require(sent, "Failed to send Ether");
        return shares;
    }
}
