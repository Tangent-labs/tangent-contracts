// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import {Script, console} from "forge-std/Script.sol";
import {YearnCurveLPVaultFactory} from "src/USG/Utilities/YearnCurveLPVaultFactory.sol";

/// forge script script/DeployYearnLPVaultFactory.s.sol --rpc-url mainnet --account <keystore> --broadcast --verify
contract DeployYearnLPVaultFactory is Script {
    address constant MULTISIG = 0x461B62CB3A7e9Df8f800aE058AE92F855F2c27Ca;

    function run() external returns (YearnCurveLPVaultFactory factory) {
        vm.startBroadcast();
        factory = new YearnCurveLPVaultFactory(MULTISIG);
        vm.stopBroadcast();
        console.log("YearnCurveLPVaultFactory", address(factory));
    }
}
