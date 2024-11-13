// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.22;

import "forge-std/console.sol";
import "forge-std/Test.sol";
import {StdCheats} from "forge-std/StdCheats.sol";
import {StdUtils} from "forge-std/StdUtils.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {UpgradeableBeacon} from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import {ProxyAdmin} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {Upgrades, Options} from "openzeppelin-foundry-upgrades/Upgrades.sol";

import "../../../src/libs/Resources/ResourcesGlobal.sol";

import "../../../src/libs/Resources/ResourcesConvex.sol";
import "../../../src/libs/Resources/ResourcesCurveLP.sol";
import "../../../src/tgUSD/Oracles/CurveStableLPOracle.sol";

import "../../../src/tgUSD/Utilities/IRMinter.sol";
import "../../../src/tgUSD/Utilities/RewardAccumulator.sol";
import "../../../src/tgUSD/tokens/tgUSD.sol";
import "../../../src/tgUSD/Oracles/tgUSDOracle.sol";

import "../../utils/AssertERC20.sol";

contract TgUSDDeployContext is StdCheats, StdUtils, AssertERC20 {
    address usr1 = makeAddr("User1");
    address usr2 = makeAddr("User2");
    address usr3 = makeAddr("User3");
    address usr4 = makeAddr("User4");
    address usr5 = makeAddr("User5");
    address usr6 = makeAddr("User6");

    address processor = makeAddr("Processor");

 

    address public owner = makeAddr("Owner");
    address public ownerGauge = makeAddr("ownerGauge");
    address public feeTreasury = makeAddr("feeTreasury");

    address public endpointAddressMainnet = 0x1a44076050125825900e736c501f859c50fE728c;

    tgUSDOracle public tgUsdOracle;

    ICurveStableSwapNG public tgUSDLp;

    tgUSD public tgUsd;

    IRMinter public irMinter;

    RewardAccumulator public rewardAccumulator;

    /// @dev Validate Implementation (false if you don't want to "forge clean" at each modification)
    bool constant IS_VALIDATE_IMPLEM = false;

    function deployBaseContracts() public {
        vm.createSelectFork("mainnet", 21093905);

        /// Deploy tgUSD
        tgUsd = new tgUSD("Tangent StableCoin", "tgUSD", endpointAddressMainnet, makeAddr("a"));
        tgUsd.mint(owner, 1_000_000 ether);

        irMinter = new IRMinter(owner, feeTreasury, tgUsd);

        /// Deploy and addLiquidity in tgUSD LP
        tgUSDLp = deployTgUSDLP();
        /// Deploy tgUSD oracle price
        tgUsdOracle = new tgUSDOracle(tgUSDLp, IPriceOracle(address(AddrChainlinkOracle.USDC)), 6);

        rewardAccumulator = new RewardAccumulator(owner, feeTreasury);
    }

    function deployTgUSDLP() public returns (ICurveStableSwapNG) {
        // Give usdc to owner before LP deployment
        deal(address(AddrClassicERC20.TOKEN_USDC), owner, 1_000_000 * 10 ** 6);
        vm.startPrank(owner);

        address[] memory tokens = new address[](2);
        tokens[0] = address(AddrClassicERC20.TOKEN_USDC);
        tokens[1] = address(tgUsd);

        uint8[] memory assetTypes = new uint8[](2);
        assetTypes[0] = 0;
        assetTypes[1] = 0;

        bytes4[] memory methodIds = new bytes4[](2);
        methodIds[0] = bytes4(0);
        methodIds[1] = bytes4(0);

        address[] memory oracles = new address[](2);
        oracles[0] = address(0);
        oracles[1] = address(0);

        ICurveStableSwapNG lpTgUSD = ICurveStableSwapNG(
            AddrCurveStableLP.STABLE_SWAP_FACTORY.deploy_plain_pool(
                "tgUSD-USDC",
                "tgUSD-USDC",
                tokens,
                5000,
                100000000,
                0,
                866,
                0,
                assetTypes,
                methodIds,
                oracles
            )
        );

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = uint256(1_000_000 * 10 ** 6);
        amounts[1] = uint256(1_000_000 ether);

        AddrClassicERC20.TOKEN_USDC.approve(address(lpTgUSD), MAX_UINT);
        tgUsd.approve(address(lpTgUSD), MAX_UINT);

        lpTgUSD.add_liquidity(amounts, uint256(0));

        return lpTgUSD;
    }
}
