// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "../../../contexts/MarketDeploymentContext.sol";
import "../../../../src/interfaces/externals/Curve/ICrvPoolPlain.sol";
import "../../../../src/interfaces/externals/Chainlink/IAggregatorV3.sol";
contract GetEthStableLPPrice is MarketDeploymentContext {
    uint256 ethPrice;
    uint256 pxETHDollarPrice;
    uint256 frxETHDollarPrice;
    function setUp() public {
        ethPrice = IPriceOracle(address(AddrChainlinkOracle.ETH)).latestAnswer() * 10 ** 10;

        frxETHDollarPrice = (AddrCurveStableLP.WETH_frxETH.price_oracle() * ethPrice) / 10 ** 18;
        pxETHDollarPrice = (AddrCurveStableLP.WETH_pxETH.price_oracle(0) * ethPrice) / 10 ** 18;
    }

    function test_pxETH_price() external view {
        assertEq(pxETHDollarPrice, oracles[AddrClassicERC20.pxETH].latestAnswer());
        assertLt(pxETHDollarPrice, ethPrice, "Almost always true as its liquidStaking");
    }

    function test_frxETH_price() external view {
        assertEq(frxETHDollarPrice, oracles[AddrClassicERC20.frxETH].latestAnswer());
        assertLt(frxETHDollarPrice, ethPrice, "Almost always true as its liquidStaking");
    }

    function test_frxeth_ETH_oracle() external view {
        uint256 vp = AddrCurveStableLP.WETH_frxETH.get_virtual_price();
        uint256 min = ethPrice < frxETHDollarPrice ? ethPrice : frxETHDollarPrice;
        assertEq(oracles[AddrCurveStableLP.WETH_frxETH].latestAnswer(), (min * vp) / 10 ** 18);
    }

    function test_pxETH_ETH_oracle() external view {
        uint256 vp = AddrCurveStableLP.WETH_pxETH.get_virtual_price();
        uint256 min = ethPrice < pxETHDollarPrice ? ethPrice : pxETHDollarPrice;
        assertEq(oracles[AddrCurveStableLP.WETH_pxETH].latestAnswer(), (min * vp) / 10 ** 18);
    }
}
