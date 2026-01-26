import { COMMON_ERC20S, veTokens } from "@tangent/defi-resources";
import { ONE_WEEK_IN_SECONDS, ONE_YEAR_IN_SECONDS } from "@tangent/defi-resources/build/utils/durations";
import { AddressLike, Contract, MaxUint256, parseEther, Signer } from "ethers";
import { ethers } from "hardhat";

export const abiVeYFI = [{
    "stateMutability": "nonpayable",
    "type": "function",
    "name": "modify_lock",
    "inputs": [
        {
            "name": "amount",
            "type": "uint256"
        },
        {
            "name": "unlock_time",
            "type": "uint256"
        }
    ],
    "outputs": [
        {
            "name": "",
            "type": "tuple",
            "components": [
                {
                    "name": "amount",
                    "type": "uint256"
                },
                {
                    "name": "end",
                    "type": "uint256"
                }
            ]
        }
    ]
}]

export const abiVlCVX = [{
    "inputs": [
        {
            "internalType": "address",
            "name": "_account",
            "type": "address"
        },
        {
            "internalType": "uint256",
            "name": "_amount",
            "type": "uint256"
        },
        {
            "internalType": "uint256",
            "name": "_spendRatio",
            "type": "uint256"
        }
    ],
    "name": "lock",
    "outputs": [],
    "stateMutability": "nonpayable",
    "type": "function"
}]

export const abiStRSUP = [{
    "inputs": [
        {
            "internalType": "uint256",
            "name": "_amount",
            "type": "uint256"
        }
    ],
    "name": "stake",
    "outputs": [
        {
            "internalType": "uint256",
            "name": "",
            "type": "uint256"
        }
    ],
    "stateMutability": "nonpayable",
    "type": "function"
}]

export async function approveMax(signer: Signer, tokenAddress: string, allow: AddressLike) {
    const token = await ethers.getContractAt("IERC20", tokenAddress);
    await token.connect(signer).approve(allow, 0);
    await token.connect(signer).approve(allow, MaxUint256);
}

export async function lockYFI(amount: bigint, signer: Signer, now: number) {
    await approveMax(signer, COMMON_ERC20S.YFI, veTokens.veYFI)

    const veYFI = new Contract(veTokens.veYFI, abiVeYFI)
    await veYFI.connect(signer).modify_lock(amount, now + 365 * 24 * 3600)
}


export async function lockCVX(amount: bigint, signer: Signer) {
    await approveMax(signer, COMMON_ERC20S.CVX, veTokens.vlCVX)

    const vlCVX = await ethers.getContractAt("IVlCVX", veTokens.vlCVX)
    await vlCVX.connect(signer).lock(await signer.getAddress(), amount, 0)
}

export async function lockPENDLE(amount: bigint, signer: Signer, now: number) {
    await approveMax(signer, COMMON_ERC20S.PENDLE, veTokens.vePENDLE)

    const vePENDLE = await ethers.getContractAt("IVePENDLE", veTokens.vePENDLE)
    await vePENDLE.connect(signer).increaseLockPosition(amount, Math.trunc(now / ONE_WEEK_IN_SECONDS) * ONE_WEEK_IN_SECONDS + ONE_WEEK_IN_SECONDS * 100)
}

export async function lockClassicVe(veToken: "veCRV" | "veSDT" | "veFXN", amount: bigint, signer: Signer, now: number) {
    let tokenAddress = ""
    let veTokenAddress = ""
    if (veToken === "veCRV") {
        tokenAddress = COMMON_ERC20S.CRV
        veTokenAddress = veTokens.veCRV
    } else if (veToken == "veFXN") {
        tokenAddress = COMMON_ERC20S.FXN
        veTokenAddress = veTokens.veFXN
    } else if (veToken == "veSDT") {
        tokenAddress = COMMON_ERC20S.SDT
        veTokenAddress = veTokens.veSDT
    }

    await approveMax(signer, tokenAddress, veTokenAddress)

    const veTokenContract = await ethers.getContractAt("IVeToken", veTokenAddress)
    await veTokenContract.connect(signer).create_lock(amount, now + 2 * ONE_YEAR_IN_SECONDS)
}