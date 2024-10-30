import "forge-std/console.sol";
import "forge-std/Test.sol";

import "../../../src/chainview/boosters/BoosterOutExpected.cv.sol";
import "../../../src/chainview/boosters/BoosterDetail.cv.sol";
import "../../../src/chainview/boosters/BoosterList.cv.sol";
contract BoosterChainview is Test {
    function test_booster_list_not_connected() public {
        vm.expectRevert();
        BoosterList boo = new BoosterList(address(0));
    }

    function test_booster_list_connected() public {
        vm.expectRevert();
        BoosterList boo = new BoosterList(0x22416Ff32559e4ea9E9168AbfFBAfcEdFCBB186E);
    }

    function test_booster_detail_not_connected() public {
        vm.expectRevert();
        BoosterDetail boo = new BoosterDetail(address(0), AddrBooster.SD_CRV_STAKING);
    }

    function test_booster_detail_connected() public {
        vm.expectRevert();

        for (uint256 index = 0; index < array.length; index++) {
            BoosterDetail boo = new BoosterDetail(0x22416Ff32559e4ea9E9168AbfFBAfcEdFCBB186E, AddrBooster.SD_CRV_STAKING);
        }
    }
}
