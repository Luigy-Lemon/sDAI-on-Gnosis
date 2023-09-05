// SPDX-License-Identifier: gpl-2.0
pragma solidity ^0.8.20;

import 'forge-std/Script.sol';
import 'forge-std/console.sol';
import 'src/SavingsXDai.sol';
import 'src/BridgeInterestReceiver.sol';
import 'src/periphery/SavingsXDaiAdapter.sol';


contract SavingsXDaiDeployer is Script {

    function run() external {

        /*//////////////////////////////////////////////////////////////
                                KEY MANAGEMENT
        //////////////////////////////////////////////////////////////*/

        uint256 deployerPrivateKey = 0;
        string memory mnemonic = vm.envString('MNEMONIC');

        if (bytes(mnemonic).length > 30) {
            deployerPrivateKey = vm.deriveKey(mnemonic, 0);
        } else {
            deployerPrivateKey = vm.envUint('PRIVATE_KEY');
        }

        vm.startBroadcast(deployerPrivateKey);
        address deployer = vm.rememberKey(deployerPrivateKey);
        console.log('Deployer: %s', deployer);

        /*//////////////////////////////////////////////////////////////
                                DEPLOYMENTS
        //////////////////////////////////////////////////////////////*/

        BridgeInterestReceiver interestReceiver = new BridgeInterestReceiver();
        console.log('Deployed InterestReceiver: %s', address(interestReceiver));

        SavingsXDai sDAI = new SavingsXDai("Savings xDAI", "sDAI");
        console.log('Deployed sDAI on Chiado: %s', address(sDAI));

        SavingsXDaiAdapter adapter = new SavingsXDaiAdapter(address(interestReceiver), payable(sDAI));
        console.log('Deployed SavingsXDaiAdapter on Chiado: %s', address(adapter));

        interestReceiver.initialize(address(sDAI));
        console.log('Initialized InterestReceiver');

        vm.stopBroadcast();
    }
}
