// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "../../../contexts/MarketDeploymentContext.sol";
import "../../../../src/interfaces/externals/Curve/ICrvPoolPlain.sol";

contract GetLPPriceCurveStableSwap is MarketDeploymentContext {
    IERC20Metadata coin0;
    IERC20Metadata coin1;
    ICrvPoolPlain lp = ICrvPoolPlain(0x4DEcE678ceceb27446b35C672dC7d61F30bAD69E);

    function setUp() public {
        coin0 = IERC20Metadata(lp.coins(0));
        coin1 = IERC20Metadata(lp.coins(1));
        deal(address(coin0), usr1, 1_000_000_000_000 * 10 ** coin0.decimals());
        deal(address(coin1), usr1, 1_000_000_000_000 * 10 ** coin1.decimals());
    }

    function test_exploit_price_crvUSD_USDC(uint256 amountInSwap, uint256 amount0Lp, uint256 amount1Lp) external {
        amountInSwap = bound(amountInSwap, 1_000_000 ether, 1_000_000_000 * 10 ** 18);

        amount0Lp = bound(amount0Lp, 1_000_000 * 10 ** coin0.decimals(), 1_000_000_000 * 10 ** coin0.decimals());
        amount1Lp = bound(amount1Lp, 1_000_000 * 10 ** coin1.decimals(), 1_000_000_000 * 10 ** coin1.decimals());

        uint256 lpPriceStart = oracles[lp].latestAnswer();

        console.log("Initial lpPrice : ", lpPriceStart);

        // Dump a lot of crvUSD
        vm.startPrank(usr1);

        AddrClassicERC20.crvUSD.approve(address(lp), MAX_UINT);
        AddrClassicERC20.USDC.approve(address(lp), MAX_UINT);

        uint256 loanAmount = lp.add_liquidity([amount0Lp, amount1Lp], 0);
        deal(address(AddrClassicERC20.crvUSD), usr1, 1_000_000_000_000 ether);

        uint256 received0 = lp.exchange(1, 0, amountInSwap, 0, usr1);

        uint256 received1 = lp.exchange(0, 1, received0, 0, usr1);

        uint256 lastLPPrice = oracles[lp].latestAnswer();

        uint256 collateralValue = (loanAmount * lastLPPrice) / 10 ** 18;
        uint256 loanMax = (85 * collateralValue) / (100 * 10 ** 18);

        uint256 sumLost = collateralValue + (amountInSwap - received1);

        assertLt(loanMax, sumLost);

        vm.stopPrank();
    }
}
