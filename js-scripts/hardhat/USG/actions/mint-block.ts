import { time, mine } from "@nomicfoundation/hardhat-toolbox/network-helpers";


export async function mintBlock() {
    // await time.increase(1);
    await mine(10000);

}

mintBlock();
