// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import {Script, console} from "forge-std/Script.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {VsTAN} from "src/USG/Tokens/VsTAN.sol";
import {IControlTower} from "src/interfaces/internals/USG/IControlTower.sol";
import {IZappingProxy} from "src/interfaces/internals/USG/IZappingProxy.sol";

/// Optimizer is needed to fit EIP-170.
/// FOUNDRY_OPTIMIZER=true FOUNDRY_OPTIMIZER_RUNS=200 forge script script/DeployVsTAN.s.sol --rpc-url mainnet --account <keystore> --broadcast --verify
contract DeployVsTAN is Script {
    // PROD_ADDRESSES.DAO
    address constant ADMIN_TAN = 0x461B62CB3A7e9Df8f800aE058AE92F855F2c27Ca;
    IControlTower constant CTRL_TWER = IControlTower(0xF3f7669dcEED2f985815011C19eD68F667267215);
    IERC20 constant TAN = IERC20(0xe6a705945Bf67a43BBb237B9EbD2C77801483eAc);
    IERC20 constant USG = IERC20(0xB1c2Db5d6cA03FCe73dBd304d320bF76C55Ae1B1);
    IERC4626 constant sUSG = IERC4626(0xF17D6f98A5C6EAA99d149079984119e0A4EF6900);
    IZappingProxy constant ZAPPING_PROXY = IZappingProxy(0xA9E0021d8917C51F496823605d218d7E78719c99);
    uint256 constant MIN_LOCK = 10 ether;

    function run() external returns (VsTAN vsTAN) {
        vm.startBroadcast();
        vsTAN = new VsTAN(ADMIN_TAN, CTRL_TWER, TAN, USG, sUSG, ZAPPING_PROXY, MIN_LOCK);
        vm.stopBroadcast();

        require(vsTAN.owner() == ADMIN_TAN, "owner");
        require(vsTAN.controlTower() == CTRL_TWER, "controlTower");
        require(vsTAN.tan() == TAN, "tan");
        require(vsTAN.USG() == USG, "USG");
        require(vsTAN.sUSG() == sUSG, "sUSG");
        require(vsTAN.zappingProxy() == ZAPPING_PROXY, "zappingProxy");
        require(vsTAN.minLock() == MIN_LOCK, "minLock");
        require(vsTAN.nextId() == 1, "nextId");
        require(USG.allowance(address(vsTAN), address(sUSG)) == type(uint256).max, "USG->sUSG allowance");
        (uint128 kickDelay, uint128 kickPct) = vsTAN.kick();
        require(kickDelay == 1 weeks && kickPct == 250, "kick");
        require(sUSG.asset() == address(USG), "sUSG asset != USG");

        console.log("vsTAN deployed at", address(vsTAN));
    }
}
