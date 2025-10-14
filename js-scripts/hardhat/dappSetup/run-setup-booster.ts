import {BoosterSetup} from "./Booster.setup";
import {LockerSetup} from "./Locker.setup";

async function main() {
    const boosterSetup = new BoosterSetup();

    await boosterSetup.setupTestUsers();
    await boosterSetup.giveTokens(boosterSetup.users, []);

    await boosterSetup.setupContracts();
    await boosterSetup.stake();

    const lockerSetup = new LockerSetup();
    await lockerSetup.setupTestUsers();
    await lockerSetup.setupContracts();
    await lockerSetup.stake();
}
main();
