// SPDX-License-Identifier: agpl-3
pragma solidity ^0.8.18;

import "openzeppelin/token/ERC20/extensions/ERC4626.sol";
import "./interfaces/IBridgeInterestReceiver.sol";

contract GnosisSavingsDAI is ERC4626{

    IBridgeInterestReceiver immutable public interestReceiver;

    /**
     * @dev Set the underlying asset contract. This must be an ERC20-compatible contract (ERC20 or ERC777).
     */
    constructor(address interestReceiver_) ERC20("Savings DAI on Gnosis", "sDAI") ERC4626(IERC20(0xe91D153E0b41518A2Ce8Dd3D7944Fa863463a97d)) {
        interestReceiver = IBridgeInterestReceiver(interestReceiver_);
    }

    function deposit(uint256 assets, address receiver) public virtual override returns (uint256) {
        interestReceiver.claim();
        return this.deposit(assets, receiver);
    }

    function mint(uint256 shares, address receiver) public virtual override returns (uint256) {
        interestReceiver.claim();
        return this.mint(shares, receiver);
    }

}
