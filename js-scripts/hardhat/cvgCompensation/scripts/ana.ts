
import * as snap from "../snapshotitos/snapshot-seed-computed.json";

export async function zaza() {


    let totalBought = 0n;
    let totalClaimed = 0n;

    snap.default.forEach((s) => {
        totalBought += BigInt(s.values.bought)
        totalClaimed += BigInt(s.values.claimed)
    });


    console.log("totalBought", totalBought)
    console.log("totalClaimed", totalClaimed)
}
zaza()