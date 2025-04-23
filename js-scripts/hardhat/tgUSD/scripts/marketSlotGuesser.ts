import {ethers} from "hardhat";
import {setStorageAt} from "@nomicfoundation/hardhat-toolbox/network-helpers";
import {GlobalHelper} from "../../GlobalHelper";

interface BalanceOfSlot {
    token: string;
    address: string;
    slot: number;
    isVyper: boolean;
}

const RANDOM_ADDRESS = "0xC82bf986c107B5456e1C9b32485640Dcb52b64dd";

async function getRouteTokenSlots(): Promise<BalanceOfSlot[]> {
    const result: BalanceOfSlot[] = [];

    // Extract unique input tokens from routes
    const tokens = new Map<string, string>();

    tokens.set("0x15700b564ca08d9439c58ca5053166e8317aa138", "deUSD");
    tokens.set("0xa3931d71877c0e7a3148cb7eb4463524fec27fbd", "sUSDS");
    // tokens.set('0x83F20F44975D03b1b09e64809B757c47f942BEeA' , 'sDAI')
    // tokens.set('0x15700b564ca08d9439c58ca5053166e8317aa138' , 'deUSD')
    // Convert to array of unique tokens
    const uniqueTokens = Array.from(tokens.entries()).map(([address, name]) => ({
        address,
        name,
    }));

    console.log("Checking slots for tokens:", uniqueTokens);

    for (const token of uniqueTokens) {
        const erc20 = await ethers.getContractAt("ERC20", token.address);
        const isVyper = token.name.includes("/") || token.name === "scrvUSD";
        // Try slots 0 to 500
        for (let k = 0; k < 10000; k++) {
            // Default to Vyper mapping calculation
            let storageSlot = "";
            if (isVyper) {
                storageSlot = GlobalHelper.calculateStorageSlotEthersVyper(RANDOM_ADDRESS, k);
            } else {
                storageSlot = GlobalHelper.calculateStorageSlotEthersSolidity(RANDOM_ADDRESS, k);
            }

            var rand = Math.floor(Math.random() * 10000);
            // Set storage slot to 1 ether
            await setStorageAt(token.address, storageSlot, ethers.parseEther((1.52 + rand).toString()));

            // Check if balance was updated
            try {
                if ((await erc20.balanceOf(RANDOM_ADDRESS)) === ethers.parseEther((1.52 + rand).toString())) {
                    result.push({
                        token: token.name,
                        address: token.address,
                        slot: k,
                        isVyper,
                    });
                    console.log(`Found slot for ${token.name}: ${k}`);
                    break;
                }
            } catch (e) {
                console.log("Error balance ", token.name);
            }
        }
    }

    console.log("All discovered slots:", result);
    return result;
}

// Execute the script
getRouteTokenSlots().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});

//npx hardhat run js-scripts/hardhat/tgUSD/scripts/marketSlotGuesser.ts
