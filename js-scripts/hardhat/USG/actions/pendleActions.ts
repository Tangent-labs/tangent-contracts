import {AddressLike, Signer} from "ethers";
import {ethers} from "hardhat";
import {PENDLE_ROUTER_V4} from "defi-resources/build/ressources/contracts/routers";
import {IERC20Metadata} from "../../../../typechain-types";
import {THIEF_TOKEN_CONFIG} from "defi-resources/build/ressources/erc20/thiefConfig";
import {giveTokenToAddresss} from "../../thief";

const DEAD_ADDRESS = "0x000000000000000000000000000000000000dEaD";

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

export const giveToken = async (contract: IERC20Metadata, amount: bigint, user: Signer) => {
    const symbol = await contract.symbol();
    const config = THIEF_TOKEN_CONFIG[symbol];

    if (!config) {
        throw new Error(`Token ${symbol} not found in THIEF_TOKEN_CONFIG`);
    }
    await giveTokenToAddresss(user, config.address, amount, config.slotBalance, config.isVyper);
};

export const pendleDepositLP = async (market: AddressLike, amount: bigint, user: Signer, underlying: AddressLike) => {
    const userAddress = await user.getAddress();
    const router = await ethers.getContractAt("IPendleRouterV4", PENDLE_ROUTER_V4);
    const underlyingContract = await ethers.getContractAt("IERC20Metadata", underlying.toString());

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
    await underlyingContract.connect(user).approve(PENDLE_ROUTER_V4, amount);

    // Create TokenInput
    const tokenInput = {
        tokenIn: underlying.toString(),
        netTokenIn: amount,
        tokenMintSy: underlying.toString(),
        pendleSwap: ethers.ZeroAddress,
        swapData: EMPTY_SWAP_DATA,
    };

    // Create ApproxParams for LP output estimation
    const approxParams = {
        guessMin: 0n,
        guessMax: amount / 2n, // Conservative estimate
        guessOffchain: amount / 4n, // Initial guess
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

export const pendleWithdrawLP = async (market: AddressLike, amount: bigint, user: Signer, underlying: AddressLike) => {
    const userAddress = await user.getAddress();
    const router = await ethers.getContractAt("IPendleRouterV4", PENDLE_ROUTER_V4);
    const marketContract = await ethers.getContractAt("IPendleMarketV3", market.toString());

    // Get market tokens to identify the underlying token
    const {_SY} = await marketContract.readTokens();
    const syToken = await ethers.getContractAt("ISYToken", _SY);
    const tokensOut = await syToken.getTokensOut();

    // Use provided underlying token or default to the first token in the array
    if (!tokensOut.includes(underlying.toString())) {
        throw new Error(`Underlying token ${underlying} is not in the SY token's getTokensOut array. Available tokens: ${tokensOut.join(", ")}`);
    }

    // Approve router to spend LP tokens
    await marketContract.connect(user).approve(PENDLE_ROUTER_V4, amount);

    // Create SwapData for no swap
    const swapData = {
        swapType: 0, // NONE
        extRouter: ethers.ZeroAddress,
        extCalldata: "0x",
        needScale: false,
    };

    // Create TokenOutput configuration
    const tokenOutput = {
        tokenOut: underlying,
        minTokenOut: 0n,
        tokenRedeemSy: underlying,
        pendleSwap: ethers.ZeroAddress,
        swapData: swapData,
    };

    // Call removeLiquiditySingleToken on the router
    const tx = await router.connect(user).removeLiquiditySingleToken(
        userAddress, // receiver
        market.toString(), // market
        amount, // netLpToBurn
        tokenOutput, // output
        EMPTY_LIMIT_DATA // limit
    );

    const receipt = await tx.wait();

    return {
        success: true,
        transactionHash: receipt?.hash,
    };
};

export const pendleDepositPT = async (market: AddressLike, amount: bigint, user: Signer) => {
    const userAddress = await user.getAddress();
    const router = await ethers.getContractAt("IPendleRouterV4", PENDLE_ROUTER_V4);
    const marketContract = await ethers.getContractAt("IPendleMarketV3", market.toString());

    // Get market tokens to identify the PT token
    const {_PT} = await marketContract.readTokens();
    const ptToken = await ethers.getContractAt("IERC20", _PT);

    // Approve router to spend LP tokens
    await marketContract.connect(user).approve(PENDLE_ROUTER_V4, amount);

    // Create ApproxParams for PT received from SY conversion
    const approxParams = {
        guessMin: 0n,
        guessMax: 1n * 10n ** 24n, // 1e24
        guessOffchain: 5n * 10n ** 23n, // 5e23
        maxIteration: 50,
        eps: 1n * 10n ** 15n, // 1e15
    };
    try {
        // Call removeLiquiditySinglePt on the router
        const tx = await router.connect(user).removeLiquiditySinglePt(
            userAddress, // receiver
            market.toString(), // market
            amount, // netLpToBurn
            0n, // minPtOut
            approxParams, // guessPtReceivedFromSy
            EMPTY_LIMIT_DATA // limit
        );

        const receipt = await tx.wait();

        // Get final balances
        const finalPtBalance = await ptToken.balanceOf(userAddress);
        const finalLpBalance = await marketContract.balanceOf(userAddress);

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

export const pendleWithdrawPT = async (market: AddressLike, amount: bigint, user: Signer) => {
    const userAddress = await user.getAddress();
    const marketContract = await ethers.getContractAt("IPendleMarketV3", market.toString());
    const {_PT} = await marketContract.readTokens();
    const ptToken = await ethers.getContractAt("IERC20Metadata", _PT);

    await ptToken.connect(user).transfer(DEAD_ADDRESS, amount);

    // Final YT balance
    const ytBalance = await ptToken.balanceOf(userAddress);

    return {
        success: true,
        ytBalance,
    };
};

export const pendleWithdrawYT = async (market: AddressLike, amount: bigint, user: Signer) => {
    const userAddress = await user.getAddress();

    const marketContract = await ethers.getContractAt("IPendleMarketV3", market.toString());
    const {_YT} = await marketContract.readTokens();
    const ytToken = await ethers.getContractAt("IERC20", _YT);
    await ytToken.connect(user).transfer(DEAD_ADDRESS, amount);

    // Final YT balance
    const ytBalance = await ytToken.balanceOf(userAddress);

    return {
        success: true,
        ytBalance,
    };
};

export const pendleDepositYT = async (market: AddressLike, amount: bigint, user: Signer, underlying: AddressLike) => {
    const userAddress = await user.getAddress();
    const router = await ethers.getContractAt("IPendleRouterV4", PENDLE_ROUTER_V4);
    const underlyingContract = await ethers.getContractAt("IERC20Metadata", underlying.toString());

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
    await underlyingContract.connect(user).approve(PENDLE_ROUTER_V4, amount);

    // Create TokenInput
    const tokenInput = {
        tokenIn: underlying.toString(),
        netTokenIn: amount,
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
        throw error;
    }
};

// TypeScript interfaces for Pendle market contracts
export interface PendleMarketContracts {
    // Market contract
    market: any; // IPendleMarketV3

    // Core token contracts
    sy: any; // ISYToken
    pt: any; // IERC20Metadata
    yt: any; // IERC20Metadata
}

/**
 * Retrieves the contract instances for a Pendle market including PT, YT, SY tokens
 * @param market - The address of the Pendle market contract
 * @returns Promise<PendleMarketContracts> - Contract instances for:
 *   - Market contract (IPendleMarketV3)
 *   - SY token contract (ISYToken)
 *   - PT token contract (IERC20Metadata)
 *   - YT token contract (IERC20Metadata)
 */
export const getPendleMarketContracts = async (market: AddressLike): Promise<PendleMarketContracts> => {
    const marketContract = await ethers.getContractAt("IPendleMarketV3", market.toString());

    // Get market tokens (SY, PT, YT)
    const {_SY, _PT, _YT} = await marketContract.readTokens();

    // Get SY token contract to access input/output tokens
    const syToken = await ethers.getContractAt("ISYToken", _SY);

    // Get PT and YT token contracts
    const ptToken = await ethers.getContractAt("IERC20Metadata", _PT);
    const ytToken = await ethers.getContractAt("IERC20Metadata", _YT);

    const marketContracts = {
        // Market contract
        market: marketContract,

        // Core token contracts
        sy: syToken,
        pt: ptToken,
        yt: ytToken,
    };

    return marketContracts;
};
