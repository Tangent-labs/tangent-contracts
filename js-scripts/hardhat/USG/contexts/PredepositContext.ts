import { ethers } from "hardhat"
import { impersonateAccount, setStorageAt, stopImpersonatingAccount } from "@nomicfoundation/hardhat-toolbox/network-helpers"
import { parseEther, zeroPadValue } from "ethers"

export async function addExternalProducts(lps: string[]) {
    // Deploy gauges on Curve
    const curveGauges = await addGaugesOnCurve(lps)
    console.log(curveGauges)

    // Deploy staking contracts on Convex
    const pids = await addGaugesOnConvex(lps, curveGauges)
    console.log(pids)

    // Deploy staking contracts on StakeDao
    const stakeVaults = await addGaugesOnStakeDao(curveGauges)
    console.log(stakeVaults)

}

export async function addGaugesOnCurve(lps: string[]) {
    const gauges: string[] = []
    const gaugeController = await ethers.getContractAt("IGaugeController", "0x2F50D538606Fa9EDD2B11E2446BEb18C9D5846bB")
    const curveStableSwapFactoryNG = await ethers.getContractAt("ICurveStableSwapFactoryNG", "0x6a8cbed756804b16e05e741edabd5cb544ae21bf")

    const admin = await gaugeController.admin()
    const adminSigner = await ethers.getSigner(admin)

    const owner = (await ethers.getSigners())[0]
    await owner.sendTransaction({ to: admin, value: parseEther("1") });

    await impersonateAccount(admin)
    for (let i = 0; i < lps.length; i++) {
        const lp = lps[i];
        await curveStableSwapFactoryNG.deploy_gauge(lp)
        console.log("A")

        const poolData = await curveStableSwapFactoryNG.pool_data(lp)
        console.log("B")

        console.log(poolData)

        await gaugeController.connect(adminSigner)["add_gauge(address,int128)"](lp, 0)
        const amountGauges = await gaugeController.n_gauges()
        gauges.push(await gaugeController.gauges(amountGauges - 1n))
    }
    await stopImpersonatingAccount(admin)
    return gauges;
}

export async function addGaugesOnConvex(lps: string[], gauges: string[]) {
    const pids: bigint[] = []
    const booster = await ethers.getContractAt("ICvxBooster", "0xF403C135812408BFbE8713b5A23a04b3D48AAE31")
    const ownerSigner = (await ethers.getSigners())[0]
    const ownerAddress = await ownerSigner.getAddress()

    // Set the poolManager slot in Convex 
    await setStorageAt("0xF403C135812408BFbE8713b5A23a04b3D48AAE31", 6, zeroPadValue(ownerAddress, 32))

    const lastIndex = await booster.poolLength()
    pids.push(lastIndex)
    pids.push(lastIndex + 1n)

    for (let i = 0; i < lps.length; i++) {
        const lp = lps[i];
        const gauge = gauges[i];
        await booster.connect(ownerSigner).addPool(lp, gauge, 0)
    }

    return pids
}

export async function addGaugesOnStakeDao(gauges: string[]) {
    const factory = await ethers.getContractAt("ICurveFactory", "0x37b015fa4ba976c57e8e3a0084288d9dcea06003")


    for (let i = 0; i < gauges.length; i++) {
        const tx = await factory.createVault(gauges[i]);
        const receipt = await tx.wait()
        console.log("coucou")
        console.log(receipt?.logs)
    }


}

