// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "./Setup.t.sol";

contract BridgeInterestReceiverTest is SetupTest {
    /*//////////////////////////////////////////////////////////////
                        BASIC VALIDATION
    //////////////////////////////////////////////////////////////*/
    function testMetadata() public {
        assertEq(address(rcv), address(rcv));
        assertEq(address(sDAI.wxdai()), address(wxdai));
    }

    function testAlreadyInitialized() public {
        testInitialize();
        vm.startPrank(initializer);
        vm.expectRevert(abi.encodeWithSignature("AlreadyInitialized()"));
        rcv.initialize();
    }

    /*//////////////////////////////////////////////////////////////
                        UNIT TESTS
    //////////////////////////////////////////////////////////////*/
    function testInitialize_anyoneAllowed() external {
        vm.startPrank(alice);
        rcv.initialize();
    }
    /*//////////////////////////////////////////////////////////////
                        CLAIM LOGIC
    //////////////////////////////////////////////////////////////*/

    function testClaim() public {
        testTopInterestReceiver();
        testInitialize();
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
        testInitialize();
        time = bound(time, 0, 2 days);
        require(time >= 0 && time <= 2 days);
        console.log("GlobalTime: %s | Time: %s | CurrentTime: %s", globalTime, time, block.timestamp);
        console.log(
            "nextClaimEpoch: %s | lastClaimTimestamp: %s | dripRate: %s",
            rcv.nextClaimEpoch(),
            rcv.lastClaimTimestamp(),
            rcv.dripRate()
        );

        uint256 shares = sDAI.totalSupply();
        uint256 totalWithdrawable = sDAI.previewRedeem(shares);
        testTopInterestReceiver();
        uint256 sDAIBalance = wxdai.balanceOf(address(sDAI));
        uint256 rcvBalance = wxdai.balanceOf(address(rcv)) + address(rcv).balance;

        uint256 endEpoch = rcv.nextClaimEpoch();
        uint256 lastClaimTime = rcv.lastClaimTimestamp();
        uint256 beforeRate = rcv.dripRate();

        skipTime(time); //skip time
        uint256 claimable = rcv.previewClaimable();
        uint256 epochBalance = rcv.currentEpochBalance();
        uint256 claimed = rcv.claim();

        console.log("GlobalTime: %s | Time: %s | CurrentTime: %s", globalTime, time, block.timestamp);
        console.log(
            "nextClaimEpoch: %s | lastClaimTimestamp: %s | dripRate: %s",
            rcv.nextClaimEpoch(),
            rcv.lastClaimTimestamp(),
            rcv.dripRate()
        );

        if (globalTime == lastClaimTime) {
            assertEq(claimed, 0);
            assertGe(wxdai.balanceOf(address(rcv)) + address(rcv).balance, rcvBalance);
        } else if (globalTime >= lastClaimTime + epoch) {
            assertEq(claimed, epochBalance);
            if (rcvBalance - claimable >= epoch && globalTime != endEpoch) {
                assertEq(rcv.nextClaimEpoch(), block.timestamp + epoch);
                assertGt(rcv.dripRate(), 0);
            }
            assertEq(claimable, claimed);
            assertLe(wxdai.balanceOf(address(rcv)), rcvBalance);
        } else if (globalTime > endEpoch) {
            if (beforeRate > 0) {
                assertGt(claimed, 0);
            }

            if (rcvBalance - claimable >= epoch) {
                assertEq(rcv.nextClaimEpoch(), block.timestamp + epoch);
                assertGt(rcv.dripRate(), 0);
            }
            assertEq(claimable, claimed);
            assertLe(wxdai.balanceOf(address(rcv)), rcvBalance);
        } else {
            assertEq(epochBalance - claimed, rcv.currentEpochBalance());
            assertEq(claimable, claimed);
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
        endEpoch = rcv.nextClaimEpoch();
        lastClaimTime = rcv.lastClaimTimestamp();
        beforeRate = rcv.dripRate();
        rcvBalance = wxdai.balanceOf(address(rcv)) + address(rcv).balance;
        console.log("rcvBalance: %s ", rcvBalance);
        skipTime(time); //skip time
        claimable = rcv.previewClaimable();
        epochBalance = rcv.currentEpochBalance();
        claimed = rcv.claim();
        console.log("GlobalTime: %s | Time: %s | CurrentTime: %s", globalTime, time, block.timestamp);
        console.log(
            "nextClaimEpoch: %s | lastClaimTimestamp: %s | dripRate: %s",
            rcv.nextClaimEpoch(),
            rcv.lastClaimTimestamp(),
            rcv.dripRate()
        );
        if (globalTime == lastClaimTime) {
            assertEq(claimed, 0);
            assertGe(wxdai.balanceOf(address(rcv)) + address(rcv).balance, rcvBalance);
        } else if (globalTime >= lastClaimTime + epoch) {
            assertEq(claimed, epochBalance);
            if (rcvBalance - claimable >= epoch && globalTime != endEpoch) {
                assertEq(rcv.nextClaimEpoch(), block.timestamp + epoch);
                assertGt(rcv.dripRate(), 0);
            }
            assertEq(claimable, claimed);
            assertLe(wxdai.balanceOf(address(rcv)), rcvBalance);
        } else if (globalTime > endEpoch) {
            if (beforeRate > 0) {
                assertGt(claimed, 0);
            }

            if (rcvBalance - claimable >= epoch) {
                assertEq(rcv.nextClaimEpoch(), block.timestamp + epoch);
                assertGt(rcv.dripRate(), 0);
            }
            assertEq(claimable, claimed);
            assertLe(wxdai.balanceOf(address(rcv)), rcvBalance);
        } else {
            assertEq(epochBalance - claimed, rcv.currentEpochBalance());
            assertEq(claimable, claimed);
            assertLe(wxdai.balanceOf(address(rcv)), rcvBalance);
        }
    }

    /*//////////////////////////////////////////////////////////////
                        CONDITIONAL CHECKS
    //////////////////////////////////////////////////////////////*/

    function testClaim_ifNotInitialized() external {
        vm.expectRevert("Not Initialized");
        rcv.claim();
    }

    function testClaim_ifInitializedWithoutBalance() external {
        testInitialize();
        uint256 claimed = rcv.claim();
        assertEq(claimed, 0);
        assertEq(rcv.dripRate(), 0);
        assertEq(rcv.nextClaimEpoch(), block.timestamp + epoch);
    }

    function testClaim_IncreasedFromZeroBalance() external {
        donateReceiverWXDAI();
        testInitialize();
        skipTime(1 hours);
        assertEq(rcv.dripRate(), rcv.currentEpochBalance() / epoch);
        assertEq(rcv.nextClaimEpoch(), rcv.lastClaimTimestamp() + epoch);
        uint256 claimed = rcv.claim();
        assertEq(claimed, rcv.dripRate() * 1 hours);
    }

    function testClaim_endOfEpochMinus1() external {
        donateReceiverWXDAI();
        testInitialize();
        skipTime(epoch - 1);
        uint256 rate = rcv.dripRate();
        assertEq(rate, rcv.currentEpochBalance() / epoch);
        assertEq(rcv.nextClaimEpoch(), rcv.lastClaimTimestamp() + epoch);
        uint256 claimed = rcv.claim();
        assertEq(claimed, rcv.dripRate() * (epoch - 1));
        assertEq(rcv.dripRate(), rate);
        assertEq(rcv.nextClaimEpoch(), block.timestamp + 1);
    }

    function testClaim_endOfEpoch() external {
        donateReceiverWXDAI();
        testInitialize();
        skipTime(epoch);
        uint256 rate = rcv.dripRate();
        assertEq(rate, rcv.currentEpochBalance() / epoch);
        assertEq(rcv.nextClaimEpoch(), rcv.lastClaimTimestamp() + epoch);
        uint256 claimed = rcv.claim();
        assertApproxEqAbs(claimed, rcv.dripRate() * epoch, 100000);
        assertEq(claimed, rcv.currentEpochBalance());
        assertEq(rcv.dripRate(), rate);
        assertEq(rcv.nextClaimEpoch(), block.timestamp);
    }

    function testClaim_endOfEpochPlus1ButNoDeposits() external {
        donateReceiverWXDAI();
        testInitialize();
        skipTime(epoch + 1);
        uint256 rate = rcv.dripRate();
        assertEq(rate, rcv.currentEpochBalance() / epoch);
        assertEq(rcv.nextClaimEpoch(), rcv.lastClaimTimestamp() + epoch);
        uint256 claimed = rcv.claim();
        assertEq(claimed, rcv.currentEpochBalance());
        assertEq(rcv.dripRate(), 0);
        assertEq(rcv.nextClaimEpoch(), block.timestamp - 1);
    }

    function testClaim_endOfEpochWithNewDeposits() external {
        donateReceiverWXDAI();
        testInitialize();
        skipTime(epoch / 2);
        donateReceiverWXDAI();
        skipTime(epoch / 2);
        uint256 rate = rcv.dripRate();
        assertEq(rate, rcv.currentEpochBalance() / epoch);
        assertEq(rcv.nextClaimEpoch(), rcv.lastClaimTimestamp() + epoch);
        uint256 claimed = rcv.claim();
        assertApproxEqAbs(claimed, rcv.dripRate() * epoch, 100000);
        assertEq(claimed, rcv.currentEpochBalance());
        assertEq(rcv.dripRate(), rate);
        assertEq(rcv.nextClaimEpoch(), block.timestamp);
    }

    function testClaim_pastEndOfEpochWithNewDeposits() external {
        donateReceiverWXDAI();
        testInitialize();
        skipTime(epoch / 2);
        donateReceiverWXDAI();
        donateReceiverWXDAI();
        uint256 rate = rcv.dripRate();
        uint256 balance = rcv.currentEpochBalance();
        assertEq(rate, balance / epoch);
        assertEq(rcv.nextClaimEpoch(), rcv.lastClaimTimestamp() + epoch);
        uint256 claimed = rcv.claim();
        assertApproxEqAbs(claimed, rcv.dripRate() * (epoch / 2), 100000);
        skipTime(epoch);
        uint256 claimed1 = rcv.claim();
        assertApproxEqAbs(claimed1, rate * (epoch / 2), 100000);
        assertEq(claimed1, balance - claimed);
        assertEq(rcv.dripRate(), rcv.currentEpochBalance() / epoch);
        assertEq(rcv.nextClaimEpoch(), block.timestamp + epoch);
    }
}
