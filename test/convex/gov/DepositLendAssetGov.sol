import "../ConvexMarketContext.sol";

contract DepositLendAssetGov is ConvexMarketContext {
    function setUp() public {
        deployBaseContracts();
        setUpSingleRandomMarket();
    }

    function test_deposit_lend_asset_and_doDeposit(uint120 amountIn) external {
        vm.assume(amountIn > 1);

        // PREPARE
        address usr = makeAddr("User");
        deal(address(lendAsset), usr, amountIn);
        vm.startPrank(usr);
        // CRVUSD
        uint256 balanceOfUserCrvUSD = lendAsset.balanceOf(usr);
        uint256 balanceOfCRVUSDControllerCrvUSD = lendAsset.balanceOf(address(crvController));
        // LLAMALEND
        uint256 totalSupplyLlamaLp = llamaVault.totalSupply();
        uint256 balOfGUSDLlamaLp = llamaVault.balanceOf(address(gUSD));
        uint256 balOfCrvGaugeLlamaLp = llamaVault.balanceOf(address(crvGauge));
        // CVX REWARD
        uint256 totalSupplyCvxReward = cvxRewardToken.totalSupply();
        uint256 balOfGUSDCvxReward = cvxRewardToken.balanceOf(address(gUSD));
        // GUSD
        uint256 totalSupplyGUSD = gUSD.totalSupply();
        uint256 usrGUSDBalance = gUSD.balanceOf(usr);

        uint256 sharesConverted = llamaVault.convertToShares(amountIn);

        // ACTIONS
        lendAsset.approve(address(splitter), amountIn);
        splitter.depositCvx(llamaVault, ILendRewardSplitter.CVX_TOKEN_TYPE.LendAsset, amountIn, false, true);

        // VERIFY

        // 100 crvUSD sent by usr
        assertEq(balanceOfUserCrvUSD - lendAsset.balanceOf(usr), amountIn);
        // 100 crvUSD received on CRVUSD Controller
        assertEq(lendAsset.balanceOf(address(crvController)) - balanceOfCRVUSDControllerCrvUSD, amountIn);

        // LlamaLend LP is minted ( totalSupply )
        assertEq(llamaVault.totalSupply() - totalSupplyLlamaLp, sharesConverted);
        // LlamaLend LP is sent the corresponding gauge
        assertEq(llamaVault.balanceOf(address(crvGauge)) - balOfCrvGaugeLlamaLp, sharesConverted);
        // LlamaLend LP is not sent to gUSD
        assertEq(llamaVault.balanceOf(address(gUSD)) - balOfGUSDLlamaLp, 0);

        // Cvx Rewards token are minted
        assertEq(cvxRewardToken.totalSupply() - totalSupplyCvxReward, sharesConverted);
        // Cvx Rewards token are sent to gUSD
        assertEq(cvxRewardToken.balanceOf(address(gUSD)) - balOfGUSDCvxReward, sharesConverted);

        // gUSD are minted
        assertApproxEqAbs(gUSD.totalSupply() - totalSupplyGUSD, amountIn, 1);
        // gUSD are sent to user
        assertApproxEqAbs(gUSD.balanceOf(usr) - usrGUSDBalance, amountIn, 1);
    }

    function test_deposit_lend_asset_and_no_doDeposit(uint120 amountIn) external {
        vm.assume(amountIn > 1);
        // PREPARE
        address usr = makeAddr("User");
        deal(address(lendAsset), usr, amountIn);
        vm.startPrank(usr);
        // CRVUSD
        uint256 balanceOfUserCrvUSD = lendAsset.balanceOf(usr);
        uint256 balanceOfCRVUSDControllerCrvUSD = lendAsset.balanceOf(address(crvController));
        // LLAMALEND
        uint256 totalSupplyLlamaLp = llamaVault.totalSupply();
        uint256 balOfGUSDLlamaLp = llamaVault.balanceOf(address(gUSD));
        uint256 balOfCrvGaugeLlamaLp = llamaVault.balanceOf(address(crvGauge));
        // CVX REWARD
        uint256 totalSupplyCvxReward = cvxRewardToken.totalSupply();
        uint256 balOfGUSDCvxReward = cvxRewardToken.balanceOf(address(gUSD));
        // GUSD
        uint256 totalSupplyGUSD = gUSD.totalSupply();
        uint256 usrGUSDBalance = gUSD.balanceOf(usr);

        uint256 sharesConverted = llamaVault.convertToShares(amountIn);

        // ACTIONS
        lendAsset.approve(address(splitter), amountIn);
        splitter.depositCvx(llamaVault, ILendRewardSplitter.CVX_TOKEN_TYPE.LendAsset, amountIn, false, false);

        // VERIFY

        // amountIn crvUSD sent by usr
        assertEq(balanceOfUserCrvUSD - lendAsset.balanceOf(usr), amountIn);
        // amountIn crvUSD received on CRVUSD Controller
        assertEq(lendAsset.balanceOf(address(crvController)) - balanceOfCRVUSDControllerCrvUSD, amountIn);

        // LlamaLend LP is minted ( totalSupply )
        assertEq(llamaVault.totalSupply() - totalSupplyLlamaLp, sharesConverted);
        // LlamaLend LP is sent to gUSD
        assertEq(llamaVault.balanceOf(address(gUSD)) - balOfGUSDLlamaLp, sharesConverted);
        // LlamaLend LP is is not staked in CRV gauge
        assertEq(llamaVault.balanceOf(address(crvGauge)) - balOfCrvGaugeLlamaLp, 0);

        // Cvx Rewards token are not minted
        assertEq(cvxRewardToken.totalSupply() - totalSupplyCvxReward, 0);
        // Cvx Rewards token are not sent to gUSD
        assertEq(cvxRewardToken.balanceOf(address(gUSD)) - balOfGUSDCvxReward, 0);

        // gUSD are minted
        assertApproxEqAbs(gUSD.totalSupply() - totalSupplyGUSD, amountIn, 1);
        // gUSD are sent to user
        assertApproxEqAbs(gUSD.balanceOf(usr) - usrGUSDBalance, amountIn, 1);
    }

    function test_deposit_lend_asset_without_doDeposit_then_deposit_with_doDeposit(uint120 randomAmount) external {
        uint256 amountIn = randomAmount / 2;
        vm.assume(amountIn > 1);

        // PREPARE
        address usr = makeAddr("User");
        deal(address(lendAsset), usr, randomAmount);
        vm.startPrank(usr);

        // CRVUSD
        uint256 balanceOfUserCrvUSD = lendAsset.balanceOf(usr);
        uint256 balanceOfCRVUSDControllerCrvUSD = lendAsset.balanceOf(address(crvController));
        // LLAMALEND
        uint256 totalSupplyLlamaLp = llamaVault.totalSupply();
        uint256 balOfGUSDLlamaLp = llamaVault.balanceOf(address(gUSD));
        uint256 balOfCrvGaugeLlamaLp = llamaVault.balanceOf(address(crvGauge));
        // CVX REWARD
        uint256 totalSupplyCvxReward = cvxRewardToken.totalSupply();
        uint256 balOfGUSDCvxReward = cvxRewardToken.balanceOf(address(gUSD));
        // GUSD
        uint256 totalSupplyGUSD = gUSD.totalSupply();
        uint256 usrGUSDBalance = gUSD.balanceOf(usr);

        uint256 sharesConverted = llamaVault.convertToShares(amountIn);

        uint256 _amountIn = amountIn;

        // ACTIONS
        lendAsset.approve(address(splitter), _amountIn * 2);
        splitter.depositCvx(llamaVault, ILendRewardSplitter.CVX_TOKEN_TYPE.LendAsset, _amountIn, false, false);

        // Pass random days
        skip(bound(vm.randomUint(), 0, 30) * 86_400);
        sharesConverted += llamaVault.convertToShares(_amountIn);

        // ACTIONS
        splitter.depositCvx(llamaVault, ILendRewardSplitter.CVX_TOKEN_TYPE.LendAsset, _amountIn, false, true);

        // VERIFY

        // 2 * amountIn crvUSD sent by usr
        assertEq(balanceOfUserCrvUSD - lendAsset.balanceOf(usr), 2 * _amountIn);
        // 2 * amountIn crvUSD received on CRVUSD Controller
        assertEq(lendAsset.balanceOf(address(crvController)) - balanceOfCRVUSDControllerCrvUSD, 2 * _amountIn);

        // LlamaLend LP is minted ( totalSupply )
        assertEq(llamaVault.totalSupply() - totalSupplyLlamaLp, sharesConverted);
        // LlamaLend LP is not sent to gUSD
        assertEq(llamaVault.balanceOf(address(gUSD)) - balOfGUSDLlamaLp, 0);
        // LlamaLend LP is staked in CRV gauge
        assertEq(llamaVault.balanceOf(address(crvGauge)) - balOfCrvGaugeLlamaLp, sharesConverted);

        // Cvx Rewards token not minted
        assertEq(cvxRewardToken.totalSupply() - totalSupplyCvxReward, sharesConverted);
        // Cvx Rewards token not sent to gUSD
        assertEq(cvxRewardToken.balanceOf(address(gUSD)) - balOfGUSDCvxReward, sharesConverted);

        // gUSD are minted
        assertApproxEqAbs(gUSD.totalSupply() - totalSupplyGUSD, _amountIn * 2, 2);
        // gUSD are sent to user
        assertApproxEqAbs(gUSD.balanceOf(usr) - usrGUSDBalance, _amountIn * 2, 2);
    }
}
