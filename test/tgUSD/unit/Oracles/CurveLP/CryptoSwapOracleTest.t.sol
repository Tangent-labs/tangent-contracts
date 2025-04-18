// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "../../../contexts/ConvexCurveContext.sol";
import "../../../../../src/interfaces/externals/Curve/ICrvPoolPlain.sol";
import "../../../../../src/interfaces/externals/Chainlink/IAggregatorV3.sol";
import "../../../handler/Curve/HLpManipulator.sol";
import "forge-std/console.sol";

contract CryptoSwapOracleTest is ConvexCurveContext {
    ICurveTriCryptoSwap[] cryptoSwaps;

    function setUp() external {
        cryptoSwaps.push(AddrCryptoSwapLP.USDT_WBTC_ETH);
        cryptoSwaps.push(AddrCryptoSwapLP.USDC_WBTC_ETH);
        cryptoSwaps.push(AddrCryptoSwapLP.CRVUSD_ETH_CRV);
        cryptoSwaps.push(AddrCryptoSwapLP.GHO_CBBTC_ETH);
    }
    /// WARNING THIS IS ONLY USED FOR TESTING PURPOSE
    /// THIS METHOD CAN BE MANIPULATED IN PROD
    function approximateLPValue(ICurveTriCryptoSwap lp) public view returns (uint256) {
        return (approximateTotalLPValue(lp) * 1e18) / lp.totalSupply();
    }

    function approximateTotalLPValue(ICurveTriCryptoSwap lp) public view returns (uint256) {
        uint256 usdValue;
        for (uint256 i = 0; i < 3; i++) {
            IERC20Metadata coin = IERC20Metadata(lp.coins(i));
            uint256 balance = lp.balances(i);
            uint256 price;
            if (i == 0) {
                IPriceOracle oracle = oracles[coin];
                assertNotEq(address(oracle), address(0), "Oracle not setup");
                price = oracle.latestAnswer() * 10 ** (18 - oracle.decimals());
            } else {
                price = lp.price_oracle(i - 1);
            }

            uint256 coinValueInLP = (price * balance * (10 ** (18 - coin.decimals()))) / 1e18;

            usdValue += coinValueInLP;
        }
        return usdValue;
    }
    function test_flash_exploit_TriCryptoSwap_oracle() external {
        HLpManipulator lpManipulator = new HLpManipulator(usr1);

        for (uint256 i = 0; i < cryptoSwaps.length; i++) {
            ICurveTriCryptoSwap lp = cryptoSwaps[i];
            uint256 oracleValueBeforeSwap = oracles[lp].latestAnswer();
            uint256 totalLPValue = approximateTotalLPValue(lp);

            IERC20Metadata coin1 = IERC20Metadata(lp.coins(1));
            IPriceOracle oracle = oracles[coin1];
            uint256 price = oracle.latestAnswer() * 10 ** (18 - oracle.decimals());

            // Sell the equivalent of the totality of the LP should increase or decrease very hard if the exploit was doable
            uint256 amountCoin1ToSellWei = (totalLPValue * 10 ** 18) / price;
            uint256 amountCoin1ToSell = amountCoin1ToSellWei / 10 ** (18 - coin1.decimals());

            lpManipulator.dumTriCryptoSwapPool(lp, 1, 2, amountCoin1ToSell);
            // This is normal because the sell of the token generated swap fee reported to lpPrice.
            assertLt(oracleValueBeforeSwap, oracles[lp].latestAnswer(), "Oracle price is always bigger as swap occured in the LP");

            uint256 oracleValueAfterSwap = oracles[lp].latestAnswer();

            // This shouldnt change it more than 1.5%
            assertApproxEqRel(oracleValueBeforeSwap, oracleValueAfterSwap, 15e15);

            //TODO Verify these assert. The price of the Lp should for me change
            // uint256 newApprox = approximateLPValue(lp);
            // skip(80000);
            // lp.price_oracle(0);
            // lp.price_oracle(1);
            // assertEq(oracleValueAfterSwap, oracles[lp].latestAnswer(), "After some time, oracle pricing should change");
            // assertApproxEqRel(newApprox, oracles[lp].latestAnswer(), 3e15, "After some time the price should have change");
        }
    }
    function test_atomic_verification() external view {
        for (uint256 i = 0; i < cryptoSwaps.length; i++) {
            ICurveTriCryptoSwap lp = cryptoSwaps[i];
            uint256 approx = approximateLPValue(lp);
            assertApproxEqRel(approx, oracles[lp].latestAnswer(), 3e15);
        }
    }
}
