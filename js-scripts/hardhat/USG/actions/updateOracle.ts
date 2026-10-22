import { impersonateAccount, stopImpersonatingAccount } from "@nomicfoundation/hardhat-toolbox/network-helpers";
import { parseEther } from "ethers";
import { ethers } from "hardhat";
import { PROD_ADDRESSES } from "../../../../ignition/prod_addresses";

export async function updateOracle(marketAddress: string) {

    const [u0, u1, u2] = await ethers.getSigners()
    const newFakeOracle = await ethers.deployContract("MockOracle")

    await newFakeOracle.setLastAnswer(parseEther("0.97"))


    const market = await ethers.getContractAt("MarketCore", marketAddress);
    const owner = await market.owner()
    const ownerSigner = await ethers.getSigner(owner)

    const tx = await u2.sendTransaction({
        to: owner,
        value: ethers.parseEther("1.0")   // ou ethers.utils.parseEther("1") sur les anciennes versions
    });


    await impersonateAccount(owner)
    await market.connect(ownerSigner).setCollatOracle(newFakeOracle)
    await stopImpersonatingAccount(owner)
}

updateOracle(PROD_ADDRESSES.MARKETS.STAKEDAO_VAULT.frxUSD_scrvUSD);
// updateOracle(PROD_ADDRESSES.MARKETS.CURVE_GAUGE.RLUSD_USDC);
// updateOracle(PROD_ADDRESSES.MARKETS.STAKEDAO_VAULT.frxUSD_sUSDS);
// updateOracle("0x4903F0d3698DDC5CA66040B235de0a2126A41437");