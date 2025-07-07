import {time} from "@nomicfoundation/hardhat-toolbox/network-helpers";

export async function mintBlock() {
    await time.increase(1);
}

mintBlock();
