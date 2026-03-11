import { ethers } from "hardhat";
import { PROD_ADDRESSES } from "../../../../ignition/prod_addresses"
import { formatEther, formatUnits } from "ethers";

async function fetchAndLogLPsState() {
    const lps = [PROD_ADDRESSES.USG_USDC, PROD_ADDRESSES.USG_frxUSD]

    const rows: { name: string; balance0: string; balance1: string; symbol0: string; symbol1: string; lastPrice: string; get_p: string, priceOracle: string }[] = []

    for (let index = 0; index < lps.length; index++) {
        const lp = await ethers.getContractAt("ICurveStableSwapNG", lps[index])
        const coin0 = await ethers.getContractAt("ERC20", await lp.coins(0))
        const coin1 = await ethers.getContractAt("ERC20", await lp.coins(1))

        const symbol0 = await coin0.symbol()
        const symbol1 = await coin1.symbol()
        const balance0 = formatUnits(await lp.balances(0), await coin0.decimals())
        const balance1 = formatUnits(await lp.balances(1), await coin1.decimals())

        rows.push({
            name: await lp.name(),
            symbol0,
            symbol1,
            balance0: Number(balance0).toLocaleString("en-US", { minimumFractionDigits: 2, maximumFractionDigits: 2 }),
            balance1: Number(balance1).toLocaleString("en-US", { minimumFractionDigits: 2, maximumFractionDigits: 2 }),
            lastPrice: Number(formatEther(await lp["last_price(uint256)"](0))).toFixed(6),
            get_p: Number(formatEther(await lp.get_p(0))).toFixed(6),
            priceOracle: Number(formatEther(await lp["price_oracle(uint256)"](0))).toFixed(6),
        })
    }

    console.table(rows.map(r => ({
        "Pool": r.name,
        [`Balance 0`]: r.balance0,
        [`Balance 1`]: r.balance1,
        "Last Price": r.lastPrice,
        "get_p": r.get_p,

        "Price Oracle": r.priceOracle,
    })))
}

fetchAndLogLPsState()