import { parseEther } from "ethers";

export const SIMU_TAN_LPS_CONFIG = [
    {
        intialAmounts: [parseEther("125"), parseEther((2_500_000).toString())],
        dump: { times: 1, amount: parseEther((3_170_000).toString()) },
    },
    {
        intialAmounts: [parseEther("125"), parseEther((2_500_000).toString())],
        dump: { times: 10, amount: parseEther((317_000).toString()) },
    },
    {
        intialAmounts: [parseEther("125"), parseEther((2_000_000).toString())],
        dump: { times: 1, amount: parseEther((3_170_000).toString()) },
    },
    {
        intialAmounts: [parseEther("125"), parseEther((2_000_000).toString())],
        dump: { times: 10, amount: parseEther((317_000).toString()) },
    },
]