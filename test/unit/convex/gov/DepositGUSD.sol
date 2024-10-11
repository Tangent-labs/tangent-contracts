import "../../../contexts/ConvexMarketContext.sol";

import "../../../chainview/PreviewDeposits.sol";

contract DepositGUSD is ConvexMarketContext {
    function setUp() public {
        deployBaseContracts();
        setUpSingleRandomMarket();
    }

    function test_deposit_vaultAsset_and_stake(uint120 sharesIn) external {
        vm.assume(sharesIn > 10000);

        depositGUSD(ILendRewardSplitter.CVX_TOKEN_TYPE.LlamalendVaultAsset, usr1, sharesIn, true);
    }

    function test_deposit_vaultAsset_and_no_stake(uint120 sharesIn) external {
        vm.assume(sharesIn > 10000);

        depositGUSD(ILendRewardSplitter.CVX_TOKEN_TYPE.LlamalendVaultAsset, usr1, sharesIn, false);
    }

    function test_deposit_lend_asset_and_stake(uint120 amountIn) external {
        vm.assume(amountIn > 1);

        depositGUSD(ILendRewardSplitter.CVX_TOKEN_TYPE.LendAsset, usr1, amountIn, true);
    }
    function test_deposit_lend_asset_and_no_stake(uint120 amountIn) external {
        vm.assume(amountIn > 1);

        depositGUSD(ILendRewardSplitter.CVX_TOKEN_TYPE.LendAsset, usr1, amountIn, false);
    }

    function test_deposit_lend_asset_without_stake_then_deposit_with_stake(uint120 randomAmount) external {
        uint256 amountIn = randomAmount / 2;
        vm.assume(amountIn > 1);

        // Deposit gUSD witout staking and increment the sociabilization pending fee
        depositGUSD(ILendRewardSplitter.CVX_TOKEN_TYPE.LendAsset, usr1, amountIn, false);

        // Pass random days
        skip(bound(vm.randomUint(), 0, 30) * 86_400);

        // Stake All shouldn't stake the pending stake to keeep it for next stakers
        gUSD.stakeAll(pid);

        // Deposit gUSD with staking and retrieve pendingShares
        depositGUSD(ILendRewardSplitter.CVX_TOKEN_TYPE.LendAsset, usr1, amountIn, true);
    }
}
