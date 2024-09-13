// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {BeaconProxy} from "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {gUSDSdt} from "./tokens/stakeDao/gUSDSdt.sol";
import {scvUSDSdt} from "./tokens/stakeDao/scvUSDSdt.sol";

import {gUSDCvx} from "./tokens/convex/gUSDCvx.sol";
import {scvUSDCvx} from "./tokens/convex/scvUsdCvx.sol";

import {Errors} from "./libs/Errors.sol";
import {ILlamaLendVault} from "./interfaces/externals/ILlamaLendVault.sol";
import {IStakeDaoVault} from "./interfaces/externals/IStakeDaoVault.sol";
import {ISdtLiquidityGauge} from "./interfaces/externals/ISdtLiquidityGauge.sol";
import {ICurveLendSplitterToken} from "./interfaces/internals/ICurveLendSplitterToken.sol";
import {ILendRewardSplitter} from "./interfaces/internals/ILendRewardSplitter.sol";
import {ICommonStruct} from "./interfaces/internals/ICommonStruct.sol";
import {IgUSDCvx} from "./interfaces/internals/IgUSDCvx.sol";

import {ICvxBooster} from "./interfaces/externals/ICvxBooster.sol";
import {ICvxRewardToken} from "./interfaces/externals/ICvxRewardToken.sol";
import "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";
import "forge-std/console.sol"; //TODO: to remove

contract LendRewardSplitter is Ownable2StepUpgradeable {
    using SafeERC20 for IERC20;
    using SafeERC20 for ILlamaLendVault;
    using SafeERC20 for IStakeDaoVault;
    using SafeERC20 for ISdtLiquidityGauge;
    using SafeERC20 for ICvxRewardToken;

    uint256 constant MAX_UINT = uint256(int256(-1));

    ICvxBooster constant CVX_BOOSTER = ICvxBooster(0xF403C135812408BFbE8713b5A23a04b3D48AAE31);

    address public gUSDBeaconSdt;
    address public scvUSDBeaconSdt;

    address public gUSDBeaconCvx;
    address public scvUSDBeaconCvx;

    mapping(IERC20 => uint256) public daoFeeForToken;

    mapping(ILlamaLendVault => IERC20) public lentAssetPerLlamaVault;
    /// StakeDAO
    mapping(ILlamaLendVault => IStakeDaoVault) public sdtVaultPerLlamaVault;
    mapping(ILlamaLendVault => ISdtLiquidityGauge) public sdtGaugePerLlamaVault;
    mapping(ILlamaLendVault => ICurveLendSplitterToken) public gUSDSdtPerLlamaVault;
    mapping(ILlamaLendVault => ICurveLendSplitterToken) public scvUSDSdtPerLlamaVault;
    /// Convex
    mapping(ILlamaLendVault => uint256) public cvxPidPerLlamaVault;
    mapping(ILlamaLendVault => ICvxRewardToken) public cvxRewardTokenPerLlamaVault;
    mapping(ILlamaLendVault => IERC20) public cvxVaultPerLlamaVault;
    mapping(ILlamaLendVault => ICurveLendSplitterToken) public gUSDCvxPerLlamaVault;
    mapping(ILlamaLendVault => ICurveLendSplitterToken) public scvUSDCvxPerLlamaVault;

    mapping(address => bool) public isLendSplitterToken;

    event DepositSdt(address indexed account, bool isStableReward, ILendRewardSplitter.SDT_TOKEN_TYPE outType, uint256 amount);
    event WithdrawSdt(address indexed account, bool isStableReward, ILendRewardSplitter.SDT_TOKEN_TYPE outType, uint256 amount);
    event DepositCvx(address indexed account, bool isStableReward, ILendRewardSplitter.CVX_TOKEN_TYPE outType, uint256 amount);
    event WithdrawCvx(address indexed account, bool isStableReward, ILendRewardSplitter.CVX_TOKEN_TYPE outType, uint256 amount);

    error NoRewardsToClaimFromContract(address contractAddr);
    error IncorretRewardLength(uint256 rewardLengthInParam, uint256 realRewardLength);
    error NoRewardToMultiClaim();
    error NoRewardToSimpleClaim();
    error NotACurveSplitterToken(address contractAddr);
    error AlreadyCreatedCvxMarket(uint256 pid);

    /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
                        CONSTRUCTOR & INITIALIZER
    =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address _owner,
        address _gUSDBeaconSdt,
        address _scvUSDBeaconSdt,
        address _gUSDBeaconCvx,
        address _scvUSDBeaconCvx
    ) external initializer {
        gUSDBeaconSdt = _gUSDBeaconSdt;
        scvUSDBeaconSdt = _scvUSDBeaconSdt;
        gUSDBeaconCvx = _gUSDBeaconCvx;
        scvUSDBeaconCvx = _scvUSDBeaconCvx;

        _transferOwnership(_owner);
    }

    /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
                        DEPOSITS
    =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */

    /*
    TODO:
    deposit with...
    USDT/DAI/USDC/USDe/ETH/WETH
    */

    /**
     *  @notice Deposit asset into the Convergence splitter contract in order to get one part of the reawrd from the lend contract.
     *  @param inType Type of token to in with with 3 steps  LendAsset >  LendCurveAsset >  LendStakeDaoAsset
     *  @param amount Amount  of {inType} token to deposit.
     *  @param isStableReward bool  IF isStableReward == true THEN   you want the stable part of the reward  ELSE you want the gauge part of the reward.
     *  @param doDeposit bool  IF doDeposit == true THEN  all the pending asset will be deposited in stakeValut.
     *  @return depositAmount Staked amount eligible to rewards.
     */
    function depositSdt(
        ILlamaLendVault llamaVault,
        ILendRewardSplitter.SDT_TOKEN_TYPE inType,
        uint256 amount,
        bool isStableReward,
        bool doDeposit
    ) external returns (uint256 depositAmount) {
        depositAmount = amount;
        ISdtLiquidityGauge stakeDaoGauge = sdtGaugePerLlamaVault[llamaVault];
        /// TODO Add input check on llamavault
        if (inType == ILendRewardSplitter.SDT_TOKEN_TYPE.SdtGaugeAsset) {
            stakeDaoGauge.safeTransferFrom(msg.sender, address(this), amount);
        } else {
            if (inType == ILendRewardSplitter.SDT_TOKEN_TYPE.LlamalendVaultAsset) {
                /// @dev Transfer the vault asset from LlamaLend
                llamaVault.safeTransferFrom(msg.sender, address(this), amount);
            } else {
                lentAssetPerLlamaVault[llamaVault].safeTransferFrom(msg.sender, address(this), amount);
                /// @dev Deposit in curveLend.
                depositAmount = llamaVault.deposit(amount, address(this));
            }

            uint256 balanceBefore = stakeDaoGauge.balanceOf(address(this));
            sdtVaultPerLlamaVault[llamaVault].deposit(address(this), depositAmount, doDeposit);
            depositAmount = stakeDaoGauge.balanceOf(address(this)) - balanceBefore;
        }

        if (isStableReward) {
            /// @dev For scvUSD, we mint 1:1 from cvcrvUSD.
            scvUSDSdtPerLlamaVault[llamaVault].mint(msg.sender, depositAmount);
        } else {
            /// @dev For gUSD, we mint 1:1 from crvUSD,
            // we use the curveLendVault.convertToAssets to calculate the amount.
            depositAmount = llamaVault.convertToAssets(depositAmount);
            gUSDSdtPerLlamaVault[llamaVault].mint(msg.sender, depositAmount);
        }

        /// @dev Requires that some tokens are deposited
        if (depositAmount == 0) {
            revert Errors.ZeroAmount();
        }

        emit DepositSdt(msg.sender, isStableReward, inType, depositAmount);
    }

    function depositCvx(
        ILlamaLendVault llamaVault,
        ILendRewardSplitter.CVX_TOKEN_TYPE inType,
        uint256 amount,
        bool isStableReward,
        bool doDeposit
    ) external returns (uint256 depositAmount) {
        depositAmount = amount;
        ICvxRewardToken cvxRewardToken = cvxRewardTokenPerLlamaVault[llamaVault];

        IgUSDCvx gUSD = IgUSDCvx(address(gUSDCvxPerLlamaVault[llamaVault]));
        if (inType == ILendRewardSplitter.CVX_TOKEN_TYPE.LlamalendVaultAsset) {
            /// @dev Transfer the vault asset from LlamaLend
            llamaVault.safeTransferFrom(msg.sender, address(gUSD), amount);
        } else {
            /// @dev Transfer the lent asset in the LlamalendVault
            lentAssetPerLlamaVault[llamaVault].safeTransferFrom(msg.sender, address(this), amount);
            /// @dev Deposit the lent asset in the LlamalendVault
            depositAmount = llamaVault.deposit(amount, address(gUSD));
        }
        if (doDeposit) {
            depositAmount = gUSD.depositAndStake(cvxRewardToken, cvxPidPerLlamaVault[llamaVault], depositAmount);
        } else {
            depositAmount = gUSD.depositNoStake(cvxVaultPerLlamaVault[llamaVault], cvxPidPerLlamaVault[llamaVault], depositAmount);
        }

        if (isStableReward) {
            /// @dev For scvUSD, we mint 1:1 from cvcrvUSD.
            scvUSDCvxPerLlamaVault[llamaVault].mint(msg.sender, depositAmount);
        } else {
            /// @dev For gUSD, we mint 1:1 from crvUSD,
            // we use the curveLendVault.convertToAssets to calculate the amount.
            depositAmount = llamaVault.convertToAssets(depositAmount);
            gUSD.mint(msg.sender, depositAmount);
        }

        /// @dev Requires that some tokens are deposited
        if (depositAmount == 0) {
            revert Errors.ZeroAmount();
        }

        emit DepositCvx(msg.sender, isStableReward, inType, depositAmount);
    }

    /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
                        WITHDRAW
    =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */

    /**
     *  @notice Withdraw assets from  the Convergence splitter contract.
     *  @param outType Type of token you want to in with with 4 steps  LendAsset >  LendCurveAsset.
     *  @param amount Amount  of {gUSD|scvUsd} token you want to withdraw.
     *  @param isStableReward  If isStableReward == true THEN   scvUsd of user is used   ELSE  gUSD of user is used.
     */
    function withdrawSdt(ILlamaLendVault llamaLendVault, ILendRewardSplitter.SDT_TOKEN_TYPE outType, uint256 amount, bool isStableReward) public {
        /// @dev We check the prerequesite.
        require(amount != 0, "WITHDRAW_LTE_0");

        ICurveLendSplitterToken recipeToken = isStableReward ? scvUSDSdtPerLlamaVault[llamaLendVault] : gUSDSdtPerLlamaVault[llamaLendVault];

        /// @dev We burn the corresponding token.
        recipeToken.burn(msg.sender, amount);

        /// @dev We process the amounts.
        uint256 shareAmount = isStableReward ? amount : llamaLendVault.convertToShares(amount);

        if (outType == ILendRewardSplitter.SDT_TOKEN_TYPE.SdtGaugeAsset) {
            /// @dev we transfer the stake share to the user.
            sdtGaugePerLlamaVault[llamaLendVault].safeTransfer(msg.sender, shareAmount);
        } else {
            /// @dev We withdraw the share from stakeDAO vault.
            sdtVaultPerLlamaVault[llamaLendVault].withdraw(shareAmount);
            // require(balanceBefore - balanceAfter >= shareAmount, "WITHDRAW ERROR");
            if (outType == ILendRewardSplitter.SDT_TOKEN_TYPE.LlamalendVaultAsset) {
                /// @dev we transfer the stake share to the user.
                llamaLendVault.safeTransfer(msg.sender, shareAmount);
            } else {
                /// @dev We withdraw from curvelend vault and send it to the user
                llamaLendVault.redeem(shareAmount, msg.sender);
            }
        }
        emit WithdrawSdt(msg.sender, isStableReward, outType, amount);
    }

    /**
     *  @notice Withdraw assets from  the Convergence splitter contract.
     *  @param outType Type of token you want to in with with 4 steps  LendAsset >  LendCurveAsset.
     *  @param amount Amount  of {gUSD|scvUsd} token you want to withdraw.
     *  @param isStableReward  If isStableReward == true THEN   scvUsd of user is used   ELSE  gUSD of user is used.
     */
    function withdrawCvx(ILlamaLendVault llamaVault, ILendRewardSplitter.CVX_TOKEN_TYPE outType, uint256 amount, bool isStableReward) public {
        /// @dev We check the prerequesite.
        require(amount != 0, "WITHDRAW_LTE_0");

        IgUSDCvx gUSD = IgUSDCvx(address(gUSDCvxPerLlamaVault[llamaVault]));

        uint256 shareAmount = amount;
        if (isStableReward) {
            /// @dev We burn the corresponding token.
            scvUSDCvxPerLlamaVault[llamaVault].burn(msg.sender, amount);
        } else {
            /// @dev We burn the corresponding token.
            ICurveLendSplitterToken(address(gUSD)).burn(msg.sender, amount);
            shareAmount = llamaVault.convertToShares(amount);
        }

        gUSD.withdraw(shareAmount, msg.sender, outType, llamaVault);

        emit WithdrawCvx(msg.sender, isStableReward, outType, amount);
    }

    /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
                        CLAIM REWARDS
    =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */

    //TODO: notice
    function claimSimple(address lendSplitterToken, address account) external {
        if (!isLendSplitterToken[lendSplitterToken]) {
            revert NotACurveSplitterToken(lendSplitterToken);
        }

        ICommonStruct.TokenAmount[] memory tokenAmounts = ICurveLendSplitterToken(lendSplitterToken).getAndUpdateRewards(account);

        if (tokenAmounts.length == 0) {
            revert NoRewardToSimpleClaim();
        }

        for (uint256 erc20Id; erc20Id < tokenAmounts.length; ) {
            tokenAmounts[erc20Id].token.safeTransfer(account, tokenAmounts[erc20Id].amount);
            unchecked {
                ++erc20Id;
            }
        }
    }

    /// QUESTION: Reward receiver can be different on multiple stakings,
    /// so are we allowing the rewards redirection to always do the safeTransfer to the same receiver ?
    function claimMultiple(address[] calldata lendSplitterTokens, address account, uint256 rewardLength) external {
        /// @dev We save this length on his own variable, to not miss with the assembly manipulations
        uint256 lendTokensLength = lendSplitterTokens.length;
        IERC20[] memory tokenList = new IERC20[](lendTokensLength);
        uint256 actualErc20Index;

        /// @dev Iterates through all of the vaults
        for (uint256 lendSplitterTokenIndex; lendSplitterTokenIndex < lendTokensLength; ) {
            address lendSplitterToken = lendSplitterTokens[lendSplitterTokenIndex];
            if (!isLendSplitterToken[lendSplitterToken]) {
                revert NotACurveSplitterToken(lendSplitterToken);
            }
            /// @dev gUSD rewards
            ICommonStruct.TokenAmount[] memory tokenAmountsToClaim = ICurveLendSplitterToken(lendSplitterToken).getAndUpdateRewards(account);
            /// @dev If the rewards returned by the gUSD is an empty array,
            if (tokenAmountsToClaim.length == 0) {
                revert NoRewardsToClaimFromContract(address(lendSplitterToken));
            }
            /// @dev Iterates over all erc20 received from the claim on the gUSD
            for (uint256 tokenIndex; tokenIndex < tokenAmountsToClaim.length; ) {
                IERC20 erc20 = tokenAmountsToClaim[tokenIndex].token;
                /// @dev If token is seen the first time (tokensToClaim[token] == 0)
                uint256 rewardAmount = _tLoadUintForAddress(address(erc20));
                if (rewardAmount == 0) {
                    /// @dev Increment tokenList length & add new token on new index
                    tokenList[actualErc20Index] = erc20;
                    unchecked {
                        ++actualErc20Index;
                    }
                }
                /// @dev Increment storage value
                _tStoreUintForAddress(address(erc20), rewardAmount + tokenAmountsToClaim[tokenIndex].amount);
                unchecked {
                    ++tokenIndex;
                }
            }

            if (rewardLength != actualErc20Index) {
                revert IncorretRewardLength(rewardLength, actualErc20Index);
            }

            unchecked {
                ++lendSplitterTokenIndex;
            }
        }

        /// @dev Iterate through tokenList
        bool isSomethingToClaim;
        for (uint256 tokenIndex; tokenIndex < tokenList.length; ) {
            IERC20 token = tokenList[tokenIndex];
            uint256 amountClaim = _tLoadUintForAddress(address(token));

            if (amountClaim != 0) {
                isSomethingToClaim = true;
                token.safeTransfer(account, amountClaim);
                /// @dev Erase transient for the token
                _tStoreUintForAddress(address(token), 0);
            }

            unchecked {
                ++tokenIndex;
            }
        }

        if (!isSomethingToClaim) {
            revert NoRewardToMultiClaim();
        }
    }

    /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
                    FEES UPDATER
   =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */
    /**
     * @notice Increment dao fees that will be transferred in this contract during a process rewards.
     *         This function is only callable by an updater (scvUSD or gUSD).
     * @param tokenAmounts array of token to used to increment fees
     */
    function incrementDaoFees(ICommonStruct.TokenAmount[] memory tokenAmounts) external {
        require(isLendSplitterToken[msg.sender], "NOT_UPDATER");
        for (uint256 erc20Id; erc20Id < tokenAmounts.length; ) {
            daoFeeForToken[tokenAmounts[erc20Id].token] += tokenAmounts[erc20Id].amount;
            unchecked {
                ++erc20Id;
            }
        }
    }

    /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
                            OWNER
   =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */

    /**
     * @notice Create a new Market through a StakeDao vault (only for collatered vaults).
     *         Deploy on the fly the corresponding streamed tokens: scvUSD (stable) & gUSD (governance)
     * @param stakeDaoVault Address of the vault of StakeDao
     */
    function createSdtMarket(IStakeDaoVault stakeDaoVault) external onlyOwner {
        require(scvUSDBeaconSdt != address(0), "BEACON_0");
        require(gUSDBeaconSdt != address(0), "BEACON_0");

        ILlamaLendVault _llamaLendVault = ILlamaLendVault(stakeDaoVault.token());
        require(address(sdtVaultPerLlamaVault[_llamaLendVault]) == address(0), "MARKET_ALREADY_EXIST");

        require(address(_llamaLendVault) != address(0), "CURVE_LEND_0");

        IERC20 _lendAsset = IERC20(_llamaLendVault.asset());
        require(address(_lendAsset) != address(0), "LEND_ASSET_0");

        ISdtLiquidityGauge _liquidityGauge = ISdtLiquidityGauge(stakeDaoVault.liquidityGauge());
        require(address(_liquidityGauge) != address(0), "LIQUIDITY_GAUGE_0");

        /// @dev Deploy gUSD (beaconProxy)
        gUSDSdt _gUSD = gUSDSdt(
            address(
                new BeaconProxy(
                    gUSDBeaconSdt,
                    //TODO: Get name of the lend token to personalize name/symbol for gUSD and scvUSD
                    abi.encodeCall(gUSDSdt.initialize, ("Governance USD/CRV", "gUSD-CRV", address(this), address(_liquidityGauge)))
                )
            )
        );
        /// @dev Deploy scvUSD (beaconProxy)
        scvUSDSdt _scvUSD = scvUSDSdt(
            address(
                new BeaconProxy(
                    scvUSDBeaconSdt,
                    //TODO: Get name of the lend token to personalize name/symbol for gUSD and scvUSD
                    abi.encodeCall(scvUSDSdt.initialize, ("Stable USD/CRV", "scvUSD-CRV", address(this)))
                )
            )
        );

        /// @dev Approvals
        //TODO: check approvals ???
        _lendAsset.approve(address(_llamaLendVault), MAX_UINT);
        _llamaLendVault.approve(address(stakeDaoVault), MAX_UINT);

        /// @dev Redirect liquidity gauge rewards to gUSD when claim occur (for processRewards)
        _liquidityGauge.set_rewards_receiver(address(_gUSD));

        sdtVaultPerLlamaVault[_llamaLendVault] = stakeDaoVault;
        sdtGaugePerLlamaVault[_llamaLendVault] = _liquidityGauge;
        lentAssetPerLlamaVault[_llamaLendVault] = _lendAsset;
        scvUSDSdtPerLlamaVault[_llamaLendVault] = ICurveLendSplitterToken(address(_scvUSD));
        gUSDSdtPerLlamaVault[_llamaLendVault] = ICurveLendSplitterToken(address(_gUSD));

        isLendSplitterToken[address(_gUSD)] = true;
        isLendSplitterToken[address(_scvUSD)] = true;

        /// @dev WL gUSD as an special updater
        isLendSplitterToken[address(_gUSD)] = true;
    }

    /**
     * @notice Create a new Market through a StakeDao vault (only for collatered vaults).
     *         Deploy on the fly the corresponding streamed tokens: scvUSD (stable) & gUSD (governance)
     * @param pid Address of the vault of StakeDao
     */
    function createCvxMarket(uint256 pid) external onlyOwner {
        require(scvUSDBeaconCvx != address(0), "BEACON_0");
        require(gUSDBeaconCvx != address(0), "BEACON_0");

        (address _llamaLendVaultAddr, address cvxVaultToken, , address rewardTokenAddr, , ) = CVX_BOOSTER.poolInfo(pid);
        ILlamaLendVault _llamaLendVault = ILlamaLendVault(_llamaLendVaultAddr);
        ICvxRewardToken rewardToken = ICvxRewardToken(rewardTokenAddr);

        if (cvxPidPerLlamaVault[_llamaLendVault] != 0) {
            revert AlreadyCreatedCvxMarket(pid);
        }
        require(address(rewardToken) != address(0), "REWARD_TOKEN_0");

        IERC20 _lendAsset = IERC20(_llamaLendVault.asset());

        /// @dev Deploy gUSD (beaconProxy)
        gUSDCvx _gUSD = gUSDCvx(
            address(
                new BeaconProxy(
                    gUSDBeaconCvx,
                    //TODO: Get name of the lend token to personalize name/symbol for gUSD and scvUSD
                    abi.encodeCall(
                        gUSDCvx.initialize,
                        ("Governance USD/CRV", "gUSD-CRV", ILendRewardSplitter(address(this)), rewardToken, IERC20(_llamaLendVaultAddr), IERC20(cvxVaultToken))
                    )
                )
            )
        );
        /// @dev Deploy scvUSD (beaconProxy)
        scvUSDCvx _scvUSD = scvUSDCvx(
            address(
                new BeaconProxy(
                    scvUSDBeaconCvx,
                    //TODO: Get name of the lend token to personalize name/symbol for gUSD and scvUSD
                    abi.encodeCall(scvUSDCvx.initialize, ("Stable USD/CRV", "scvUSD-CRV", ILendRewardSplitter(address(this))))
                )
            )
        );

        /// @dev Approvals
        //TODO: check approvals ???
        _lendAsset.approve(address(_llamaLendVault), MAX_UINT);
        _llamaLendVault.approve(address(CVX_BOOSTER), MAX_UINT);

        cvxPidPerLlamaVault[_llamaLendVault] = pid;
        lentAssetPerLlamaVault[_llamaLendVault] = _lendAsset;
        cvxRewardTokenPerLlamaVault[_llamaLendVault] = rewardToken;
        cvxVaultPerLlamaVault[_llamaLendVault] = IERC20(cvxVaultToken);

        scvUSDCvxPerLlamaVault[_llamaLendVault] = ICurveLendSplitterToken(address(_scvUSD));
        gUSDCvxPerLlamaVault[_llamaLendVault] = ICurveLendSplitterToken(address(_gUSD));

        isLendSplitterToken[address(_gUSD)] = true;
        isLendSplitterToken[address(_scvUSD)] = true;
    }

    /**
     * @notice Withdraw all the balance of the desired fees token and erase the corresponding storage.
     * @param tokens IERC20 array to withdraw
     */
    function withdrawFees(IERC20[] memory tokens) external onlyOwner {
        //TODO: Change this function to send token to the right treasury

        for (uint256 erc20Id; erc20Id < tokens.length; ) {
            IERC20 erc20 = tokens[erc20Id];
            uint256 daoFeeToken = daoFeeForToken[erc20];
            require(daoFeeToken != 0, "SOME_TOKEN_WITHDRAW_0");
            erc20.transfer(msg.sender, daoFeeToken);
            delete daoFeeForToken[erc20];
            unchecked {
                ++erc20Id;
            }
        }
    }

    /**
     * @notice Set a new beacon contract used to deploy scvUSD/gUSD tokens
     *         To use only for emergencys.
     * @param _gUSDBeaconSdt address of the new gUSDBeacon
     */
    function setgUSDBeacon(address _gUSDBeaconSdt) external onlyOwner {
        gUSDBeaconSdt = _gUSDBeaconSdt;
    }

    /**
     * @notice Set a new beacon contract used to deploy scvUSD/gUSD tokens
     *         To use only for emergencys.
     * @param _scvUSDBeaconSdt address of the new cvUSDBeacon
     */
    function setcvUSDBeacon(address _scvUSDBeaconSdt) external onlyOwner {
        scvUSDBeaconSdt = _scvUSDBeaconSdt;
    }

    /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
                            INTERNALS
    =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */

    function _tStoreUintForAddress(address location, uint256 value) private {
        assembly {
            tstore(location, value)
        }
    }

    function _tLoadUintForAddress(address location) private view returns (uint256 value) {
        assembly {
            value := tload(location)
        }
    }
}
