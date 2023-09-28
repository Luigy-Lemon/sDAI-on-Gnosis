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
        setClaimerAndInitialize();
        vm.startPrank(initializer);
        vm.expectRevert(abi.encodeWithSignature("AlreadyInitialized()"));
        rcv.initialize();
    }

    function testInitialize_anyoneAllowed() external {
        vm.startPrank(alice);
        vm.deal(address(rcv), 50000 ether);
        rcv.initialize();
    }

    function testInitialize_notEnoughBalance() external {
        vm.startPrank(alice);
        vm.deal(address(rcv), 5000 ether);
        vm.expectRevert("Fill it up first");
        rcv.initialize();
    }
    /*//////////////////////////////////////////////////////////////
                        CLAIM LOGIC
    //////////////////////////////////////////////////////////////*/

    function claimEOA() public returns (uint256 claimed) {
        vm.startPrank(bob, bob);
        claimed = rcv.claim();
        vm.stopPrank();
    }

    function testClaim__FromAdapter() public {
        setClaimerAndInitialize();
        skipTime(1 hours);
        uint256 claimable = rcv.previewClaimable();
        vm.prank(bob,bob);
        adapter.depositXDAI{value: 1 ether}(bob);
        uint256 claimed = claimable - rcv.previewClaimable();
        assertEq(claimable, claimed);
        assertGt(claimed, 0);
    }

    function testClaim__FromContract() public {
        setClaimerAndInitialize();
        skipTime(1 hours);
        vm.expectRevert("Not valid Claimer");
        rcv.claim();
    }

    function testClaim() public {
        testTopInterestReceiver();
        setClaimerAndInitialize();
        uint256 shares = sDAI.totalSupply();
        uint256 totalWithdrawable = sDAI.previewRedeem(shares);
        skipTime(1 days);
        testTopInterestReceiver();
        uint256 sDAIBalance = wxdai.balanceOf(address(sDAI));
        uint256 rcvBalance = wxdai.balanceOf(address(rcv)) + address(rcv).balance;
        uint256 claimed = claimEOA();
        assertLe(sDAIBalance, sDAI.totalAssets());
        assertLe(wxdai.balanceOf(address(rcv)), rcvBalance);
        assertEq(sDAI.totalSupply(), shares);
        assertLe(totalWithdrawable, sDAI.previewRedeem(shares));
        assertGt(claimed, 0);
        console.log("Claimed %e", claimed);
    }

    function testFuzzClaim(uint256 time) public {
        setClaimerAndInitialize();
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
        uint256 claimed = claimEOA();

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
        claimed = claimEOA();
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

    function skipFirstEpoch() public {
        skipTime(rcv.nextClaimEpoch() + 1);
        claimEOA();
    }

    /*//////////////////////////////////////////////////////////////
                        CONDITIONAL CHECKS
    //////////////////////////////////////////////////////////////*/

    function testClaim_ifNotInitialized() external {
        vm.expectRevert("Not Initialized");
        claimEOA();
    }

    function testClaim_IncreasedFromZeroBalance() external {
        setClaimerAndInitialize();
        donateReceiverWXDAI();              
        skipFirstEpoch();
        skipTime(1 hours);
        assertEq(rcv.dripRate(), rcv.currentEpochBalance() / epoch);
        assertEq(rcv.nextClaimEpoch(), rcv.lastClaimTimestamp() + epoch);
        uint256 claimed = claimEOA();
        assertEq(claimed, rcv.dripRate() * 1 hours);
    }

    function testClaim_endOfEpochMinus1() external {
        setClaimerAndInitialize();
        donateReceiverWXDAI();              
        skipFirstEpoch();
        skipTime(epoch - 1);
        uint256 rate = rcv.dripRate();
        assertEq(rate, rcv.currentEpochBalance() / epoch);
        assertEq(rcv.nextClaimEpoch(), rcv.lastClaimTimestamp() + epoch);
        uint256 claimed = claimEOA();
        assertEq(claimed, rcv.dripRate() * (epoch - 1));
        assertEq(rcv.dripRate(), rate);
        assertEq(rcv.nextClaimEpoch(), block.timestamp + 1);
    }

    function testClaim_endOfEpoch() external {
        setClaimerAndInitialize();
        donateReceiverWXDAI();              
        skipFirstEpoch();
        skipTime(epoch);
        uint256 rate = rcv.dripRate();
        assertEq(rate, rcv.currentEpochBalance() / epoch);
        assertEq(rcv.nextClaimEpoch(), rcv.lastClaimTimestamp() + epoch);
        uint256 claimed = claimEOA();
        assertApproxEqAbs(claimed, rcv.dripRate() * epoch, 500000);
        assertEq(claimed, rcv.currentEpochBalance());
        assertEq(rcv.dripRate(), rate);
        assertEq(rcv.nextClaimEpoch(), block.timestamp);
    }

    function testClaim_endOfEpochPlus1ButNoDeposits() external {
        setClaimerAndInitialize();
        donateReceiverWXDAI();              
        skipFirstEpoch();
        skipTime(epoch + 1);
        uint256 rate = rcv.dripRate();
        assertEq(rate, rcv.currentEpochBalance() / epoch);
        assertEq(rcv.nextClaimEpoch(), rcv.lastClaimTimestamp() + epoch);
        uint256 claimed = claimEOA();
        assertEq(claimed, rcv.currentEpochBalance());
        assertEq(rcv.dripRate(), 0);
        assertEq(rcv.nextClaimEpoch(), block.timestamp - 1);
    }

    function testClaim_endOfEpochWithNewDeposits() external {
        setClaimerAndInitialize();
        donateReceiverWXDAI();              
        skipFirstEpoch();
        skipTime(epoch / 2);
        donateReceiverWXDAI();
        skipTime(epoch / 2);
        uint256 rate = rcv.dripRate();
        assertEq(rate, rcv.currentEpochBalance() / epoch);
        assertEq(rcv.nextClaimEpoch(), rcv.lastClaimTimestamp() + epoch);
        uint256 claimed = claimEOA();
        assertApproxEqAbs(claimed, rcv.dripRate() * epoch, 500000);
        assertEq(claimed, rcv.currentEpochBalance());
        assertEq(rcv.dripRate(), rate);
        assertEq(rcv.nextClaimEpoch(), block.timestamp);
    }

    function testClaim_pastEndOfEpochWithNewDeposits() external {
        setClaimerAndInitialize();
        donateReceiverWXDAI();              
        skipFirstEpoch();
        skipTime(epoch / 2);
        donateReceiverWXDAI();
        donateReceiverWXDAI();
        uint256 rate = rcv.dripRate();
        uint256 balance = rcv.currentEpochBalance();
        assertEq(rate, balance / epoch);
        assertEq(rcv.nextClaimEpoch(), rcv.lastClaimTimestamp() + epoch);
        uint256 claimed = claimEOA();
        assertApproxEqAbs(claimed, rcv.dripRate() * (epoch / 2), 500000);
        skipTime(epoch);
        uint256 balance1 = rcv.currentEpochBalance();
        uint256 claimed1 = claimEOA();
        assertEq(claimed1, balance1);
        assertEq(claimed1, balance - claimed);
        assertEq(rcv.dripRate(), rcv.currentEpochBalance() / epoch);
        assertEq(rcv.nextClaimEpoch(), block.timestamp + epoch);
    }
}
