import {AddressLike, Signer} from "ethers";
import {ethers} from "hardhat";

// TypeScript interfaces for Pendle market information
interface PendleTokenInfo {
    address: string;
    name: string;
    symbol: string;
    decimals: bigint;
    totalSupply: string;
}

interface PendleSYTokenInfo extends PendleTokenInfo {
    asset: string;
    yieldToken: string;
    tokensIn: string[];
    tokensOut: string[];
}

interface PendleMarketInfo {
    // Market basic info
    marketAddress: string;
    marketName: string;
    marketSymbol: string;
    marketDecimals: bigint;
    expiry: string;
    isExpired: boolean;
    totalSupply: string;

    // Core tokens
    sy: PendleSYTokenInfo;
    pt: PendleTokenInfo;
    yt: PendleTokenInfo;

    // Additional info
    rewardTokens: string[];

    // Formatted info for display
    formatted: {
        expiryDate: string;
        isExpired: string;
        totalSupplyFormatted: string;
        syTotalSupplyFormatted: string;
        ptTotalSupplyFormatted: string;
        ytTotalSupplyFormatted: string;
    };
}

export const PENDLE_ROUTER_V4 = "0x888888888889758F76e7103c6CbF23ABbF58F946";

const EMPTY_SWAP_DATA = {
    swapType: 0, // NONE
    extRouter: ethers.ZeroAddress,
    extCalldata: "0x",
    needScale: false,
};

const EMPTY_LIMIT_DATA = {
    limitRouter: ethers.ZeroAddress,
    epsSkipMarket: 0n,
    normalFills: [],
    flashFills: [],
    optData: "0x",
};

export const pendleDeposit = async (market: AddressLike, underlying: AddressLike, amountUnderlying: bigint, user: Signer) => {
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

    // Create TokenInput
    const tokenInput = {
        tokenIn: underlying.toString(),
        netTokenIn: amountUnderlying,
        tokenMintSy: underlying.toString(),
        pendleSwap: ethers.ZeroAddress,
        swapData: EMPTY_SWAP_DATA,
    };

    // Create ApproxParams for LP output estimation
    const approxParams = {
        guessMin: 0n,
        guessMax: amountUnderlying / 2n, // Conservative estimate
        guessOffchain: amountUnderlying / 4n, // Initial guess
        maxIteration: 30,
        eps: 1n * 10n ** 12n, // 1e12
    };

    // Call addLiquiditySingleToken directly on the router
    const tx = await router.connect(user).addLiquiditySingleToken(
        userAddress, // receiver
        market.toString(), // market
        1n, // index of SY token
        approxParams, // guessLpOut
        tokenInput, // input
        EMPTY_LIMIT_DATA // limit
    );

    await tx.wait();
};

export const pendleWithdraw = async (market: AddressLike, underlyingToken: AddressLike, amountLpToBurn: bigint, user: Signer) => {
    const userAddress = await user.getAddress();
    const router = await ethers.getContractAt("IPendleRouterV4", PENDLE_ROUTER_V4);
    const marketContract = await ethers.getContractAt("IPendleMarketV3", market.toString());

    // Get market tokens to identify the underlying token
    const {_SY} = await marketContract.readTokens();
    const syToken = await ethers.getContractAt("ISYToken", _SY);
    const tokensOut = await syToken.getTokensOut();

    // Use provided underlying token or default to the first token in the array
    if (!tokensOut.includes(underlyingToken.toString())) {
        throw new Error(`Underlying token ${underlyingToken} is not in the SY token's getTokensOut array. Available tokens: ${tokensOut.join(", ")}`);
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

    // Call removeLiquiditySingleToken on the router
    const tx = await router.connect(user).removeLiquiditySingleToken(
        userAddress, // receiver
        market.toString(), // market
        amountLpToBurn, // netLpToBurn
        tokenOutput, // output
        EMPTY_LIMIT_DATA // limit
    );

    const receipt = await tx.wait();

    return {
        success: true,
        transactionHash: receipt?.hash,
    };
};

export const pendleDepositKeepYt = async (market: AddressLike, underlying: AddressLike, amountUnderlying: bigint, user: Signer) => {
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

    // Create TokenInput
    const tokenInput = {
        tokenIn: underlying.toString(),
        netTokenIn: amountUnderlying,
        tokenMintSy: underlying.toString(),
        pendleSwap: ethers.ZeroAddress,
        swapData: EMPTY_SWAP_DATA,
    };

    try {
        // First, let's estimate the expected output using staticCall
        const estimatedResult = await router.connect(user).addLiquiditySingleTokenKeepYt.staticCall(
            userAddress, // receiver
            market.toString(), // market
            0n, // minLpOut
            0n, // minYtOut
            tokenInput // input
        );

        const [estimatedLpOut, estimatedYtOut, estimatedSyMintPy, estimatedSyInterm] = estimatedResult;

        console.log(`Estimated LP out: ${ethers.formatEther(estimatedLpOut)}`);
        console.log(`Estimated YT out: ${ethers.formatEther(estimatedYtOut)}`);

        // Use estimated values with some slippage tolerance (e.g., 95% of estimated)
        const minLpOut = (estimatedLpOut * 95n) / 100n;
        const minYtOut = (estimatedYtOut * 95n) / 100n;

        // Call addLiquiditySingleTokenKeepYt on the router
        const tx = await router.connect(user).addLiquiditySingleTokenKeepYt(
            userAddress, // receiver
            market.toString(), // market
            minLpOut, // minLpOut
            minYtOut, // minYtOut
            tokenInput // input
        );

        const receipt = await tx.wait();
        console.log("Receipt:", receipt);

        console.log(`Transaction successful!`);
        console.log(`Net LP out: ${ethers.formatEther(estimatedLpOut)}`);
        console.log(`Net YT out: ${ethers.formatEther(estimatedYtOut)}`);
        console.log(`Net SY mint PY: ${ethers.formatEther(estimatedSyMintPy)}`);
        console.log(`Net SY intermediate: ${ethers.formatEther(estimatedSyInterm)}`);

        return {
            success: true,
            transactionHash: receipt?.hash,
            netLpOut: estimatedLpOut,
            netYtOut: estimatedYtOut,
            netSyMintPy: estimatedSyMintPy,
            netSyInterm: estimatedSyInterm,
        };
    } catch (error) {
        console.error("Error with addLiquiditySingleTokenKeepYt:", error);
        console.log("Falling back to regular addLiquiditySingleToken...");

        // Fallback to regular deposit without YT retention
        const approxParams = {
            guessMin: 0n,
            guessMax: amountUnderlying / 2n,
            guessOffchain: amountUnderlying / 4n,
            maxIteration: 30,
            eps: 1n * 10n ** 12n,
        };

        const limitData = {
            limitRouter: ethers.ZeroAddress,
            epsSkipMarket: 0n,
            normalFills: [],
            flashFills: [],
            optData: "0x",
        };

        const tx = await router.connect(user).addLiquiditySingleToken(
            userAddress,
            market.toString(),
            0n, // minLpOut
            approxParams,
            tokenInput,
            limitData
        );

        const receipt = await tx.wait();
        console.log("Fallback transaction successful!");

        return {
            success: true,
            transactionHash: receipt?.hash,
            fallback: true,
        };
    }
};

export const pendleWithdrawSinglePt = async (market: AddressLike, amountLpToBurn: bigint, minPtOut: bigint, user: Signer) => {
    const userAddress = await user.getAddress();
    const router = await ethers.getContractAt("IPendleRouterV4", PENDLE_ROUTER_V4);
    const marketContract = await ethers.getContractAt("IPendleMarketV3", market.toString());

    // Get market tokens to identify the PT token
    const {_PT} = await marketContract.readTokens();
    const ptToken = await ethers.getContractAt("IERC20", _PT);

    console.log(`PT token address: ${_PT}`);

    // Approve router to spend LP tokens
    await marketContract.connect(user).approve(PENDLE_ROUTER_V4, amountLpToBurn);

    // Create ApproxParams for PT received from SY conversion
    const approxParams = {
        guessMin: 0n,
        guessMax: 1n * 10n ** 24n, // 1e24
        guessOffchain: 5n * 10n ** 23n, // 5e23
        maxIteration: 50,
        eps: 1n * 10n ** 15n, // 1e15
    };
    console.log("Calling removeLiquiditySinglePt...");

    try {
        // Call removeLiquiditySinglePt on the router
        const tx = await router.connect(user).removeLiquiditySinglePt(
            userAddress, // receiver
            market.toString(), // market
            amountLpToBurn, // netLpToBurn
            minPtOut, // minPtOut
            approxParams, // guessPtReceivedFromSy
            EMPTY_LIMIT_DATA // limit
        );

        const receipt = await tx.wait();

        // Get final balances
        const finalPtBalance = await ptToken.balanceOf(userAddress);
        const finalLpBalance = await marketContract.balanceOf(userAddress);

        console.log(`Transaction successful!`);
        console.log(`Final PT balance: ${ethers.formatEther(finalPtBalance)}`);
        console.log(`Final LP balance: ${ethers.formatEther(finalLpBalance)}`);

        return {
            success: true,
            transactionHash: receipt?.hash,
            finalPtBalance: finalPtBalance,
            finalLpBalance: finalLpBalance,
        };
    } catch (error) {
        console.error("Error with removeLiquiditySinglePt:", error);
        throw error;
    }
};

/**
 * Retrieves comprehensive information about a Pendle market including PT, YT, SY tokens and their input/output tokens
 * @param market - The address of the Pendle market contract
 * @returns Promise<PendleMarketInfo> - Complete market information including:
 *   - Market basic info (name, symbol, decimals, expiry, etc.)
 *   - SY token info (address, name, symbol, input/output tokens, asset, yield token)
 *   - PT token info (address, name, symbol, decimals, total supply)
 *   - YT token info (address, name, symbol, decimals, total supply)
 *   - Reward tokens array
 *   - Formatted display information
 */
export const getPendleMarketInfo = async (market: AddressLike): Promise<PendleMarketInfo> => {
    const marketContract = await ethers.getContractAt("IPendleMarketV3", market.toString());

    // Get market tokens (SY, PT, YT)
    const {_SY, _PT, _YT} = await marketContract.readTokens();

    // Get SY token contract to access input/output tokens
    const syToken = await ethers.getContractAt("ISYToken", _SY);

    // Get PT and YT token contracts
    const ptToken = await ethers.getContractAt("IERC20Metadata", _PT);
    const ytToken = await ethers.getContractAt("IERC20Metadata", _YT);

    // Parallel execution of all contract calls for better performance
    const [
        // Market information
        marketName,
        marketSymbol,
        marketDecimals,
        expiry,
        isExpired,
        totalSupply,
        rewardTokens,

        // SY token information
        tokensIn,
        tokensOut,
        syName,
        sySymbol,
        syDecimals,
        syTotalSupply,
        syAsset,
        syYieldToken,

        // PT token information
        ptName,
        ptSymbol,
        ptDecimals,
        ptTotalSupply,

        // YT token information
        ytName,
        ytSymbol,
        ytDecimals,
        ytTotalSupply,
    ] = await Promise.all([
        // Market calls
        marketContract.name(),
        marketContract.symbol(),
        marketContract.decimals(),
        marketContract.expiry(),
        marketContract.isExpired(),
        marketContract.totalSupply(),
        marketContract.getRewardTokens(),

        // SY token calls
        syToken.getTokensIn(),
        syToken.getTokensOut(),
        syToken.name(),
        syToken.symbol(),
        syToken.decimals(),
        syToken.totalSupply(),
        syToken.asset(),
        syToken.yieldToken(),

        // PT token calls
        ptToken.name(),
        ptToken.symbol(),
        ptToken.decimals(),
        ptToken.totalSupply(),

        // YT token calls
        ytToken.name(),
        ytToken.symbol(),
        ytToken.decimals(),
        ytToken.totalSupply(),
    ]);

    const marketInfo = {
        // Market basic info
        marketAddress: market.toString(),
        marketName,
        marketSymbol,
        marketDecimals,
        expiry: expiry.toString(),
        isExpired,
        totalSupply: totalSupply.toString(),

        // Core tokens
        sy: {
            address: _SY,
            name: syName,
            symbol: sySymbol,
            decimals: syDecimals,
            totalSupply: syTotalSupply.toString(),
            asset: syAsset,
            yieldToken: syYieldToken,
            tokensIn,
            tokensOut,
        },
        pt: {
            address: _PT,
            name: ptName,
            symbol: ptSymbol,
            decimals: ptDecimals,
            totalSupply: ptTotalSupply.toString(),
        },
        yt: {
            address: _YT,
            name: ytName,
            symbol: ytSymbol,
            decimals: ytDecimals,
            totalSupply: ytTotalSupply.toString(),
        },

        // Additional info
        rewardTokens,

        // Formatted info for display
        formatted: {
            expiryDate: new Date(Number(expiry) * 1000).toISOString(),
            isExpired: isExpired ? "Yes" : "No",
            totalSupplyFormatted: ethers.formatEther(totalSupply),
            syTotalSupplyFormatted: ethers.formatEther(syTotalSupply),
            ptTotalSupplyFormatted: ethers.formatEther(ptTotalSupply),
            ytTotalSupplyFormatted: ethers.formatEther(ytTotalSupply),
        },
    };

    return marketInfo;
};
