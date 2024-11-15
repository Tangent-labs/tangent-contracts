// import "../contexts/TgUSDDeployContext.sol";

// import "../../../src/interfaces/externals/Curve/ICrvPoolPlain.sol";
// import "../../../src/interfaces/externals/Chainlink/IAggregatorV3.sol";
// import "../../../src/interfaces/externals/Chainlink/IAggregatorV3.sol";

// contract GetLiquidationGasCost is TgUSDDeployContext {
//     IERC20Metadata coin0;
//     IERC20Metadata coin1;
//     ICurveStableSwapNG lp = AddrCurveStableLP.CRVUSD_USDC;
//     ICvxRewardToken rewardToken = AddrCvxRewardTokens.CRVUSD_USDC_LP;

//     uint256 poolId = PidCvxCrvBooster.CRVUSD_USDC_LP;

//     function setUp() public {
//         deployBaseContracts();
//         coin0 = IERC20Metadata(lp.coins(0));
//         coin1 = IERC20Metadata(lp.coins(1));
//     }

//     // 170k
//     function _getCoinsAndLP() internal returns (uint256) {
//         vm.startPrank(usr1);
//         uint256 amount0 = 1_000 * 10 ** (coin0.decimals());
//         uint256 amount1 = 1_000 * 10 ** (coin1.decimals());
//         deal(address(coin0), usr1, amount0);
//         deal(address(coin1), usr1, amount1);

//         coin0.approve(address(lp), 1_000_000_000_000 ether); // 25k
//         coin1.approve(address(lp), 1_000_000_000_000 ether); // 25k

//         uint256[] memory amounts = new uint256[](2);
//         amounts[0] = amount0;
//         amounts[1] = amount1;

//         uint256 lpAmount = lp.add_liquidity(amounts, 0); // 118k
//         vm.stopPrank();
//         return lpAmount;
//     }

//     // // 573k
//     // function test_cost_LP_on_curve_AND_stake_on_convex_WITHOUT_staking_in_gauge() external {
//     //     uint256 lpAmount = _getCoinsAndLP(); // 170k
//     //     vm.startPrank(usr1);
//     //     lp.approve(address(AddrCvxGlobal.CVX_BOOSTER), 1_000_000_000_000 ether); // Not taken into account because approval will be already done
//     //     AddrCvxGlobal.CVX_BOOSTER.deposit(poolId, lpAmount, false); // 403 k
//     //     vm.stopPrank();
//     // }

//     // // 877k
//     // function test_cost_LP_on_curve_AND_stake_on_convex_WITH_staking_in_gauge() external {
//     //     uint256 lpAmount = _getCoinsAndLP(); // 170k
//     //     vm.startPrank(usr1);
//     //     lp.approve(address(AddrCvxGlobal.CVX_BOOSTER), 1_000_000_000_000 ether); // Not taken into account because approval will be already done
//     //     AddrCvxGlobal.CVX_BOOSTER.deposit(poolId, lpAmount, true); // 707 k
//     //     vm.stopPrank();
//     // }

//     // 300 k
//     function test_cost_liquidation() external {
//         uint256 lpAmount = _getCoinsAndLP();
//         vm.startPrank(usr1);
//         lp.approve(address(AddrCvxGlobal.CVX_BOOSTER), 1_000_000_000_000 ether);
//         AddrCvxGlobal.CVX_BOOSTER.deposit(poolId, lpAmount, true);

//         uint256 price = curveLPOracle.latestAnswer(); // 56k
//         rewardToken.withdrawAndUnwrap(lpAmount, false); // 200k
//         lp.remove_liquidity(lpAmount, [uint256(0), uint256(0)]); // 58k

//         // 30k for burn

//         vm.stopPrank();
//     }
// }
