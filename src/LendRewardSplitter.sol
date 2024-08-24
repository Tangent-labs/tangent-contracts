// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {BeaconProxy} from "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ICurveLendVault} from "./interfaces/ICurveLendVault.sol";
import {IStakeDaoVault} from "./interfaces/IStakeDaoVault.sol";
import {ISDLiquidityGauge} from "./interfaces/ISDLiquidityGauge.sol";
import {CurveLendSplitterToken} from "./tokens/CurveLendSplitterToken.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";
import "forge-std/console.sol"; //TODO: to remove

contract LendRewardSplitter is Ownable2StepUpgradeable {
    using SafeERC20 for IERC20;
    using SafeERC20 for ICurveLendVault;
    using SafeERC20 for IStakeDaoVault;

    uint256 constant MAX_UINT = uint256(int256(-1));

    address public beaconCurveLendSplitterToken;
    mapping(IERC20 => uint256) public daoFeeForToken;
    mapping(address => MarketStruct) public markets;
    mapping(address => bool) public isSpecialUpdater;

    struct MarketStruct {
        ICurveLendVault curveLendVault;
        ISDLiquidityGauge liquidityGauge;
        IERC20 lendAsset;
        CurveLendSplitterToken gUSD;
        CurveLendSplitterToken scvUSD;
    }

    event Deposit(address indexed account, bool isStableReward, uint256 amount);
    event Withdraw(address indexed account, bool isStableReward, TOKEN_TYPE outType, uint256 amount);

    enum TOKEN_TYPE {
        /// @dev Asset use as collateral in the lend contract. (ex : crvUSD)
        LendAsset,
        /// @dev share of  curve vault contract. (ex : cvcrvUSD)
        LendCurveAsset,
        /// @dev share of  curve vault contract. (ex : sdcvcrvUSD)
        LendStakeDaoAsset
    }

    /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
                        CONSTRUCTOR & INITIALIZER
    =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address _owner, address _beaconCurveLendSplitterToken) external initializer {
        beaconCurveLendSplitterToken = _beaconCurveLendSplitterToken;
        _transferOwnership(_owner);
    }

    /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
                        EXTERNALS USER
    =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */

    /*
    TODO:
    deposit with...
    USDT/DAI/USDC/USDe/ETH/WETH
    */

    /**
     *  @notice Deposit asset into the Convergence splitter contract in order to get one part of the reawrd from the lend contract.
     *  @param inType Type of token you want to in with with 4 steps  LendAsset >  LendCurveAsset >  LendStakeDaoAsset
     *  @param amount Amount  of {inType} token you want to deposit.
     *  @param isStableReward bool  IF isStableReward == true THEN   you want the stable part of the reward  ELSE you want the gauge part of the reward.
     *  @param doDeposit bool  IF doDeposit == true THEN  all the pending asset will be deposited in stakeValut.
     *  @return depositAmount Staked amount eligible to rewards.
     */
    function deposit(
        address stakeDaoVault,
        TOKEN_TYPE inType,
        uint256 amount,
        bool isStableReward,
        bool doDeposit
    ) external returns (uint256 depositAmount) {
        require(amount != 0, "NO_INPUT_AMOUNT");

        MarketStruct memory market = markets[stakeDaoVault];

        /// @dev Transfer the token from the user to this contract..
        _transferTokens(market, inType, amount);

        if (inType == TOKEN_TYPE.LendAsset) {
            /// @dev Deposit in curveLend.
            depositAmount = market.curveLendVault.deposit(amount, address(this));
        } else {
            /// @dev In others code path token are minted 1:1.
            depositAmount = amount;
        }

        if (inType < TOKEN_TYPE.LendStakeDaoAsset) {
            /// @dev Stake into stakedao strategies to get OnlyBoost.
            uint256 balanceBefore = market.liquidityGauge.balanceOf(address(this));
            IStakeDaoVault(stakeDaoVault).deposit(address(this), depositAmount, doDeposit);
            depositAmount = market.liquidityGauge.balanceOf(address(this)) - balanceBefore;
        }

        if (isStableReward) {
            /// @dev For scvUSD, we mint 1:1 from cvcrvUSD.
            market.scvUSD.mint(msg.sender, depositAmount);
        } else {
            /// @dev For gUSD, we mint 1:1 from crvUSD,
            // we use the curveLendVault.convertToAssets to calculate the amount.
            depositAmount = market.curveLendVault.convertToAssets(depositAmount);
            market.gUSD.mint(msg.sender, depositAmount);
        }
        emit Deposit(msg.sender, isStableReward, depositAmount);
    }

    /**
     *  @notice Withdraw assets from  the Convergence splitter contract.
     *  @param outType Type of token you want to in with with 4 steps  LendAsset >  LendCurveAsset.
     *  @param amount Amount  of {gUSD|scvUsd} token you want to withdraw.
     *  @param isStableReward  If isStableReward == true THEN   scvUsd of user is used   ELSE  gUSD of user is used.
     */
    function withdraw(address stakeDaoVault, TOKEN_TYPE outType, uint256 amount, bool isStableReward) public {
        /// @dev We check the prerequesite.
        require(amount != 0, "WITHDRAW_LTE_0");

        MarketStruct memory market = markets[stakeDaoVault];

        CurveLendSplitterToken recipeToken = isStableReward ? market.scvUSD : market.gUSD;
        require(amount <= recipeToken.balanceOf(msg.sender), "NOT_ENOUGH_BALANCE");

        /// @dev We burn the corresponding token.
        recipeToken.burn(msg.sender, amount);

        /// @dev We process the amounts.
        uint256 shareAmount = isStableReward ? amount : market.curveLendVault.convertToShares(amount);

        if (outType == TOKEN_TYPE.LendStakeDaoAsset) {
            /// @dev we transfer the stake share to the user.
            IERC20(address(market.liquidityGauge)).safeTransfer(msg.sender, shareAmount);
        } else {
            /// @dev We withdraw the share from stakeDAO vault.
            IStakeDaoVault(stakeDaoVault).withdraw(shareAmount);
            // require(balanceBefore - balanceAfter >= shareAmount, "WITHDRAW ERROR");
            if (outType == TOKEN_TYPE.LendCurveAsset) {
                /// @dev we transfer the stake share to the user.
                IERC20(address(market.curveLendVault)).safeTransfer(msg.sender, shareAmount);
            }
            if (outType == TOKEN_TYPE.LendAsset) {
                /// @dev We check if we can withdraw from curvelend vault.
                uint256 maxShareAllowed = market.curveLendVault.maxRedeem(address(this));
                require(shareAmount <= maxShareAllowed, "MORE_THAN_MAX_WIDTHDRAW");
                /// @dev We withdraw from curvelend vault.
                uint256 assetAmountWithdrawn = market.curveLendVault.redeem(shareAmount);
                /// @dev We transfer to the user.
                IERC20(address(market.lendAsset)).safeTransfer(msg.sender, assetAmountWithdrawn);
            }
        }
        emit Withdraw(msg.sender, isStableReward, outType, amount);
    }

    //TODO: notice
    function claimSimple(address stakeDaoVault, bool isGovRewards, address claimer) external {
        (CurveLendSplitterToken.TokenAmount[] memory tokenAmounts, address rewardReceiver) = isGovRewards
            ? markets[stakeDaoVault].gUSD.getReward(claimer)
            : markets[stakeDaoVault].scvUSD.getReward(claimer);

        require(tokenAmounts.length != 0, "NOTHING_TO_CLAIM");

        for (uint256 i; i < tokenAmounts.length; ) {
            tokenAmounts[i].token.safeTransfer(rewardReceiver, tokenAmounts[i].amount);
            unchecked {
                ++i;
            }
        }
    }

    /// QUESTION: Reward receiver can be different on multiple stakings,
    /// so are we allowing the rewards redirection to always do the safeTransfer to the same receiver ?
    //TODO: function claimSimple(address stakeDaoVault, address claimer)
    //TODO: function claimMultiple(address[] vaults,address claimer)
    /*
    mapping(IERC20=>amount) tokensToClaim;
    function claimMultiple(address[] vaults,address claimer){
        IERC20[] tokenList;
        for(uint256 i;i<vaults.length,){
            //gov rewards
            markets[vaults[i]].gUSD.getReward(claimer)
            //if tokenAmounts.length != 0 update tokensToClaim
            //if token is seen for the first time (tokensToClaim[token] == 0 ) => add the token to the tokenList

            //scvUSD rewards
            markets[vaults[i]].gUSD.getReward(claimer)
            //if tokenAmounts.length != 0 update tokensToClaim
            unchecked {
                ++i;
            }
        }

        //iterate through tokenList and transfer with the amount present into tokensToClaim
        //et voilà, mon nom Borat !
    }
    */

    /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
                            INTERNALS
    =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */

    function _transferTokens(MarketStruct memory market, TOKEN_TYPE inType, uint256 amount) internal {
        /// @dev Transfer the token (LendAsset).
        if (inType == TOKEN_TYPE.LendAsset) {
            market.lendAsset.safeTransferFrom(msg.sender, address(this), amount);
        }
        /// @dev Transfer the token (LendCurveAsset) to this contract.
        if (inType == TOKEN_TYPE.LendCurveAsset) {
            market.curveLendVault.safeTransferFrom(msg.sender, address(this), amount);
        }
        /// @dev Transfer the token (LendStakeDaoAsset) to this contract.
        if (inType == TOKEN_TYPE.LendStakeDaoAsset) {
            IERC20(address(market.liquidityGauge)).safeTransferFrom(msg.sender, address(this), amount);
        }
    }

    /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
                            VIEWS
    =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */

    function stableDepositTotal(address stakeDaoVault) external view returns (uint256) {
        return markets[stakeDaoVault].scvUSD.totalSupply();
    }

    function govDepositTotal(address stakeDaoVault) external view returns (uint256) {
        return markets[stakeDaoVault].gUSD.totalSupply();
    }

    function stakeDaoVaultShareOwned(address stakeDaoVault) external view returns (uint256) {
        return markets[stakeDaoVault].liquidityGauge.balanceOf(address(this));
    }

    function getMarket(address stakeDaoVault) external view returns (MarketStruct memory) {
        return markets[stakeDaoVault];
    }

    /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
                            OWNER
   =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */

    //TODO: notice
    function createMarket(address stakeDaoVault) external onlyOwner {
        IStakeDaoVault _stakeDaoVault = IStakeDaoVault(stakeDaoVault);
        require(address(markets[stakeDaoVault].curveLendVault) == address(0), "MARKET_ALREADY_EXIST");
        require(beaconCurveLendSplitterToken != address(0), "BEACON_0");

        ICurveLendVault _curveLendVault = ICurveLendVault(_stakeDaoVault.token());
        require(address(_curveLendVault) != address(0), "CURVE_LEND_0");

        IERC20 _lendAsset = IERC20(_curveLendVault.asset());
        require(address(_lendAsset) != address(0), "LEND_ASSET_0");

        ISDLiquidityGauge _liquidityGauge = ISDLiquidityGauge(_stakeDaoVault.liquidityGauge());
        require(address(_liquidityGauge) != address(0), "LIQUIDITY_GAUGE_0");

        /// @dev Deploy gUSD (beaconProxy)
        CurveLendSplitterToken _gUSD = CurveLendSplitterToken(
            address(
                new BeaconProxy(
                    beaconCurveLendSplitterToken,
                    //TODO: Get name of the lend token to personalize name/symbol for gUSD and scvUSD
                    abi.encodeCall(
                        CurveLendSplitterToken.initialize,
                        ("Governance USD/CRV", "gUSD-CRV", address(this), address(_liquidityGauge))
                    )
                )
            )
        );
        /// @dev Deploy scvUSD (beaconProxy)
        CurveLendSplitterToken _scvUSD = CurveLendSplitterToken(
            address(
                new BeaconProxy(
                    beaconCurveLendSplitterToken,
                    //TODO: Get name of the lend token to personalize name/symbol for gUSD and scvUSD
                    abi.encodeCall(
                        CurveLendSplitterToken.initialize,
                        ("Stable USD/CRV", "scvUSD-CRV", address(this), address(_liquidityGauge))
                    )
                )
            )
        );

        /// @dev Approvals
        //TODO: check approvals ???
        _lendAsset.approve(address(_curveLendVault), MAX_UINT);
        _curveLendVault.approve(stakeDaoVault, MAX_UINT);
        _liquidityGauge.approve(address(_gUSD), MAX_UINT);
        _liquidityGauge.approve(address(_scvUSD), MAX_UINT);

        /// @dev Redirect liquidity gauge rewards to gUSD when claim occur (for processGovRewards)
        _liquidityGauge.set_rewards_receiver(address(_gUSD));

        /// @dev Save market on markets mapping
        markets[stakeDaoVault] = MarketStruct({
            curveLendVault: _curveLendVault,
            liquidityGauge: _liquidityGauge,
            lendAsset: _lendAsset,
            gUSD: _gUSD,
            scvUSD: _scvUSD
        });

        /// @dev WL gUSD as an special updater
        isSpecialUpdater[address(_gUSD)] = true;
    }

    //TODO: notice
    function updateDaoFees(IERC20[] memory tokens, uint256[] memory amounts) external {
        require(isSpecialUpdater[msg.sender], "NOT_UPDATER");
        for (uint256 i; i < tokens.length; ) {
            daoFeeForToken[tokens[i]] += amounts[i];
            unchecked {
                ++i;
            }
        }
    }

    //TODO: notice
    function withdrawFees(IERC20[] memory tokens) external onlyOwner {
        //TODO: Change this function to send token to the right treasury
        for (uint256 i; i < tokens.length; ) {
            uint256 daoFeeToken = daoFeeForToken[tokens[i]];
            require(daoFeeToken != 0, "SOME_TOKEN_WITHDRAW_0");
            tokens[i].transfer(msg.sender, daoFeeToken);
            delete daoFeeForToken[tokens[i]];
            unchecked {
                ++i;
            }
        }
    }

    function setBeaconCurveLendSplitterToken(address _beaconCurveLendSplitterToken) external onlyOwner {
        beaconCurveLendSplitterToken = _beaconCurveLendSplitterToken;
    }
}
