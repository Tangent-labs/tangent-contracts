import {ethers} from "hardhat";
import fs from "fs";

const abiCoder = ethers.AbiCoder.defaultAbiCoder();
export interface MerkleNode {
    address: string;
    amount: bigint;
}

export class GlobalHelper {
    static erc20ArtifactName = "@openzeppelin/contracts/token/ERC20/IERC20.sol:IERC20";

    static countDecimals(value: number) {
        if (Math.floor(value) === value) return 0;
        return value.toString().split(".")[1].length || 0;
    }

    static priceToBigNumber(number: number, decimals: number) {
        return ethers.parseUnits(number.toString(), decimals);
    }
    static bigNumberFactory(number: number, decimals: number) {
        return BigInt(number) * BigInt(10) ** BigInt(decimals);
    }

    static convertEthersToNumber(bigNumber: bigint) {
        return Number(ethers.formatEther(bigNumber));
    }

    static render_svg(output: string, name: string, pathRender: string) {
        const raw_slice = output.slice(29);
        const decoded_json = atob(raw_slice);
        const json = JSON.parse(decoded_json);
        const image_base64 = json.image;
        let url = image_base64.replace("data:image/svg+xml;base64,", "");
        var svg = decodeURIComponent(escape(atob(url)));
        fs.writeFile(pathRender + `logo_${name}.svg`, svg, function (err) {
            if (err) throw err;
            // console.log("File is created successfully.");
        });
    }

    static calculateStorageSlotEthersSolidity = (addressKey: string, mappingSlot: number) => {
        const paddedAddress = ethers.zeroPadValue(addressKey, 32);
        const paddedSlot = ethers.zeroPadValue(ethers.toBeHex(mappingSlot), 32);
        const concatenated = ethers.concat([paddedAddress, paddedSlot]);
        const hash = ethers.keccak256(concatenated);
        return hash;
    };

    static calculateERC20OZUpgradeable = (addressKey: string) => {
        // The storage slot for _balances is the ERC20StorageLocation.
        // Note: Use the same constant from the contract:
        const ERC20StorageLocation = "0x52c63247e1f47db19d5ce0460030c497f067ca4cebf71ba98eeadabe20bace00";
        const abiCoder = new ethers.AbiCoder();
        const encoded = abiCoder.encode(["address", "uint256"], [addressKey, ERC20StorageLocation]);
        const index = ethers.keccak256(encoded);

        // Compute the slot for account's balance:
        // keccak256(abi.encode(key, slot))
        // const hash = ethers.keccak256(abiCoder.encode(["address", "uint256"], [addressKey, ERC20StorageLocation]));
        return index;
    };

    static calculateStorageSlotEthersVyper = (addressKey: string, mappingSlot: number) => {
        const paddedSlot = ethers.zeroPadValue(ethers.toBeHex(mappingSlot), 32);
        const paddedAddress = ethers.zeroPadValue(addressKey, 32);
        const concatenated = ethers.concat([paddedSlot, paddedAddress]);
        const hash = ethers.keccak256(concatenated);
        return hash;
    };
}
