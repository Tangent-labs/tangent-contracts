// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "../../contexts/MarketDeploymentContext.sol";

import {GetGaugeVotes, GetGaugeVotesIn, AccountGauge, GetGaugeVotesOut, IGaugeController} from "../../../src/chainview/USG/bot/GetGaugeVotes.cv.sol";

contract GetGaugeVotesTest is MarketDeploymentContext {
    // LIST
    function test_getGaugeVotes() public {
        GetGaugeVotesIn[] memory paramIn = new GetGaugeVotesIn[](2);

        AccountGauge[] memory accountGaugeCurve = new AccountGauge[](4);
        accountGaugeCurve[0] = AccountGauge({account: 0x52f541764E6e90eeBc5c21Ff570De0e2D63766B6, gauge: 0x86611888764D7F1787aAF9697894Ab0F78aA616b});
        accountGaugeCurve[1] = AccountGauge({account: 0x52f541764E6e90eeBc5c21Ff570De0e2D63766B6, gauge: 0xB84637aB9Be835580821A67823f414FFd0bbf625});
        accountGaugeCurve[2] = AccountGauge({account: 0x52f541764E6e90eeBc5c21Ff570De0e2D63766B6, gauge: 0xB84637aB9Be835580821A67823f414FFd0bbf625});
        accountGaugeCurve[3] = AccountGauge({account: 0x989AEb4d175e16225E39E87d0D97A3360524AD80, gauge: 0x06B30D5F2341C2FB3F6B48b109685997022Bd272});

        AccountGauge[] memory accountGaugeFxn = new AccountGauge[](2);
        accountGaugeCurve[0] = AccountGauge({account: 0x06232028c253dA3404cce43A4789dc802a62C846, gauge: 0x215D87bd3c7482E2348338815E059DE07Daf798A});
        accountGaugeCurve[1] = AccountGauge({account: 0x4f15Fec6D26fE0b9f8BAA0648892344F261999D9, gauge: 0xA5250C540914E012E22e623275E290c4dC993D11});

        paramIn[0] = GetGaugeVotesIn({gaugeController: IGaugeController(0x2F50D538606Fa9EDD2B11E2446BEb18C9D5846bB), accountGauges: accountGaugeCurve});
        paramIn[1] = GetGaugeVotesIn({gaugeController: IGaugeController(0xe60eB8098B34eD775ac44B1ddE864e098C6d7f37), accountGauges: accountGaugeFxn});

        try new GetGaugeVotes(paramIn) {} catch (bytes memory reason) {
            GetGaugeVotesOut[] memory result = abi.decode(removeFirst4Bytes(reason), (GetGaugeVotesOut[]));
            for (uint256 i; i < result.length; i++) {}
            assertTrue(reason.length > 3, "Chainview failed");
        }
    }
}
