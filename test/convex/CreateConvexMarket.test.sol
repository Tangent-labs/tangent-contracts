import {Test, console} from "forge-std/Test.sol";
import {LendRewardSplitterTestCommon} from "../LendRewardSplitter.common.test.sol";
import {LendRewardSplitter} from "../../src/LendRewardSplitter.sol";
import {IStakeDaoVault} from "../../src/interfaces/externals/IStakeDaoVault.sol";
import {CurveLendSplitterToken} from "../../src/tokens/CurveLendSplitterToken.sol";

import {gUSDCvx} from "../../src/tokens/convex/gUSDCvx.sol";
import {AddrLlamaLendVaults, AddrSdtVaults, AddrSdtGauges, AddrClassicERC20, AddrCvxRewardTokens, PidCvxBooster} from "../../src/libs/Resources.sol";

contract CreateConvexMarket is Test {
    LendRewardSplitter splitter;
    LendRewardSplitterTestCommon testCommon = new LendRewardSplitterTestCommon();

    function setUp() public {
        testCommon = new LendRewardSplitterTestCommon();
        testCommon.fork();
        testCommon.setUpSplitter();
        splitter = testCommon.splitter();
    }

    function test_create_cvrUSD_crv_market() external {
        vm.prank(testCommon.owner());
        uint256[] memory pids = new uint256[](1);
        pids[0] = PidCvxBooster.CRVUSD_CRV;
        splitter.createCvxMarkets(pids);

        CurveLendSplitterToken gUSD = CurveLendSplitterToken(address(splitter.gUSDCvxPerLlamaVault(AddrLlamaLendVaults.CRVUSD_CRV)));
        CurveLendSplitterToken scvUSD = CurveLendSplitterToken(address(splitter.scvUSDCvxPerLlamaVault(AddrLlamaLendVaults.CRVUSD_CRV)));
        address cvxRewardToken = address(splitter.cvxRewardTokenPerLlamaVault(AddrLlamaLendVaults.CRVUSD_CRV));
        // Verify that all mappings are filled properly
        assertEq(splitter.cvxPidPerLlamaVault(AddrLlamaLendVaults.CRVUSD_CRV), PidCvxBooster.CRVUSD_CRV);
        assertEq(cvxRewardToken, address(AddrCvxRewardTokens.CRVUSD_CRV));
        assertNotEq(address(gUSD), address(0));
        assertNotEq(address(scvUSD), address(0));

        // Verify beacons initialization
        assertEq(address(gUSD.lendRewardSplitter()), address(splitter));
        assertEq(address(gUSDCvx(address(gUSD)).cvxRewardToken()), address(AddrCvxRewardTokens.CRVUSD_CRV));
        assertEq(address(scvUSD.lendRewardSplitter()), address(splitter));
    }

    function test_create_twice_same_market() external {
        uint256[] memory pids = new uint256[](1);
        pids[0] = PidCvxBooster.CRVUSD_CRV;
        splitter.createCvxMarkets(pids);

        vm.startPrank(testCommon.owner());
        splitter.createCvxMarkets(pids);
        vm.expectRevert(abi.encodeWithSelector(LendRewardSplitter.AlreadyCreatedCvxMarket.selector, PidCvxBooster.CRVUSD_CRV));
        splitter.createCvxMarkets(pids);
    }

    function test_create_market_as_not_owner() external {
        uint256[] memory pids = new uint256[](1);
        pids[0] = PidCvxBooster.CRVUSD_CRV;

        address usr = makeAddr("Test");
        vm.prank(usr);
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", usr));
        splitter.createCvxMarkets(pids);
    }
}
