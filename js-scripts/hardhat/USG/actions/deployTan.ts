import { ethers } from "hardhat"
import { PROD_ADDRESSES } from "../../../../ignition/prod_addresses"
import { MaxUint256, parseEther, parseUnits, Signer } from "ethers"
import { impersonateAccount, stopImpersonatingAccount } from "@nomicfoundation/hardhat-toolbox/network-helpers"
import { COMMON_ERC20S } from "@tangent/defi-resources"
import { giveTokenToAddress } from "../../thief/thief"

export async function deployTan() {
    const tan = await ethers.deployContract("TAN", [PROD_ADDRESSES.DAO])
    const vsTAN = await ethers.deployContract("VsTAN", [PROD_ADDRESSES.DAO, PROD_ADDRESSES.CONTROL_TOWER, tan, PROD_ADDRESSES.USG, PROD_ADDRESSES.sUSG, PROD_ADDRESSES.ZAPPING_PROXY, parseEther("1000")])

    console.log("TAN", await tan.getAddress())
    console.log("vsTAN", await vsTAN.getAddress())
    const signers = await ethers.getSigners()
    const dao = await ethers.getSigner(PROD_ADDRESSES.DAO)

    await signers[1].sendTransaction({
        to: dao,
        value: ethers.parseEther("1"),
    });
    await impersonateAccount(PROD_ADDRESSES.DAO)
    for (let index = 0; index < signers.length - 10; index++) {
        const signer = signers[index];
        await tan.connect(dao).transfer(signer, parseEther("333000"))
    }

    await stopImpersonatingAccount(PROD_ADDRESSES.DAO)

    const lp = await deploy_TAN_ETH_LP(await tan.getAddress(), signers[0])
    console.log("LP TAN/WETH", await lp.getAddress())

}

async function deploy_TAN_ETH_LP(tan: string, owner: Signer) {

    const curveStableSwapFactory = await ethers.getContractAt("ICurveCryptoSwapFactoryNG", "0x98EE851a00abeE0d95D08cF4CA2BdCE32aeaAF7F");

    const poolCount = await curveStableSwapFactory.pool_count();
    const lpCreationTx = await curveStableSwapFactory
        .deploy_pool(
            "TAN",
            "TAN",
            [COMMON_ERC20S.WETH, tan],
            0,
            400000,
            145000000000000,
            26000000,
            45000000,
            230000000000000,
            2000000000000,
            146000000000000,
            866,
            6006006006000
        );
    await lpCreationTx.wait();

    await giveTokenToAddress(owner, "WETH", parseEther("400"))
    const lp = await ethers.getContractAt("ICurveCryptoSwap", await curveStableSwapFactory.pool_list(poolCount));
    const coin0 = await ethers.getContractAt("ERC20", COMMON_ERC20S.WETH);
    const coin1 = await ethers.getContractAt("ERC20", tan);
    await coin0.connect(owner).approve(lp, MaxUint256);
    await coin1.connect(owner).approve(lp, MaxUint256);

    await lp.connect(owner)["add_liquidity(uint256[2],uint256)"]([parseUnits("200", await coin0.decimals()), parseUnits("333000", await coin1.decimals())], 0);

    return lp;
}

deployTan()