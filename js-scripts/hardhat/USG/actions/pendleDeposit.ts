import {HardhatEthersSigner} from "@nomicfoundation/hardhat-ethers/signers";
import {sdPENDLE} from "defi-resources/build/ressources/erc20/stakeDao";
import {AddressLike} from "ethers";
import {ethers} from "hardhat";

export const PENDLE_ROUTER = "0x888888888889758F76e7103c6CbF23ABbF58F946";

export const pendleDeposit = async (market: AddressLike, amountPT: BigInt, amountSY: BigInt, user: HardhatEthersSigner) => {
    const marketContract = await ethers.getContractAt("IPendleMarketV3", market.toString());

    const {_PT, _SY, _YT} = await marketContract.readTokens();
    const ptAddress = _PT.toString();
    const syAddress = _SY.toString();

    console.log("ptAddress", ptAddress);
    console.log("syAddress", syAddress);
    console.log("YTAddress", _YT);

    // const ptContract = await ethers.getContractAt("IERC20", ptAddress);
    // const syContract = await ethers.getContractAt("IERC20", syAddress);

    // await ptContract.connect(user).approve(PENDLE_ROUTER, amountPT.toString());
    // await syContract.connect(user).approve(PENDLE_ROUTER, amountSY.toString());

    // const userAddress = await user.getAddress();

    // const tx = await marketContract.connect(user).mint(userAddress, amountPT.toString(), amountSY.toString());
    // await tx.wait();
};
