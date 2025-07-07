import {ethers} from "hardhat";
import {giveTokensToAddresses} from "../../thief";
import {TOKENS_TO_GIVE} from "../../tokensToGive.config";
import {MaxUint256} from "ethers";

async function main() {
    // await borrowAll(addresses.markets);
    const lpAddress = "0x02950460E2b9529D0E00284A5fA2d7bDF3fA4d72";
    const lp = await ethers.getContractAt("ICurveStableSwapNG", lpAddress);

    const gauge = await ethers.getContractAt("ISharedLiquidityGauge", "0x04E80Db3f84873e4132B221831af1045D27f140F");

    const coin0Address = await lp.coins(0);
    const coin1Address = await lp.coins(1);

    const coin0Contract = await ethers.getContractAt("ERC20", coin0Address);
    const coin1Contract = await ethers.getContractAt("ERC20", coin1Address);

    // Retrieve les décimales

    const user0 = (await ethers.getSigners())[0];

    // GET TOKEN ON USER 0
    await giveTokensToAddresses([user0], TOKENS_TO_GIVE(100000));

    // APPROVE
    await coin0Contract.connect(user0).approve(lpAddress, MaxUint256);
    await coin1Contract.connect(user0).approve(lpAddress, MaxUint256);

    //// ADD LIQUIDITY FROM Curve GAUGE ////
    const balanceBefore = await lp.balanceOf(user0);
    await lp.connect(user0)["add_liquidity(uint256[],uint256)"]([10n ** 19n, 10000000n], 0);
    const balanceAfterDeposit = await lp.balanceOf(user0);

    //// STAKE LP ON CURVE GAUGE ////

    // Approve the Curve Gauge to spend LP
    await lp.connect(user0).approve(gauge, MaxUint256);
    await gauge.connect(user0)["deposit(uint256)"](balanceAfterDeposit);

    //// WITHDRAW LP FROM CURVE GAUGE ////

    await gauge.connect(user0)["withdraw(uint256)"](balanceAfterDeposit);

    /// REMOVE LIQUIDITY FROM THE LP

    // No need to approve
    await lp.connect(user0)["remove_liquidity(uint256,uint256[2])"](balanceAfterDeposit, [0, 0]);

    const balanceAfterRemove = await lp.balanceOf(user0);

    console.log(balanceBefore, balanceAfterDeposit, balanceAfterRemove);
}

main();
