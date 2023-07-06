// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import 'forge-std/console.sol';

import "./Setup.t.sol";

contract BridgeInterestReceiverTest is SetupTest {
    function invariantMetadata() public {
        assertEq(address(sDAI.interestReceiver()), address(interestReceiver));
        assertEq(address(sDAI.wxdai()), address(wxdai));
        assertEq(alice, address(10));
        assertEq(bob, address(11));
    }

    /*//////////////////////////////////////////////////////////////
                        MODIFIED LOGIC
    //////////////////////////////////////////////////////////////*/

}
