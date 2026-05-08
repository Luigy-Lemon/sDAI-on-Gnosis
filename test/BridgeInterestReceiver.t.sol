// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "./Setup.t.sol";
import {IBridgeInterestReceiver} from "src/interfaces/IBridgeInterestReceiver.sol";

contract BridgeInterestReceiverTest is SetupTest {
    /*//////////////////////////////////////////////////////////////
                        BASIC VALIDATION
    //////////////////////////////////////////////////////////////*/
    function testMetadata() public view {
        assertEq(rcv.vault(), address(sDAI));
        assertEq(address(sDAI.wxdai()), address(wxdai));
    }

    /// @dev Shared branch assertions for `testFuzzClaim` (two identical claim phases).
    function _assertFuzzClaimPhase(
        uint256 lastClaimTime,
        uint256 endEpoch,
        uint256 beforeRate,
        uint256 rcvBalance,
        uint256 claimable,
        uint256 epochBalance,
        uint256 claimed
    ) internal view {
        uint256 e = epoch;
        if (globalTime == lastClaimTime) {
            assertEq(claimed, 0);
            assertGe(wxdai.balanceOf(address(rcv)) + address(rcv).balance, rcvBalance);
        } else if (globalTime >= lastClaimTime + e) {
            assertEq(claimed, epochBalance);
            if (rcvBalance - claimable >= e && globalTime != endEpoch) {
                assertEq(rcv.nextClaimEpoch(), block.timestamp + e);
                assertGt(rcv.dripRate(), 0);
            }
            assertEq(claimable, claimed);
            assertLe(wxdai.balanceOf(address(rcv)), rcvBalance);
        } else if (globalTime > endEpoch) {
            if (beforeRate > 0) {
                assertGt(claimed, 0);
            }

            if (rcvBalance - claimable >= e) {
                assertEq(rcv.nextClaimEpoch(), block.timestamp + e);
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

    function testAlreadyInitialized() public {
        setClaimerAndInitialize();
        vm.startPrank(initializer);
        vm.expectRevert(abi.encodeWithSignature("InvalidInitialization()"));
        rcv.initialize(address(adapter));
    }

    /// @dev `initialize` is gated on the constructor-set claimer to prevent a front-runner
    ///      from hijacking the operational claimer once the funding threshold is reached.
    function testInitialize_onlyDeployer() external {
        vm.deal(address(rcv), 50000 ether);
        vm.prank(alice);
        vm.expectRevert(IBridgeInterestReceiver.InvalidSender.selector);
        rcv.initialize(address(adapter));

        // Deployer can.
        vm.prank(initializer);
        rcv.initialize(address(adapter));
        assertEq(rcv.claimer(), address(adapter));
    }

    function testInitialize_rejectsZeroClaimer() external {
        vm.deal(address(rcv), 50000 ether);
        vm.prank(initializer);
        vm.expectRevert(IBridgeInterestReceiver.InvalidClaimer.selector);
        rcv.initialize(address(0));
    }

    function testInitialize_notEnoughBalance() external {
        vm.startPrank(initializer);
        vm.expectRevert(
            abi.encodeWithSelector(
                IBridgeInterestReceiver.InsufficientInitialBalance.selector,
                0,
                rcv.MIN_INITIAL_BALANCE()
            )
        );
        rcv.initialize(address(adapter));
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
        vm.expectRevert(IBridgeInterestReceiver.InvalidSender.selector);
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
    }

    function testFuzzClaim(uint256 time) public {
        setClaimerAndInitialize();
        time = bound(time, 0, 2 days);

        uint256 shares = sDAI.totalSupply();
        uint256 totalWithdrawable = sDAI.previewRedeem(shares);
        testTopInterestReceiver();
        uint256 sDAIBalance = wxdai.balanceOf(address(sDAI));
        uint256 rcvBalance = wxdai.balanceOf(address(rcv)) + address(rcv).balance;

        uint256 endEpoch = rcv.nextClaimEpoch();
        uint256 lastClaimTime = rcv.lastClaimTimestamp();
        uint256 beforeRate = rcv.dripRate();

        skipTime(time);
        uint256 claimable = rcv.previewClaimable();
        uint256 epochBalance = rcv.currentEpochBalance();
        uint256 claimed = claimEOA();

        _assertFuzzClaimPhase(lastClaimTime, endEpoch, beforeRate, rcvBalance, claimable, epochBalance, claimed);

        assertEq(wxdai.balanceOf(address(rcv)) + address(rcv).balance, rcvBalance - claimed);
        assertEq(claimed, wxdai.balanceOf(address(sDAI)) - sDAIBalance);
        assertEq(sDAI.totalSupply(), shares);
        assertLe(sDAIBalance, sDAI.totalAssets());
        assertLe(totalWithdrawable, sDAI.previewRedeem(shares));

        vm.startPrank(bob);
        wxdai.transfer(address(rcv), 10e18);
        endEpoch = rcv.nextClaimEpoch();
        lastClaimTime = rcv.lastClaimTimestamp();
        beforeRate = rcv.dripRate();
        rcvBalance = wxdai.balanceOf(address(rcv)) + address(rcv).balance;
        skipTime(time);
        claimable = rcv.previewClaimable();
        epochBalance = rcv.currentEpochBalance();
        claimed = claimEOA();
        _assertFuzzClaimPhase(lastClaimTime, endEpoch, beforeRate, rcvBalance, claimable, epochBalance, claimed);
    }

    function skipFirstEpoch() public {
        skipTime(rcv.nextClaimEpoch() + 1);
        claimEOA();
    }

    /*//////////////////////////////////////////////////////////////
                        CONDITIONAL CHECKS
    //////////////////////////////////////////////////////////////*/

    function testClaim_ifNotInitialized() external {
        vm.expectRevert(IBridgeInterestReceiver.NotInitialized.selector);
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
        uint256 epochBalanceBefore = rcv.currentEpochBalance();
        uint256 claimed = claimEOA();
        // Pause branch: post-claim balance below threshold → zero drip, rewritten epoch balance,
        // and nextClaimEpoch still advances (regression for stale balance bricking later claims).
        assertEq(claimed, epochBalanceBefore);
        assertEq(rcv.dripRate(), 0);
        assertEq(rcv.currentEpochBalance(), 0, "epoch balance must be rewritten on pause");
        assertEq(rcv.nextClaimEpoch(), block.timestamp + epoch, "nextClaimEpoch must always advance on rollover");
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

    /*//////////////////////////////////////////////////////////////
                        vaultAPY
    //////////////////////////////////////////////////////////////*/

    function testVaultAPY() public {
        setClaimerAndInitialize();
        // Deposit into sDAI so totalAssets() > 0
        vm.startPrank(alice);
        wxdai.approve(address(sDAI), 1e18);
        sDAI.deposit(1e18, alice);
        vm.stopPrank();

        uint256 deposits = sDAI.totalAssets();
        assertGt(deposits, 0);

        uint256 expectedAPY = (1e18 * rcv.dripRate() * 365 days) / deposits;
        uint256 actualAPY = rcv.vaultAPY();
        assertEq(actualAPY, expectedAPY);
        assertGt(actualAPY, 0);
    }

    function testVaultAPY_ZeroDeposits() public view {
        // Fresh sDAI has no deposits, totalAssets() == 0.
        // vaultAPY() now returns 0 instead of reverting on division by zero,
        // so view-only consumers (UIs, indexers) don't crash on a fresh deploy.
        assertEq(rcv.vaultAPY(), 0);
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

    /*//////////////////////////////////////////////////////////////
                CLAIMABLE EXCEEDS EPOCH BALANCE GUARD
    //////////////////////////////////////////////////////////////*/

    /// @dev Exercises the `claimable = currentEpochBalance` cap inside `_computeClaimable`
    ///      when `unclaimedTime * dripRate > currentEpochBalance`. After the cap, the
    ///      subsequent `currentEpochBalance -= claimable` in `_settleClaim` zeroes out
    ///      the epoch balance.
    function testClaim_ClaimableExceedsEpochBalance() external {
        setClaimerAndInitialize();
        donateReceiverWXDAI();
        skipFirstEpoch();

        uint256 rate = rcv.dripRate();
        assertGt(rate, 0);

        // Storage layout (post-immutables): slot 0 = claimer, 1 = dripRate, 2 = nextClaimEpoch,
        // 3 = currentEpochBalance, 4 = lastClaimTimestamp. Force currentEpochBalance to a
        // value smaller than dripRate * unclaimedTime to drive the cap branch.
        uint256 tinyBalance = 1e15;
        vm.store(address(rcv), bytes32(uint256(3)), bytes32(tinyBalance));

        // Stay within the epoch to take the partial-epoch path (unclaimedTime < EPOCH_LENGTH).
        uint256 lastClaim = rcv.lastClaimTimestamp();
        uint256 nextEpoch = rcv.nextClaimEpoch();
        uint256 timeToSkip = 1 hours;
        require(lastClaim + timeToSkip < nextEpoch, "must stay within epoch");
        skipTime(timeToSkip);

        // Verify the guard condition: rate * time > tinyBalance
        uint256 uncapped = rate * timeToSkip;
        assertGt(uncapped, tinyBalance, "rate*time must exceed tinyBalance for guard to trigger");

        // previewClaimable already includes the cap, so it returns tinyBalance (the guard output)
        uint256 previewed = rcv.previewClaimable();
        assertEq(previewed, tinyBalance, "preview should return capped value");

        // Execute claim -- _computeClaimable caps claimable to tinyBalance, then _settleClaim
        // subtracts it and currentEpochBalance ends up at zero.
        uint256 claimed = claimEOA();
        assertEq(claimed, tinyBalance, "claimed should equal the capped currentEpochBalance");
        assertEq(rcv.currentEpochBalance(), 0, "currentEpochBalance should be zeroed after settle");
    }

    /*//////////////////////////////////////////////////////////////
                PAUSE-AND-RESUME REGRESSION (drip trap fix)
    //////////////////////////////////////////////////////////////*/

    /// @dev Regression for the pre-fix "drip trap": when a rollover hit the pause threshold,
    ///      `currentEpochBalance` and `nextClaimEpoch` were left stale, which bricked the next
    ///      claim because `_computeClaimable` would return more than the contract actually held.
    ///      With the fix in place, the receiver self-heals: a top-up above the threshold
    ///      followed by a post-epoch claim must restart the drip.
    function testClaim_PauseThenResume() external {
        setClaimerAndInitialize();
        donateReceiverWXDAI(); // adds 3000 ether (above threshold but < 30k init buffer)
        skipFirstEpoch();      // claims the bootstrap epoch; receiver now holds ~3000 ether

        // Step 1: drain into the pause state.
        skipTime(epoch + 1);
        claimEOA();
        assertEq(rcv.dripRate(), 0, "drip should be paused");
        assertEq(rcv.currentEpochBalance(), 0, "epoch balance should be rewritten to 0");
        uint256 pausedNextEpoch = rcv.nextClaimEpoch();
        assertEq(pausedNextEpoch, block.timestamp + epoch, "nextClaimEpoch must advance even when paused");

        // Step 2: top up above threshold while still inside the (advanced) epoch window.
        donateReceiverWXDAI(); // 3000 ether > DRIP_PAUSE_THRESHOLD
        // A claim *within* the epoch must NOT revert and must NOT transfer (drip rate is 0).
        uint256 vaultBalanceBefore = wxdai.balanceOf(address(sDAI));
        uint256 claimedWithinEpoch = claimEOA();
        assertEq(claimedWithinEpoch, 0, "no drip while paused mid-epoch");
        assertEq(wxdai.balanceOf(address(sDAI)), vaultBalanceBefore, "no transfer while paused mid-epoch");

        // Step 3: cross the next epoch boundary -- the rollover branch should resume the drip.
        // Note: rollover predicate is strict (`block.timestamp > nextClaimEpoch`), so +1 is required.
        skipTime(epoch + 1);
        claimEOA();
        assertGt(rcv.dripRate(), 0, "drip should resume after top-up + epoch rollover");
        assertGt(rcv.currentEpochBalance(), 0, "new epoch balance should be set");
        assertEq(rcv.nextClaimEpoch(), block.timestamp + epoch, "nextClaimEpoch reset to fresh window");
    }

    /// @dev Pre-fix this would have reverted on `wxdai.transfer` because the stale
    ///      `currentEpochBalance` (e.g. 3000 ether) exceeded the contract's actual balance.
    function testClaim_PauseThenLongIdle_DoesNotRevert() external {
        setClaimerAndInitialize();
        donateReceiverWXDAI();
        skipFirstEpoch();

        // Trip the pause.
        skipTime(epoch + 1);
        claimEOA();
        assertEq(rcv.dripRate(), 0);

        // Long idle period without any top-up. Pre-fix this would set claimable
        // = stale currentEpochBalance and revert in safeTransfer.
        skipTime(10 * epoch);
        uint256 claimed = claimEOA();
        assertEq(claimed, 0, "nothing to claim while paused with empty contract");
    }

    /*//////////////////////////////////////////////////////////////
                            EVENT EMISSIONS
    //////////////////////////////////////////////////////////////*/

    function testEvent_ReceiverInitialized_AndConstructorClaimer() external {
        // Constructor emits ClaimerChanged(address(0), deployer).
        vm.expectEmit(true, true, false, false);
        emit IBridgeInterestReceiver.ClaimerChanged(address(0), address(this));
        BridgeInterestReceiver fresh = new BridgeInterestReceiver(address(sDAI));

        vm.deal(address(fresh), 30001 ether);
        uint256 expectedBalance = 30001 ether;
        uint256 epochLen = fresh.EPOCH_LENGTH();
        uint256 expectedRate = expectedBalance / epochLen;
        uint256 expectedNext = block.timestamp + epochLen;

        // initialize emits ClaimerChanged(deployer, _claimer) THEN ReceiverInitialized(...).
        vm.expectEmit(true, true, false, false);
        emit IBridgeInterestReceiver.ClaimerChanged(address(this), address(adapter));
        vm.expectEmit(false, false, false, true);
        emit IBridgeInterestReceiver.ReceiverInitialized(expectedBalance, expectedRate, expectedNext);
        fresh.initialize(address(adapter));
    }

    function testEvent_Claimed() external {
        setClaimerAndInitialize();
        skipTime(1 days);
        uint256 expected = rcv.previewClaimable();
        vm.prank(bob, bob);
        vm.expectEmit(true, false, false, true);
        emit IBridgeInterestReceiver.Claimed(address(sDAI), expected);
        rcv.claim();
    }

    function testEvent_EpochRolled() external {
        setClaimerAndInitialize();
        donateReceiverWXDAI();
        skipFirstEpoch();
        // Move forward to a brand new epoch with healthy balance for rollover.
        donateReceiverWXDAI(); // top up so postClaim stays above DRIP_PAUSE_THRESHOLD
        skipTime(epoch + 1);

        // Pre-compute the expected emit values using the same pure helpers' arithmetic.
        uint256 balance = wxdai.balanceOf(address(rcv)) + address(rcv).balance;
        uint256 claimable = rcv.previewClaimable();
        uint256 postClaim = balance - claimable;
        require(postClaim >= rcv.DRIP_PAUSE_THRESHOLD(), "test setup: postClaim must clear pause threshold");

        uint256 expectedRate = postClaim / epoch;
        uint256 expectedNextEpoch = block.timestamp + epoch;

        vm.expectEmit(false, false, false, true);
        emit IBridgeInterestReceiver.EpochRolled(expectedRate, postClaim, expectedNextEpoch);
        claimEOA();
    }

    function testEvent_DripPaused() external {
        setClaimerAndInitialize();
        donateReceiverWXDAI();
        skipFirstEpoch();
        skipTime(epoch + 1);

        uint256 balance = wxdai.balanceOf(address(rcv)) + address(rcv).balance;
        uint256 claimable = rcv.previewClaimable();
        require(balance - claimable < rcv.DRIP_PAUSE_THRESHOLD(), "test setup: postClaim must trip pause threshold");

        vm.expectEmit(false, false, false, true);
        emit IBridgeInterestReceiver.DripPaused(balance - claimable);
        claimEOA();
    }
}
