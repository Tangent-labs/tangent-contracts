import { impersonateAccount, stopImpersonatingAccount } from "@nomicfoundation/hardhat-toolbox/network-helpers"
import { Contract, parseEther, Signer } from "ethers"
import { ethers } from "hardhat"
import { onchainBoostUserConfig } from "../config/onchainBoost"
import { abiStRSUP, approveMax, lockClassicVe, lockCVX, lockPENDLE, lockYFI } from "../actions/lock-ve-tokens";
import { giveTokenToAddress } from "../../thief/thief";
import { commonERC20 } from "@tangent/defi-resources";

export async function executeBoostContext() {

    const now = (await ethers.provider.getBlock("latest"))?.timestamp!;

    const signers = await ethers.getSigners()
    for (let i = 0; i < onchainBoostUserConfig.length; i++) {
        const user = signers[i]
        const config = onchainBoostUserConfig[i];
        if (config.llamaNFT) {
            await mintLlamaNFT(user, config.llamaNFT)
        }
        else if (config.veYFI) {
            await lockYFI(parseEther(config.veYFI.toString()), user, now)
        }
        else if (config.vlCVX) {
            await lockCVX(parseEther(config.vlCVX.toString()), user)
        }
        else if (config.vePENDLE) {
            await lockPENDLE(parseEther(config.vePENDLE.toString()), user)
        }
        else if (config.veCRV) {
            await lockClassicVe("veCRV", parseEther(config.veCRV.toString()), user, now)
        }
        else if (config.veSDT) {
            await lockClassicVe("veSDT", parseEther(config.veSDT.toString()), user, now)
        }
        else if (config.veFXN) {
            await lockClassicVe("veFXN", parseEther(config.veFXN.toString()), user, now)
        }
        else if (config.sINV) {
            await giveTokenToAddress(user, "sINV", parseEther(config.sINV.toString()))
        }
        else if (config.stRESOLV) {
            await giveTokenToAddress(user, "stRESOLV", parseEther(config.stRESOLV.toString()))
        }
        else if (config.stRSUP) {
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
    await approveMax(signer, commonERC20.RSUP, stRSUP)
    await stRSUP.connect(signer).stake(amount)

}