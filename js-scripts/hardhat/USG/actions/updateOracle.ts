import { impersonateAccount, stopImpersonatingAccount } from "@nomicfoundation/hardhat-toolbox/network-helpers";
import { parseEther } from "ethers";
import { ethers } from "hardhat";
import { PROD_ADDRESSES } from "../../../../ignition/prod_addresses";

export async function updateOracle(marketAddress: string) {
    const newFakeOracle = await ethers.deployContract("MockOracle")

    await newFakeOracle.setLastAnswer(parseEther("0.90"))


    const market = await ethers.getContractAt("MarketCore", marketAddress);
    const owner = await market.owner()
    const ownerSigner = await ethers.getSigner(owner)


    await impersonateAccount(owner)
    await market.connect(ownerSigner).setCollatOracle(newFakeOracle)
    await stopImpersonatingAccount(owner)
}

// updateOracle(PROD_ADDRESSES.MARKETS.STAKEDAO_VAULT.frxUSD_sUSDS);
updateOracle(PROD_ADDRESSES.MARKETS.STAKEDAO_VAULT.reUSD_scrvUSD);
