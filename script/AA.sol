// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";

contract DeployEmptyContract is Script {
    function run() external {
        vm.startBroadcast();
        new EmptyContract();
        vm.stopBroadcast();
    }
}
contract EmptyContract {
    // Un contrat vide sans aucune logique
}
