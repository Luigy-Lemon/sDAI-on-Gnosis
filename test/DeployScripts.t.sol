// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import {BridgeInterestReceiver} from "src/BridgeInterestReceiver.sol";
import "script/DeployReceiverAdapter.s.sol";
import "script/SavingsXDaiDeployer.s.sol";

contract DeployScriptsTest is Test {
    /// @dev Mirrors on-chain {BridgeInterestReceiver.MIN_INITIAL_BALANCE} (probe deploy; vault unused).
    uint256 internal minInitialBalance;

    /// @dev Labeled broadcast EOA from {makeAddrAndKey} — must match script `PRIVATE_KEY` / `MNEMONIC=short` path.
    address internal broadcastSender;
    uint256 internal broadcastPrivateKey;

    function setUp() public {
        vm.createSelectFork("gnosis");
        minInitialBalance = (new BridgeInterestReceiver(address(1))).MIN_INITIAL_BALANCE();
        (broadcastSender, broadcastPrivateKey) = makeAddrAndKey("my_name");
    }

    function _privateKeyEnv(uint256 pk) private pure returns (string memory) {
        bytes memory alphabet = "0123456789abcdef";
        bytes32 v = bytes32(pk);
        bytes memory buf = new bytes(66);
        buf[0] = "0";
        buf[1] = "x";
        for (uint256 i; i < 32; ++i) {
            uint8 b = uint8(v[i]);
            buf[2 + 2 * i] = alphabet[b >> 4];
            buf[3 + 2 * i] = alphabet[b & 0x0f];
        }
        return string(buf);
    }

    /// @dev Scripts take `PRIVATE_KEY` when `MNEMONIC` is short — aligns `vm.deal` with `vm.startBroadcast` signer.
    function _useBroadcastKey() internal {
        vm.setEnv("MNEMONIC", "short");
        vm.setEnv("PRIVATE_KEY", _privateKeyEnv(broadcastPrivateKey));
    }

    function _dealDeployer() internal {
        // Script transfers `MIN_INITIAL_BALANCE` to the receiver; leave headroom for gas.
        vm.deal(broadcastSender, minInitialBalance * 2);
    }

    /// @dev All four tests use {makeAddrAndKey} + `PRIVATE_KEY` so the funded EOA matches the broadcast signer.
    ///      `forge coverage` often reports zero hits on the `vm.deriveKey` line in scripts even when the
    ///      mnemonic branch runs in other environments.

    function testDeployReceiverAdapter() public {
        vm.setEnv("SDAI_ADDRESS", "0x0000000000000000000000000000000000000001");
        _useBroadcastKey();
        _dealDeployer();

        DeployReceiverAdapter script = new DeployReceiverAdapter();
        script.run();
    }

    function testSavingsXDaiDeployer() public {
        _useBroadcastKey();
        _dealDeployer();

        SavingsXDaiDeployer script = new SavingsXDaiDeployer();
        script.run();
    }

    function testDeployReceiverAdapter_WithPrivateKey() public {
        vm.setEnv("SDAI_ADDRESS", "0x0000000000000000000000000000000000000001");
        _useBroadcastKey();
        _dealDeployer();

        DeployReceiverAdapter script = new DeployReceiverAdapter();
        script.run();
    }

    function testSavingsXDaiDeployer_WithPrivateKey() public {
        _useBroadcastKey();
        _dealDeployer();

        SavingsXDaiDeployer script = new SavingsXDaiDeployer();
        script.run();
    }
}
