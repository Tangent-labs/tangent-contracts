import {chainView} from "../../../chainView";

import PointPricesArtifact from "../../../../artifacts/src/chainview/USG/bot/PointPrices.cv.sol/PointPrices.json";
import deployAddresses from "./../../../../addresses.json";

const sCRVUSD = "0x0655977FEb2f289A4aB78af67BAB0d17aAb84367"; // sCRVUSD

const test = async () => {
    const paramsAddresses = {
        usg: deployAddresses.tokens.USG,
        usgOracle: deployAddresses.oracles.USG,
        sUsg: deployAddresses.tokens.sUSG,
        pegKeepers: Object.values(deployAddresses.pegKeepers),
    };

    const params = [[sCRVUSD], paramsAddresses];

    const userAccountsData = await chainView<typeof params, [any]>(PointPricesArtifact.abi, PointPricesArtifact.bytecode, params);
    console.log(userAccountsData);
};

test();
// npx hardhat run  js-scripts/hardhat/USG/scripts/pendle-test.ts --
