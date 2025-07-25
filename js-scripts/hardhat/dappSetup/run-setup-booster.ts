import {BoosterSetup} from "./Booster.setup";
import {LockerSetup} from "./Locker.setup";

async function main() {
    const boosterSetup = new BoosterSetup();

    await boosterSetup.setupTestUsers(2);
    await boosterSetup.giveTokens(boosterSetup.users, []);
    console.log("------------------------------------------------ Contracts setup ");
    await boosterSetup.setupContracts();
    console.log("------------------------------------------------ Tokens given to user 1");
    await boosterSetup.giveSpecificTokens();
    console.log("------------------------------------------------ Staked");
    await boosterSetup.stake();
    console.log("------------------------------------------------ Done");

    // const lockerSetup = new LockerSetup();
    // await lockerSetup.setupTestUsers();
    // await lockerSetup.setupContracts();
    // await lockerSetup.stake();
}
main();
