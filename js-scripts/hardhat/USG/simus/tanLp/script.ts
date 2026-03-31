import { BaseContext } from "../../contexts/BaseContext";
import { LpDeployContext } from "../../contexts/LPDeployContext";

import { SIMU_TAN_LPS_CONFIG } from "./config";
import { formatEther } from "ethers";
import { ethers } from "hardhat";
import * as fs from "fs";
import { impersonateAccount, stopImpersonatingAccount, time } from "@nomicfoundation/hardhat-toolbox/network-helpers";
import { giveTokensToAddresses } from "../../../thief/thief";
import { COMMON_ERC20S } from "@tangent/defi-resources";
import { THIEF_TOKEN_CONFIG } from "@tangent/defi-resources/build/ressources/erc20/thiefConfig";
import { PROD_ADDRESSES } from "../../../../../ignition/prod_addresses";


export async function main() {
    const csvs = []
    for (let i = 0; i < SIMU_TAN_LPS_CONFIG.length; i++) {
        const config = SIMU_TAN_LPS_CONFIG[i];
        const csv = (await simu(config)).map(row => row.join(",")).join("\r\n")
        const fileName = `initAmount0_${formatEther(config.intialAmounts[0])}_initAmount1_${formatEther(config.intialAmounts[1])}_dumpTimes_${config.dump.times}_dumpAmount_${formatEther(config.dump.amount)}.csv`
        fs.writeFileSync(fileName, csv);
        console.log(`${fileName} created at the root `)
    }
}

main()

async function simu(
    param: {
        intialAmounts: bigint[],
        dump: {
            times: number;
            amount: bigint;
        }
    }
) {

    const dao = await ethers.getSigner(PROD_ADDRESSES.DAO)

    const baseContext = new BaseContext(1);
    const lpDeployContext = new LpDeployContext();

    await baseContext.setupTestUsers();


    await giveTokensToAddresses(baseContext.users, [
        { ...THIEF_TOKEN_CONFIG.WETH, amount: 10_000_000 },
    ]);
    const tanFactory = await ethers.getContractFactory("TAN")

    const weth = await ethers.getContractAt("IERC20Metadata", COMMON_ERC20S.WETH)
    const tan = await tanFactory.deploy(baseContext.users[0])

    const initialPrice = param.intialAmounts[0] * (10n * 10n ** 18n) / param.intialAmounts[1]
    // Create USG LP
    const tanETHLp = await lpDeployContext.deploy_TAN_ETH_LPP(
        tan,
        {
            A: 400000,
            gamma: 150000000000000,
            mid_fee: 26000000,
            out_fee: 45000000,
            fee_gamma: 230000000000000,
            allowed_extra_profit: 10000000000000,
            adjustment_step: 150000000000000,
            ma_exp_time: 601,
            initial_price: initialPrice,
        },
        [param.intialAmounts[0], param.intialAmounts[1]]
    );
    await baseContext.approveCurveLP(await tanETHLp.getAddress());

    const csv = [["Times", "Amount"], [param.dump.times, formatEther(param.dump.amount)], ["Dump Amount", "WETH bal", "TAN bal", "Last_price", "Price Oracle"]]
    csv.push([
        "0",
        Number(formatEther(await tanETHLp.balances(0))).toFixed(2),// ETH
        Number(formatEther(await tanETHLp.balances(1))).toFixed(2), // TAN
        (Number(formatEther(await tanETHLp.last_prices()))).toString(),
        (Number(formatEther(await tanETHLp.price_oracle()))).toString()
    ])
    let dumpAcc = 0n
    for (let i = 0; i < param.dump.times; i++) {
        dumpAcc += param.dump.amount
        await impersonateAccount(PROD_ADDRESSES.DAO)
        await tanETHLp.connect(dao)["exchange(uint256,uint256,uint256,uint256)"](1, 0, param.dump.amount, 0)
        await stopImpersonatingAccount(PROD_ADDRESSES.DAO)

        await time.increase(20 * 60)
        csv.push([
            Number(formatEther(dumpAcc.toString())).toFixed(),
            Number(formatEther(await tanETHLp.balances(0))).toFixed(2),// ETH
            Number(formatEther(await tanETHLp.balances(1))).toFixed(2), // TAN
            (Number(formatEther(await tanETHLp.last_prices()))).toString(),
            (Number(formatEther(await tanETHLp.price_oracle()))).toString()
        ])

    }

    return csv;
}
