// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "forge-std/Script.sol";

contract T is Script {
    function run() external {
        vm.startBroadcast();
        // Minimal deployment
        address test = address(new SimpleContract());
        console.log("Deployed to:", test);
        vm.stopBroadcast();
    }
}

contract SimpleContract {
    // Simple contract to test deployment
}
