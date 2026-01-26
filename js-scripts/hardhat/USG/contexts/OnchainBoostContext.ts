import { impersonateAccount, stopImpersonatingAccount } from "@nomicfoundation/hardhat-toolbox/network-helpers"
import { Contract, parseEther, Signer } from "ethers"
import { ethers } from "hardhat"
import { onchainBoostUserConfig } from "../config/onchainBoost"
import { abiStRSUP, approveMax, lockClassicVe, lockCVX, lockPENDLE, lockYFI } from "../actions/lock-ve-tokens";
import { giveTokenToAddress } from "../../thief/thief";
import { COMMON_ERC20S } from "@tangent/defi-resources";

export async function executeBoostContext() {

    const now = (await ethers.provider.getBlock("latest"))?.timestamp!;

    const signers = await ethers.getSigners()
    for (let i = 0; i < onchainBoostUserConfig.length; i++) {
        const user = signers[i]
        const config = onchainBoostUserConfig[i];

        if (config.llamaNFT) {
            await mintLlamaNFT(user, config.llamaNFT)
        }
        if (config.veYFI) {
            await lockYFI(parseEther(config.veYFI.toString()), user, now)
        }
        if (config.vlCVX) {
            await lockCVX(parseEther(config.vlCVX.toString()), user)
        }
        if (config.vePENDLE) {
            await lockPENDLE(parseEther(config.vePENDLE.toString()), user, now)
        }
        if (config.veCRV) {
            await lockClassicVe("veCRV", parseEther(config.veCRV.toString()), user, now)
        }
        if (config.veSDT) {
            await lockClassicVe("veSDT", parseEther(config.veSDT.toString()), user, now)
        }
        if (config.veFXN) {
            await lockClassicVe("veFXN", parseEther(config.veFXN.toString()), user, now)
        }
        if (config.sINV) {
            await giveTokenToAddress(user, "sINV", parseEther(config.sINV.toString()))
        }
        if (config.stRESOLV) {
            await giveTokenToAddress(user, "stRESOLV", parseEther(config.stRESOLV.toString()))
        }
        if (config.stRSUP) {
            await stakeRSUP(user, parseEther(config.stRSUP.toString()))
        }
    }
}

export async function mintLlamaNFT(user: Signer, nftAmount: number) {
    const llamaNFT = await ethers.getContractAt("ILlamaNFT", "0xe127cE638293FA123Be79C25782a5652581Db234")
    const bigLlamaOwner = await ethers.getSigner("0x4cc25e0366c564847546f2feda3d7f0d9155b9ac")

    const owner = (await ethers.getSigners())[0]
    await owner.sendTransaction({ to: bigLlamaOwner, value: parseEther("1") });

    await impersonateAccount(await bigLlamaOwner.getAddress())
    for (let i = 0; i < nftAmount; i++) {
        const id = await llamaNFT.tokenOfOwnerByIndex(bigLlamaOwner, i)
        await llamaNFT.connect(bigLlamaOwner).transferFrom(bigLlamaOwner, user, id)
    }

    await stopImpersonatingAccount(await bigLlamaOwner.getAddress())

}

export async function stakeRSUP(signer: Signer, amount: bigint) {
    const stRSUP = new Contract("0x22222222E9fE38F6f1FC8C61b25228adB4D8B953", abiStRSUP)
    await approveMax(signer, COMMON_ERC20S.RSUP, stRSUP)
    await stRSUP.connect(signer).stake(amount)

}