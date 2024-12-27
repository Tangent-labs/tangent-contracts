// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "../../contexts/ConvexCurveContext.sol";
import "../../../../src/interfaces/externals/Curve/ICrvPoolPlain.sol";
import "../../../../src/interfaces/externals/Chainlink/IAggregatorV3.sol";
contract GetEthStableLPPrice is ConvexCurveContext {
    uint256 ethPrice;
    uint256 pxETHDollarPrice;
    uint256 frxETHDollarPrice;
    function setUp() public {
        ethPrice = IPriceOracle(address(AddrChainlinkOracle.ETH)).latestAnswer() * 10 ** 10;

        frxETHDollarPrice = (AddrCurveStableLP.FRXETH_WETH.price_oracle() * ethPrice) / 10 ** 18;
        pxETHDollarPrice = (AddrCurveStableLP.PXETH_WETH.price_oracle(0) * ethPrice) / 10 ** 18;
    }

    function test_pxETH_price() external view {
        assertEq(pxETHDollarPrice, oracles[AddrClassicERC20.TOKEN_PXETH].latestAnswer());
        assertLt(pxETHDollarPrice, ethPrice, "Almost always true as its liquidStaking");
    }

    function test_frxETH_price() external view {
        assertEq(frxETHDollarPrice, oracles[AddrClassicERC20.TOKEN_FRXETH].latestAnswer());
        assertLt(frxETHDollarPrice, ethPrice, "Almost always true as its liquidStaking");
    }

    function test_frxeth_ETH_oracle() external view {
        uint256 vp = AddrCurveStableLP.FRXETH_WETH.get_virtual_price();
        uint256 min = ethPrice < frxETHDollarPrice ? ethPrice : frxETHDollarPrice;
        assertEq(oracles[AddrCurveStableLP.FRXETH_WETH].latestAnswer(), (min * vp) / 10 ** 18);
    }

    function test_pxETH_ETH_oracle() external view {
        uint256 vp = AddrCurveStableLP.PXETH_WETH.get_virtual_price();
        uint256 min = ethPrice < pxETHDollarPrice ? ethPrice : pxETHDollarPrice;
        assertEq(oracles[AddrCurveStableLP.PXETH_WETH].latestAnswer(), (min * vp) / 10 ** 18);
    }
}
