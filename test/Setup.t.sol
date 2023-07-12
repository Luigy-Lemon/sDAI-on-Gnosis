// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import 'forge-std/console.sol';
import {GnosisSavingsDAI} from 'src/GnosisSavingsDAI.sol';
import {BridgeInterestReceiver} from 'src/BridgeInterestReceiver.sol';
import {IWXDAI} from 'src/interfaces/IWXDAI.sol';


contract SetupTest is Test {

    address public initializer = address(9);
    address public alice = address(10);
    address public bob = address(11);
    BridgeInterestReceiver public interestReceiver;
    GnosisSavingsDAI public sDAI;
    IWXDAI public wxdai = IWXDAI(0xe91D153E0b41518A2Ce8Dd3D7944Fa863463a97d);

    function setUp() public payable {

        vm.createSelectFork("gnosis");

        vm.deal(initializer, 100 ether);
        vm.deal(alice, 10000 ether);
        vm.deal(bob, 100000 ether);
        vm.startPrank(alice);

        /*//////////////////////////////////////////////////////////////
                                DEPLOYMENTS
        //////////////////////////////////////////////////////////////*/

        interestReceiver = new BridgeInterestReceiver();
        console.log('Deployed InterestReceiver: %s', address(interestReceiver));

        sDAI = new GnosisSavingsDAI(address(interestReceiver), "Savings DAI on Gnosis", "sDAI");
        console.log('Deployed sDAI on Gnosis: %s', address(sDAI));
        vm.stopPrank();

        testInitialize();
        
        deal(address(wxdai), alice, 100e18);
        assertEq(wxdai.balanceOf(alice), 100e18);

        deal(address(wxdai), bob, 10000e18);
        assertEq(wxdai.balanceOf(bob), 10000e18);

        deal(address(wxdai), address(interestReceiver), 100e18);
        assertEq(wxdai.balanceOf(address(interestReceiver)), 100e18);
    }


    /*//////////////////////////////////////////////////////////////
                        INITIALIZER
    //////////////////////////////////////////////////////////////*/

    function testInitialize() public {
        address vault = address(sDAI);

        vm.startPrank(initializer);
        try interestReceiver.initialize(vault){
            console.log("initialized");
        }
        catch {
            console.log("already initialized");
        }
        sDAI.depositXDAI{value:1e18}(initializer);
        vm.stopPrank();

        vm.startPrank(bob);
        sDAI.depositXDAI{value:10e18}(bob);
        vm.stopPrank();
    }


    /*//////////////////////////////////////////////////////////////
                        BASIC TRANSFERS
    //////////////////////////////////////////////////////////////*/

    function testTransferXDAI() public payable{
        uint256 value = 1e16;
        address payable _to  = payable(sDAI);

        vm.expectRevert(bytes(""));
        (bool revertsAsExpected ) = _to.send(value);
        assertTrue(revertsAsExpected, "expectRevert: call did not revert");
 
        (bool sent, ) = _to.call{value: value}("");
        assertFalse(sent, "expectRevert: call did not revert");
    }

    function testDonateWXDAI() public{
        vm.roll(100);
        uint256 initialPreview = sDAI.previewRedeem(10000);
        // Bob does a donation
        vm.startPrank(bob);
        wxdai.transfer(address(sDAI), 10e18);
        wxdai.transfer(address(sDAI.interestReceiver()), 10e18);
        
        vm.stopPrank();
        assertEq(wxdai.balanceOf(address(sDAI)), sDAI.totalAssets());
        assertGe(sDAI.previewRedeem(10000), initialPreview);
    }


}