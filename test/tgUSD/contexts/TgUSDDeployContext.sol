// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.22;

import "forge-std/console.sol";
import {StdCheats} from "forge-std/StdCheats.sol";
import {StdUtils} from "forge-std/StdUtils.sol";

import "../../../src/libs/Resources/ResourcesConvex.sol";
import "../../../src/libs/Resources/ResourcesCurveLP.sol";

import "../../../src/tgUSD/tokens/TgUSD.sol";
import "../../../src/tgUSD/tokens/TgStable.sol";
import "../../../src/tgUSD/Utilities/RewardAccumulator.sol";
import "../../../src/tgUSD/Utilities/Zapper.sol";
import "../../../src/tgUSD/Utilities/ControlTower.sol";
import "../../../src/tgUSD/Utilities/MarketCreator.sol";
import "../../../test/tgUSD/mocks/MockEnsoRouter.sol";
import "../../../src/tgUSD/Market/Convex/ConvexCrvLPMarket.sol";
import "../../../src/tgUSD/Market/Convex/ConvexFxnLPMarket.sol";
import "../../../src/tgUSD/Market/MarketNoSociabilization.sol";
import "../../utils/AssertERC20.sol";
import "../../utils/LowLevel.sol";
import "../../utils/EnsoUtils.sol";
import "../../utils/Labeliser.sol";
import "../../utils/Array.sol";

contract TgUSDDeployContext is StdCheats, StdUtils, AssertERC20, LowLevel {
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
    address public mockedLP = makeAddr("Mocked LP");

    address public endpointAddressMainnet = 0x1a44076050125825900e736c501f859c50fE728c;

    ControlTower public controlTower;
    MarketCreator public marketCreator;
    address public convexCrvLPMarketImplem;
    address public convexFxnLPMarketImplem;
    address public marketNoSociabilizationImplem;
    Zapper public zapper;
    ICurveStableSwapNG public tgUSDLp;
    TgUSD public tgUsd;
    RewardAccumulator public rewardAccumulator;
    MockEnsoRouter public mockEnsoRouter;
    EnsoUtils public ensoUtils;
    Labeliser public labeliser;

    /// @dev Validate Implementation (false if you don't want to "forge clean" at each modification)
    bool constant IS_VALIDATE_IMPLEM = false;

    constructor() {
        vm.createSelectFork("mainnet", 21514132);

        vm.startPrank(owner);

        convexCrvLPMarketImplem = address(new ConvexCrvLPMarket());
        convexFxnLPMarketImplem = address(new ConvexFxnLPMarket());
        marketNoSociabilizationImplem = address(new MarketNoSociabilization());

        ensoUtils = new EnsoUtils();

        labeliser = new Labeliser();
        labeliser.labelizeERC20();
        labeliser.labelizeERC4626();

        controlTower = new ControlTower(owner, feeTreasury);

        rewardAccumulator = new RewardAccumulator(owner, controlTower, feeTreasury);

        // Deploy tgUSD
        tgUsd = new TgUSD("Tangent StableCoin", "tgUSD", endpointAddressMainnet, makeAddr("a"), owner, controlTower);

        mockEnsoRouter = new MockEnsoRouter();

        vm.allowCheatcodes(address(AddrAggregator.ENSO_ROUTER));
        zapper = new Zapper(owner, controlTower, tgUsd);

        controlTower.toggleZapper(address(zapper));

        deal(address(tgUsd), owner, 1_000_000 ether);

        // Deploy and addLiquidity in tgUSD LP
        tgUSDLp = deployTgUSDLP();

        vm.label(address(tgUsd), "tgUSD");
        vm.label(address(controlTower), "ControlTower");
        vm.label(address(tgUSDLp), "LP tgUSD");
        vm.label(address(rewardAccumulator), "RewardAccumulator");
        vm.label(address(AddrAggregator.ENSO_ROUTER), "Enso Router");
        vm.label(address(mockEnsoRouter), "Mock Odos Router");

        vm.stopPrank();
    }

    function deployTgUSDLP() public returns (ICurveStableSwapNG) {
        // Give usdc to owner before LP deployment
        deal(address(AddrClassicERC20.TOKEN_USDC), owner, 1_000_000 * 10 ** 6);
        vm.startPrank(owner);

        ICurveStableSwapNG lpTgUSD = ICurveStableSwapNG(
            AddrCurveStableLP.STABLE_SWAP_FACTORY.deploy_plain_pool(
                "tgUSD-USDC",
                "tgUSD-USDC",
                Array.memoryAddress([address(AddrClassicERC20.TOKEN_USDC), address(tgUsd)]),
                5000,
                100000000,
                0,
                866,
                0,
                Array.memoryUint8([uint8(0), uint8(0)]),
                Array.memoryBytes4([bytes4(0), bytes4(0)]),
                Array.memoryAddress([address(0), address(0)])
            )
        );

        AddrClassicERC20.TOKEN_USDC.approve(address(lpTgUSD), MAX_UINT);
        tgUsd.approve(address(lpTgUSD), MAX_UINT);

        lpTgUSD.add_liquidity(Array.memoryUint256([uint256(1_000_000 * 10 ** 6), uint256(1_000_000 ether)]), uint256(0));

        return lpTgUSD;
    }
}
