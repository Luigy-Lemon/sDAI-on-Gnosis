// SPDX-License-Identifier: gpl-2.0
pragma solidity 0.8.19;

import 'forge-std/Script.sol';
import 'forge-std/console.sol';
import 'src/GnosisSavingsDAI.sol';
import 'src/BridgeInterestReceiver.sol';


contract GnosisSavingsDAIDeployer is Script {

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

        GnosisSavingsDAI sDAI = new GnosisSavingsDAI(address(interestReceiver));
        console.log('Deployed sDAI on Gnosis: %s', address(sDAI));

        interestReceiver.initialize(address(sDAI));
        console.log('Initialized InterestReceiver');

        vm.stopBroadcast();
    }
}
