import "../../../contexts/TestWrapper.sol";
import "../../../chainview/PreviewDeposits.sol";

contract DepositSCVUSD is TestWrapper {
    function setUp() public {
        deployBaseContracts();
        setUpSingleRandomMarket();
    }

    function test_deposit_vaultAsset_and_stake(uint120 sharesIn) external {
        vm.assume(sharesIn > 10000);
        depositSCVUSD(ILendRewardSplitter.CVX_TOKEN_TYPE.LlamalendVaultAsset, usr1, sharesIn, false, true);
    }

    function test_deposit_vaultAsset_and_no_stake(uint120 sharesIn) external {
        vm.assume(sharesIn > 10000);
        depositSCVUSD(ILendRewardSplitter.CVX_TOKEN_TYPE.LlamalendVaultAsset, usr1, sharesIn, false, false);
    }

    function test_deposit_lend_asset_and_stake(uint120 amountIn) external {
        vm.assume(amountIn > 1);

        depositSCVUSD(ILendRewardSplitter.CVX_TOKEN_TYPE.LendAsset, usr1, amountIn, false, true);
    }
    function test_deposit_lend_asset_and_no_stake(uint120 amountIn) external {
        vm.assume(amountIn > 1);

        depositSCVUSD(ILendRewardSplitter.CVX_TOKEN_TYPE.LendAsset, usr1, amountIn, false, false);
    }

    function test_deposit_lend_asset_without_stake_then_deposit_with_stake(uint120 randomAmount) external {
        uint256 amountIn = randomAmount / 2;
        vm.assume(amountIn > 1);

        // Deposit gUSD witout staking and increment the sociabilization pending fee
        (uint256 llamaVaultMinted, ) = depositSCVUSD(ILendRewardSplitter.CVX_TOKEN_TYPE.LendAsset, usr1, amountIn, false, false);

        // Pass random days
        skip(bound(vm.randomUint(), 0, 30) * 86_400);

        _verifyStakeAll();
        // Stake All shouldn't stake the pending stake to keeep it for next stakers
        gUSD.stakeAll(pid);
        assertERC20Tracking();

        //  Deposit gUSD with staking and retrieve pendingShares
        depositSCVUSD(ILendRewardSplitter.CVX_TOKEN_TYPE.LendAsset, usr1, amountIn, false, true);
    }
}
