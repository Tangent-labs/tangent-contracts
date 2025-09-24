import {HardhatEthersSigner} from "@nomicfoundation/hardhat-ethers/signers";
import {parseEther} from "ethers";
import {ethers} from "hardhat";

export const CONTROLLER_MAPPING: {
    [gaugeControllerKey: string]: {
        controller: string;
        gauges: {
            [gaugeKey: string]: string;
        };
    };
} = {
    CRV: {
        controller: "0x2F50D538606Fa9EDD2B11E2446BEb18C9D5846bB",
        gauges: {
            USDC_USDf: "0x156527deF9a2AB4F54C849575f23dC4BB439d9d9",
            crvUSD_USDC: "0x95f00391cB5EebCd190EB58728B4CE23DbFa6ac1",
            crvUSD_USDT: "0x4e6bB6B7447B7B2Aa268C16AB87F4Bb48BF57939",
        },
    },
    FXN: {
        controller: "0xe60eB8098B34eD775ac44B1ddE864e098C6d7f37",
        gauges: {
            STABILITY_POOL: "0x215D87bd3c7482E2348338815E059DE07Daf798A",
            cvxFXN_FXN: "0x95f00391cB5EebCd190EB58728B4CE23DbFa6ac1",
        },
    },
};
export async function voteOnGauge(gaugeKey: string, user: HardhatEthersSigner, voteAmount: number, gaugeControllerKey: "CRV" | "FXN") {
    const gaugeControllerAddress = CONTROLLER_MAPPING[gaugeControllerKey].controller;
    const gaugeController = await ethers.getContractAt("IGaugeController", gaugeControllerAddress);
    const gauge = CONTROLLER_MAPPING[gaugeControllerKey].gauges[gaugeKey];

    await gaugeController.connect(user).vote_for_gauge_weights(gauge, parseEther(voteAmount.toString()));
}
