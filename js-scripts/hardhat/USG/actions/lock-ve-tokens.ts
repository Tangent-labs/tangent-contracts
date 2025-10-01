import { commonERC20 } from "@tangent/defi-resources";
import { MaxUint256, parseEther } from "ethers";
import { ethers } from "hardhat";
import { giveTokenToAddress } from "../../thief/thief";

export async function lockVeTokensForAllUsers() {
    const signers = await ethers.getSigners();
    const lockers = [
        { symbol: "CRV", token: commonERC20.CRV, locker: "0x5f3b5DfEb7B28CDbD7FAba78963EE202a494e2A2" },
        { symbol: "FXN", token: commonERC20.FXN, locker: "0xEC6B8A3F3605B083F7044C0F31f2cac0caf1d469" },
    ];
    const amountToLock = parseEther("1000000");

    const now = (await ethers.provider.getBlock("latest"))?.timestamp!;
    for (let i = 0; i < lockers.length; i++) {
        const locker = lockers[i];
        const erc20 = await ethers.getContractAt("IERC20", locker.token);
        const veToken = await ethers.getContractAt("IVeToken", locker.locker);


        for (let j = 0; j < signers.length; j++) {
            const signer = signers[j];
            if (await veToken["balanceOf(address)"](signer) >= parseEther("50000")) {
                break;
            }


            // Get the token
            await giveTokenToAddress(signer, locker.symbol, amountToLock);
            // Approve
            await erc20.connect(signer).approve(locker.locker, MaxUint256);
            //  Lock
            await veToken.connect(signer).create_lock(amountToLock, now + 365 * 24 * 3600 * 3);
        }
    }
}
