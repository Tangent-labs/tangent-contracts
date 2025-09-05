import {AddressLike, formatEther, formatUnits, MaxUint256, parseEther, parseUnits, Signer, ZeroAddress} from "ethers";
import {ethers} from "hardhat";
import {PENDLE_ROUTER_V4} from "@tangent/defi-resources/build/ressources/contracts/routers";
import {PendlePools} from "@tangent/defi-resources";
import {IERC20Metadata, IPendleMarketV3, IPendleSYToken} from "../../../../typechain-types";

export type PendleKeys = keyof typeof PendlePools;

const EMPTY_SWAP_DATA = {
    swapType: 0, // NONE
    extRouter: ZeroAddress,
    extCalldata: "0x",
    needScale: false,
};

const EMPTY_LIMIT_DATA = {
    limitRouter: ZeroAddress,
    epsSkipMarket: 0n,
    normalFills: [],
    flashFills: [],
    optData: "0x",
};

async function pendleDepositSy(sy: string, amount: bigint, user: Signer) {
    const syToken = await ethers.getContractAt("IPendleSYToken", sy);

    const tokensIn = await syToken.getTokensIn();
    const underlyingContract = await ethers.getContractAt("IERC20Metadata", tokensIn[0]);

    await underlyingContract.connect(user).approve(syToken, MaxUint256);
    const bal = await syToken.balanceOf(user);
    await syToken.connect(user).deposit(user, underlyingContract, amount, 0);

    return (await syToken.balanceOf(user)) - bal;
}

export async function pendleDepositPTAndYT(marketKey: PendleKeys, user: Signer, amount: number) {
    const pendleData = PendlePools[marketKey];
    const syToken = await ethers.getContractAt("IPendleSYToken", pendleData.SY);

    const syMinted = await pendleDepositSy(pendleData.SY, parseEther(amount.toString()), user);

    const ytToken = await ethers.getContractAt("IPendleYTToken", pendleData.YT);

    await syToken.connect(user).transfer(ytToken, syMinted);
    await ytToken.connect(user).mintPY(user, user);
}

export async function pendleDepositLP(marketKey: PendleKeys, user: Signer, amount: number) {
    const pendleData = PendlePools[marketKey];

    const syMinted = await pendleDepositSy(pendleData.SY, parseEther(amount.toString()), user);
    const am = syMinted / 2n;

    await pendleDepositPTAndYT(marketKey, user, amount);

    const marketContract = await ethers.getContractAt("IPendleMarketV3", pendleData.MARKET);
    const syToken = await ethers.getContractAt("IPendleSYToken", pendleData.SY);
    const ptToken = await ethers.getContractAt("IERC20Metadata", pendleData.PT);

    await syToken.connect(user).transfer(marketContract, am);
    await ptToken.connect(user).transfer(marketContract, am);

    await marketContract.connect(user).mint(user, am, am);
}

export async function pendleWithdrawLP(marketKey: PendleKeys, user: Signer, amount: number) {
    const pendleData = PendlePools[marketKey];

    const marketContract = await ethers.getContractAt("IPendleMarketV3", pendleData.MARKET);

    await marketContract.connect(user).transfer(marketContract, parseEther(amount.toString()));
    await marketContract.connect(user).burn(user, user, parseEther(amount.toString()));
}

export async function pendleWithdrawPT(marketKey: PendleKeys, user: Signer, amount: number) {
    const pendleData = PendlePools[marketKey];
    const ptToken = await ethers.getContractAt("IERC20Metadata", pendleData.PT);
    const ytToken = await ethers.getContractAt("IPendleYTToken", pendleData.YT);

    await ptToken.connect(user).transfer(ytToken, parseEther(amount.toString()));
    await ytToken.connect(user).redeemPY(user);
}

export async function pendleWithdrawYT(marketKey: PendleKeys, user: Signer, amount: number) {
    const pendleData = PendlePools[marketKey];

    const ytToken = await ethers.getContractAt("IPendleYTToken", pendleData.YT);

    await ytToken.connect(user).transfer(ytToken, parseEther(amount.toString()));
    await ytToken.connect(user).redeemPY(user);
}

export const pendleDepositLPRouter = async (marketKey: PendleKeys, user: Signer, amount: bigint) => {
    const pendleData = PendlePools[marketKey];

    const router = await ethers.getContractAt("IPendleRouterV4", PENDLE_ROUTER_V4);

    // Get market contract to access SY token
    const syToken = await ethers.getContractAt("IPendleSYToken", pendleData.SY);

    const tokensIn = await syToken.getTokensIn();

    const underlying = tokensIn[0];
    const underlyingContract = await ethers.getContractAt("IERC20Metadata", underlying.toString());

    // Approve router to spend underlying tokens
    await underlyingContract.connect(user).approve(PENDLE_ROUTER_V4, amount);

    // Create TokenInput
    const tokenInput = {
        tokenIn: underlying.toString(),
        netTokenIn: amount,
        tokenMintSy: underlying.toString(),
        pendleSwap: ZeroAddress,
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
        user, // receiver
        pendleData.MARKET, // market
        1n, // index of SY token
        approxParams, // guessLpOut
        tokenInput, // input
        EMPTY_LIMIT_DATA // limit
    );

    await tx.wait();
};

export const pendleWithdrawLPRouter = async (marketKey: PendleKeys, user: Signer, amount: bigint) => {
    const pendleData = PendlePools[marketKey];

    const router = await ethers.getContractAt("IPendleRouterV4", PENDLE_ROUTER_V4);
    const marketContract = await ethers.getContractAt("IPendleMarketV3", pendleData.MARKET);

    // Get market tokens to identify the underlying token
    const syToken = await ethers.getContractAt("IPendleSYToken", pendleData.SY);
    const tokensOut = await syToken.getTokensOut();

    const underlying = tokensOut[0];

    // Approve router to spend LP tokens
    await marketContract.connect(user).approve(PENDLE_ROUTER_V4, amount);

    // Create SwapData for no swap
    const swapData = {
        swapType: 0, // NONE
        extRouter: ZeroAddress,
        extCalldata: "0x",
        needScale: false,
    };

    // Create TokenOutput configuration
    const tokenOutput = {
        tokenOut: underlying,
        minTokenOut: 0n,
        tokenRedeemSy: underlying,
        pendleSwap: ZeroAddress,
        swapData: swapData,
    };

    // Call removeLiquiditySingleToken on the router
    const tx = await router.connect(user).removeLiquiditySingleToken(
        user, // receiver
        pendleData.MARKET, // market
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

export const pendleDepositPTRouter = async (marketKey: PendleKeys, user: Signer, amount: bigint) => {
    const pendleData = PendlePools[marketKey];

    const userAddress = await user.getAddress();
    const router = await ethers.getContractAt("IPendleRouterV4", PENDLE_ROUTER_V4);
    const marketContract = await ethers.getContractAt("IPendleMarketV3", pendleData.MARKET);

    // Get market tokens to identify the PT token
    const ptToken = await ethers.getContractAt("IERC20", pendleData.PT);

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
            pendleData.MARKET, // market
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

export const pendleDepositYTRouter = async (marketKey: PendleKeys, user: Signer, amount: bigint) => {
    const pendleData = PendlePools[marketKey];

    const userAddress = await user.getAddress();
    const router = await ethers.getContractAt("IPendleRouterV4", PENDLE_ROUTER_V4);

    const syToken = await ethers.getContractAt("IPendleSYToken", pendleData.SY);

    const tokensIn = await syToken.getTokensIn();
    const underlying = tokensIn[0];

    const underlyingContract = await ethers.getContractAt("IERC20Metadata", underlying.toString());

    // Approve router to spend underlying tokens
    await underlyingContract.connect(user).approve(PENDLE_ROUTER_V4, amount);

    // Create TokenInput
    const tokenInput = {
        tokenIn: underlying.toString(),
        netTokenIn: amount,
        tokenMintSy: underlying.toString(),
        pendleSwap: ZeroAddress,
        swapData: EMPTY_SWAP_DATA,
    };

    try {
        // First, let's estimate the expected output using staticCall
        const estimatedResult = await router.connect(user).addLiquiditySingleTokenKeepYt.staticCall(
            userAddress, // receiver
            pendleData.MARKET, // market
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
            pendleData.MARKET, // market
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
    market: IPendleMarketV3; // IPendleMarketV3

    // Core token contracts
    sy: IPendleSYToken; // IPendleSYToken
    pt: IERC20Metadata; // IERC20Metadata
    yt: IERC20Metadata; // IERC20Metadata
}

/**
 * Retrieves the contract instances for a Pendle market including PT, YT, SY tokens
 * @param market - The address of the Pendle market contract
 * @returns Promise<PendleMarketContracts> - Contract instances for:
 *   - Market contract (IPendleMarketV3)
 *   - SY token contract (IPendleSYToken)
 *   - PT token contract (IERC20Metadata)
 *   - YT token contract (IERC20Metadata)
 */
export const getPendleMarketContracts = async (market: AddressLike): Promise<PendleMarketContracts> => {
    const marketContract = await ethers.getContractAt("IPendleMarketV3", market.toString());

    // Get market tokens (SY, PT, YT)
    const {_SY, _PT, _YT} = await marketContract.readTokens();

    // Get SY token contract to access input/output tokens
    const syToken = await ethers.getContractAt("IPendleSYToken", _SY);

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
