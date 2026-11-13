// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import {Script, console} from "forge-std/Script.sol";
import {YearnCurveLPVaultFactory} from "src/USG/Utilities/YearnCurveLPVaultFactory.sol";
import {IYearnRoleManager} from "src/interfaces/externals/YearnFi/IYearnRoleManager.sol";

/// forge script script/DeployYearnLPVaultFactory.s.sol --rpc-url mainnet --account <keystore> --broadcast --verify
contract DeployYearnLPVaultFactory is Script {
    address constant YEARN_BRAIN = 0x16388463d60FFE0661Cf7F1f31a7D658aC790ff7; // factory owner
    IYearnRoleManager constant YEARN_ROLE_MANAGER = IYearnRoleManager(0xb3bd6B2E61753C311EFbCF0111f75D29706D9a41);

    function run() external returns (YearnCurveLPVaultFactory factory) {
        vm.startBroadcast();
        factory = new YearnCurveLPVaultFactory(YEARN_BRAIN, YEARN_ROLE_MANAGER);
        vm.stopBroadcast();
        console.log("YearnCurveLPVaultFactory", address(factory));
    }
}
