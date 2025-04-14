import {formatEther, formatUnits, parseEther, parseUnits} from "ethers";
import {Decimal} from "decimal.js";
const args = process.argv;

const ONE_YEAR = 31536000;

const oldIndex = args[2];
const ir = args[3];
const timeDelta = args[4];

// const oldIndex = "9000000000000000000000022430";
// const ir = "7751";
// const timeDelta = "7751";

function printIndex() {
    console.log(computeIndex(oldIndex, ir, timeDelta));
}
printIndex();

function computeIndex(oldIndex, ir, timeDelta) {
    const irFloat = new Decimal(formatEther(ir));
    const indexFloat = new Decimal(formatUnits(oldIndex, 27));

    const yearRatio = timeDelta / ONE_YEAR;

    let expContent = irFloat * yearRatio;
    expContent = expContent > 43 ? 43 : expContent;

    const exp = new Decimal(Math.exp(expContent));

    const index = indexFloat.times(exp);

    return parseUnits(index.toString(), 27);
}
