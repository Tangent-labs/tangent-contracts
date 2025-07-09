import {HardhatEthersSigner} from "@nomicfoundation/hardhat-ethers/signers";
import {IERC20, MarketExternalActions} from "../../../../typechain-types";
import {MaxUint256} from "ethers";

export const borrowUSG = async (market: MarketExternalActions, marketAddress: string, collatContract: IERC20, user: HardhatEthersSigner, borrowAmount: bigint) => {
    const userAddress = await user.getAddress();
    await collatContract.connect(user).approve(marketAddress, MaxUint256);
    await market?.connect(user)?.borrow(userAddress, borrowAmount);
};
