import {Test, console} from "forge-std/Test.sol";
import {LendRewardSplitterTestCommon} from "../LendRewardSplitter.common.test.sol";
import {LendRewardSplitter} from "../../src/LendRewardSplitter.sol";
import {Addr} from "../../src/libs/Addr.sol";

contract LendRewardSplitterCreateMarket is Test {
    LendRewardSplitter splitter;
    LendRewardSplitterTestCommon testCommon;

    address owner = makeAddr("Owner");
    address randomUser = makeAddr("RandomUser");

    function setUp() public {
        testCommon = new LendRewardSplitterTestCommon();
        testCommon.fork();
        testCommon.setUpSplitter();
        splitter = testCommon.splitter();
    }

    function test_revertWhen_CreateMarketWithRandomUser() external {
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", randomUser));
        vm.prank(randomUser);
        splitter.createMarket(Addr.STAKEDAO_CRVUSD_CRV);
    }
    function test_revertWhen_CreateMarketAlreadyExistent() external {
        vm.expectRevert(bytes("MARKET_ALREADY_EXIST"));
        vm.prank(owner);
        splitter.createMarket(Addr.STAKEDAO_CRVUSD_CRV);
    }
    function test_revertWhen_CreateMarketWithWrongVault() external {
        vm.expectRevert();
        vm.prank(owner);
        splitter.createMarket(Addr.TOKEN_SDT);
    }
    function test_CreateMarketAndVerifyDatas() external {
        vm.prank(owner);
        splitter.createMarket(Addr.STAKEDAO_CRVUSD_LEVERAGE_WETH);
        LendRewardSplitter.MarketStruct memory market = splitter.getMarket(Addr.STAKEDAO_CRVUSD_LEVERAGE_WETH);
        assertEq(address(market.curveLendVault), Addr.CURVE_CRVUSD_LEVERAGE_WETH);
        assertEq(address(market.lendAsset), Addr.TOKEN_CRVUSD);
        assertEq(address(market.liquidityGauge), Addr.STAKEDAO_CRVUSD_LEVERAGE_WETH_GAUGE);
        assumeNotZeroAddress(address(market.gUSD));
        assumeNotZeroAddress(address(market.scvUSD));
    }
}
