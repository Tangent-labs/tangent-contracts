import "../ConvexMarketContext.sol";

contract ProcessStableConvex is ConvexMarketContext {
    function setUp() public {
        deployBaseContracts();
        setUpSingleRandomMarket();
    }

    function test_dada() external {
        uint256 amount = 100 ether;
        address user = makeAddr("USER");
        deal(address(AddrClassicERC20.TOKEN_CRVUSD), user, amount * 1000);
        vm.startPrank(user);
        AddrClassicERC20.TOKEN_CRVUSD.approve(address(splitter), type(uint256).max);

        // Deposit for stable rewards
        splitter.depositCvx(vaultStruct.llamaVault, ILendRewardSplitter.CVX_TOKEN_TYPE.LendAsset, amount, true, true);

        // Deposit for governance rewards
        splitter.depositCvx(vaultStruct.llamaVault, ILendRewardSplitter.CVX_TOKEN_TYPE.LendAsset, amount, false, true);

        skip(100 days);

        vaultStruct.scvUSD.processRewards();
        vaultStruct.gUSD.processRewards();

        skip(7 days);

        splitter.claimSimple(address(vaultStruct.scvUSD), user);
        splitter.claimSimple(address(vaultStruct.gUSD), user);

        splitter.withdrawCvx(vaultStruct.llamaVault, ILendRewardSplitter.CVX_TOKEN_TYPE.LendAsset, vaultStruct.gUSD.balanceOf(user), false);
        splitter.withdrawCvx(vaultStruct.llamaVault, ILendRewardSplitter.CVX_TOKEN_TYPE.LendAsset, vaultStruct.scvUSD.balanceOf(user), true);
    }
}
