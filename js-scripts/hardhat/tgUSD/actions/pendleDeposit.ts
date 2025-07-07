import {AddressLike, Signer} from "ethers";
import {ethers} from "hardhat";

export const PENDLE_ROUTER_V4 = "0x888888888889758F76e7103c6CbF23ABbF58F946";

export const pendleDeposit = async (market: AddressLike, underlying: AddressLike, amountUnderlying: bigint, user: Signer) => {
    console.log("Setting up Pendle deposit via Router V4...");
    console.log(`Market: ${market}`);
    console.log(`Underlying: ${underlying}`);
    console.log(`Amount: ${ethers.formatEther(amountUnderlying)}`);

    const userAddress = await user.getAddress();
    const router = await ethers.getContractAt("IPendleRouterV4", PENDLE_ROUTER_V4);
    const underlyingContract = await ethers.getContractAt("IERC20", underlying.toString());

    // Get market contract to access SY token
    const marketContract = await ethers.getContractAt("IPendleMarketV3", market.toString());
    const {_SY} = await marketContract.readTokens();
    const syToken = await ethers.getContractAt("ISYToken", _SY);

    // Check if underlying token is in the SY token's getTokensIn array
    const tokensIn = await syToken.getTokensIn();
    const isUnderlyingTokenIn = tokensIn.includes(underlying.toString());
    if (!isUnderlyingTokenIn) {
        throw new Error(`Underlying token ${underlying} is not in the SY token's getTokensIn array. Available tokens: ${tokensIn.join(", ")}`);
    }

    // Approve router to spend underlying tokens
    await underlyingContract.connect(user).approve(PENDLE_ROUTER_V4, amountUnderlying);

    // Create SwapData for no swap
    const swapData = {
        swapType: 0, // NONE
        extRouter: ethers.ZeroAddress,
        extCalldata: "0x",
        needScale: false,
    };

    // Create TokenInput
    const tokenInput = {
        tokenIn: underlying.toString(),
        netTokenIn: amountUnderlying,
        tokenMintSy: underlying.toString(),
        pendleSwap: ethers.ZeroAddress,
        swapData: swapData,
    };

    // Create ApproxParams for LP output estimation
    const approxParams = {
        guessMin: 0n,
        guessMax: amountUnderlying / 2n, // Conservative estimate
        guessOffchain: amountUnderlying / 4n, // Initial guess
        maxIteration: 30,
        eps: 1n * 10n ** 12n, // 1e12
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

    console.log("Calling addLiquiditySingleToken...");

    // Call addLiquiditySingleToken directly on the router
    const tx = await router.connect(user).addLiquiditySingleToken(
        userAddress, // receiver
        market.toString(), // market
        1n, // index of SY token
        approxParams, // guessLpOut
        tokenInput, // input
        limitData // limit
    );

    await tx.wait();

};
