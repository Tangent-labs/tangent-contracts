import * as bonds from "../snapshotitos/bonds.json";


export function main() {
    const final: { [address: string]: bigint | string } = {};
    bonds.forEach(b => {
        if (!final[b.address]) {
            final[b.address] = 0n
        }
        else {
            final[b.address] += b.value
        }

    })

}