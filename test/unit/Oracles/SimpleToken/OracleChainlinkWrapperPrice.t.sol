// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "../../../contexts/MarketDeploymentContext.sol";
import "../../../handler/Curve/HLPManipulator.sol";

contract OracleChainlinkWrapperPrice is MarketDeploymentContext {
    function test_chainlink_oracle_latestAnswer_usdc_with_a_fallback() external {
        OracleRedstoneWrapperFallback USDCFallback = new OracleRedstoneWrapperFallback(KeyBytes32RestoneOracle.USDC, "Redstone USDC/USD Fallback");
        OracleChainlinkWrapper usdcOracle = new OracleChainlinkWrapper(AddrChainlinkOracle.USDC, 12 hours, address(USDCFallback), "USDC / USD");

        // Chainlink price is correct
        uint256 priceChainlink = usdcOracle.latestAnswer(false);
        assertEq(priceChainlink, AddrChainlinkOracle.USDC.latestAnswer() * 10 ** (18 - AddrChainlinkOracle.USDC.decimals()), "Price of Chainlink is returned");

        // Chainlink price becomes incorrect but not the Redstone one
        skip(12 hours);
        // Should return something even if the fallback is stale because isNoFailMode = true
        uint256 priceRedstone = USDCFallback.latestAnswer(false);
        uint256 priceOracle = usdcOracle.latestAnswer(true);
        assertApproxEqRel(priceChainlink, priceRedstone, 2e14); // 0.02% delta rel max
        assertEq(priceOracle, priceRedstone, "Price of redstone is returned by the oracle 1");

        priceOracle = usdcOracle.latestAnswer(false);
        assertEq(priceOracle, priceRedstone, "Price of redstone is returned by the oracle 2");

        skip(15 hours);

        // Shoudld revert in isNoFail mode to false
        vm.expectRevert(abi.encodeWithSelector(OracleRedstoneWrapperFallback.InvalidAggregatorValue.selector));
        usdcOracle.latestAnswer(false);

        priceOracle = usdcOracle.latestAnswer(true);
        assertEq(priceOracle, usdcOracle.lastGoodValue(), "Last good value price is returned");
    }

    function test_chainlink_oracle_latestAnswerUpdate_usdc_with_a_fallback() external {
        OracleRedstoneWrapperFallback USDCFallback = new OracleRedstoneWrapperFallback(KeyBytes32RestoneOracle.USDC, "Redstone USDC/USD Fallback");
        OracleChainlinkWrapper usdcOracle = new OracleChainlinkWrapper(AddrChainlinkOracle.USDC, 12 hours, address(USDCFallback), "USDC / USD");

        // Chainlink price is correct
        uint256 priceChainlink = usdcOracle.latestAnswerUpdate(false);
        assertEq(priceChainlink, AddrChainlinkOracle.USDC.latestAnswer() * 10 ** (18 - AddrChainlinkOracle.USDC.decimals()), "Price of Chainlink is returned");

        // Chainlink price becomes incorrect but not the Redstone one
        skip(12 hours);
        // Should return something even if the fallback is stale because isNoFailMode = true
        uint256 priceRedstone = USDCFallback.latestAnswer(false);
        uint256 priceOracle = usdcOracle.latestAnswerUpdate(true);
        assertApproxEqRel(priceChainlink, priceRedstone, 2e14); // 0.02% delta rel max
        assertEq(priceOracle, priceRedstone, "Price of redstone is returned by the oracle 1");

        priceOracle = usdcOracle.latestAnswerUpdate(false);
        assertEq(priceOracle, priceRedstone, "Price of redstone is returned by the oracle 2");

        skip(15 hours);

        // Shoudld revert in isNoFail mode to false
        vm.expectRevert(abi.encodeWithSelector(OracleRedstoneWrapperFallback.InvalidAggregatorValue.selector));
        usdcOracle.latestAnswerUpdate(false);

        priceOracle = usdcOracle.latestAnswerUpdate(true);
        assertEq(priceOracle, usdcOracle.lastGoodValue(), "Last good value price is returned");
    }

    function test_chainlink_oracle_latestAnswer_without_a_fallback() external {
        OracleChainlinkWrapper usdcOracle = new OracleChainlinkWrapper(AddrChainlinkOracle.USDC, 24 hours, address(0), "USDC / USD Oracle");

        // Chainlink price is correct
        uint256 priceChainlink = usdcOracle.latestAnswer(false);
        assertEq(priceChainlink, AddrChainlinkOracle.USDC.latestAnswer() * 10 ** (18 - AddrChainlinkOracle.USDC.decimals()), "Price of Chainlink is returned");

        // Chainlink price becomes incorrect but not the Redstone one
        skip(1 days);

        // Should return something even if the fallback is stale because isNoFailMode = true
        uint256 priceOracle = usdcOracle.latestAnswer(true);
        assertEq(priceOracle, priceChainlink, "Price of Chainlink is returned by the oracle");

        // Shoudld revert in isNoFail mode to false
        vm.expectRevert(abi.encodeWithSelector(OracleRedstoneWrapperFallback.InvalidAggregatorValue.selector));
        usdcOracle.latestAnswer(false);
    }

    function test_chainlink_oracle_latestAnswerUpdate_without_a_fallback() external {
        OracleChainlinkWrapper usdcOracle = new OracleChainlinkWrapper(AddrChainlinkOracle.USDC, 24 hours, address(0), "USDC / USD Oracle");

        // Chainlink price is correct
        uint256 priceChainlink = usdcOracle.latestAnswerUpdate(false);
        assertEq(priceChainlink, AddrChainlinkOracle.USDC.latestAnswer() * 10 ** (18 - AddrChainlinkOracle.USDC.decimals()), "Price of Chainlink is returned");

        // Chainlink price becomes incorrect but not the Redstone one
        skip(1 days);

        // Should return something even if the fallback is stale because isNoFailMode = true
        uint256 priceOracle = usdcOracle.latestAnswerUpdate(true);
        assertEq(priceOracle, priceChainlink, "Price of Chainlink is returned by the oracle");

        // Shoudld revert in isNoFail mode to false
        vm.expectRevert(abi.encodeWithSelector(OracleRedstoneWrapperFallback.InvalidAggregatorValue.selector));
        usdcOracle.latestAnswerUpdate(false);
    }

    function test_chainlink_oracle_eth_with_a_fallback() external {
        OracleRedstoneWrapperFallback ETHFallback = new OracleRedstoneWrapperFallback(KeyBytes32RestoneOracle.ETH, "Redstone ETH/USD Fallback");
        OracleChainlinkWrapper ETHOracle = new OracleChainlinkWrapper(AddrChainlinkOracle.ETH, 12 hours, address(ETHFallback), "ETH / USD Oracle");
        assertEq(ETHFallback.decimals(), 18);
        // Chainlink price is correct
        uint256 priceChainlink = ETHOracle.latestAnswer(false);
        assertEq(priceChainlink, AddrChainlinkOracle.ETH.latestAnswer() * 10 ** (18 - AddrChainlinkOracle.ETH.decimals()), "Price of Chainlink is returned");

        // Chainlink price becomes incorrect but not the Redstone one
        skip(12 hours);

        // Should return something even if the fallback is stale because isNoFailMode = true
        uint256 priceRedstone = ETHFallback.latestAnswer(false);
        uint256 priceOracle = ETHOracle.latestAnswer(true);
        assertApproxEqRel(priceChainlink, priceRedstone, 20e14); // 0.1% delta rel max
        assertEq(priceOracle, priceRedstone, "Price of redstone is returned by the oracle 1");

        priceOracle = ETHOracle.latestAnswer(false);
        assertEq(priceOracle, priceRedstone, "Price of redstone is returned by the oracle 2");

        skip(24 hours);

        // Shoudld revert in isNoFail mode to false
        vm.expectRevert(abi.encodeWithSelector(OracleRedstoneWrapperFallback.InvalidAggregatorValue.selector));
        ETHOracle.latestAnswer(false);

        priceOracle = ETHOracle.latestAnswer(true);
        assertEq(priceOracle, ETHOracle.lastGoodValue(), "Last good value is returned");
    }

    function test_oracle_deployment_fails_because_chainlink_invalid() external {
        // Chainlink price becomes incorrect but not the Redstone one
        skip(24 hours);
        OracleRedstoneWrapperFallback ETHFallback = new OracleRedstoneWrapperFallback(KeyBytes32RestoneOracle.ETH, "Redstone ETH/USD Fallback");
        vm.expectRevert(abi.encodeWithSelector(OracleRedstoneWrapperFallback.InvalidAggregatorValue.selector));
        OracleChainlinkWrapper ETHOracle = new OracleChainlinkWrapper(AddrChainlinkOracle.ETH, 12 hours, address(ETHFallback), "ETH / USD Oracle");
    }

    function test_chainlink_oracle_with_curve_lp_as_fallback() external {
        OracleCoinFromCurveLP oraclePYUSDCurve = new OracleCoinFromCurveLP(address(AddrCurveStableLP.PYUSD_USDC), oracles[AddrClassicERC20.USDC], 0, "PYUSD");

        OracleChainlinkWrapper usdcOracle = new OracleChainlinkWrapper(AddrChainlinkOracle.PYUSD, 24 hours, address(oraclePYUSDCurve), "PYUSD / USD Oracle");

        // Chainlink price is correct
        uint256 oraclePrice = usdcOracle.latestAnswerUpdate(false);

        assertEq(oraclePrice, AddrChainlinkOracle.PYUSD.latestAnswer() * 10 ** (18 - AddrChainlinkOracle.PYUSD.decimals()), "Price of Chainlink is returned");
        uint256 priceChainlink = oraclePrice;
        // Chainlink price becomes incorrect but not the Redstone one
        skip(1 days);

        // Should return something even if the fallback is stale because isNoFailMode = true
        uint256 priceOracle = usdcOracle.latestAnswerUpdate(true);
        assertEq(priceOracle, oraclePYUSDCurve.latestAnswer(true), "Price of Curve LP is returned by the Oracle");
    }
}
