// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.24;

// import {Test, console} from "forge-std/Test.sol";
// import {SplitterToken} from "../../src/tokens/SplitterToken.sol";
// import {LendRewardSplitter} from "../../src/LendRewardSplitter.sol";
// import {UpgradeableBeacon} from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
// import {BeaconProxy} from "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
// import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
// import {ProxyAdmin} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
// import {Upgrades, Options} from "openzeppelin-foundry-upgrades/Upgrades.sol";

// contract UpgradeableDeployTransparentProxy is Test {
//     address owner = makeAddr("Owner");

//     // function test_deploy_transparent_proxy() external {
//     //     //deploy ProxyAdmin
//     //     vm.prank(owner);
//     //     address proxyAdmin = address(new ProxyAdmin(owner));
//     //     //validate Implementation
//     //     Options memory opts;
//     //     Upgrades.validateImplementation("LendRewardSplitter.sol:LendRewardSplitter", opts);
//     //     //deploy Implem & Proxy
//     //     address proxyAddress = address(
//     //         new TransparentUpgradeableProxy(
//     //             address(new LendRewardSplitter()),
//     //             proxyAdmin,
//     //             abi.encodeCall(LendRewardSplitter.initialize, (owner))
//     //         )
//     //     );
//     //     console.log("proxyAddress", proxyAddress);
//     // }

//     function test_deploy_beacon_proxy() external {
//         //deploy ProxyAdmin
//         vm.prank(owner);
//         address proxyAdmin = address(new ProxyAdmin(owner));
//         // //validate Implementation
//         // Options memory opts;
//         // Upgrades.validateImplementation("SplitterToken.sol:SplitterToken", opts);
//         //deploy Implem & Proxy

//         address upgradeableBeaconProxy = address(new UpgradeableBeacon(address(new SplitterToken()), owner));
//         console.log("upgradeableBeaconProxy", upgradeableBeaconProxy);
//     }
// }
