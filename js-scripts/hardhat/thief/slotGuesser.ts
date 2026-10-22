import {AddressLike} from "ethers";
import {ethers} from "hardhat";
import {setStorageAt} from "@nomicfoundation/hardhat-toolbox/network-helpers";
import {GlobalHelper} from "../GlobalHelper";

interface Tokens {
    address: string;
    isVyper?: boolean;
    name?: string;
}

interface BalanceOfSlot {
    token: AddressLike;
    slot: number;
    name: string;
    isVyper: boolean;
    symbol?: string;
    decimals?: bigint;
}

type StorageLayout = "solidity" | "vyper";

function getStorageSlot(layout: StorageLayout, address: string, slot: number) {
    return layout === "vyper" ? GlobalHelper.calculateStorageSlotEthersVyper(address, slot) : GlobalHelper.calculateStorageSlotEthersSolidity(address, slot);
}

export async function getSlot(tokens: Tokens[], maxSlot = 100): Promise<BalanceOfSlot[]> {
    const result: BalanceOfSlot[] = [];

    for (const token of tokens) {
        const randomAddress = ethers.Wallet.createRandom().address;
        const amount = ethers.parseEther((1 + Math.random()).toString());
        const erc20 = await ethers.getContractAt("ERC20", token.address);
        const layouts: StorageLayout[] = token.isVyper === undefined ? ["solidity", "vyper"] : [token.isVyper ? "vyper" : "solidity"];

        for (const layout of layouts) {
            let found = false;
            for (let k = 0; k < maxSlot; k++) {
                await setStorageAt(token.address, getStorageSlot(layout, randomAddress, k), amount);

                if ((await erc20.balanceOf(randomAddress)) === amount) {
                    const [name, symbol, decimals] = await Promise.all([erc20.name(), erc20.symbol(), erc20.decimals()]);
                    result.push({
                        token: token.address,
                        name: token.name || name,
                        symbol,
                        decimals,
                        slot: k,
                        isVyper: layout === "vyper",
                    });
                    found = true;
                    break;
                }
            }
            if (found) {
                break;
            }
        }

        if (!result.find((row) => row.token === token.address)) {
            const [name, symbol, decimals] = await Promise.all([erc20.name(), erc20.symbol(), erc20.decimals()]);
            result.push({
                token: token.address,
                name: token.name || name,
                symbol,
                decimals,
                slot: -1,
                isVyper: false,
            });
        }
    }

    return result;
}

export async function getSlotWithLayout(tokens: Required<Pick<Tokens, "address" | "isVyper">>[], maxSlot = 100): Promise<BalanceOfSlot[]> {
    const result: BalanceOfSlot[] = [];

    for (const token of tokens) {
        const randomAddress = ethers.Wallet.createRandom().address;
        const amount = ethers.parseEther((1 + Math.random()).toString());
        const erc20 = await ethers.getContractAt("ERC20", token.address);
        for (let k = 0; k < maxSlot; k++) {
            const storageSlot = token.isVyper ? GlobalHelper.calculateStorageSlotEthersVyper(randomAddress, k) : GlobalHelper.calculateStorageSlotEthersSolidity(randomAddress, k);
            await setStorageAt(token.address, storageSlot, amount);

            if ((await erc20.balanceOf(randomAddress)) === amount) {
                result.push({
                    token: token.address,
                    name: await erc20.name(),
                    symbol: await erc20.symbol(),
                    decimals: await erc20.decimals(),
                    slot: k,
                    isVyper: token.isVyper,
                });
                break;
            }
        }
    }

    return result;
}
