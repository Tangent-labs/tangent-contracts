
import * as fs from "fs";
import * as bonds from "../snapshotitos/bonds.json";
import * as cvgBalances from "../snapshotitos/cvg-balances.json";
import * as ibo from "../snapshotitos/ibo.json";
import * as lockers from "../snapshotitos/lockers.json";
import * as seed from "../snapshotitos/seed.json";
import * as cvgEthLp from "../snapshotitos/snapshot-CVG-ETH-LP-balances.json";
import * as cvgFraxBpLP from "../snapshotitos/snapshot-CVG-FRAXBP-LP-balances.json";
import * as cvgEthGauge from "../snapshotitos/snapshot-CrvGauge-CVG-ETH-balances.json";
import * as cvgFraxBpGauge from "../snapshotitos/snapshot-CrvGauge-CVG-FRAXBP-LP-balances.json";
import * as cvgEthGaugeStake from "../snapshotitos/snapshot-StakeDao-CVG-ETH-LP.json";
import * as stkCvgEth from "../snapshotitos/stkCvgEth-balances.json";
import * as stkCvgSdt from "../snapshotitos/stkCvgSdt-balances.json";
import * as wl from "../snapshotitos/wl.json";
export async function zaza() {
    const allFiles = [bonds,
        cvgBalances, ibo, lockers, seed, cvgEthLp, cvgFraxBpLP,
        cvgEthGauge, cvgFraxBpGauge, cvgEthGaugeStake, cvgFraxBpGauge,
        stkCvgEth, stkCvgSdt, wl
    ]
    const set = new Set<string>()

    allFiles.forEach(f => {
        f?.default.forEach(i => {
            set.add(i.address.toLowerCase())
        })
    })

    console.log(set)
    fs.writeFileSync("./cvgCompensation.json", JSON.stringify(Array.from(set)))

}
zaza()