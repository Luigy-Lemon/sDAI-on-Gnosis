// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "script/DeployReceiverAdapter.s.sol";
import "script/SavingsXDaiDeployer.s.sol";

contract DeployScriptsTest is Test {
    function setUp() public {
        vm.createSelectFork("gnosis");
    }

    /// @dev Key path coverage: `testDeployReceiverAdapter` / `testSavingsXDaiDeployer` use the
    ///      long BIP-39 test mnemonic (>30 chars) so `vm.deriveKey` runs; `_WithPrivateKey` tests
    ///      use `MNEMONIC=short` and `PRIVATE_KEY`. `forge coverage` often reports `deriveKey` as
    ///      zero hits on the assignment line (cheatcode), even when that branch executes.

    function testDeployReceiverAdapter() public {
        vm.setEnv("SDAI_ADDRESS", "0x0000000000000000000000000000000000000001");
        vm.setEnv("MNEMONIC", "test test test test test test test test test test test junk");

        vm.deal(0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266, 2 ether);

        DeployReceiverAdapter script = new DeployReceiverAdapter();
        script.run();
    }

    function testSavingsXDaiDeployer() public {
        vm.setEnv("MNEMONIC", "test test test test test test test test test test test junk");

        vm.deal(0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266, 2 ether);

        SavingsXDaiDeployer script = new SavingsXDaiDeployer();
        script.run();
    }

    function testDeployReceiverAdapter_WithPrivateKey() public {
        vm.setEnv("SDAI_ADDRESS", "0x0000000000000000000000000000000000000001");
        vm.setEnv("MNEMONIC", "short");
        vm.setEnv("PRIVATE_KEY", "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80");

        vm.deal(0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266, 2 ether);

        DeployReceiverAdapter script = new DeployReceiverAdapter();
        script.run();
    }

    function testSavingsXDaiDeployer_WithPrivateKey() public {
        vm.setEnv("MNEMONIC", "short");
        vm.setEnv("PRIVATE_KEY", "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80");

        vm.deal(0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266, 2 ether);

        SavingsXDaiDeployer script = new SavingsXDaiDeployer();
        script.run();
    }
}
