// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "../../contexts/MarketDeploymentContext.sol";

contract CreateStakeDaoVaultV2Market is MarketDeploymentContext {
    RCParams public rcParams;
    IRParams public irParams;
    MarketInit public marketInit;

    function setUp() external {
        IERC20[] memory rewardTokens = new IERC20[](1);
        rewardTokens[0] = AddrClassicERC20.CRV;

        marketInit = MarketInit({
            name: "",
            collatToken: AddrCurveStableLP.USDT_crvUSD,
            collatOracle: IPriceOracle(address(0)),
            maxLTV: 0,
            liquidationThreshold: 95_000,
            liquidationFee: 0,
            maxMarketDebt: 0,
            rewardTokens: rewardTokens,
            minimumLoan: 0
        });
        irParams = IRParams({isHEC: true, rMin: 4_000, rMax: 400_000, pMin: 980_000, pMax: 995_000, pInf: 990_000, a1: 2_000, a2: 2_000, k: 250});
        rcParams = RCParams({harvestFeePercentage: 1_000, startCutPercentage: 50_000, endCutPercentage: 100_000, stepAmount: 4, startCutPrice: 995_000, endCutPrice: 900_000});
    }

    function test_createStakeDaoVaultMarket_success() external {
        vm.startPrank(owner);
        address market = marketCreator.createStakeDaoVaultV2Market(marketInit, AddrStakeDaoVaultV2.USDT_crvUSD_LP, irParams, rcParams);

        assertTrue(usg.isMinter(market));
        assertTrue(usg.isBurner(market));
        assertTrue(rewardAccumulator.isMarket(market));
        assertEq(irCalculator.debtIndexes(market), RAY);
        assertTrue(address(StakeDaoVaultV2Market(market).receiptToken()) == address(AddrStakeDaoVaultV2.USDT_crvUSD_LP));
        assertEq(address(rewardAccumulator.rewardTokens(market, 0)), address(AddrClassicERC20.CRV));
    }

    function test_createStakeDaoVaultMarket_fails_as_not_owner() external {
        vm.startPrank(usr1);
        vm.expectRevert(abi.encodeWithSelector(LightOwnable.OwnableUnauthorizedAccount.selector, usr1));
        marketCreator.createStakeDaoVaultV2Market(marketInit, AddrStakeDaoVaultV2.USDT_crvUSD_LP, irParams, rcParams);
    }

    function test_createStakeDaoVaultMarket_fails_as_wrong_vault() external {
        vm.startPrank(owner);
        vm.expectRevert(abi.encodeWithSelector(StakeDaoVaultV2Market.WrongVaultToken.selector));
        marketCreator.createStakeDaoVaultV2Market(marketInit, AddrStakeDaoVaultV2.USDC_crvUSD_LP, irParams, rcParams);
    }
}
