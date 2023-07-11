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
                        CLAIM LOGIC
    //////////////////////////////////////////////////////////////*/


    function testClaim() public {
        uint256 shares = sDAI.totalSupply();
        uint256 totalWithdrawable = sDAI.previewRedeem(shares);
        testDonateWXDAI();
        uint256 sDAIBalance = wxdai.balanceOf(address(sDAI));
        uint256 interestReceiverBalance = wxdai.balanceOf(address(interestReceiver));

        interestReceiver.claim();

        assertLe(sDAIBalance, sDAI.totalAssets());
        assertLe(interestReceiverBalance, wxdai.balanceOf(address(interestReceiver)));
        assertEq(sDAI.totalSupply(), shares);
        assertLt(totalWithdrawable, sDAI.previewRedeem(shares));
    }

}
