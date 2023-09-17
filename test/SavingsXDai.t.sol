// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "./Setup.t.sol";
import "./Mocks/MockMultisig.sol";

contract SavingsXDaiTest is SetupTest {
    event Transfer(address indexed from, address indexed to, uint256 value);

    bytes32 constant PERMIT_TYPEHASH =
        keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");

    function testMetadata() public {
        assertEq(address(rcv), address(rcv));
        assertEq(address(sDAI.wxdai()), address(wxdai));
    }

    /*//////////////////////////////////////////////////////////////
                        CORE LOGIC
    //////////////////////////////////////////////////////////////*/

    function testTransferShares() public {
        uint256 assets = 1e18;
        address sender = alice;
        vm.startPrank(sender);
        wxdai.approve(address(sDAI), assets);
        uint256 shares = sDAI.deposit(assets, sender);
        assertGe(sDAI.balanceOf(sender), shares);
        assertGt(shares, 0);
        uint256 initialBalance_a = sDAI.balanceOf(sender);
        uint256 initialBalance_b = sDAI.balanceOf(bob);

        vm.expectEmit();
        emit Transfer(sender, bob, shares);
        sDAI.transfer(bob, shares);

        assertEq(sDAI.balanceOf(sender), initialBalance_a - shares);
        assertEq(sDAI.balanceOf(bob), initialBalance_b + shares);
        vm.stopPrank();
    }

    function testDeposit() public {
        uint256 assets = 1e18;
        address receiver = alice;
        vm.startPrank(receiver);
        uint256 initialBalance = wxdai.balanceOf(receiver);
        wxdai.approve(address(sDAI), initialBalance);
        vm.expectEmit();
        emit Transfer(address(0), receiver, sDAI.previewDeposit(assets));
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

    function testFuzzDeposit(uint256 assets) public {
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
        vm.expectEmit();
        emit Transfer(address(0), receiver, shares);
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

        vm.expectEmit();
        emit Transfer(receiver, address(0), sDAI.previewWithdraw(assets));
        uint256 shares = sDAI.withdraw(assets, receiver, owner);

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
        vm.expectEmit();
        emit Transfer(receiver, address(0), shares);
        uint256 assets = sDAI.redeem(shares, receiver, owner);

        assertEq(sDAI.balanceOf(owner), initialShares - shares);
        assertGe(sDAI.totalAssets(), sDAI.maxWithdraw(receiver));
        assertEq(wxdai.balanceOf(receiver), initialAssets + assets);

        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                        SPECIAL STATES
    //////////////////////////////////////////////////////////////*/

    function testMintAndWithdraw(uint256 shares) public {
        uint256 initialAssets = wxdai.balanceOf(alice);
        vm.assume(shares < sDAI.convertToShares(initialAssets));

        vm.startPrank(alice);

        wxdai.approve(address(sDAI), initialAssets);
        uint256 assets = sDAI.mint(shares, alice);
        uint256 shares2 = sDAI.withdraw(assets, alice, alice);
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

        wxdai.approve(address(sDAI), wxdaiBalance);
        uint256 sharesERC20_a = sDAI.deposit(assets, alice);
        uint256 assetsERC20_a = sDAI.mint(sharesERC20_a, alice);
        assertEq(assetsERC20_a, assets);
        vm.stopPrank();
        vm.startPrank(bob);
        wxdaiBalance = wxdai.balanceOf(bob);
        assertGe(wxdaiBalance, assets * 2);
        assertGe(bob.balance, assets);
        wxdai.approve(address(sDAI), wxdaiBalance);
        uint256 sharesERC20_b = sDAI.deposit(assets, bob);
        uint256 assetsERC20_b = sDAI.mint(sharesERC20_b, bob);
        assertEq(assetsERC20_b, assets);
        vm.stopPrank();
        assertGt(sharesERC20_a, 100);
    }

    // checks that all withdraw functions from withdraw, withdrawXDAI and redeem all return the same shares given equivalent inputs.
    function test_CompareAllTypes_Withdrawals() public {
        uint256 assets = 1e18;

        vm.startPrank(alice);
        uint256 initialShares_a = sDAI.balanceOf(alice);
        assertGt(alice.balance, assets * 2);
        wxdai.approve(address(sDAI), assets * 2);
        uint256 sharesDeposited_a = sDAI.deposit(assets * 2, alice);
        uint256 sharesERC20_a = sDAI.withdraw(assets, alice, alice);
        uint256 assetsERC20_a = sDAI.redeem(sharesERC20_a, alice, alice);
        assertEq(assetsERC20_a, assets);
        vm.stopPrank();

        vm.startPrank(bob);
        assertGt(bob.balance, assets * 2);
        wxdai.approve(address(sDAI), assets * 2);
        uint256 sharesDeposited_b = sDAI.deposit(assets * 2, bob);
        uint256 sharesERC20_b = sDAI.withdraw(assets, bob, bob);
        uint256 assetsERC20_b = sDAI.redeem(sharesERC20_a, bob, bob);
        assertEq(assetsERC20_b, assets);
        vm.stopPrank();
        assertEq(sDAI.balanceOf(alice), initialShares_a);
        assertEq(sharesDeposited_a, sharesDeposited_b);
        assertEq(sharesERC20_a, sharesERC20_b);
        assertGt(sharesERC20_a, 100);
    }

    /*//////////////////////////////////////////////////////////////
                        PERMIT LOGIC 
    //////////////////////////////////////////////////////////////*/

    function testPermit() public {
        uint256 privateKey = 0xBEEF;
        address owner = vm.addr(privateKey);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            privateKey,
            keccak256(
                abi.encodePacked(
                    "\x19\x01",
                    sDAI.DOMAIN_SEPARATOR(),
                    keccak256(abi.encode(PERMIT_TYPEHASH, owner, address(0xCAFE), 1e18, 0, block.timestamp))
                )
            )
        );

        sDAI.permit(owner, address(0xCAFE), 1e18, block.timestamp, v, r, s);

        assertEq(sDAI.allowance(owner, address(0xCAFE)), 1e18);
        assertEq(sDAI.nonces(owner), 1);
    }

    function testPermitContract() public {
        uint256 privateKey1 = 0xBEEF;
        address signer1 = vm.addr(privateKey1);
        uint256 privateKey2 = 0xBEEE;
        address signer2 = vm.addr(privateKey2);

        address mockMultisig = address(new MockMultisig(signer1, signer2));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            uint256(privateKey1),
            keccak256(
                abi.encodePacked(
                    "\x19\x01",
                    sDAI.DOMAIN_SEPARATOR(),
                    keccak256(abi.encode(PERMIT_TYPEHASH, mockMultisig, address(0xCAFE), 1e18, 0, block.timestamp))
                )
            )
        );

        (uint8 v2, bytes32 r2, bytes32 s2) = vm.sign(
            uint256(privateKey2),
            keccak256(
                abi.encodePacked(
                    "\x19\x01",
                    sDAI.DOMAIN_SEPARATOR(),
                    keccak256(abi.encode(PERMIT_TYPEHASH, mockMultisig, address(0xCAFE), 1e18, 0, block.timestamp))
                )
            )
        );

        bytes memory signature = abi.encode(r, s, bytes32(uint256(v) << 248), r2, s2, bytes32(uint256(v2) << 248));

        sDAI.permit(mockMultisig, address(0xCAFE), 1e18, block.timestamp, signature);

        assertEq(sDAI.allowance(mockMultisig, address(0xCAFE)), 1e18);
        assertEq(sDAI.nonces(mockMultisig), 1);
    }

    function testPermitContractInvalidSignature() public {
        uint256 privateKey1 = 0xBEEF;
        address signer1 = vm.addr(privateKey1);
        uint256 privateKey2 = 0xBEEE;
        address signer2 = vm.addr(privateKey2);

        address mockMultisig = address(new MockMultisig(signer1, signer2));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            uint256(privateKey1),
            keccak256(
                abi.encodePacked(
                    "\x19\x01",
                    sDAI.DOMAIN_SEPARATOR(),
                    keccak256(abi.encode(PERMIT_TYPEHASH, mockMultisig, address(0xCAFE), 1e18, 0, block.timestamp))
                )
            )
        );

        (uint8 v2, bytes32 r2, bytes32 s2) = vm.sign(
            uint256(0xCEEE),
            keccak256(
                abi.encodePacked(
                    "\x19\x01",
                    sDAI.DOMAIN_SEPARATOR(),
                    keccak256(abi.encode(PERMIT_TYPEHASH, mockMultisig, address(0xCAFE), 1e18, 0, block.timestamp))
                )
            )
        );

        bytes memory signature = abi.encode(r, s, bytes32(uint256(v) << 248), r2, s2, bytes32(uint256(v2) << 248));

        vm.expectRevert("SavingsXDai/invalid-permit");
        sDAI.permit(mockMultisig, address(0xCAFE), 1e18, block.timestamp, signature);
    }
}
