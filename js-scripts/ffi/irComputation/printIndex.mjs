import {formatEther, formatUnits, parseEther, parseUnits} from "ethers";
import {Decimal} from "decimal.js";
const args = process.argv;

const ONE_YEAR = 31536000;

const oldIndex = args[2];
const ir = args[3];
const timestamp = args[4];
const now = args[5];

// const oldIndex = "1000000000000000000000000002";
// const ir = "7846357498172365477";
// const timestamp = "1520646699";
// const now = "1738746839";

function printIndex() {
    console.log(computeIndex(oldIndex, ir, timestamp));
}
printIndex();

function computeIndex(oldIndex, ir, timestamp) {
    Decimal.set({precision: 27});
    const timeDelta = now - timestamp;
    const irFloat = new Decimal(formatEther(ir));

    const indexFloat = new Decimal(formatUnits(oldIndex, 27));

    const yearRatio = new Decimal(timeDelta).dividedBy(new Decimal(ONE_YEAR));
    let expContent = irFloat.times(yearRatio);
    expContent = expContent > 43 ? new Decimal(43) : expContent;

    const exp = expContent.naturalExponential();

    const index = indexFloat.times(exp);

    return parseUnits(index.toString(), 27);
}
