// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {IGaugeController} from "../../../interfaces/externals/Curve/IGaugeController.sol";
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
struct GetGaugeVotesOut {
    IGaugeController gaugeController;
    uint256[] weights;
}
contract GetGaugeVotes {
    error GetGaugeVotesError(GetGaugeVotesOut[] output);

    constructor(GetGaugeVotesIn[] memory paramIn) {
        // Create as much element as gauge controller to monitor
        GetGaugeVotesOut[] memory out = new GetGaugeVotesOut[](paramIn.length);
        // For each gauge controller we want to monitor
        for (uint256 i; i < paramIn.length; i++) {
            uint256[] memory weights = new uint256[](paramIn[i].accountGauges.length);
            // Now we iterate over all account that voted
            for (uint256 j; j < paramIn[i].accountGauges.length; j++) {
                AccountGauge memory accountGauge = paramIn[i].accountGauges[j];
                (, uint256 power, ) = paramIn[i].gaugeController.vote_user_slopes(accountGauge.account, accountGauge.gauge);
                weights[j] = power;
            }

            out[i] = GetGaugeVotesOut({gaugeController: paramIn[i].gaugeController, weights: weights});
        }

        revert GetGaugeVotesError(out);
    }
}
