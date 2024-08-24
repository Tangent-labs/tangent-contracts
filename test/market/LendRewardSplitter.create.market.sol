import {Test, console} from "forge-std/Test.sol";
import {LendRewardSplitterTestCommon} from "../LendRewardSplitter.common.test.sol";
import {LendRewardSplitter} from "../../src/LendRewardSplitter.sol";
import {Addr} from "../../src/libs/Addr.sol";

contract LendRewardSplitterCreateMarket is Test {
    LendRewardSplitter splitter;
    LendRewardSplitterTestCommon testCommon;

    function setUp() public {
        testCommon = new LendRewardSplitterTestCommon();
        testCommon.fork();
        testCommon.setUpSplitter();
        splitter = testCommon.splitter();
    }

    function test_revertWhen_CreateMarketAlreadyExistent() external {
        vm.expectRevert(bytes("MARKET_ALREADY_EXIST"));
        splitter.createMarket(Addr.STAKEDAO_CRV_VAULT);
    }

    //TODO: create a new market and verify each datas (need other markets)
}
