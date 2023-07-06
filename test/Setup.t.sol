// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import 'forge-std/console.sol';
import {GnosisSavingsDAI} from 'src/GnosisSavingsDAI.sol';
import {BridgeInterestReceiver} from 'src/BridgeInterestReceiver.sol';
import {IWXDAI} from 'src/interfaces/IWXDAI.sol';


contract SetupTest is Test {

    address public alice = address(10);
    address public bob = address(11);
    BridgeInterestReceiver public interestReceiver;
    GnosisSavingsDAI public sDAI;
    IWXDAI public wxdai = IWXDAI(0xe91D153E0b41518A2Ce8Dd3D7944Fa863463a97d);

    function setUp() public payable {

        vm.createSelectFork("gnosis", 28_803_915);


        vm.deal(alice, 10000 ether);
        vm.deal(bob, 100000 ether);
        vm.startPrank(alice);

        /*//////////////////////////////////////////////////////////////
                                DEPLOYMENTS
        //////////////////////////////////////////////////////////////*/

        interestReceiver = new BridgeInterestReceiver();
        console.log('Deployed InterestReceiver: %s', address(interestReceiver));

        sDAI = new GnosisSavingsDAI(address(interestReceiver));
        console.log('Deployed sDAI on Gnosis: %s', address(sDAI));

        interestReceiver.initialize(address(sDAI));
        console.log('Initialized InterestReceiver');
        
        vm.stopPrank();

        deal(address(wxdai), alice, 100e18);
        assertEq(wxdai.balanceOf(alice), 100e18);

        deal(address(wxdai), bob, 10000e18);
        assertEq(wxdai.balanceOf(bob), 10000e18);

        deal(address(wxdai), address(interestReceiver), 100e18);
        assertEq(wxdai.balanceOf(address(interestReceiver)), 100e18);
    }

}