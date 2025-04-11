import {formatEther, parseEther} from "ethers";
const args = process.argv;

const ONE_YEAR = 31536000;

const oldIndex = args[2];
const ir = args[3];
const timeDelta = args[4];

// const oldIndex = "1070473834971196042";
// const ir = "5048";
// const timeDelta = "5048";

function printIndex() {
    console.log(computeIndex(oldIndex, ir, timeDelta));
}
printIndex();

function computeIndex(oldIndex, ir, timeDelta) {
    const irFloat = Number(formatEther(ir));
    const indexFloat = Number(formatEther(oldIndex));

    const yearRatio = timeDelta / ONE_YEAR;

    let expContent = irFloat * yearRatio;
    expContent = expContent > 43 ? 43 : expContent;

    const exp = Math.exp(expContent);

    const index = (indexFloat * exp).toLocaleString("fullwide", {useGrouping: false, minimumSignificantDigits: 18});

    return parseEther(index);
}
