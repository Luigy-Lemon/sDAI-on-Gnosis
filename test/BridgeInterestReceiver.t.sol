// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "./Setup.t.sol";

contract BridgeInterestReceiverTest is SetupTest {
    function testMetadata() public {
        assertEq(address(rcv), address(rcv));
        assertEq(address(sDAI.wxdai()), address(wxdai));
    }

    /*//////////////////////////////////////////////////////////////
                        CLAIM LOGIC
    //////////////////////////////////////////////////////////////*/

    function testClaim() public {
        uint256 shares = sDAI.totalSupply();
        uint256 totalWithdrawable = sDAI.previewRedeem(shares);
        skipTime(1 days);
        testTopInterestReceiver();
        uint256 sDAIBalance = wxdai.balanceOf(address(sDAI));
        uint256 rcvBalance = wxdai.balanceOf(address(rcv)) + address(rcv).balance;

        uint256 claimed = rcv.claim();

        assertLe(sDAIBalance, sDAI.totalAssets());
        assertLe(wxdai.balanceOf(address(rcv)), rcvBalance);
        assertEq(sDAI.totalSupply(), shares);
        assertLe(totalWithdrawable, sDAI.previewRedeem(shares));
        assertGt(claimed, 0);
        console.log("Claimed %e", claimed);
    }

    function testFuzzClaim(uint256 time) public {
        time = bound(time, 0, 2 days);
        require(time >= 0 && time <= 2 days);
        console.log("GlobalTime: %s | Time: %s | CurrentTime: %s", globalTime, time, block.timestamp);
        console.log(
            "_nextClaimEpoch: %s | _lastClaimTimestamp: %s | dripRate: %s",
            rcv._nextClaimEpoch(),
            rcv._lastClaimTimestamp(),
            rcv.dripRate()
        );

        uint256 shares = sDAI.totalSupply();
        uint256 totalWithdrawable = sDAI.previewRedeem(shares);
        testTopInterestReceiver();
        uint256 sDAIBalance = wxdai.balanceOf(address(sDAI));
        uint256 rcvBalance = wxdai.balanceOf(address(rcv)) + address(rcv).balance;

        uint256 endEpoch = rcv._nextClaimEpoch();
        uint256 lastClaimTime = rcv._lastClaimTimestamp();
        uint256 beforeRate = rcv.dripRate();

        skipTime(time); //skip time
        uint256 claimable = rcv.previewClaimable(rcvBalance);
        uint256 claimed = rcv.claim();

        console.log("GlobalTime: %s | Time: %s | CurrentTime: %s", globalTime, time, block.timestamp);
        console.log(
            "_nextClaimEpoch: %s | _lastClaimTimestamp: %s | dripRate: %s",
            rcv._nextClaimEpoch(),
            rcv._lastClaimTimestamp(),
            rcv.dripRate()
        );

        if (globalTime == lastClaimTime) {
            assertEq(claimed, 0);
            assertGe(wxdai.balanceOf(address(rcv)) + address(rcv).balance, rcvBalance);
        } else if (globalTime >= lastClaimTime + rcv.epochLength()) {
            assertEq(claimed, rcvBalance);
            if (rcv.dripRate() > 0) {
                assertEq(rcv._nextClaimEpoch(), rcv._lastClaimTimestamp() + rcv.epochLength());
            }
            assertEq(claimable, claimed);
            assertEq(address(rcv).balance, 0);
            assertLe(wxdai.balanceOf(address(rcv)), rcvBalance);
        } else {
            if (beforeRate > 0) {
                assertGt(claimed, 0);
            }
            assertEq(address(rcv).balance, 0);
            assertEq(claimable, claimed);
            assertLe(endEpoch, rcv._lastClaimTimestamp() + rcv.epochLength());
            assertLe(wxdai.balanceOf(address(rcv)), rcvBalance);
        }

        assertEq(wxdai.balanceOf(address(rcv)) + address(rcv).balance, rcvBalance - claimed);
        assertEq(claimed, wxdai.balanceOf(address(sDAI)) - sDAIBalance);
        assertEq(sDAI.totalSupply(), shares);
        assertLe(sDAIBalance, sDAI.totalAssets());
        assertEq(sDAI.totalSupply(), shares);
        assertLe(totalWithdrawable, sDAI.previewRedeem(shares));

        vm.startPrank(bob);
        wxdai.transfer(address(rcv), 10e18);
        endEpoch = rcv._nextClaimEpoch();
        lastClaimTime = rcv._lastClaimTimestamp();
        beforeRate = rcv.dripRate();
        rcvBalance = wxdai.balanceOf(address(rcv)) + address(rcv).balance;

        skipTime(time); //skip time
        claimable = rcv.previewClaimable(rcvBalance);
        claimed = rcv.claim();
        console.log("GlobalTime: %s | Time: %s | CurrentTime: %s", globalTime, time, block.timestamp);
        console.log(
            "_nextClaimEpoch: %s | _lastClaimTimestamp: %s | dripRate: %s",
            rcv._nextClaimEpoch(),
            rcv._lastClaimTimestamp(),
            rcv.dripRate()
        );

        if (globalTime == lastClaimTime) {
            assertEq(claimed, 0);
            assertGe(wxdai.balanceOf(address(rcv)) + address(rcv).balance, rcvBalance);
        } else if (globalTime >= lastClaimTime + rcv.epochLength()) {
            assertEq(claimed, rcvBalance);
            if (rcv.dripRate() > 0) {
                assertEq(rcv._nextClaimEpoch(), rcv._lastClaimTimestamp() + rcv.epochLength());
            }
            assertEq(claimable, claimed);
            assertEq(address(rcv).balance, 0);
            assertLe(wxdai.balanceOf(address(rcv)), rcvBalance);
        } else {
            if (beforeRate > 0) {
                assertGt(claimed, 0);
            }
            assertEq(address(rcv).balance, 0);
            assertEq(claimable, claimed);
            assertLe(endEpoch, rcv._lastClaimTimestamp() + rcv.epochLength());
            assertLe(wxdai.balanceOf(address(rcv)), rcvBalance);
        }
    }
}
