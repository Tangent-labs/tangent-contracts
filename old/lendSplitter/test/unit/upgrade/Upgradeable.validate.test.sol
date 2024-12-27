// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.24;

// import {Test, console} from "forge-std/Test.sol";
// import {Upgrades, Options} from "openzeppelin-foundry-upgrades/Upgrades.sol";

// contract UpgradeableValidateTest is Test {
//     function test_validateImplem() external {
//         Options memory opts;
//         Upgrades.validateImplementation("SplitterToken.sol:SplitterToken", opts);
//     }
//     function test_validateUpgrade() external {
//         Options memory opts;
//         opts.referenceContract = "SplitterToken.sol:SplitterToken";
//         Upgrades.validateUpgrade("SplitterTokenStreamV2.sol:SplitterTokenStreamV2", opts);
//     }
// }
