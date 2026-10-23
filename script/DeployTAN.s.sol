// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import {Script, console} from "forge-std/Script.sol";
import {TAN} from "src/USG/Tokens/TAN.sol";

/// forge script script/DeployTAN.s.sol --rpc-url $RPC_URL --account <keystore> --broadcast --verify
contract DeployTAN is Script {
    address constant DAO = 0xd2c46b4c28f4B7976d9f87687863c46Bb2f71Dbb;

    function run() external returns (TAN tan) {
        vm.startBroadcast();
        tan = new TAN(DAO);
        vm.stopBroadcast();

        require(tan.balanceOf(DAO) == 10_000_000 ether, "DAO supply");
        console.log("TAN deployed at", address(tan));
    }
}
