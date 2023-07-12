// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import 'forge-std/console.sol';
import "./Setup.t.sol";
import "./Mocks/MockMultisig.sol";


contract GnosisSavingsDAITest is SetupTest{

    bytes32 constant PERMIT_TYPEHASH = keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");

    function invariantMetadata() public {
        assertEq(address(sDAI.interestReceiver()), address(interestReceiver));
        assertEq(address(sDAI.wxdai()), address(wxdai));
        assertEq(alice, address(10));
        assertEq(bob, address(11));
    }

    

    /*//////////////////////////////////////////////////////////////
                        CORE LOGIC
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

        vm.expectRevert("SavingsDai/invalid-permit");
        sDAI.permit(mockMultisig, address(0xCAFE), 1e18, block.timestamp, signature);
    }
}
