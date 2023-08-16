// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import 'forge-std/console.sol';
import {GnosisSavingsDAI} from 'src/GnosisSavingsDAI.sol';
import {BridgeInterestReceiver} from 'src/BridgeInterestReceiver.sol';
import {IWXDAI} from 'src/interfaces/IWXDAI.sol';
import 'src/periphery/ClaimSavingsAdapter.sol';


contract SetupTest is Test {

    address public initializer = address(15);
    address public alice = address(16);
    address public bob = address(17);
    BridgeInterestReceiver public rcv;
    GnosisSavingsDAI public sDAI;
    ClaimSavingsAdapter public adapter;
    IWXDAI public wxdai = IWXDAI(0xe91D153E0b41518A2Ce8Dd3D7944Fa863463a97d);
    uint256 public globalTime;

    function setUp() public payable {

        vm.deal(address(this), 100 ether);
        vm.deal(initializer, 100 ether);
        vm.deal(alice, 10000 ether);
        vm.deal(bob, 100000 ether);
        vm.startPrank(alice);

        /*//////////////////////////////////////////////////////////////
                                DEPLOYMENTS
        //////////////////////////////////////////////////////////////*/

        rcv = new BridgeInterestReceiver();
        console.log('Deployed InterestReceiver: %s', address(rcv));

        sDAI = new GnosisSavingsDAI("Savings DAI on Gnosis", "sDAI");
        console.log('Deployed sDAI on Gnosis: %s', address(sDAI));

        adapter = new ClaimSavingsAdapter(address(rcv), payable(sDAI));
        console.log('Deployed ClaimSavingsAdapter on Gnosis: %s', address(adapter));
        vm.stopPrank();

        vm.deal(address(rcv), 100 ether);

        testInitialize();
        
        deal(address(wxdai), alice, 100e18);
        assertEq(wxdai.balanceOf(alice), 100e18);

        deal(address(wxdai), bob, 10000e18);
        assertEq(wxdai.balanceOf(bob), 10000e18);

        deal(address(wxdai), address(rcv), 100e18);
        assertEq(wxdai.balanceOf(address(rcv)), 100e18);
    }


    /*//////////////////////////////////////////////////////////////
                        INITIALIZER
    //////////////////////////////////////////////////////////////*/

    function testInitialize() public {
        address vault = address(sDAI);

        vm.startPrank(initializer);
        try rcv.initialize(vault){
            console.log("initialized");
        }
        catch {
            console.log("already initialized");
        }
        globalTime = block.timestamp;
        sDAI.depositXDAI{value:1e18}(initializer);
        vm.stopPrank();

        vm.startPrank(bob);
        sDAI.depositXDAI{value:10e18}(bob);
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

    function testTopInterestReceiver() public{
        uint256 initialPreview = rcv.previewClaimable(10000);
        // Bob does a donation
        vm.startPrank(bob);
        wxdai.transfer(address(rcv), 1000e18);
        
        vm.stopPrank();
        assertEq(rcv.previewClaimable(10000), initialPreview);
    }

    function testTransferXDAI() public{
        uint256 value = 1e16;
        address payable _to  = payable(sDAI);
        bool sent;
        vm.expectRevert(bytes("No xDAI deposits"));
        (sent ) = _to.send(value);
        vm.expectRevert(bytes("No xDAI deposits"));
        (sent, ) = _to.call{value: value}("");
        vm.expectRevert(bytes("No xDAI deposits"));
        _to.transfer(value);
    }


    /*//////////////////////////////////////////////////////////////
                        UTILS
    //////////////////////////////////////////////////////////////*/

    function teleport(uint256 _timestamp) public{
        globalTime = _timestamp;
        vm.warp(globalTime);
    }

    function skipTime(uint256 secs) public{
        globalTime += secs;
        vm.warp(globalTime);
    }
}