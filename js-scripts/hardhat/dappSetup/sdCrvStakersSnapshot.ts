import { ethers } from "hardhat";


async function main() {
    const sdtPositionManager = await ethers.getContractAt("ISdtStakingManager", "0x7319662ad7d7ce2d1595073ea042b723f6d0dc48")
    const sdFxnStaking = await ethers.getContractAt("ISdtStaking", "0x35e30Bc815935Bb5EC1743f772331864D780cc26")

    const totalSuppNft = await sdtPositionManager.totalSupply()
    const balances: { [owner: string]: bigint } = {}
    let totalSdCrvStaked = 0n
    for (let i = 1; i <= totalSuppNft; i++) {
        const owner = await sdtPositionManager.ownerOf(i)
        const sdCrvStaked = (await sdFxnStaking.tokenTotalStaked(i))
        totalSdCrvStaked += sdCrvStaked
        if (!balances[owner]) {
            if (sdCrvStaked !== 0n) {
                balances[owner] = sdCrvStaked
            }
        } else {
            balances[owner] += sdCrvStaked
        }
    }

    console.log(totalSdCrvStaked, balances)
}

main()