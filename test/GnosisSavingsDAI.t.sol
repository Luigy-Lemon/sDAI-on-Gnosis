// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import 'forge-std/console.sol';
import "./Setup.t.sol";


contract GnosisSavingsDAITest is SetupTest{

    function invariantMetadata() public {
        assertEq(address(sDAI.interestReceiver()), address(interestReceiver));
        assertEq(address(sDAI.wxdai()), address(wxdai));
        assertEq(alice, address(10));
        assertEq(bob, address(11));
    }

    

    /*//////////////////////////////////////////////////////////////
                        MODIFIED LOGIC
    //////////////////////////////////////////////////////////////*/

    function testDeposit() public{
        uint256 assets = 1e18;
        address receiver = alice;
        vm.startPrank(receiver);
        uint256 initialBalance = wxdai.balanceOf(receiver);
        wxdai.approve(address(sDAI), initialBalance);
        uint256 shares = sDAI.deposit(assets, receiver);
        console.log("totalAssets: %e", sDAI.totalAssets());
        console.log("previewDeposit: %e", sDAI.previewDeposit(assets));
        console.log("previewRedeem: %e", sDAI.previewRedeem(sDAI.balanceOf(receiver)));
        console.log("maxWithdraw: %e", sDAI.maxWithdraw(receiver));
        assertEq(sDAI.balanceOf(receiver), shares);
        assertGe(sDAI.totalAssets(), sDAI.maxWithdraw(receiver));
        assertEq(wxdai.balanceOf(receiver), initialBalance - assets);
        vm.stopPrank();
    }


    function testFuzzDeposit(uint256 assets) public{
        address receiver = alice;

        uint256 initialAssets = wxdai.balanceOf(receiver);
        uint256 initialShares = sDAI.balanceOf(receiver);
        vm.assume(assets <= wxdai.balanceOf(alice));

        vm.startPrank(alice);

        wxdai.approve(address(sDAI), initialAssets);
        uint256 shares = sDAI.deposit(assets, receiver);

        assertEq(sDAI.balanceOf(receiver), initialShares + shares);
        assertGe(sDAI.totalAssets(), sDAI.maxWithdraw(receiver));
        assertEq(wxdai.balanceOf(receiver), initialAssets - assets);

        vm.stopPrank();
    }

    function testFuzzMint(uint256 shares) public {
        address receiver = alice;

        uint256 initialAssets = wxdai.balanceOf(receiver);
        uint256 initialShares = sDAI.balanceOf(receiver);

        vm.assume(shares <= sDAI.convertToShares(wxdai.balanceOf(alice)));

        vm.startPrank(alice);
        wxdai.approve(address(sDAI), initialAssets);
        uint256 assets = sDAI.mint(shares, receiver);

        assertEq(sDAI.balanceOf(receiver), initialShares + shares);
        assertGe(sDAI.totalAssets(), sDAI.maxWithdraw(receiver));
        assertEq(wxdai.balanceOf(receiver), initialAssets - assets);

        vm.stopPrank();
    }

    function testFuzzWithdraw(uint256 assets) public {
        address receiver = alice;
        address owner = alice;

        testDeposit();

        vm.startPrank(alice);

        vm.assume(assets <= sDAI.maxWithdraw(receiver));

        uint256 initialAssets = wxdai.balanceOf(receiver);
        uint256 initialShares = sDAI.balanceOf(owner);

        uint256 shares = sDAI.withdraw(assets, receiver, owner);

        assertEq(sDAI.balanceOf(owner), initialShares - shares);
        assertGe(sDAI.totalAssets(), sDAI.maxWithdraw(receiver));
        assertEq(wxdai.balanceOf(receiver), initialAssets + assets);

        vm.stopPrank();

    }


    function testFuzzRedeem(uint256 shares) public{
        address receiver = alice;
        address owner = alice;

        testDeposit();

        uint256 initialAssets = wxdai.balanceOf(receiver);
        uint256 initialShares = sDAI.balanceOf(owner);

        vm.assume(shares <= initialShares);
        
        vm.startPrank(alice);
        uint256 assets = sDAI.redeem(shares, receiver, owner);

        assertEq(sDAI.balanceOf(owner), initialShares - shares);
        assertGe(sDAI.totalAssets(), sDAI.maxWithdraw(receiver));
        assertEq(wxdai.balanceOf(receiver), initialAssets + assets);

        vm.stopPrank();

    }

    function testDepositXDAI() public payable{
        uint256 assets = 1e18;
        address receiver = alice;
        uint256 initialAssets = alice.balance;
        uint256 initialShares = sDAI.balanceOf(receiver);

        vm.startPrank(alice);
        uint256 shares = sDAI.depositXDAI{value:assets}(receiver);
        vm.stopPrank();

        assertEq(sDAI.balanceOf(receiver), initialShares + shares);
        assertGe(sDAI.totalAssets(), sDAI.maxWithdraw(receiver));
        assertEq(alice.balance, initialAssets - assets);
    }

    function testWithdrawXDAI(uint256 assets) public payable{

        address receiver = alice;
        address owner = alice;

        vm.assume(assets <= sDAI.maxWithdraw(receiver));
        sDAI.deposit(assets, alice);

        uint256 initialAssets = alice.balance;
        uint256 initialShares = sDAI.balanceOf(alice);

        vm.startPrank(alice);
        uint256 shares = sDAI.withdrawXDAI(assets, receiver, owner);
        vm.stopPrank();

        assertEq(sDAI.balanceOf(receiver), initialShares - shares);
        assertGe(sDAI.totalAssets(), sDAI.maxWithdraw(receiver));
        assertEq(alice.balance, initialAssets + assets);
        if (shares > 0 && wxdai.balanceOf(address(sDAI)) == 0){
            revert();
        }

    }


    /*//////////////////////////////////////////////////////////////
                        SPECIAL STATES
    //////////////////////////////////////////////////////////////*/

    function testMintAndWithdraw(uint256 shares) public{

        uint256 initialAssets = wxdai.balanceOf(alice);
        vm.assume(shares < sDAI.convertToShares(initialAssets));

        vm.startPrank(alice);

        wxdai.approve(address(sDAI), initialAssets);
        uint256 assets = sDAI.mint(shares, alice);
        uint256 shares2 = sDAI.withdraw(assets, alice, alice);
        assertGe(shares2 , shares);

        vm.stopPrank();

    }
        


}