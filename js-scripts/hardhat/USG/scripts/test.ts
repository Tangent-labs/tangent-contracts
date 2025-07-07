import {formatUnits, MaxUint256} from "ethers";
import {giveTokensToAddresses} from "../../thief";
import {TOKENS_TO_GIVE} from "../../tokensToGive.config";
import {ethers} from "hardhat";

async function main() {
    const user0 = (await ethers.getSigners())[0];

    const vault = await ethers.getContractAt("ILlamaVault", "0xff467c6e827ebbea64da1ab0425021e6c89fbe0d");

    const crvUSD = await ethers.getContractAt("ERC20", "0xf939e0a03fb07f59a73314e73794be0e57ac1b4e");

    await giveTokensToAddresses([user0], TOKENS_TO_GIVE(100000));

    await crvUSD.connect(user0).approve(vault, MaxUint256);

    await vault.connect(user0)["deposit(uint256)"](10n ** 19n);

    const balance = await vault.balanceOf(user0);

    console.log("BALANCE : ", balance);
    console.log("BALANCE : ", formatUnits(balance, 18));

    await vault.connect(user0)["withdraw(uint256)"](10000000000000000n);

    const newBalance = await vault.balanceOf(user0);

    console.log("newBalance : ", newBalance);
    console.log("newBalance : ", formatUnits(newBalance, 18));
}

main();
