// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import {Script, console} from "forge-std/Script.sol";
import {FeeDispatcher, IERC20, IZappingProxy, IAggregatorStablePriceV3} from "../src/USG/Utilities/FeeDispatcher.sol";

/// forge script script/DeployFeeDispatcher.s.sol --rpc-url mainnet --account <keystore> --broadcast --verify
contract DeployFeeDispatcher is Script {
    address constant ADMIN = 0x461B62CB3A7e9Df8f800aE058AE92F855F2c27Ca;
    // PROD_ADDRESSES.ORACLES.CHAINLINK.crvUSD
    IERC20 constant USG = IERC20(0xB1c2Db5d6cA03FCe73dBd304d320bF76C55Ae1B1);
    IZappingProxy constant ZAPPING_PROXY = IZappingProxy(0xA9E0021d8917C51F496823605d218d7E78719c99);
    IAggregatorStablePriceV3 constant USG_ORACLE = IAggregatorStablePriceV3(0x970b2F2cEc66F92dE81DAe6af363d1D135dD2F97);
    address constant DAO = 0xd2c46b4c28f4B7976d9f87687863c46Bb2f71Dbb;
    uint256 constant lastDispatch = 11;
    uint256 constant minDispatch = 2500 ether;

    function run() external returns (FeeDispatcher feeDispatcher) {
        vm.startBroadcast();
        feeDispatcher = new FeeDispatcher(ADMIN, USG,ZAPPING_PROXY, USG_ORACLE,DAO,lastDispatch, minDispatch );
        vm.stopBroadcast();

        console.log("feeDispatche", address(feeDispatcher));
    }
}
