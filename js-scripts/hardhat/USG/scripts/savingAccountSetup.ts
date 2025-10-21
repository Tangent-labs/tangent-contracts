import {SavingAccountContext} from "../contexts/SavingAccountContext";

const main = async () => {
    const context = new SavingAccountContext();
    await context.doDeploy();
};

main()
    .catch((error) => {
        console.error(error);
        process.exitCode = 1;
    })
    .finally(() => {
        console.log("DONE");
        process.exit(0);
    });
