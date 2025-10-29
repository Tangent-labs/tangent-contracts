// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "../../../contexts/MarketDeploymentContext.sol";
import "../../../handler/Curve/HLPManipulator.sol";

contract OracleChainlinkWrapperPrice is MarketDeploymentContext {
    function test_chainlink_oracle_usdc_with_a_fallback() external {
        OracleRedstoneWrapperFallback USDCFallback = new OracleRedstoneWrapperFallback(KeyBytes32RestoneOracle.USDC);
        OracleChainlinkWrapper usdcOracle = new OracleChainlinkWrapper(AddrChainlinkOracle.USDC, 24 hours, USDCFallback);

        // Chainlink price is correct
        uint256 priceChainlink = usdcOracle.latestAnswer(false);
        assertEq(priceChainlink, AddrChainlinkOracle.USDC.latestAnswer() * 10 ** (18 - AddrChainlinkOracle.USDC.decimals()), "Price of Chainlink is returned");

        // Chainlink price becomes incorrect but not the Redstone one
        skip(8 hours);

        // Should return something even if the fallback is stale because isNoFailMode = true
        uint256 priceRedstone = USDCFallback.latestAnswer(true);
        uint256 priceOracle = usdcOracle.latestAnswer(true);
        assertApproxEqRel(priceChainlink, priceRedstone, 1e14); // 0.01% delta rel max
        assertEq(priceOracle, priceRedstone, "Price of redstone is returned by the oracle");

        priceOracle = usdcOracle.latestAnswer(false);
        assertEq(priceOracle, priceRedstone, "Price of redstone is returned by the oracle");

        skip(12 hours);

        // Shoudld revert in isNoFail mode to false
        vm.expectRevert(abi.encodeWithSelector(OracleRedstoneWrapperFallback.InvalidAggregatorValue.selector));
        usdcOracle.latestAnswer(false);

        priceOracle = usdcOracle.latestAnswer(true);
        assertEq(priceOracle, priceRedstone, "Price of redstone is returned by the oracle");
    }

    function test_chainlink_oracle_without_a_fallback() external {
        OracleChainlinkWrapper usdcOracle = new OracleChainlinkWrapper(AddrChainlinkOracle.USDC, 24 hours, IPriceOracle(address(0)));

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

    function test_chainlink_oracle_eth_with_a_fallback() external {
        OracleRedstoneWrapperFallback ETHFallback = new OracleRedstoneWrapperFallback(KeyBytes32RestoneOracle.ETH);
        OracleChainlinkWrapper ETHOracle = new OracleChainlinkWrapper(AddrChainlinkOracle.ETH, 12 hours, ETHFallback);

        // Chainlink price is correct
        uint256 priceChainlink = ETHOracle.latestAnswer(false);
        assertEq(priceChainlink, AddrChainlinkOracle.ETH.latestAnswer() * 10 ** (18 - AddrChainlinkOracle.ETH.decimals()), "Price of Chainlink is returned");

        // Chainlink price becomes incorrect but not the Redstone one
        skip(12 hours);

        // Should return something even if the fallback is stale because isNoFailMode = true
        uint256 priceRedstone = ETHFallback.latestAnswer(true);
        uint256 priceOracle = ETHOracle.latestAnswer(true);
        assertApproxEqRel(priceChainlink, priceRedstone, 10e14); // 0.1% delta rel max
        assertEq(priceOracle, priceRedstone, "Price of redstone is returned by the oracle");

        priceOracle = ETHOracle.latestAnswer(false);
        assertEq(priceOracle, priceRedstone, "Price of redstone is returned by the oracle");

        skip(24 hours);

        // Shoudld revert in isNoFail mode to false
        vm.expectRevert(abi.encodeWithSelector(OracleRedstoneWrapperFallback.InvalidAggregatorValue.selector));
        ETHOracle.latestAnswer(false);

        priceOracle = ETHOracle.latestAnswer(true);
        assertEq(priceOracle, priceRedstone, "Price of redstone is returned by the oracle");
    }
}
