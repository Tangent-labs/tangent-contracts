// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "../../contexts/MarketDeploymentContext.sol";

import {FeeDispatcher} from "../../../src/USG/Utilities/FeeDispatcher.sol";
import {OracleCurveEmaOrSpot, CurvePoolType} from "../../../src/USG/Oracles/Token/OracleCurveEmaOrSpot.sol";
import {MockOracle} from "../../../src/mock/MockOracle.sol";
import {OracleCoinFromCurveLP} from "../../../src/USG/Oracles/Token/OracleCoinFromCurveLP.sol";

/// @dev Fake route that sends USG to the fee treasury (like `IRCalculator.mintIR` would) instead of paying the swap receiver.
contract TreasuryInflatingRouter {
    function swap(IERC20 tokenIn, uint256 amountIn, IERC20 usg, address treasury, uint256 amount) external {
        tokenIn.transferFrom(msg.sender, address(this), amountIn);
        usg.transfer(treasury, amount);
    }
}

contract FeeDispatcherTest is MarketDeploymentContext {
    FeeDispatcher dispatcher;
    MockOracle crvOracle;
    IERC20 crv = IERC20(address(AddrClassicERC20.CRV));

    uint256 constant AMOUNT_CRV = 10_000 ether;
    address constant BOLD_USDC_POOL = 0xEFc6516323FbD28e80B85A497B65A86243a54B3E;

    function setUp() external {
        vm.startPrank(owner);
        dispatcher = new FeeDispatcher(owner, usg, zappingProxy, USGOracle);
        controlTower.setFeeTreasury(address(dispatcher));

        crvOracle = new MockOracle();
        crvOracle.setLastAnswer(0.5 ether);
        dispatcher.setTokenConfig(crv, crvOracle, 100);

        sUSG.add_role(address(dispatcher), 32);
        vsTan.setRewardDistributor(address(dispatcher));
        vm.stopPrank();

        deal(address(crv), address(dispatcher), AMOUNT_CRV);
        deal(address(usg), address(mockRouter), 1_000_000 ether);
    }

    function _mockZap(IERC20 tokenIn, uint256 amountIn, uint256 amountOut, address receiver) internal view returns (ZapStruct memory) {
        return ZapStruct({router: address(mockRouter), routerCall: abi.encodeCall(MockRouter.swap, (tokenIn, amountIn, usg, receiver, amountOut))});
    }

    function _one(IERC20 tokenIn, uint256 amountIn, uint256 minAmountOut, ZapStruct memory zap) internal pure returns (FeeDispatcher.DumpParams[] memory dumps) {
        dumps = new FeeDispatcher.DumpParams[](1);
        dumps[0] = FeeDispatcher.DumpParams({tokenIn: tokenIn, amountIn: amountIn, minAmountOut: minAmountOut, zap: zap});
    }

    /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
                            DUMP
    =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */

    function test_dump_at_floor() external {
        uint256 floor = dispatcher.oracleFloor(crv, AMOUNT_CRV);
        assertEq(floor, ((((AMOUNT_CRV / 2) * 1e18) / dispatcher.usgPrice()) * 9_900) / 10_000, "Floor");

        vm.prank(usr1);
        dispatcher.dump(_one(crv, AMOUNT_CRV, floor, _mockZap(crv, AMOUNT_CRV, floor, address(dispatcher.receiver()))));

        assertEq(usg.balanceOf(address(dispatcher)), floor, "USG received");
        assertEq(usg.balanceOf(address(dispatcher.receiver())), 0, "Receiver emptied");
        assertEq(crv.balanceOf(address(dispatcher)), 0, "CRV sold");
    }

    function test_dump_reverts_caller_min_below_floor() external {
        uint256 floor = dispatcher.oracleFloor(crv, AMOUNT_CRV);
        ZapStruct memory zap = _mockZap(crv, AMOUNT_CRV, floor, address(dispatcher.receiver()));

        vm.prank(usr1);
        vm.expectRevert(FeeDispatcher.MinBelowFloor.selector);
        dispatcher.dump(_one(crv, AMOUNT_CRV, floor - 1, zap));
    }

    function test_dump_reverts_route_below_floor() external {
        uint256 floor = dispatcher.oracleFloor(crv, AMOUNT_CRV);
        ZapStruct memory zap = _mockZap(crv, AMOUNT_CRV, floor - 1, address(dispatcher.receiver()));

        vm.prank(usr1);
        vm.expectRevert(ZappingProxy.MinAmountOutNotReached.selector);
        dispatcher.dump(_one(crv, AMOUNT_CRV, floor, zap));
    }

    function test_dump_caller_min_above_floor_is_kept() external {
        uint256 floor = dispatcher.oracleFloor(crv, AMOUNT_CRV);
        ZapStruct memory zap = _mockZap(crv, AMOUNT_CRV, floor, address(dispatcher.receiver()));

        vm.prank(usr1);
        vm.expectRevert(ZappingProxy.MinAmountOutNotReached.selector);
        dispatcher.dump(_one(crv, AMOUNT_CRV, floor + 1, zap));
    }

    function _setupPyusd() internal returns (IERC20 pyusd) {
        pyusd = IERC20(address(AddrClassicERC20.PYUSD));
        MockOracle pyusdOracle = new MockOracle();
        vm.prank(owner);
        dispatcher.setTokenConfig(pyusd, pyusdOracle, 30);
        deal(address(pyusd), address(dispatcher), 5_000e6);
    }

    function test_dump_several_tokens() external {
        IERC20 pyusd = _setupPyusd();
        address recv = address(dispatcher.receiver());

        uint256 floorCrv = dispatcher.oracleFloor(crv, AMOUNT_CRV);
        uint256 floorPyusd = dispatcher.oracleFloor(pyusd, 5_000e6);

        FeeDispatcher.DumpParams[] memory dumps = new FeeDispatcher.DumpParams[](2);
        dumps[0] = FeeDispatcher.DumpParams({tokenIn: crv, amountIn: AMOUNT_CRV, minAmountOut: floorCrv, zap: _mockZap(crv, AMOUNT_CRV, floorCrv, recv)});
        dumps[1] = FeeDispatcher.DumpParams({tokenIn: pyusd, amountIn: 5_000e6, minAmountOut: floorPyusd, zap: _mockZap(pyusd, 5_000e6, floorPyusd, recv)});

        vm.prank(usr1);
        uint256 totalOut = dispatcher.dump(dumps);

        assertEq(totalOut, floorCrv + floorPyusd, "Total out");
        assertEq(usg.balanceOf(address(dispatcher)), floorCrv + floorPyusd, "USG received");
        assertEq(usg.balanceOf(recv), 0, "Receiver emptied");
        assertEq(crv.balanceOf(address(dispatcher)), 0, "CRV sold");
        assertEq(pyusd.balanceOf(address(dispatcher)), 0, "PYUSD sold");
    }

    function test_dump_several_tokens_is_atomic() external {
        IERC20 pyusd = _setupPyusd();
        address recv = address(dispatcher.receiver());

        uint256 floorCrv = dispatcher.oracleFloor(crv, AMOUNT_CRV);
        uint256 floorPyusd = dispatcher.oracleFloor(pyusd, 5_000e6);

        // Second route pays 1 wei below its min: the first swap must not go through either
        FeeDispatcher.DumpParams[] memory dumps = new FeeDispatcher.DumpParams[](2);
        dumps[0] = FeeDispatcher.DumpParams({tokenIn: crv, amountIn: AMOUNT_CRV, minAmountOut: floorCrv, zap: _mockZap(crv, AMOUNT_CRV, floorCrv, recv)});
        dumps[1] = FeeDispatcher.DumpParams({tokenIn: pyusd, amountIn: 5_000e6, minAmountOut: floorPyusd, zap: _mockZap(pyusd, 5_000e6, floorPyusd - 1, recv)});

        vm.prank(usr1);
        vm.expectRevert(ZappingProxy.MinAmountOutNotReached.selector);
        dispatcher.dump(dumps);

        assertEq(crv.balanceOf(address(dispatcher)), AMOUNT_CRV, "CRV untouched");
    }

    function test_dump_reverts_not_configured_token() external {
        IERC20 collat = IERC20(address(AddrClassicERC20.USDC));
        deal(address(collat), address(dispatcher), 1_000e6);
        ZapStruct memory zap = _mockZap(collat, 1_000e6, 1_000 ether, address(dispatcher.receiver()));

        vm.prank(usr1);
        vm.expectRevert(abi.encodeWithSelector(FeeDispatcher.TokenNotDumpable.selector, collat));
        dispatcher.dump(_one(collat, 1_000e6, 0, zap));
    }

    function test_dump_treasury_inflation_does_not_count() external {
        TreasuryInflatingRouter router = new TreasuryInflatingRouter();
        uint256 floor = dispatcher.oracleFloor(crv, AMOUNT_CRV);
        deal(address(usg), address(router), floor);

        ZapStruct memory zap = ZapStruct({router: address(router), routerCall: abi.encodeCall(TreasuryInflatingRouter.swap, (crv, AMOUNT_CRV, usg, address(dispatcher), floor))});

        vm.prank(usr1);
        vm.expectRevert(ZappingProxy.MinAmountOutNotReached.selector);
        dispatcher.dump(_one(crv, AMOUNT_CRV, floor, zap));
    }

    function test_getTokens_tracks_configs() external {
        IERC20 pyusd = IERC20(address(AddrClassicERC20.PYUSD));
        IERC20 rlusd = IERC20(address(AddrClassicERC20.RLUSD));

        vm.startPrank(owner);
        dispatcher.setTokenConfig(pyusd, crvOracle, 30);
        dispatcher.setTokenConfig(rlusd, crvOracle, 30);
        // Updating an existing config doesn't add it twice
        dispatcher.setTokenConfig(crv, crvOracle, 200);
        vm.stopPrank();

        FeeDispatcher.TokenWithConfig[] memory tokens = dispatcher.getTokens();
        assertEq(tokens.length, 3, "3 tokens");
        assertEq(address(tokens[0].token), address(crv));
        assertEq(tokens[0].config.maxSlippageBps, 200, "Updated config");
        assertEq(tokens[0].config.decimals, 18, "CRV decimals stored");
        assertEq(tokens[1].config.decimals, 6, "PYUSD decimals stored");
        assertEq(address(tokens[1].token), address(pyusd));
        assertEq(address(tokens[2].token), address(rlusd));

        // Removing (oracle at 0) swaps with the last one
        vm.prank(owner);
        dispatcher.setTokenConfig(crv, IPriceOracle(address(0)), 0);

        tokens = dispatcher.getTokens();
        assertEq(tokens.length, 2, "2 tokens");
        assertEq(address(tokens[0].token), address(rlusd));
        assertEq(address(tokens[1].token), address(pyusd));
    }

    function test_getTokens_balance_and_floor() external {
        FeeDispatcher.TokenWithConfig[] memory tokens = dispatcher.getTokens();
        assertEq(tokens[0].balance, AMOUNT_CRV, "Balance held");
        assertEq(tokens[0].floor, dispatcher.oracleFloor(crv, AMOUNT_CRV), "Floor of the whole balance");

        // A reverting oracle doesn't break the view, floor is 0
        vm.mockCallRevert(address(crvOracle), abi.encodeWithSelector(IPriceOracle.latestAnswer.selector), "stale");
        tokens = dispatcher.getTokens();
        assertEq(tokens[0].balance, AMOUNT_CRV, "Balance still returned");
        assertEq(tokens[0].floor, 0, "Floor 0 on oracle revert");
    }

    function test_setTokenConfig_reverts() external {
        vm.startPrank(owner);
        vm.expectRevert(abi.encodeWithSelector(FeeDispatcher.TokenNotDumpable.selector, usg));
        dispatcher.setTokenConfig(usg, crvOracle, 100);

        vm.expectRevert(FeeDispatcher.SlippageTooHigh.selector);
        dispatcher.setTokenConfig(crv, crvOracle, 501);
        vm.stopPrank();

        vm.prank(usr1);
        vm.expectRevert(abi.encodeWithSelector(LightOwnable.OwnableUnauthorizedAccount.selector, usr1));
        dispatcher.setTokenConfig(crv, crvOracle, 100);
    }

    /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
                            USG PRICE
    =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */

    function test_usgPrice_capped_at_one_and_follows_spot_down() external {
        assertLe(dispatcher.usgPrice(), 1e18, "Capped at 1$");

        ICurveStableSwapNG pool = lpDeploymentContext.USGLPs("USG-USDC");
        assertEq(pool.coins(1), address(usg), "USG is coin 1");

        // Crash USG spot in one pool, EMA doesn't move in the same block
        uint256 emaBefore = USGOracle.price();
        deal(address(usg), usr1, 400_000 ether);
        vm.startPrank(usr1);
        usg.approve(address(pool), MAX_UINT);
        pool.exchange(1, 0, 400_000 ether, 0);
        vm.stopPrank();

        uint256 spot = pool.get_p(0);
        assertEq(USGOracle.price(), emaBefore, "EMA not moved");
        assertLt(spot, emaBefore, "Spot below EMA");
        assertEq(dispatcher.usgPrice(), spot, "Takes the spot");
        // Lower USG price => more USG required
        assertGt(dispatcher.oracleFloor(crv, AMOUNT_CRV), ((AMOUNT_CRV / 2) * 9_900) / 10_000, "Floor raised");
    }

    /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
                            DISPATCH
    =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */

    /// @dev Prod config: 40% vsTAN, 35% DAO, 25% sUSG
    function _setDefaultActions() internal {
        TokenAmount[] memory tokenAmounts = new TokenAmount[](1);
        tokenAmounts[0] = TokenAmount({token: usg, amount: 0});

        FeeDispatcher.DispatchAction[] memory actions = new FeeDispatcher.DispatchAction[](3);
        actions[0] = FeeDispatcher.DispatchAction({
            target: address(vsTan),
            bps: 4_000,
            funding: FeeDispatcher.Funding.APPROVE,
            amountOffset: 100,
            data: abi.encodeCall(VsTAN.processRewards, (tokenAmounts))
        });
        actions[1] = FeeDispatcher.DispatchAction({target: dispatcher.dao(), bps: 3_500, funding: FeeDispatcher.Funding.TRANSFER, amountOffset: type(uint32).max, data: ""});
        actions[2] = FeeDispatcher.DispatchAction({
            target: address(sUSG),
            bps: 2_500,
            funding: FeeDispatcher.Funding.TRANSFER,
            amountOffset: type(uint32).max,
            data: abi.encodeCall(IYearnV3Vault.process_report, (address(sUSG)))
        });

        vm.prank(owner);
        dispatcher.setActions(actions);
    }

    function test_dispatch() external {
        _setDefaultActions();
        uint256 total = 100_000 ether + 123;
        deal(address(usg), address(dispatcher), total);

        uint256 sUSGAssetsBefore = sUSG.totalAssets();

        vm.prank(usr1);
        dispatcher.dispatch();

        uint256 toVsTan = (total * 4_000) / 10_000;
        uint256 streamed = toVsTan - (toVsTan % 1 weeks);
        uint256 toDAO = (total * 3_500) / 10_000;
        uint256 toSUSG = (total * 2_500) / 10_000;

        (, , uint256 rewardRate, ) = vsTan.rewardData(usg);
        assertEq(rewardRate, streamed / 1 weeks, "vsTAN rate");
        assertEq(usg.balanceOf(address(vsTan)), streamed, "vsTAN pulled");
        assertEq(usg.allowance(address(dispatcher), address(vsTan)), 0, "Allowance cleared");
        assertEq(usg.balanceOf(dispatcher.dao()), toDAO, "DAO received");
        assertEq(sUSG.totalAssets(), sUSGAssetsBefore + toSUSG, "sUSG reported");
        // Only the vsTAN dusts and the bps rounding stay
        assertEq(usg.balanceOf(address(dispatcher)), total - streamed - toDAO - toSUSG, "Dusts stay");
    }

    function test_dispatch_cooldown() external {
        _setDefaultActions();
        deal(address(usg), address(dispatcher), 100_000 ether);
        dispatcher.dispatch();

        deal(address(usg), address(dispatcher), 100_000 ether);
        vm.expectRevert(FeeDispatcher.DispatchCooldown.selector);
        dispatcher.dispatch();

        skip(1 weeks);
        dispatcher.dispatch();
    }

    function test_dispatch_bubbles_revert() external {
        _setDefaultActions();
        vm.prank(owner);
        vsTan.setRewardDistributor(address(0));

        deal(address(usg), address(dispatcher), 100_000 ether);
        vm.expectRevert(abi.encodeWithSelector(LightOwnable.OwnableUnauthorizedAccount.selector, address(dispatcher)));
        dispatcher.dispatch();
    }

    function test_setActions_reverts() external {
        FeeDispatcher.DispatchAction[] memory actions = new FeeDispatcher.DispatchAction[](1);
        actions[0] = FeeDispatcher.DispatchAction({target: owner, bps: 10_001, funding: FeeDispatcher.Funding.TRANSFER, amountOffset: type(uint32).max, data: ""});

        vm.startPrank(owner);
        vm.expectRevert(FeeDispatcher.NotHundredPercent.selector);
        dispatcher.setActions(actions);

        actions[0].bps = 1_000;
        actions[0].amountOffset = 0;
        vm.expectRevert(FeeDispatcher.InvalidAction.selector);
        dispatcher.setActions(actions);

        actions[0].amountOffset = type(uint32).max;
        actions[0].target = address(0);
        vm.expectRevert(FeeDispatcher.InvalidAction.selector);
        dispatcher.setActions(actions);
        vm.stopPrank();
    }

    /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
                            CLAIM
    =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */

    function test_claim() external {
        vm.deal(address(dispatcher), 1 ether);

        vm.startPrank(owner);
        dispatcher.claim(crv, AMOUNT_CRV);
        dispatcher.claim(ETH_NAKED, 1 ether);
        vm.stopPrank();

        assertEq(crv.balanceOf(dispatcher.dao()), AMOUNT_CRV);
        assertEq(dispatcher.dao().balance, 1 ether);

        vm.prank(usr1);
        vm.expectRevert(abi.encodeWithSelector(LightOwnable.OwnableUnauthorizedAccount.selector, usr1));
        dispatcher.claim(crv, 1);
    }

    /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
                            VSTAN
    =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */

    function test_vsTan_processRewards_only_owner_or_distributor() external {
        TokenAmount[] memory tokenAmounts = new TokenAmount[](1);
        tokenAmounts[0] = TokenAmount({token: usg, amount: 1_000 ether});

        vm.prank(usr1);
        vm.expectRevert(abi.encodeWithSelector(LightOwnable.OwnableUnauthorizedAccount.selector, usr1));
        vsTan.processRewards(tokenAmounts);
    }

    /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
                        ORACLE EMA OR SPOT
    =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */

    function test_oracleCurveEmaOrSpot_takes_spot_on_pump() external {
        ICurveCryptoSwap pool = AddrCryptoSwapLP.FXN_ETH_POOL;
        assertEq(pool.coins(0), address(AddrClassicERC20.WETH), "WETH coin 0");
        assertEq(pool.coins(1), address(AddrClassicERC20.FXN), "FXN coin 1");

        IPriceOracle ethOracle = oracles[AddrClassicERC20.WETH];
        OracleCurveEmaOrSpot fxnOracle = new OracleCurveEmaOrSpot(address(pool), ethOracle, false, "FXN / USD");
        uint256 ethPrice = ethOracle.latestAnswer(false);

        uint256 ema = pool.price_oracle();
        uint256 spot = pool.last_prices();
        assertEq(fxnOracle.latestAnswer(false), ((ema > spot ? ema : spot) * ethPrice) / 1e18, "max(EMA, spot)");

        // Pump FXN: buy it with WETH
        deal(address(AddrClassicERC20.WETH), usr1, 100 ether);
        vm.startPrank(usr1);
        AddrClassicERC20.WETH.approve(address(pool), MAX_UINT);
        pool.exchange(0, 1, 100 ether, 0);
        vm.stopPrank();

        spot = pool.last_prices();
        ema = pool.price_oracle();
        assertGt(spot, ema, "Spot above EMA after pump");
        assertEq(fxnOracle.latestAnswer(false), (spot * ethPrice) / 1e18, "Takes the spot");
    }

    function test_oracleCurveEmaOrSpot_detects_pool_type() external {
        IPriceOracle ethOracle = oracles[AddrClassicERC20.WETH];
        IPriceOracle usdcOracle = oracles[AddrClassicERC20.USDC];

        OracleCurveEmaOrSpot crypto = new OracleCurveEmaOrSpot(address(AddrCryptoSwapLP.FXN_ETH_POOL), ethOracle, false, "FXN");
        OracleCurveEmaOrSpot tricrypto = new OracleCurveEmaOrSpot(address(AddrCryptoSwapLP.crvUSD_ETH_CRV), oracles[AddrClassicERC20.crvUSD], false, "ETH");
        OracleCurveEmaOrSpot ng = new OracleCurveEmaOrSpot(BOLD_USDC_POOL, usdcOracle, true, "BOLD");

        assertEq(uint8(crypto.poolType()), uint8(CurvePoolType.CRYPTO));
        assertEq(uint8(tricrypto.poolType()), uint8(CurvePoolType.TRICRYPTO));
        assertEq(uint8(ng.poolType()), uint8(CurvePoolType.STABLESWAP_NG));
        assertGt(tricrypto.latestAnswer(false), 0);

        vm.expectRevert(OracleCurveEmaOrSpot.UnsupportedPool.selector);
        new OracleCurveEmaOrSpot(address(usg), usdcOracle, false, "Not a pool");
    }

    /// @dev BOLD sits at ~0.98 long enough for the EMA to converge, then pumps sharply.
    ///      The EMA-only oracle lags low (exploitable floor), OracleCurveEmaOrSpot follows the spot.
    function test_oracleCurveEmaOrSpot_bold_sharp_recovery() external {
        ICurveStableSwapNG pool = ICurveStableSwapNG(BOLD_USDC_POOL);
        IERC20 bold = IERC20(pool.coins(0));
        assertEq(pool.coins(1), address(AddrClassicERC20.USDC), "USDC coin 1");

        IPriceOracle usdcOracle = oracles[AddrClassicERC20.USDC];
        OracleCurveEmaOrSpot boldOracle = new OracleCurveEmaOrSpot(address(pool), usdcOracle, true, "BOLD / USD");
        OracleCoinFromCurveLP boldEmaOnly = new OracleCoinFromCurveLP(address(pool), usdcOracle, 1, "BOLD / USD EMA");

        vm.startPrank(usr1);
        bold.approve(address(pool), MAX_UINT);
        AddrClassicERC20.USDC.approve(address(pool), MAX_UINT);

        // Depeg: dump BOLD until spot ~0.98, then let the EMA converge
        deal(address(bold), usr1, 30_000_000 ether);
        while (1e36 / pool.get_p(0) > 0.98 ether) pool.exchange(0, 1, 1_000_000 ether, 0);
        skip(1 days);
        // Stableswap NG price_oracle extrapolates with time, but refresh it with a tiny trade anyway
        pool.exchange(0, 1, 1 ether, 0);
        uint256 depegPrice = boldEmaOnly.latestAnswer(false);
        assertApproxEqRel(depegPrice, boldOracle.latestAnswer(false), 0.001e18, "EMA converged to spot");

        // Sharp recovery in one block: buy BOLD back with USDC
        deal(address(AddrClassicERC20.USDC), usr1, 30_000_000e6);
        while (1e36 / pool.get_p(0) < 0.999 ether) pool.exchange(1, 0, 1_000_000e6, 0);
        vm.stopPrank();

        uint256 spotPrice = ((1e36 / pool.get_p(0)) * usdcOracle.latestAnswer(false)) / 1e18;
        assertLt(boldEmaOnly.latestAnswer(false), depegPrice + 0.001 ether, "EMA-only still at depeg");
        assertEq(boldOracle.latestAnswer(false), spotPrice, "Takes the spot");
        assertGt(boldOracle.latestAnswer(false), boldEmaOnly.latestAnswer(false) + 0.015 ether, "Floor >1.5% above EMA-only");
    }
}
