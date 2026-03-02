import { PROD_ADDRESSES } from "../prod_addresses";
import { ethers } from "hardhat";
import { IAggregatorStablePriceV3, IPegKeeperRegulator } from "../../typechain-types";

export async function main() {

    const usgOracleFactory = await ethers.getContractFactory("AggregatorStablePriceV3")
    const pegKeeperFactory = await ethers.getContractFactory("PegKeeperV2")
    const pegKeeperRegulatorFactory = await ethers.getContractFactory("PegKeeperRegulator")
    const yearnVaultCreator = await ethers.getContractAt("IYearnVaultFactory", "0x770D0d1Fb036483Ed4AbB6d53c1C88fb277D812F");


    const USGOracle = (await usgOracleFactory.deploy(
        PROD_ADDRESSES.USG,
        "1000000000000000",
        PROD_ADDRESSES.DAO
    )) as unknown as IAggregatorStablePriceV3;
    await USGOracle.waitForDeployment();

    const pegKeeperRegulator = await pegKeeperRegulatorFactory.deploy(PROD_ADDRESSES.USG, USGOracle, PROD_ADDRESSES.FEE_TRESO, PROD_ADDRESSES.DAO, PROD_ADDRESSES.DAO) as unknown as IPegKeeperRegulator;
    await pegKeeperRegulator.waitForDeployment();

    const pegKeeperUSG_USDC = await pegKeeperFactory.deploy(PROD_ADDRESSES.USG_USDC, "20000", pegKeeperRegulator, PROD_ADDRESSES.DAO) as unknown as IPegKeeperRegulator;
    await pegKeeperUSG_USDC.waitForDeployment();

    const receipt = (await (await yearnVaultCreator.deploy_new_vault(PROD_ADDRESSES.USG, "Staked USG", "sUSG", PROD_ADDRESSES.DAO, 7 * 86400)).wait())!

    const sUSG = ethers.getAddress(ethers.dataSlice(receipt.logs[0].topics[1], 12));



}
main()