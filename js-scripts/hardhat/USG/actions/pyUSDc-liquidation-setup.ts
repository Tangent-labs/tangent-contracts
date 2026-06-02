import { impersonateAccount, setBalance } from "@nomicfoundation/hardhat-toolbox/network-helpers";
import { parseEther } from "ethers";
import { ethers } from "hardhat";
import { PROD_ADDRESSES } from "../../../../ignition/prod_addresses";


export async function zaza() {


    const market = await ethers.getContractAt("MarketExternalActions", PROD_ADDRESSES.MARKETS.CURVE_GAUGE.PYUSD_USDC)

    const fakeOracle = await ethers.deployContract("MockOracle")

    const dao = await ethers.getSigner(PROD_ADDRESSES.DAO)
    await impersonateAccount(PROD_ADDRESSES.DAO)
    await setBalance(PROD_ADDRESSES.DAO, parseEther("10"))
    await fakeOracle.connect(dao).setLastAnswer(parseEther("0.92"))
    await market.connect(dao).setCollatOracle(fakeOracle)


}
zaza()
