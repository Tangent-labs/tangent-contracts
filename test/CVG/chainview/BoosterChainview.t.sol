// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "../../tgUSD/contexts/ConvexCurveContext.sol";

import "../../../src/chainview/boosters/BoosterOutExpected.cv.sol";
import "../../../src/chainview/boosters/BoosterDetail.cv.sol";
import "../../../src/chainview/boosters/BoosterList.cv.sol";
contract BoosterChainview is ConvexCurveContext {
    // LIST
    function test_booster_list_not_connected() public {
        try new BoosterList(address(0)) {} catch (bytes memory reason) {
            assertTrue(reason.length > 3, "Chainview failed");
        }
    }

    function test_booster_list_connected() public {
        try new BoosterList(0x22416Ff32559e4ea9E9168AbfFBAfcEdFCBB186E) {} catch (bytes memory reason) {
            assertTrue(reason.length > 3, "Chainview failed");
        }
    }
    // DETAIL
    function test_booster_detail_not_connected() public {
        ISdtStaking[4] memory sdtStakings = [AddrBooster.SD_CRV_STAKING, AddrBooster.SD_BAL_STAKING, AddrBooster.SD_PENDLE_STAKING, AddrBooster.SD_FXN_STAKING];

        for (uint256 index = 0; index < sdtStakings.length; index++) {
            try new BoosterDetail(address(0), sdtStakings[index]) {} catch (bytes memory reason) {
                assertTrue(reason.length > 3, "Chainview failed");
            }
        }
    }

    function test_booster_detail_connected() public {
        ISdtStaking[4] memory sdtStakings = [AddrBooster.SD_CRV_STAKING, AddrBooster.SD_BAL_STAKING, AddrBooster.SD_PENDLE_STAKING, AddrBooster.SD_FXN_STAKING];

        for (uint256 index = 0; index < sdtStakings.length; index++) {
            try new BoosterDetail(0x22416Ff32559e4ea9E9168AbfFBAfcEdFCBB186E, sdtStakings[index]) {} catch (bytes memory reason) {
                assertTrue(reason.length > 3, "Chainview failed");
            }
        }
    }
    // ASSET => SDASSET
    function test_booster_out() public {
        ISdtStaking[4] memory sdtStakings = [AddrBooster.SD_CRV_STAKING, AddrBooster.SD_BAL_STAKING, AddrBooster.SD_PENDLE_STAKING, AddrBooster.SD_FXN_STAKING];

        for (uint256 index = 0; index < sdtStakings.length; index++) {
            try new BoosterOutExpected(sdtStakings[index], 1000 ether, false) {} catch (bytes memory reason) {
                assertTrue(reason.length > 3, "Chainview failed");
            }
        }
    }
}
