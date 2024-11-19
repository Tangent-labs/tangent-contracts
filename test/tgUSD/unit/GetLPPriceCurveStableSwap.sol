import "../contexts/TgUSDDeployContext.sol";

import "../../../src/interfaces/externals/Curve/ICrvPoolPlain.sol";
import "../../../src/interfaces/externals/Chainlink/IAggregatorV3.sol";
contract GetLPPriceCurveStableSwap is TgUSDDeployContext {
    IERC20Metadata coin0;
    IERC20Metadata coin1;
    ICurveStableSwapNG lp = ICurveStableSwapNG(0x4DEcE678ceceb27446b35C672dC7d61F30bAD69E);

    function setUp() public {
        coin0 = IERC20Metadata(lp.coins(0));
        coin1 = IERC20Metadata(lp.coins(1));
    }

    // 80361
    // function test_price_crvUSD_USDC() external {
    //     uint256 lpPriceStart = curveLPOracle.getLPPrice();
    // }

    // function test_exploit_price_crvUSD_USDC(uint256 amountInSwap, uint256 amount0Lp, uint256 amount1Lp) external {
    //     deal(address(coin0), usr1, 1_000_000_000_000 * 10 ** coin0.decimals());
    //     deal(address(coin1), usr1, 1_000_000_000_000 * 10 ** coin1.decimals());
    //     amountInSwap = bound(amountInSwap, 1_000_000 ether, 1_000_000_000 * 10 ** 18);

    //     amount0Lp = bound(amount0Lp, 1_000_000 * 10 ** coin0.decimals(), 1_000_000_000 * 10 ** coin0.decimals());
    //     amount1Lp = bound(amount1Lp, 1_000_000 * 10 ** coin1.decimals(), 1_000_000_000 * 10 ** coin1.decimals());

    //     uint256 lpPriceStart = curveLPOracle.getLPPrice();

    //     console.log("Initial lpPrice : ", lpPriceStart);

    //     // Dump a lot of crvUSD
    //     vm.startPrank(usr1);

    //     AddrClassicERC20.TOKEN_CRVUSD.approve(address(lp), 1_000_000_000_000 ether);
    //     AddrClassicERC20.TOKEN_USDC.approve(address(lp), 1_000_000_000_000 ether);

    //     uint256 loanAmount = lp.add_liquidity([amount0Lp, amount1Lp], 0);
    //     deal(address(AddrClassicERC20.TOKEN_CRVUSD), usr1, 1_000_000_000_000 ether);

    //     uint256 received0 = lp.exchange(1, 0, amountInSwap, 0, usr1);

    //     uint256 received1 = lp.exchange(0, 1, received0, 0, usr1);

    //     uint256 lastLPPrice = curveLPOracle.getLPPrice();

    //     uint256 collateralValue = (loanAmount * lastLPPrice) / 10 ** 18;
    //     uint256 loanMax = (85 * collateralValue) / (100 * 10 ** 18);

    //     uint256 sumLost = collateralValue + (amountInSwap - received1);

    //     assertLt(loanMax, sumLost);
    //     console.log(loanMax, sumLost);

    //     console.log("USDC received", received0);
    //     console.log("CRVUSD received", received1);
    //     console.log("lastLPPrice ", lastLPPrice);
    // }
}
