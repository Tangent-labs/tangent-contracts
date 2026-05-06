import { time } from "@nomicfoundation/hardhat-toolbox/network-helpers";

const days = 7;
export async function timeTravel(facultativeDays?: number) {
    let seconds;
    if (days) {
        seconds = Number(days!) * 86400;
    } else {
        seconds = Number(facultativeDays) * 86400;
    }
    const secondsToIncrease = Math.floor(seconds)
    await time.increase(secondsToIncrease);

    console.info("\x1b[32m%s\x1b[0m", "Time has been incresed by " + secondsToIncrease + " seconds on the test node !");
}


timeTravel()