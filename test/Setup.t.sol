// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import {SavingsXDai} from "src/SavingsXDai.sol";
import {BridgeInterestReceiver} from "src/BridgeInterestReceiver.sol";
import {IWXDAI} from "src/interfaces/IWXDAI.sol";
import "src/periphery/SavingsXDaiAdapter.sol";

contract SetupTest is Test {
    address public initializer = address(18);
    address public alice = address(16);
    address public bob = address(17);
    BridgeInterestReceiver public rcv;
    SavingsXDai public sDAI;
    SavingsXDaiAdapter public adapter;
    IWXDAI public wxdai = IWXDAI(0xe91D153E0b41518A2Ce8Dd3D7944Fa863463a97d);
    uint256 public globalTime;
    uint256 public epoch;

    function setUp() public payable {
        vm.deal(address(this), 100 ether);
        vm.deal(initializer, 100 ether);
        vm.deal(alice, 10000 ether);
        vm.deal(bob, 100000 ether);
        vm.startPrank(initializer);

        /*//////////////////////////////////////////////////////////////
                                DEPLOYMENTS
        //////////////////////////////////////////////////////////////*/

        sDAI = new SavingsXDai("Savings DAI on Gnosis", "sDAI");
        console.log("Deployed sDAI on Gnosis: %s", address(sDAI));

        rcv = new BridgeInterestReceiver(address(sDAI));
        console.log("Deployed InterestReceiver: %s", address(rcv));

        adapter = new SavingsXDaiAdapter(address(rcv), payable(sDAI));
        console.log("Deployed SavingsXDaiAdapter on Gnosis: %s", address(adapter));
        vm.stopPrank();

        deal(address(wxdai), initializer, 100e18);
        assertEq(wxdai.balanceOf(initializer), 100e18);

        deal(address(wxdai), alice, 100e18);
        assertEq(wxdai.balanceOf(alice), 100e18);

        deal(address(wxdai), bob, 10000e18);
        assertEq(wxdai.balanceOf(bob), 10000e18);
        globalTime = block.timestamp;
        epoch = rcv.epochLength();
    }

    /*//////////////////////////////////////////////////////////////
                        INITIALIZER
    //////////////////////////////////////////////////////////////*/

    function testInitialize() public {
        vm.startPrank(initializer);
        if (address(rcv).balance > 30000 ether) {
            rcv.initialize();
        } else {
            vm.expectRevert("Fill it up first");
            rcv.initialize();
        }
        vm.stopPrank();
    }

    function testSetClaimer() public {
        assertEq(rcv.claimer(), initializer);
        vm.startPrank(initializer);
        rcv.setClaimer(address(adapter));
        console.log("Claimer configured: %s", address(adapter));
        vm.stopPrank();
        assertEq(rcv.claimer(), address(adapter));
        vm.startPrank(initializer);
        vm.expectRevert("Not Claimer");
        rcv.setClaimer(bob);
        vm.stopPrank();
    }

    function setClaimerAndInitialize() public {
        vm.startPrank(initializer);
        rcv.setClaimer(address(adapter));
        vm.deal(address(rcv), 30001 ether);
        rcv.initialize();
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                        BASIC TRANSFERS
    //////////////////////////////////////////////////////////////*/
    function testDonateWXDAI() public {
        uint256 initialPreview = sDAI.previewRedeem(10000);
        // Bob does a donation
        vm.startPrank(bob);
        wxdai.transfer(address(sDAI), 10e18);
        wxdai.transfer(address(rcv), 100e18);

        vm.stopPrank();
        assertEq(wxdai.balanceOf(address(sDAI)), sDAI.totalAssets());
        assertGe(sDAI.previewRedeem(10000), initialPreview);
    }

    function donateReceiverWXDAI() public {
        vm.startPrank(bob);
        wxdai.transfer(address(rcv), 3000e18);
        vm.stopPrank();
    }

    function testTopInterestReceiver() public {
        uint256 initialPreview = rcv.previewClaimable();
        // Bob does a donation
        vm.startPrank(bob);
        wxdai.transfer(address(rcv), 1000e18);

        vm.stopPrank();
        assertEq(rcv.previewClaimable(), initialPreview);
    }

    function testTransferXDAI() public {
        uint256 value = 1e16;
        address payable _to = payable(sDAI);
        bool sent;
        vm.expectRevert(bytes("No xDAI deposits"));
        (sent) = _to.send(value);
        vm.expectRevert(bytes("No xDAI deposits"));
        (sent,) = _to.call{value: value}("");
        vm.expectRevert(bytes("No xDAI deposits"));
        _to.transfer(value);
    }

    /*//////////////////////////////////////////////////////////////
                        UTILS
    //////////////////////////////////////////////////////////////*/

    function teleport(uint256 _timestamp) public {
        globalTime = _timestamp;
        vm.warp(globalTime);
    }

    function skipTime(uint256 secs) public {
        globalTime += secs;
        vm.warp(globalTime);
    }
}
