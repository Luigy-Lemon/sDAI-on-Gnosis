// SPDX-License-Identifier: gpl-2.0
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "src/BridgeInterestReceiver.sol";
import "src/periphery/SavingsXDaiAdapter.sol";

contract DeployReceiverAdapter is Script {
    function run() external {
        address sDAI = vm.envAddress("SDAI_ADDRESS");

        uint256 deployerPrivateKey;
        string memory mnemonic = vm.envString("MNEMONIC");

        if (bytes(mnemonic).length > 30) {
            deployerPrivateKey = vm.deriveKey(mnemonic, 0);
        } else {
            deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        }

        vm.startBroadcast(deployerPrivateKey);
        address deployer = vm.rememberKey(deployerPrivateKey);
        console.log("Deployer: %s", deployer);
        console.log("sDAI: %s", sDAI);

        BridgeInterestReceiver interestReceiver = new BridgeInterestReceiver(sDAI);
        console.log("Deployed InterestReceiver: %s", address(interestReceiver));

        SavingsXDaiAdapter adapter = new SavingsXDaiAdapter(address(interestReceiver), payable(sDAI));
        console.log("Deployed SavingsXDaiAdapter: %s", address(adapter));

        // Seed interestReceiver with initial XDAI (MIN_INITIAL_BALANCE = 1 ether)
        payable(address(interestReceiver)).transfer(1 ether);
        console.log("Transferred 1 XDAI to InterestReceiver");

        // Attempt initialization — requires interestReceiver balance >= MIN_INITIAL_BALANCE
        try interestReceiver.initialize(address(adapter)) {
            console.log("InterestReceiver initialized with claimer: %s", address(adapter));
        } catch {
            console.log("InterestReceiver not initialized: fund with >= 1 XDAI then call initialize(%s)", address(adapter));
        }

        vm.stopBroadcast();
    }
}
