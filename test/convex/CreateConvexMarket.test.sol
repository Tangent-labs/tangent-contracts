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
        splitter.createCvxMarket(PidCvxBooster.CRVUSD_CRV);

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
        vm.startPrank(testCommon.owner());
        splitter.createCvxMarket(PidCvxBooster.CRVUSD_CRV);
        vm.expectRevert(abi.encodeWithSelector(LendRewardSplitter.AlreadyCreatedCvxMarket.selector, PidCvxBooster.CRVUSD_CRV));
        splitter.createCvxMarket(PidCvxBooster.CRVUSD_CRV);
    }

    function test_create_market_as_not_owner() external {
        address usr = makeAddr("Test");
        vm.prank(usr);
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", usr));
        splitter.createCvxMarket(PidCvxBooster.CRVUSD_CRV);
    }
}
