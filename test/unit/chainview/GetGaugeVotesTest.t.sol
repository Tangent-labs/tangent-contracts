// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "../../contexts/MarketDeploymentContext.sol";

import {GetGaugeVotes, GetGaugeVotesIn, AccountGauge, GetGaugeVotesOut, IGaugeController} from "../../../src/chainview/USG/bot/GetGaugeVotes.cv.sol";

contract GetGaugeVotesTest is MarketDeploymentContext {
    // LIST
    function test_getGaugeVotes() public {
        GetGaugeVotesIn[] memory paramIn = new GetGaugeVotesIn[](2);

        AccountGauge[] memory accountGaugeCurve = new AccountGauge[](1);
        accountGaugeCurve[0] = AccountGauge({account: 0x989AEb4d175e16225E39E87d0D97A3360524AD80, gauge: 0xB53c23D2CC6219adf78ea22Bfd38bFfc50eC54cB});

        AccountGauge[] memory accountGaugeFxn = new AccountGauge[](2);
        accountGaugeFxn[0] = AccountGauge({account: 0x06232028c253dA3404cce43A4789dc802a62C846, gauge: 0x215D87bd3c7482E2348338815E059DE07Daf798A});
        accountGaugeFxn[1] = AccountGauge({account: 0x4f15Fec6D26fE0b9f8BAA0648892344F261999D9, gauge: 0xA5250C540914E012E22e623275E290c4dC993D11});

        paramIn[0] = GetGaugeVotesIn({gaugeController: IGaugeController(0x2F50D538606Fa9EDD2B11E2446BEb18C9D5846bB), accountGauges: accountGaugeCurve});
        paramIn[1] = GetGaugeVotesIn({gaugeController: IGaugeController(0xe60eB8098B34eD775ac44B1ddE864e098C6d7f37), accountGauges: accountGaugeFxn});

        try new GetGaugeVotes(paramIn) {} catch (bytes memory reason) {
            GetGaugeVotesOut memory result = abi.decode(removeFirst4Bytes(reason), (GetGaugeVotesOut));
            for (uint256 i; i < result.gaugeControllerWeights.length; i++) {
                for (uint256 j; j < result.gaugeControllerWeights[i].weights.length; j++) {}
            }
            assertTrue(reason.length > 3, "Chainview failed");
        }
    }
}
