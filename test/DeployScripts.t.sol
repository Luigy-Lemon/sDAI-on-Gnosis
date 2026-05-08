// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import {BridgeInterestReceiver} from "src/BridgeInterestReceiver.sol";
import "script/DeployReceiverAdapter.s.sol";
import "script/SavingsXDaiDeployer.s.sol";

contract DeployScriptsTest is Test {
    /// @dev Mirrors on-chain {BridgeInterestReceiver.MIN_INITIAL_BALANCE} (probe deploy; vault unused).
    uint256 internal minInitialBalance;

    /// @dev Default broadcast account used by these script tests (`vm.deal` target).
    address internal constant BROADCAST_SENDER = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;

    function setUp() public {
        vm.createSelectFork("gnosis");
        minInitialBalance = (new BridgeInterestReceiver(address(1))).MIN_INITIAL_BALANCE();
    }

    function _dealDeployer() internal {
        // Script transfers `MIN_INITIAL_BALANCE` to the receiver; leave headroom for gas.
        vm.deal(BROADCAST_SENDER, minInitialBalance * 2);
    }

    /// @dev Key path coverage: `testDeployReceiverAdapter` / `testSavingsXDaiDeployer` use the
    ///      long BIP-39 test mnemonic (>30 chars) so `vm.deriveKey` runs; `_WithPrivateKey` tests
    ///      use `MNEMONIC=short` and `PRIVATE_KEY`. `forge coverage` often reports `deriveKey` as
    ///      zero hits on the assignment line (cheatcode), even when that branch executes.

    function testDeployReceiverAdapter() public {
        vm.setEnv("SDAI_ADDRESS", "0x0000000000000000000000000000000000000001");
        vm.setEnv("MNEMONIC", "test test test test test test test test test test test junk");

        _dealDeployer();

        DeployReceiverAdapter script = new DeployReceiverAdapter();
        script.run();
    }

    function testSavingsXDaiDeployer() public {
        vm.setEnv("MNEMONIC", "test test test test test test test test test test test junk");

        _dealDeployer();

        SavingsXDaiDeployer script = new SavingsXDaiDeployer();
        script.run();
    }

    function testDeployReceiverAdapter_WithPrivateKey() public {
        vm.setEnv("SDAI_ADDRESS", "0x0000000000000000000000000000000000000001");
        vm.setEnv("MNEMONIC", "short");
        vm.setEnv("PRIVATE_KEY", "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80");

        _dealDeployer();

        DeployReceiverAdapter script = new DeployReceiverAdapter();
        script.run();
    }

    function testSavingsXDaiDeployer_WithPrivateKey() public {
        vm.setEnv("MNEMONIC", "short");
        vm.setEnv("PRIVATE_KEY", "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80");

        _dealDeployer();

        SavingsXDaiDeployer script = new SavingsXDaiDeployer();
        script.run();
    }
}
