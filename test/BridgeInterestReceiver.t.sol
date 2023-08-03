// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import 'forge-std/console.sol';
import "./Setup.t.sol";

contract BridgeInterestReceiverTest is SetupTest {


    function testMetadata() public {
        assertEq(address(sDAI.interestReceiver()), address(rcv));
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
        time = bound(time, 0 , 5 days);
        require(time >= 0 && time<= 5 days);
        console.log("GlobalTime: %s | Time: %s | CurrentTime: %s",globalTime, time, block.timestamp);
        console.log("_nextClaimEpoch: %s | _lastClaimTimestamp: %s | dripRate: %s",rcv._nextClaimEpoch(),rcv._lastClaimTimestamp(),rcv.dripRate());

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

        console.log("GlobalTime: %s | Time: %s | CurrentTime: %s",globalTime, time, block.timestamp);
        console.log("_nextClaimEpoch: %s | _lastClaimTimestamp: %s | dripRate: %s",rcv._nextClaimEpoch(),rcv._lastClaimTimestamp(),rcv.dripRate());

        if(globalTime == lastClaimTime){
            assertEq(claimed,0);
        }
        else if (globalTime >= lastClaimTime + rcv.epochLength()){
            assertEq(claimed,rcvBalance);
            assertGe(rcv._nextClaimEpoch(), rcv._lastClaimTimestamp() + rcv.epochLength());
            assertEq(claimable, claimed);
        }
        else{
            if (beforeRate > 0){
                assertGt(claimed,0);
            }
            assertEq(claimable, claimed);
            assertLe(endEpoch, rcv._lastClaimTimestamp() + rcv.epochLength());
        }

        assertEq(wxdai.balanceOf(address(rcv)), rcvBalance - claimed);
        assertEq(claimed, wxdai.balanceOf(address(sDAI)) - sDAIBalance);
        assertEq(sDAI.totalSupply(), shares);
        assertLe(sDAIBalance, sDAI.totalAssets());
        assertLe(wxdai.balanceOf(address(rcv)), rcvBalance);
        assertEq(sDAI.totalSupply(), shares);
        assertLe(totalWithdrawable, sDAI.previewRedeem(shares));  
    }


    function testClaimDream() public {
        uint256 shares = sDAI.totalSupply();
        uint256 totalWithdrawable = sDAI.previewRedeem(shares);
        testTopInterestReceiver();
        skipTime(1);
        uint256 sDAIBalance = wxdai.balanceOf(address(sDAI));
        uint256 initRcvBalance = wxdai.balanceOf(address(rcv)) + address(rcv).balance;
        uint256 claimed = rcv.claim();

        uint256 startDripRate = rcv.dripRate();

        uint256 endEpoch = rcv._nextClaimEpoch();

        skipTime(10 hours);
        claimed = rcv.claim();

        uint256 rcvBalance = wxdai.balanceOf(address(rcv)) + address(rcv).balance;

        testTopInterestReceiver();
        assertGe(claimed, startDripRate * 10 hours);
        assertEq(startDripRate, rcv.dripRate());
        assertGt(wxdai.balanceOf(address(rcv)), rcvBalance);
        assertEq(startDripRate, rcv.dripRate());

        teleport(endEpoch);
        claimed = rcv.claim();

        rcvBalance = wxdai.balanceOf(address(rcv)) + address(rcv).balance;
        
        if (initRcvBalance > rcvBalance){
            assertGt(startDripRate, rcv.dripRate());
        }
        else {
            assertLe(startDripRate, rcv.dripRate());
        }

        skipTime(1000);
        claimed = rcv.claim();

        rcvBalance = wxdai.balanceOf(address(rcv)) + address(rcv).balance;

        assertLe(sDAIBalance, sDAI.totalAssets());
        assertLe(wxdai.balanceOf(address(rcv)), rcvBalance);
        assertEq(sDAI.totalSupply(), shares);
        assertLe(totalWithdrawable, sDAI.previewRedeem(shares));

    }
}
