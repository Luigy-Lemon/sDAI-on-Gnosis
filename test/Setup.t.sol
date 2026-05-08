// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import {Gnosis} from "src/constants/Gnosis.sol";
import {SavingsXDai} from "src/SavingsXDai.sol";
import {ISavingsXDai} from "src/interfaces/ISavingsXDai.sol";
import {BridgeInterestReceiver} from "src/BridgeInterestReceiver.sol";
import {IBridgeInterestReceiver} from "src/interfaces/IBridgeInterestReceiver.sol";
import {IWXDAI} from "src/interfaces/IWXDAI.sol";
import "src/periphery/SavingsXDaiAdapter.sol";

contract SetupTest is Test {
    bool internal constant VERBOSE_SETUP = false;
    address public initializer = makeAddr("initializer");
    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");
    BridgeInterestReceiver public rcv;
    SavingsXDai public sDAI;
    SavingsXDaiAdapter public adapter;
    IWXDAI public wxdai;
    uint256 public globalTime;
    uint256 public epoch;

    function setUp() public payable {
        vm.createSelectFork("gnosis");

        wxdai = IWXDAI(Gnosis.WXDAI);
        vm.deal(address(this), 100 ether);
        vm.deal(initializer, 100 ether);
        vm.deal(alice, 10000 ether);
        vm.etch(alice, ""); // clear any code at address on forked network
        vm.deal(bob, 100000 ether);
        vm.etch(bob, ""); // clear any code at address on forked network
        vm.startPrank(initializer);

        /*//////////////////////////////////////////////////////////////
                                DEPLOYMENTS
        //////////////////////////////////////////////////////////////*/

        sDAI = new SavingsXDai("Savings DAI on Gnosis", "sDAI");
        if (VERBOSE_SETUP) {
            emit log_named_address("Deployed sDAI on Gnosis", address(sDAI));
        }

        rcv = new BridgeInterestReceiver(address(sDAI));
        if (VERBOSE_SETUP) {
            emit log_named_address("Deployed InterestReceiver", address(rcv));
        }

        adapter = new SavingsXDaiAdapter(address(rcv), payable(sDAI));
        if (VERBOSE_SETUP) {
            emit log_named_address("Deployed SavingsXDaiAdapter on Gnosis", address(adapter));
        }
        vm.stopPrank();

        deal(address(wxdai), initializer, 100e18);
        assertEq(wxdai.balanceOf(initializer), 100e18);

        deal(address(wxdai), alice, 100e18);
        assertEq(wxdai.balanceOf(alice), 100e18);

        deal(address(wxdai), bob, 10000e18);
        assertEq(wxdai.balanceOf(bob), 10000e18);
        globalTime = block.timestamp;
        epoch = rcv.EPOCH_LENGTH();
    }

    /*//////////////////////////////////////////////////////////////
                        INITIALIZER
    //////////////////////////////////////////////////////////////*/

    function testInitialize_revertsWhenUnderfunded() public {
        deal(address(wxdai), address(rcv), 0);
        vm.deal(address(rcv), 0);
        vm.startPrank(initializer);
        uint256 minB = rcv.MIN_INITIAL_BALANCE();
        vm.deal(address(rcv), minB - 1);
        vm.expectRevert(
            abi.encodeWithSelector(
                IBridgeInterestReceiver.InsufficientInitialBalance.selector, minB - 1, minB
            )
        );
        rcv.initialize(address(adapter));
        vm.stopPrank();
    }

    function testInitialize_succeedsWhenFunded() public {
        deal(address(wxdai), address(rcv), 0);
        vm.deal(address(rcv), 0);
        vm.startPrank(initializer);
        uint256 minB = rcv.MIN_INITIAL_BALANCE();
        vm.deal(address(rcv), minB);
        rcv.initialize(address(adapter));
        vm.stopPrank();
        assertEq(rcv.claimer(), address(adapter));
    }

    function setClaimerAndInitialize() public {
        vm.startPrank(initializer);
        vm.deal(address(rcv), rcv.MIN_INITIAL_BALANCE());
        rcv.initialize(address(adapter));
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
        vm.expectRevert(ISavingsXDai.NoXDaiDeposits.selector);
        (sent) = _to.send(value);
        vm.expectRevert(ISavingsXDai.NoXDaiDeposits.selector);
        (sent,) = _to.call{value: value}("");
        vm.expectRevert(ISavingsXDai.NoXDaiDeposits.selector);
        _to.transfer(value);
    }

    /*//////////////////////////////////////////////////////////////
                        UTILS
    //////////////////////////////////////////////////////////////*/

    function skipTime(uint256 secs) public {
        globalTime += secs;
        vm.warp(globalTime);
    }
}
