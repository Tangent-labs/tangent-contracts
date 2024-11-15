// SPDX-License-Identifier: UNKNOWN
import "../../../contexts/ConvexMarketContext.sol";

contract CreateConvexMarket is DeployContext {
    function setUp() public {
        deployBaseContracts();
    }

    function test_create_cvrUSD_crv_market() external {
        vm.prank(owner);
        uint256[] memory pids = new uint256[](1);
        pids[0] = PidCvxCrvBooster.CRVUSD_CRV;
        splitter.createMarkets(pids);

        SplitterToken gUSD = SplitterToken(address(splitter.gUSDPerLlamaVault(AddrLlamaLendVaults.CRVUSD_CRV)));
        SplitterToken scvUSD = SplitterToken(address(splitter.scvUSDPerLlamaVault(AddrLlamaLendVaults.CRVUSD_CRV)));
        address cvxRewardToken = address(splitter.rewardTokenPerLlamaVault(AddrLlamaLendVaults.CRVUSD_CRV));
        // Verify that all mappings are filled properly
        assertEq(splitter.pidPerLlamaVault(AddrLlamaLendVaults.CRVUSD_CRV), PidCvxCrvBooster.CRVUSD_CRV);
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
        pids[0] = PidCvxCrvBooster.CRVUSD_CRV;
        vm.startPrank(owner);
        splitter.createMarkets(pids);
        vm.expectRevert(abi.encodeWithSelector(LendRewardSplitter.AlreadyCreatedCvxMarket.selector, PidCvxCrvBooster.CRVUSD_CRV));
        splitter.createMarkets(pids);
    }

    function test_create_market_as_not_owner() external {
        uint256[] memory pids = new uint256[](1);
        pids[0] = PidCvxCrvBooster.CRVUSD_CRV;

        address usr = makeAddr("Test");
        vm.prank(usr);
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", usr));
        splitter.createMarkets(pids);
    }
}
