// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import 'forge-std/console.sol';
import "./Setup.t.sol";


contract GnosisSavingsDAITest is SetupTest {

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

        vm.startPrank(alice);
        uint256 initialBalance = wxdai.balanceOf(alice);
        wxdai.approve(address(sDAI), initialBalance);
        uint256 shares = sDAI.deposit(assets, receiver);
        console.log("totalAssets: %e", sDAI.totalAssets());
        console.log("previewDeposit: %e", sDAI.previewDeposit(assets));
        console.log("previewRedeem: %e", sDAI.previewRedeem(sDAI.balanceOf(alice)));
        console.log("maxWithdraw: %e", sDAI.maxWithdraw(alice));
        assertEq(sDAI.balanceOf(receiver), shares);
        assertEq(sDAI.totalAssets(), sDAI.maxWithdraw(receiver));
        assertEq(wxdai.balanceOf(alice), initialBalance - assets);
        vm.stopPrank();

        // Bob does a donation
        vm.startPrank(bob);
        wxdai.transfer(address(sDAI), 10e18);
        vm.stopPrank();
        assertLt(sDAI.maxWithdraw(receiver), sDAI.totalAssets());
        assertEq(sDAI.previewRedeem(sDAI.balanceOf(alice)), sDAI.maxWithdraw(receiver));
    }


    function testFuzzDeposit(uint256 assets) public{
        address receiver = alice;
        vm.assume(assets < wxdai.balanceOf(alice));

        vm.startPrank(alice);
        uint256 initialBalance = wxdai.balanceOf(alice);
        wxdai.approve(address(sDAI), initialBalance);
        uint256 shares = sDAI.deposit(assets, receiver);

        assertEq(sDAI.balanceOf(receiver), shares);
        assertEq(sDAI.totalAssets(), sDAI.maxWithdraw(receiver));
        assertEq(wxdai.balanceOf(alice), initialBalance - assets);

        vm.stopPrank();
    }

    function testDepositXDAI() public payable{

        uint256 assets = 1e18;
        address receiver = alice;

        vm.startPrank(alice);
        uint256 initialBalance = alice.balance;
        uint256 shares = sDAI.depositXDAI{value:assets}(receiver);
        vm.stopPrank();

        assertEq(sDAI.balanceOf(receiver), shares);
        assertEq(sDAI.totalAssets(), sDAI.maxWithdraw(receiver));
        assertEq(alice.balance, initialBalance - assets);
    }

/*
    function mint(uint256 shares, address receiver) public virtual override returns (uint256) {
        interestReceiver.claim();
        return this.mint(shares, receiver);
    }


    function withdrawXDAI(uint256 assets, address receiver, address owner) public payable virtual returns (uint256) {
        uint256 shares = this.withdraw(assets, address(this), owner);
        wxdai.withdraw(assets);
        (bool sent,) = receiver.call{value: msg.value}("");
        require(sent, "Failed to send Ether");
        return shares;
    }*/

    /*//////////////////////////////////////////////////////////////
                        ERC4626 LOGIC
    //////////////////////////////////////////////////////////////*/

    /*//////////////////////////////////////////////////////////////
                        VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/
/*
    function testGetWrappedAgToken() public {
        vm.startPrank(0x1BEeEeeEEeeEeeeeEeeEEEEEeeEeEeEEeEeEeEEe);
        TokenData[] memory agTokens = IAgaveProtocolDataProvider(token.Provider()).getAllATokens();
        address[] memory deployed = token.deployWrappedAgTokens(3);
        vm.stopPrank();
        address wrappedAg0 = token.getWrappedAgToken(agTokens[0].tokenAddress);
        address wrappedAg1 = token.getWrappedAgToken(agTokens[1].tokenAddress);
        address wrappedAg2 = token.getWrappedAgToken(agTokens[2].tokenAddress);
        assertEq(deployed[0], wrappedAg0);
        assertEq(deployed[1], wrappedAg1);
        assertEq(deployed[2], wrappedAg2);
    }*/
}
