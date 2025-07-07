import {time} from "@nomicfoundation/hardhat-toolbox/network-helpers";

const days = process.env.DAYS;
export async function timeTravel() {
    const seconds = Number(days!) * 86400;
    await time.increase(seconds);

    console.info("\x1b[32m%s\x1b[0m", "Time has been incresed by " + seconds + " seconds on the test node !");
}

timeTravel();
