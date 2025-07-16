import {PointsContext} from "../contexts/PointsContext";

async function main() {
    const pointsContext = new PointsContext();

    await pointsContext.initUsers();

    await pointsContext.curveDeposit();
}

main();
