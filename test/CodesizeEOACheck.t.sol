// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.19;

import "forge-std/Test.sol";

contract Target {
    modifier onlyEOA() {
        require(msg.sender.code.length == 0, "Not EOA");
        _;
    }

    function guarded() external view onlyEOA returns (bool) {
        return true;
    }
}

contract Caller {
    Target public target;

    constructor(address _target) {
        target = Target(_target);
    }

    function callGuarded() external view returns (bool) {
        return target.guarded();
    }
}

contract CodesizeEOACheckTest is Test {
    Target public target;
    address public eoa = makeAddr("eoa");
    Caller public caller;

    function setUp() public {
        target = new Target();
        caller = new Caller(address(target));
    }

    function test_EOA_PassesCodesizeCheck() public {
        vm.prank(eoa);
        assertTrue(target.guarded());
    }

    function test_Contract_RejectedByCodesizeCheck() public {
        vm.prank(address(caller));
        vm.expectRevert("Not EOA");
        target.guarded();
    }

    function test_DelegatedEOA_RejectedByCodesizeCheck() public {
        // EIP-7702 sets delegation designation (0xef0100 || address, 23 bytes) as the EOA's code.
        // This makes code.length > 0, so codesize check correctly blocks it.
        // Simulate by etching arbitrary non-zero bytecode to the EOA address.
        bytes memory fakeCode = hex"6000";

        vm.etch(eoa, fakeCode);
        assertGt(eoa.code.length, 0);

        vm.prank(eoa);
        vm.expectRevert("Not EOA");
        target.guarded();
    }

    function test_CallerContractViaAdapter_RejectedByCodesizeCheck() public {
        vm.expectRevert("Not EOA");
        caller.callGuarded();
    }
}
