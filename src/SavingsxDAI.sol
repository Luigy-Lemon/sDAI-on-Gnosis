// SPDX-License-Identifier: agpl-3
pragma solidity ^0.8.18;

import "openzeppelin/token/ERC20/extensions/ERC4626.sol";

contract SavingsxDAI is ERC4626{

    address immutable public interestStreamer;

    /**
     * @dev Set the underlying asset contract. This must be an ERC20-compatible contract (ERC20 or ERC777).
     */
    constructor(address interestStreamer_) ERC20("Savings xDAI", "sxDAI") ERC4626(IERC20(0xe91D153E0b41518A2Ce8Dd3D7944Fa863463a97d)) {
        interestStreamer = interestStreamer_;
    }


}
