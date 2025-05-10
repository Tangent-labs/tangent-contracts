// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "../../../contexts/MarketDeploymentContext.sol";
import "../../../handler/Curve/HLPManipulator.sol";
import "forge-std/console.sol";

contract CryptoSwapOracleTest is MarketDeploymentContext {
    address[] cryptoSwaps;

    function setUp() external {
        // TRI POOL
        cryptoSwaps.push(address(AddrCryptoSwapLP.USDT_WBTC_ETH));
        cryptoSwaps.push(address(AddrCryptoSwapLP.USDC_WBTC_ETH));
        cryptoSwaps.push(address(AddrCryptoSwapLP.crvUSD_ETH_CRV));
        cryptoSwaps.push(address(AddrCryptoSwapLP.GHO_cbBTC_ETH));

        // DUO POOL
        cryptoSwaps.push(address(AddrCryptoSwapLP.USR_RLP));
        cryptoSwaps.push(address(AddrCryptoSwapLP.CVX_ETH));
    }
    /// WARNING THIS IS ONLY USED FOR TESTING PURPOSE
    /// THIS METHOD CAN BE MANIPULATED IN PROD
    function approximateLPValue(ICurveTriCryptoSwap lp) public view returns (uint256) {
        uint256 totalSupp;

        (, bytes memory totalSupplyBytes) = address(lp).staticcall(abi.encodeWithSelector(bytes4(keccak256("totalSupply()"))));

        // For the LP that are not merged with the token
        if (totalSupplyBytes.length == 0) {
            (, bytes memory lpTokenBytes) = address(lp).staticcall(abi.encodeWithSelector(bytes4(keccak256("token()"))));
            totalSupp = IERC20Metadata(abi.decode(lpTokenBytes, (address))).totalSupply();
        } else {
            totalSupp = abi.decode(totalSupplyBytes, (uint256));
        }

        return (approximateTotalLPValue(lp) * 1e18) / totalSupp;
    }

    function approximateTotalLPValue(ICurveTriCryptoSwap lp) public view returns (uint256) {
        uint256 usdValue;
        for (uint256 i = 0; i < 5; i++) {
            IERC20Metadata coin;

            try lp.coins(i) {
                coin = IERC20Metadata(lp.coins(i));
            } catch {
                break;
            }

            IPriceOracle oracle = oracles[coin];
            assertNotEq(address(oracle), address(0), "Oracle not setup");
            uint256 price = oracle.latestAnswer() * 10 ** (18 - oracle.decimals());

            usdValue += (price * lp.balances(i) * (10 ** (18 - coin.decimals()))) / 1e18;
        }

        return usdValue;
    }
    function test_flash_exploit_TriCryptoSwap_oracle() external {
        HLPManipulator lpManipulator = new HLPManipulator(usr1);

        for (uint256 i = 0; i < cryptoSwaps.length; i++) {
            ICurveTriCryptoSwap lp = ICurveTriCryptoSwap(cryptoSwaps[i]);
            uint256 oracleValueBeforeSwap = oracles[lp].latestAnswer();
            uint256 totalLPValue = approximateTotalLPValue(lp);

            IERC20Metadata coin1 = IERC20Metadata(lp.coins(1));
            IPriceOracle oracle = oracles[coin1];
            uint256 price = oracle.latestAnswer() * 10 ** (18 - oracle.decimals());

            // Sell the equivalent of the totality of the LP should increase or decrease very hard if the exploit was doable
            uint256 amountCoin1ToSellWei = (totalLPValue * 10 ** 18) / price;
            uint256 amountCoin1ToSell = amountCoin1ToSellWei / 10 ** (18 - coin1.decimals());

            lpManipulator.dumTriCryptoSwapPool(lp, 1, 0, amountCoin1ToSell);
            // This is normal because the sell of the token generated swap fee reported to lpPrice.
            assertLt(oracleValueBeforeSwap, oracles[lp].latestAnswer(), "Oracle price is always bigger as swap occured in the LP");

            uint256 oracleValueAfterSwap = oracles[lp].latestAnswer();

            // This shouldnt change it more than 1.5%
            assertApproxEqRel(oracleValueBeforeSwap, oracleValueAfterSwap, 30e15);

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
            ICurveTriCryptoSwap lp = ICurveTriCryptoSwap(cryptoSwaps[i]);
            uint256 approx = approximateLPValue(lp);
            assertApproxEqRel(approx, oracles[lp].latestAnswer(), 7e15); // 0.7% maximum
        }
    }
}
