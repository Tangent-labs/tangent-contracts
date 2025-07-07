// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/console.sol";
import "../../../contexts/MarketDeploymentContext.sol";
import "../../../../src/interfaces/externals/Pendle/IPendleMarketV3.sol";
import "../../../../src/interfaces/externals/Pendle/IPendleRouterV4.sol";
import "../../../../src/interfaces/externals/Pendle/IPendlePYLpOracle.sol";
import "../../../../src/interfaces/externals/Pendle/ISyToken.sol";

contract PendleRouterTest is MarketDeploymentContext {
    IPendleMarketV3 public market;
    IPendleRouterV4 public router;

    IERC20Metadata public ptToken;
    IERC20Metadata public syToken;
    IERC20Metadata public ytToken;
    IERC20Metadata public underlyingToken;

    uint256 public constant amountPT = 1000 ether;
    uint256 public constant amountSY = 10000 ether;
    uint256 public constant amountLp = 500 ether;
    uint256 public constant amountUnderlyingToken = 1000 ether;

    // Known addresses for testing
    address public constant PENDLE_ROUTER_V4 = 0x888888888889758F76e7103c6CbF23ABbF58F946;

    // Helper functions for empty parameters
    function getEmptySwapData() internal pure returns (IPendleRouterV4.SwapData memory) {
        return IPendleRouterV4.SwapData({swapType: IPendleRouterV4.SwapType.NONE, extRouter: address(0), extCalldata: "", needScale: false});
    }

    function getEmptyLimitData() internal pure returns (IPendleRouterV4.LimitOrderData memory) {
        return
            IPendleRouterV4.LimitOrderData({
                limitRouter: address(0),
                epsSkipMarket: 0,
                normalFills: new IPendleRouterV4.FillOrderParams[](0),
                flashFills: new IPendleRouterV4.FillOrderParams[](0),
                optData: ""
            });
    }

    function setUp() public {
        // Use a known Pendle market for testing (PT-USDe market)
        market = IPendleMarketV3(0xC64D59eb11c869012C686349d24e1D7C91C86ee2);
        router = IPendleRouterV4(PENDLE_ROUTER_V4);
        underlyingToken = IERC20Metadata(0x40D16FC0246aD3160Ccc09B8D0D3A2cD28aE6C2f); //GHO

        // underlyingToken = IERC20Metadata(0x6A29A46E21C730DcA1d8b23d637c101cec605C5B); //fGHO
        // Get market tokens
        (address _SY, address _PT, address _YT) = market.readTokens();
        syToken = IERC20Metadata(_SY);
        ytToken = IERC20Metadata(_YT);
        ptToken = IERC20Metadata(_PT);

        address[] memory tokensIn = ISYToken(address(syToken)).getTokensIn();

        // check if underlyingToken is in the tokensIn array
        bool isUnderlyingTokenIn = false;
        for (uint256 i = 0; i < tokensIn.length; i++) {
            if (tokensIn[i] == address(underlyingToken)) {
                isUnderlyingTokenIn = true;
            }
        }

        assertEq(isUnderlyingTokenIn, true, "Underlying token should be in the tokensIn array");

        vm.label(address(underlyingToken), underlyingToken.symbol());
        vm.label(address(syToken), syToken.symbol());
    }

    function test_pendle_router_add_liquidity_single_token() public {
        vm.startPrank(usr1);

        giveCollateralToUsers(underlyingToken);
        uint256 initialUnderlyingTokenBalance = underlyingToken.balanceOf(usr1);
        uint256 initialLpBalance = syToken.balanceOf(usr1);
        // Approve the router to spend the remaining tokens
        underlyingToken.approve(address(router), amountUnderlyingToken);

        IPendleRouterV4.TokenInput memory input = IPendleRouterV4.TokenInput({
            tokenIn: address(underlyingToken), // <- underlying
            netTokenIn: amountUnderlyingToken,
            tokenMintSy: address(underlyingToken),
            pendleSwap: address(0),
            swapData: getEmptySwapData()
        });

        IPendleRouterV4.ApproxParams memory guessLpOut = IPendleRouterV4.ApproxParams({
            guessMin: 0,
            guessMax: amountUnderlyingToken / 2, // Or whatever max you want
            guessOffchain: amountUnderlyingToken / 2, // Or your guess/2
            maxIteration: 30,
            eps: 1e12
        });

        (uint256 netLpOut, , ) = router.addLiquiditySingleToken(usr1, address(market), 1, guessLpOut, input, getEmptyLimitData());

        uint256 finalLpBalance = IPendleMarketV3(market).balanceOf(usr1);
        uint256 finalUnderlyingTokenBalance = underlyingToken.balanceOf(usr1);

        assertGt(finalLpBalance, 0, "Lp balance should be greater than 0");
        assertLt(finalUnderlyingTokenBalance, initialUnderlyingTokenBalance, "Minted should be equal to the underlying token balance");
        assertEq(finalLpBalance, initialLpBalance + netLpOut, "LP balance should increase by the net out");

        vm.stopPrank();
    }

    function test_pendle_router_remove_liquidity_single_token() external {
        // Step 1: mint LP via your existing add test
        test_pendle_router_add_liquidity_single_token();

        vm.startPrank(usr1);

        // Step 2: record starting balances
        uint256 initialUnderlying = underlyingToken.balanceOf(usr1);
        uint256 initialLp = IPendleMarketV3(market).balanceOf(usr1);

        console.log("Initial LP balance:", initialLp);
        console.log("Initial underlying balance:", initialUnderlying);

        bytes4 selector = IPendleRouterV4.removeLiquiditySingleToken.selector;
        console.logBytes4(selector);

        // Approve router to spend LP tokens
        IPendleMarketV3(market).approve(address(router), initialLp);

        // ApproxParams for SY received from LP burning
        IPendleRouterV4.ApproxParams memory guessSyReceivedFromLp = IPendleRouterV4.ApproxParams({
            guessMin: 0,
            guessMax: initialLp,
            guessOffchain: initialLp / 2,
            maxIteration: 30,
            eps: 1e12
        });

        // TokenOutput configuration
        IPendleRouterV4.TokenOutput memory tokenOutput = IPendleRouterV4.TokenOutput({
            tokenOut: address(underlyingToken),
            minTokenOut: 0,
            tokenRedeemSy: address(underlyingToken),
            pendleSwap: address(0),
            swapData: getEmptySwapData()
        });
        /*
            address limitRouter;
            uint256 epsSkipMarket;
            FillOrderParams[] normalFills;
            FillOrderParams[] flashFills;
            bytes optData;
        */

        (uint256 netTokenOut, uint256 netSyFee, uint256 netSyInterm) = router.removeLiquiditySingleToken(usr1, address(market), initialLp, tokenOutput, getEmptyLimitData());

        // Step 4: post-call balances
        uint256 finalUnderlying = underlyingToken.balanceOf(usr1);
        uint256 finalLp = IPendleMarketV3(market).balanceOf(usr1);

        console.log("Net token out:", netTokenOut);
        console.log("Net SY fee:", netSyFee);
        console.log("Net SY intermediate:", netSyInterm);
        console.log("Final underlying:", finalUnderlying);
        console.log("Final LP:", finalLp);

        // 🧪 Assertions
        // assertEq(finalLp, 0, "All LP should be burned");
        // assertGt(finalUnderlying, initialUnderlying, "Underlying balance should increase");
        // assertEq(finalUnderlying, initialUnderlying + netTokenOut, "Underlying increased by net token out");

        vm.stopPrank();
    }

    function test_pendle_router_add_liquidity_single_token_keep_yt() public {
        vm.startPrank(usr1);

        giveCollateralToUsers(underlyingToken);
        uint256 initialUnderlyingTokenBalance = underlyingToken.balanceOf(usr1);
        uint256 initialLpBalance = IPendleMarketV3(market).balanceOf(usr1);
        uint256 initialYtBalance = ytToken.balanceOf(usr1);

        // Approve the router to spend the underlying tokens
        underlyingToken.approve(address(router), amountUnderlyingToken);

        IPendleRouterV4.TokenInput memory input = IPendleRouterV4.TokenInput({
            tokenIn: address(underlyingToken),
            netTokenIn: amountUnderlyingToken,
            tokenMintSy: address(underlyingToken),
            pendleSwap: address(0),
            swapData: getEmptySwapData()
        });

        (uint256 netLpOut, uint256 netYtOut, uint256 netSyMintPy, uint256 netSyInterm) = router.addLiquiditySingleTokenKeepYt(usr1, address(market), 0, 0, input);

        uint256 finalLpBalance = IPendleMarketV3(market).balanceOf(usr1);
        uint256 finalUnderlyingTokenBalance = underlyingToken.balanceOf(usr1);
        uint256 finalYtBalance = ytToken.balanceOf(usr1);

        // Assertions
        assertEq(finalLpBalance, initialLpBalance + netLpOut, "LP balance should increase by the net out");
        assertEq(finalYtBalance, initialYtBalance + netYtOut, "YT balance should increase by the net YT out");

        vm.stopPrank();
    }

    function test_pendle_router_remove_liquidity_single_pt() public {
        test_pendle_router_add_liquidity_single_token();
        vm.startPrank(usr1);

        uint256 initialPtBalance = ptToken.balanceOf(usr1);
        uint256 initialLpBalance = IPendleMarketV3(market).balanceOf(usr1);

        uint256 netLpToRemove = initialLpBalance / 2;

        console.log("Market PT balance:", ptToken.balanceOf(address(market)));
        console.log("User LP balance:", IPendleMarketV3(market).balanceOf(usr1));

        IPendleMarketV3(market).approve(address(router), initialLpBalance);

        IPendleRouterV4.ApproxParams memory guessPtReceivedFromSy = IPendleRouterV4.ApproxParams({guessMin: 0, guessMax: 1e24, guessOffchain: 5e23, maxIteration: 50, eps: 1e15});

        uint256 minPtOut = 1; // Set low for test

        (uint256 netPtOut, uint256 netSyFee) = router.removeLiquiditySinglePt(usr1, address(market), netLpToRemove, minPtOut, guessPtReceivedFromSy, getEmptyLimitData());

        uint256 finalPtBalance = ptToken.balanceOf(usr1);
        uint256 finalLpBalance = IPendleMarketV3(market).balanceOf(usr1);

        // ... (Assertions)

        // has PT in the market
        assertGt(ptToken.balanceOf(usr1), 0, "User should have PT");

        // has LP in the user

        vm.stopPrank();
    }
}
