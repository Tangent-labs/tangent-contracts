import {thiefConfig} from "@tangent/defi-resources";
import {giveTokensToAddresses} from "../thief/thief";
import {BoosterSetup} from "./Booster.setup";
import {ethers} from "hardhat";
import {time} from "@nomicfoundation/hardhat-toolbox/network-helpers";

async function main() {
    const boosterSetup = new BoosterSetup();

    await boosterSetup.setupTestUsers();
    await boosterSetup.setupContracts();
    const oneWeek = 86_400n * 7n;

    const lastTimestamp = (BigInt(await time.latest()) / oneWeek) * oneWeek;
    let nextTimestamp = lastTimestamp + oneWeek + 10n * 60n * 60n;

    await giveTokensToAddresses(
        [await ethers.getSigner(await boosterSetup.sdCrvBuffer.getAddress())],
        [
            {...thiefConfig.THIEF_TOKEN_CONFIG.CRV, amount: 100000},
            {...thiefConfig.THIEF_TOKEN_CONFIG.sd_CRV, amount: 10000},
            {...thiefConfig.THIEF_TOKEN_CONFIG.crvUSD, amount: 100000},
        ]
    );

    await giveTokensToAddresses(
        [await ethers.getSigner(await boosterSetup.sdPendleBuffer.getAddress())],
        [
            {...thiefConfig.THIEF_TOKEN_CONFIG.PENDLE, amount: 100000},
            {...thiefConfig.THIEF_TOKEN_CONFIG.sd_PENDLE, amount: 10000},
        ]
    );

    await giveTokensToAddresses(
        [await ethers.getSigner(await boosterSetup.sdFxnBuffer.getAddress())],
        [
            {...thiefConfig.THIEF_TOKEN_CONFIG.sd_FXN, amount: 100000},
            {...thiefConfig.THIEF_TOKEN_CONFIG.wstETH, amount: 1},
        ]
    );

    await giveTokensToAddresses(
        [await ethers.getSigner(await boosterSetup.sdBalBuffer.getAddress())],
        [
            {...thiefConfig.THIEF_TOKEN_CONFIG.sd_BAL, amount: 100000},
            {...thiefConfig.THIEF_TOKEN_CONFIG.USDC, amount: 10000},
            {...thiefConfig.THIEF_TOKEN_CONFIG.BAL, amount: 10000},
        ]
    );

    await giveTokensToAddresses([await ethers.getSigner(await boosterSetup.cvgSDTBuffer.getAddress())], [{...thiefConfig.THIEF_TOKEN_CONFIG.cvgSDT, amount: 100000}]);

    await giveTokensToAddresses([await ethers.getSigner(await boosterSetup.cvgCVX.getAddress())], [{...thiefConfig.THIEF_TOKEN_CONFIG.cvgCVX, amount: 100000}]);
    console.log("cvgCVX balance of cvgCVX ", await boosterSetup.cvgCVX.balanceOf(await boosterSetup.cvgCVX.getAddress()));

    await time.increaseTo(nextTimestamp);

    await boosterSetup.cycleProcessor.cycleProcess(3, [
        boosterSetup.SD_CRV_STAKING,
        boosterSetup.SD_PENDLE_STAKING,
        boosterSetup.SD_FXN_STAKING,
        boosterSetup.SD_BAL_STAKING,
        boosterSetup.CVG_SDT_STAKING,
    ]);
    await boosterSetup.CVG_CVX_STAKING.processCvxRewards();
}
main();
