import {AddressLike, Signer} from "ethers";
import {ethers} from "hardhat";

export const PENDLE_ROUTER_V4 = "0x888888888889758F76e7103c6CbF23ABbF58F946";

export const pendleWithdraw = async (market: AddressLike, underlyingToken: AddressLike, amountLpToBurn: bigint, user: Signer) => {
    console.log("Setting up Pendle withdraw via Router V4...");
    console.log(`Market: ${market}`);
    console.log(`Amount LP to burn: ${ethers.formatEther(amountLpToBurn)} for ${underlyingToken}`);

    const userAddress = await user.getAddress();
    const router = await ethers.getContractAt("IPendleRouterV4", PENDLE_ROUTER_V4);
    const marketContract = await ethers.getContractAt("IPendleMarketV3", market.toString());

    // Get market tokens to identify the underlying token
    const {_SY} = await marketContract.readTokens();
    const syToken = await ethers.getContractAt("ISYToken", _SY);
    const tokensIn = await syToken.getTokensIn();

    // Use provided underlying token or default to the first token in the array
    if (!tokensIn.includes(underlyingToken.toString())) {
        throw new Error(`Underlying token ${underlyingToken} is not in the SY token's getTokensIn array. Available tokens: ${tokensIn.join(", ")}`);
    }

    // Approve router to spend LP tokens
    await marketContract.connect(user).approve(PENDLE_ROUTER_V4, amountLpToBurn);

    // Create SwapData for no swap
    const swapData = {
        swapType: 0, // NONE
        extRouter: ethers.ZeroAddress,
        extCalldata: "0x",
        needScale: false,
    };

    // Create TokenOutput configuration
    const tokenOutput = {
        tokenOut: underlyingToken,
        minTokenOut: 0n,
        tokenRedeemSy: underlyingToken,
        pendleSwap: ethers.ZeroAddress,
        swapData: swapData,
    };

    // Create empty arrays for limit order data
    const normalFillsArray: any[] = [];
    const flashFillsArray: any[] = [];

    // Create LimitOrderData
    const limitData = {
        limitRouter: ethers.ZeroAddress,
        epsSkipMarket: 0n,
        normalFills: normalFillsArray,
        flashFills: flashFillsArray,
        optData: "0x",
    };

    console.log("Calling removeLiquiditySingleToken...");

    // Call removeLiquiditySingleToken on the router
    const tx = await router.connect(user).removeLiquiditySingleToken(
        userAddress, // receiver
        market.toString(), // market
        amountLpToBurn, // netLpToBurn
        tokenOutput, // output
        limitData // limit
    );

    const receipt = await tx.wait();

    return {
        success: true,
        transactionHash: receipt?.hash,
    };
};
