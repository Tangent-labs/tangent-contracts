// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.24;

// import {Test, console} from "forge-std/Test.sol";
// import {Upgrades, Options} from "openzeppelin-foundry-upgrades/Upgrades.sol";

// contract UpgradeableValidateTest is Test {
//     function test_validateImplem() external {
//         Options memory opts;
//         Upgrades.validateImplementation("CurveLendSplitterToken.sol:CurveLendSplitterToken", opts);
//     }
//     function test_validateUpgrade() external {
//         Options memory opts;
//         opts.referenceContract = "CurveLendSplitterToken.sol:CurveLendSplitterToken";
//         Upgrades.validateUpgrade("CurveLendSplitterTokenStreamV2.sol:CurveLendSplitterTokenStreamV2", opts);
//     }
// }
