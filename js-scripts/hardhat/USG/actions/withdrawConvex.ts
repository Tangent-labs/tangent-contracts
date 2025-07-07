import {ethers} from "hardhat";
import {MaxUint256} from "ethers";
import {ICurveStableSwapNG} from "../../../../typechain-types/src/interfaces/externals/Curve/ICurveStableSwapNG";
import {HardhatEthersSigner} from "@nomicfoundation/hardhat-ethers/signers";

export const withdrawConvex = async (address: string, lp: ICurveStableSwapNG, user: HardhatEthersSigner, amount: bigint) => {
    const rewardsContract = await ethers.getContractAt("ICvxRewardToken", address);
    await lp.connect(user).approve(address, MaxUint256);
    await rewardsContract.connect(user).withdrawAndUnwrap(amount, true);
};
