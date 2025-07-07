import {ethers} from "hardhat";
import {HardhatEthersSigner} from "@nomicfoundation/hardhat-ethers/signers";
import {MaxUint256} from "ethers";
import {ICurveStableSwapNG} from "../../../../typechain-types/src/interfaces/externals/Curve/ICurveStableSwapNG";

export const depositOnCurveGauge = async (address: string, lp: ICurveStableSwapNG, user: HardhatEthersSigner, amount: bigint) => {
    const gauge = await ethers.getContractAt("ISharedLiquidityGauge", address);
    await lp.connect(user).approve(gauge, MaxUint256);
    gauge.connect(user)["deposit(uint256)"](amount);
};
