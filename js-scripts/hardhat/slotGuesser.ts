import {AddressLike} from "ethers";
import {ethers} from "hardhat";
import {setStorageAt} from "@nomicfoundation/hardhat-toolbox/network-helpers";
import {GlobalHelper} from "./GlobalHelper";
import {THIEF_TOKEN_CONFIG} from "defi-resources/build/ressources/erc20/thiefConfig";

interface Tokens {
    address: string;
    isVyper: boolean;
}

interface BalanceOfSlot {
    token: AddressLike;
    slot: number;
}

const RANDOM_ADDRESS = "0x47b4Dd903bC719D689a3a9391186c5deAaC5D8Ff";
export async function getSlot(tokens: Tokens[]): Promise<BalanceOfSlot[]> {
    const result: BalanceOfSlot[] = [];
    for (let i = 0; i < tokens.length; i++) {
        const token = tokens[i];
        const erc20 = await ethers.getContractAt("ERC20", tokens[i].address);
        for (let k = 0; k < 100_000; k++) {
            let storageSlot;
            if (token.isVyper) {
                storageSlot = GlobalHelper.calculateStorageSlotEthersVyper(RANDOM_ADDRESS, k);
            } else if (token.address === "0x66a1e37c9b0eaddca17d3662d6c05f4decf3e110") {
                storageSlot = GlobalHelper.calculateERC20OZUpgradeable(RANDOM_ADDRESS);
            } else {
                storageSlot = GlobalHelper.calculateStorageSlotEthersSolidity(RANDOM_ADDRESS, k);
            }
            await setStorageAt(token.address, storageSlot, ethers.parseEther("1"));
            if ((await erc20.balanceOf(RANDOM_ADDRESS)) === ethers.parseEther("1")) {
                result.push({
                    token: await erc20.name(),
                    slot: k,
                });
                break;
            }
        }
    }
    console.log(result);
    return result;
}

getSlot([{address: "0x865377367054516e17014ccded1e7d814edc9ce4", isVyper: false}]).catch((error) => {
    console.error(error);
    process.exitCode = 1;
});

//npx hardhat run utils/erc20/slotGuesser.ts
