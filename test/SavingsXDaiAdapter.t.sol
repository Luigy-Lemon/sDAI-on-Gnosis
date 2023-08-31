// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "./Setup.t.sol";

contract SavingsXDaiAdapterTest is SetupTest {
    event Transfer(address indexed from, address indexed to, uint256 value);

    function testMetadata() public {
        assertEq(address(rcv), address(rcv));
        assertEq(address(sDAI.wxdai()), address(wxdai));
    }

    /*//////////////////////////////////////////////////////////////
                        CORE LOGIC
    //////////////////////////////////////////////////////////////*/

    function testDeposit() public {
        uint256 assets = 1e18;
        address receiver = alice;
        vm.startPrank(receiver);
        uint256 initialBalance = wxdai.balanceOf(receiver);
        wxdai.approve(address(adapter), initialBalance);

        uint256 shares = adapter.deposit(assets, receiver);
        console.log("totalAssets: %e", sDAI.totalAssets());
        console.log("previewDeposit: %e", sDAI.previewDeposit(assets));
        console.log(
            "previewRedeem: %e",
            sDAI.previewRedeem(sDAI.balanceOf(receiver))
        );
        console.log("maxWithdraw: %e", sDAI.maxWithdraw(receiver));
        assertEq(sDAI.balanceOf(receiver), shares);
        assertGe(sDAI.totalAssets(), sDAI.maxWithdraw(receiver));
        assertEq(wxdai.balanceOf(receiver), initialBalance - assets);
        vm.stopPrank();
    }

    function testFuzzDeposit(uint256 assets) public {
        address receiver = alice;

        uint256 initialAssets = wxdai.balanceOf(receiver);
        uint256 initialShares = sDAI.balanceOf(receiver);
        vm.assume(assets <= wxdai.balanceOf(alice));

        vm.startPrank(alice);

        wxdai.approve(address(adapter), initialAssets);
        uint256 shares = adapter.deposit(assets, receiver);

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
        wxdai.approve(address(adapter), initialAssets);

        uint256 assets = adapter.mint(shares, receiver);

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

        sDAI.approve(address(adapter), initialShares);
        uint256 shares = adapter.withdraw(assets, receiver, owner);

        assertEq(sDAI.balanceOf(owner), initialShares - shares);
        assertGe(sDAI.totalAssets(), sDAI.maxWithdraw(receiver));
        assertEq(wxdai.balanceOf(receiver), initialAssets + assets);

        vm.stopPrank();
    }

    function testFuzzRedeem(uint256 shares) public {
        address receiver = alice;
        address owner = alice;

        testDeposit();

        uint256 initialAssets = wxdai.balanceOf(receiver);
        uint256 initialShares = sDAI.balanceOf(owner);

        vm.assume(shares <= initialShares);

        vm.startPrank(alice);
        sDAI.approve(address(adapter), shares);

        uint256 assets = adapter.redeem(shares, receiver, owner);

        assertEq(sDAI.balanceOf(owner), initialShares - shares);
        assertGe(sDAI.totalAssets(), sDAI.maxWithdraw(receiver));
        assertEq(wxdai.balanceOf(receiver), initialAssets + assets);

        vm.stopPrank();
    }

    function testDepositXDAI() public payable {
        uint256 assets = 1e18;
        address receiver = alice;
        uint256 initialAssets = alice.balance;
        uint256 initialShares = sDAI.balanceOf(receiver);
        uint256 expectedShares = sDAI.previewDeposit(assets);

        vm.startPrank(alice);

        uint256 shares = adapter.depositXDAI{value: assets}(receiver);
        vm.stopPrank();

        assertEq(expectedShares, shares);
        assertEq(sDAI.balanceOf(receiver), initialShares + shares);
        assertGe(sDAI.totalAssets(), sDAI.maxWithdraw(receiver));
        assertEq(alice.balance, initialAssets - assets);
    }

    function testXDaiTransfer() public payable {
        uint256 assets = 1e18;
        address receiver = alice;
        uint256 initialAssets = alice.balance;
        uint256 initialShares = sDAI.balanceOf(receiver);
        uint256 expectedShares = sDAI.previewDeposit(assets);

        vm.startPrank(receiver);

        (bool y, ) = address(adapter).call{
            value: assets
        }("");
        assertEq(y, true);

        uint256 shares = sDAI.balanceOf(receiver);

        assertEq(expectedShares, shares);
        assertEq(sDAI.balanceOf(receiver), initialShares + shares);
        assertGe(sDAI.totalAssets(), sDAI.maxWithdraw(receiver));
        assertEq(alice.balance, initialAssets - assets);
    }

    function testWithdrawXDAI(uint256 assets) public payable {
        address receiver = alice;
        address owner = alice;

        vm.assume(assets <= sDAI.maxWithdraw(receiver));
        adapter.deposit(assets, alice);

        uint256 initialAssets = alice.balance;
        uint256 initialShares = sDAI.balanceOf(alice);

        vm.startPrank(alice);

        sDAI.approve(address(adapter), sDAI.convertToShares(assets));
        uint256 shares = adapter.withdrawXDAI(assets, receiver, owner);
        vm.stopPrank();

        assertEq(sDAI.balanceOf(receiver), initialShares - shares);
        assertGe(sDAI.totalAssets(), sDAI.maxWithdraw(receiver));
        assertEq(alice.balance, initialAssets + assets);
        if (shares > 0 && wxdai.balanceOf(address(sDAI)) == 0) {
            revert();
        }
    }

    function testRedeemAll() public {
        address receiver = alice;
        address owner = alice;

        testDeposit();

        uint256 initialAssets = receiver.balance;
        uint256 initialShares = sDAI.balanceOf(owner);
        uint256 initialWXDAI = wxdai.balanceOf(receiver);
        vm.startPrank(alice);
        sDAI.approve(address(adapter), initialShares);
        uint256 shares = adapter.redeemAll(receiver, owner);
        vm.stopPrank();

        assertEq(sDAI.balanceOf(owner), 0);
        assertGe(sDAI.totalAssets(), sDAI.maxWithdraw(owner));
        assertEq(0, sDAI.maxWithdraw(owner));
        assertEq(receiver.balance, initialAssets);
        assertEq(
            wxdai.balanceOf(receiver),
            initialWXDAI + sDAI.convertToAssets(shares)
        );
        if (shares > 0 && wxdai.balanceOf(address(sDAI)) == 0) {
            revert();
        }
    }

    function testRedeemAllXDAI() public {
        address receiver = alice;
        address owner = alice;

        testDeposit();

        uint256 initialAssets = receiver.balance;
        uint256 initialShares = sDAI.balanceOf(owner);
        vm.startPrank(alice);
        sDAI.approve(address(adapter), initialShares);
        uint256 shares = adapter.redeemAllXDAI(receiver, owner);
        vm.stopPrank();

        assertEq(sDAI.balanceOf(owner), 0);
        assertGe(sDAI.totalAssets(), sDAI.maxWithdraw(owner));
        assertEq(sDAI.maxWithdraw(owner), 0);
        assertEq(
            receiver.balance,
            initialAssets + sDAI.convertToAssets(shares)
        );
        if (shares > 0 && wxdai.balanceOf(address(sDAI)) == 0) {
            revert();
        }
    }

    /*//////////////////////////////////////////////////////////////
                        SPECIAL STATES
    //////////////////////////////////////////////////////////////*/

    function testMintAndWithdraw(uint256 shares) public {
        uint256 initialAssets = wxdai.balanceOf(alice);
        vm.assume(shares < sDAI.convertToShares(initialAssets));

        vm.startPrank(alice);

        wxdai.approve(address(adapter), initialAssets);
        uint256 assets = adapter.mint(shares, alice);
        sDAI.approve(address(adapter), shares);
        uint256 shares2 = adapter.withdraw(assets, alice, alice);
        assertGe(shares2, shares);

        vm.stopPrank();
    }

    // checks that all deposit functions from deposit, depositXDAI and mint all return the same shares given equivalent inputs.
    function test_CompareAllTypes_Deposits() public {
        uint256 assets = 1e18;

        vm.startPrank(alice);
        uint256 wxdaiBalance = wxdai.balanceOf(alice);

        assertGe(wxdaiBalance, assets * 2);
        assertGe(alice.balance, assets);

        wxdai.approve(address(adapter), wxdaiBalance);
        uint256 sharesERC20_a = adapter.deposit(assets, alice);
        uint256 sharesRaw_a = adapter.depositXDAI{value: assets}(alice);
        uint256 assetsERC20_a = adapter.mint(sharesERC20_a, alice);
        assertEq(sharesERC20_a, sharesRaw_a);
        assertEq(assetsERC20_a, assets);
        vm.stopPrank();
        vm.startPrank(bob);
        wxdaiBalance = wxdai.balanceOf(bob);
        assertGe(wxdaiBalance, assets * 2);
        assertGe(bob.balance, assets);
        wxdai.approve(address(adapter), wxdaiBalance);
        uint256 sharesERC20_b = adapter.deposit(assets, bob);
        uint256 sharesRaw_b = adapter.depositXDAI{value: assets}(bob);
        uint256 assetsERC20_b = adapter.mint(sharesERC20_b, bob);
        assertEq(sharesERC20_b, sharesRaw_b);
        assertEq(assetsERC20_b, assets);
        vm.stopPrank();
        assertEq(sharesERC20_a, sharesRaw_b);
        assertGt(sharesERC20_a, 100);
    }

    // checks that all withdraw functions from withdraw, withdrawXDAI and redeem all return the same shares given equivalent inputs.
    function test_CompareAllTypes_Withdrawals() public {
        uint256 assets = 1e18;

        vm.startPrank(alice);
        uint256 initialShares_a = sDAI.balanceOf(alice);
        assertGt(alice.balance, assets * 3);
        uint256 sharesDeposited_a = adapter.depositXDAI{value: assets * 3}(
            alice
        );
        sDAI.approve(address(adapter), sharesDeposited_a);
        uint256 sharesERC20_a = adapter.withdraw(assets, alice, alice);
        uint256 sharesRaw_a = adapter.withdrawXDAI(assets, alice, alice);
        uint256 assetsERC20_a = adapter.redeem(sharesERC20_a, alice, alice);
        assertEq(sharesERC20_a, sharesRaw_a);
        assertEq(assetsERC20_a, assets);
        vm.stopPrank();

        vm.startPrank(bob);
        assertGt(bob.balance, assets * 3);
        uint256 sharesDeposited_b = adapter.depositXDAI{value: assets * 3}(bob);
        sDAI.approve(address(adapter), sharesDeposited_b);
        uint256 sharesERC20_b = adapter.withdraw(assets, bob, bob);
        uint256 sharesRaw_b = adapter.withdrawXDAI(assets, bob, bob);
        uint256 assetsERC20_b = adapter.redeem(sharesERC20_a, bob, bob);
        assertEq(sharesERC20_b, sharesRaw_b);
        assertEq(assetsERC20_b, assets);
        vm.stopPrank();
        assertEq(sDAI.balanceOf(alice), initialShares_a);
        assertEq(sharesDeposited_a, sharesDeposited_b);
        assertEq(sharesERC20_a, sharesRaw_b);
        assertGt(sharesERC20_a, 100);
    }
}
