// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {IGaugeController} from "../../../interfaces/externals/Curve/IGaugeController.sol";
import {IVeToken} from "../../../interfaces/externals/Curve/IVeToken.sol";

// IN
struct AccountGauge {
    address account;
    address gauge;
}
struct GetGaugeVotesIn {
    IGaugeController gaugeController;
    AccountGauge[] accountGauges;
}

// OUT
struct GaugeControllerWeights {
    IGaugeController gaugeController;
    uint256[] weights;
}

struct GetGaugeVotesOut {
    uint256 timestamp;
    GaugeControllerWeights[] gaugeControllerWeights;
}

contract GetGaugeVotes {
    error GetGaugeVotesError(GetGaugeVotesOut output);

    constructor(GetGaugeVotesIn[] memory paramIn) {
        // Create as much element as gauge controller to monitor
        GaugeControllerWeights[] memory out = new GaugeControllerWeights[](paramIn.length);
        // For each gauge controller we want to monitor
        for (uint256 i; i < paramIn.length; i++) {
            uint256[] memory weights = new uint256[](paramIn[i].accountGauges.length);
            // Now we iterate over all account that voted
            for (uint256 j; j < paramIn[i].accountGauges.length; j++) {
                AccountGauge memory accountGauge = paramIn[i].accountGauges[j];
                uint256 userVePower = IVeToken(paramIn[i].gaugeController.voting_escrow()).balanceOf(accountGauge.account);

                (, uint256 power, ) = paramIn[i].gaugeController.vote_user_slopes(accountGauge.account, accountGauge.gauge);
                uint256 vePowerDeployedOnGauge = (userVePower * power) / 10_000;
                weights[j] = vePowerDeployedOnGauge;
            }

            out[i] = GaugeControllerWeights({gaugeController: paramIn[i].gaugeController, weights: weights});
        }

        revert GetGaugeVotesError(GetGaugeVotesOut({timestamp: block.timestamp, gaugeControllerWeights: out}));
    }
}
