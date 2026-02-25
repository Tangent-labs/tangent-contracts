import { BaseContext } from "../../contexts/BaseContext";
import { OracleContext } from "../../contexts/OracleContext";
import { LpDeployContext } from "../../contexts/LPDeployContext";

import { SIMU_USG_LPS_CONFIG } from "./config";
import { formatEther, formatUnits, parseEther, parseUnits } from "ethers";
import { IAggregatorStablePriceV3 } from "../../../../../typechain-types";
import { ethers } from "hardhat";
import * as fs from "fs";
import { time } from "@nomicfoundation/hardhat-toolbox/network-helpers";
import { giveTokensToAddresses } from "../../../thief/thief";
import { COMMON_ERC20S } from "@tangent/defi-resources";
import { THIEF_TOKEN_CONFIG } from "@tangent/defi-resources/build/ressources/erc20/thiefConfig";


export async function main() {
    const csvs = []
    for (let i = 0; i < SIMU_USG_LPS_CONFIG.length; i++) {
        const config = SIMU_USG_LPS_CONFIG[i];
        const csv = (await simu(config)).map(row => row.join(",")).join("\r\n")
        const fileName = `A_${config.a}_OFFPEGMULTI_${config.offPegFeeMulti}.csv`
        fs.writeFileSync(fileName, csv);
        console.log(`${fileName} created at the root `)
    }
}

main()

async function simu(
    lpConfig: {
        a: number;
        offPegFeeMulti: number;
    }
) {
    const baseContext = new BaseContext(1);
    const lpDeployContext = new LpDeployContext();

    await baseContext.setupTestUsers();

    const controlTower = await (await ethers.getContractFactory("ControlTower")).deploy(baseContext.users[0], baseContext.users[0]);

    const usg = await (await ethers.getContractFactory("USG")).deploy(baseContext.users[0], controlTower);
    await usg.waitForDeployment();


    await giveTokensToAddresses(baseContext.users, [
        { address: await usg.getAddress(), amount: 10_000_000, decimals: 18, isVyper: false, slotBalance: 0 },
        { ...THIEF_TOKEN_CONFIG.USDC, amount: 10_000_000 },
        { ...THIEF_TOKEN_CONFIG.frxUSD, amount: 10_000_000 },
    ]);

    const usdc = await ethers.getContractAt("IERC20Metadata", COMMON_ERC20S.USDC)
    const frxUSD = await ethers.getContractAt("IERC20Metadata", COMMON_ERC20S.frxUSD)

    // Create USG LP
    const usgUSDCLp = await lpDeployContext.deployStableLP(
        baseContext,
        "USG-USDC",
        "USG-USDC",
        [usdc, usg],
        [1_000_000, 1_000_000],
        lpConfig.a, // A
        1000000, // fee
        lpConfig.offPegFeeMulti,// OffPeg x
        866, // ema exp time
        0 // ImplemID
    );

    // Create USG LP
    const usgFrxUSDLp = await lpDeployContext.deployStableLP(
        baseContext,
        "USG-frxUSD",
        "usgfrxUSD",
        [frxUSD, usg],
        [1_000_000, 1_000_000],
        lpConfig.a, // A
        1000000, // fee
        lpConfig.offPegFeeMulti,// OffPeg x
        866, // ema exp time
        0 // ImplemID
    );

    const USGOracle = (await (
        await ethers.getContractFactory("AggregatorStablePriceV3")
    ).deploy(usg, "1000000000000000", baseContext.users[0])) as unknown as IAggregatorStablePriceV3;
    await USGOracle.waitForDeployment();

    await USGOracle.add_price_pair(usgUSDCLp);
    await USGOracle.add_price_pair(usgFrxUSDLp);

    const usgLps = [usgUSDCLp, usgFrxUSDLp]
    for (let i = 0; i < usgLps.length; i++) {
        const lp = usgLps[i];
        await baseContext.approveCurveLP(await lp.getAddress());
    }


    const consecutiveDumps = 50
    let dump = 0
    const amountDump = 20_000
    const csv = [["A", "OffPeg"], [lpConfig.a, lpConfig.offPegFeeMulti], ["Dump Amount", "Contrepartie bal", "USG bal", "Price Oracle"]]

    for (let i = 0; i < consecutiveDumps; i++) {

        dump += amountDump
        const lpBalances = []
        for (let j = 0; j < usgLps.length; j++) {
            const lp = usgLps[j];
            await lp["exchange(int128,int128,uint256,uint256)"](1, 0, parseEther("20000"), 0)
            lpBalances.push([await lp.balances(0), await lp.balances(1)])

        }
        await time.increase(20 * 60)
        await USGOracle.price_w()
        const priceOracle = await USGOracle.price()
        csv.push([dump.toString(), (Number(formatUnits(lpBalances[0][0], 6).toString()) + Number(formatUnits(lpBalances[1][0], 18).toString())).toString(), (Number(formatEther(lpBalances[0][1]).toString()) + Number(formatEther(lpBalances[1][1]).toString())).toString(), formatEther(priceOracle)])

    }

    return csv;
}
