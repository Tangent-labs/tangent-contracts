// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Ownable2StepUpgradeable} from "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";
import {BeaconProxy} from "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {gUSDCvx} from "./tokens/gUSDCvx.sol";
import {scvUSDCvx} from "./tokens/scvUSDCvx.sol";

import {SplitterTokenComp} from "./tokens/SplitterTokenComp.sol";

import {Errors} from "./libs/Errors.sol";
import {ILlamaVault} from "./interfaces/externals/ILlamaVault.sol";
import {ISplitterToken} from "./interfaces/internals/ISplitterToken.sol";
import {ILendRewardSplitter} from "./interfaces/internals/ILendRewardSplitter.sol";
import {ICommonStruct} from "./interfaces/internals/ICommonStruct.sol";

import {ICvxBooster} from "./interfaces/externals/ICvxBooster.sol";
import {ICurveRouter} from "./interfaces/externals/ICurveRouter.sol";
import {ICvxRewardToken} from "./interfaces/externals/ICvxRewardToken.sol";

import {IgUSDCvx} from "./interfaces/internals/IgUSDCvx.sol";
import {IscvUSD} from "./interfaces/internals/IscvUSD.sol";
import "forge-std/console.sol"; //TODO: to remove

contract LendRewardSplitter is Ownable2StepUpgradeable, ILendRewardSplitter {
    using SafeERC20 for IERC20;
    using SafeERC20 for ILlamaVault;
    using SafeERC20 for ICvxRewardToken;

    uint256 constant MAX_UINT = uint256(int256(-1));

    ICvxBooster constant CVX_BOOSTER = ICvxBooster(0xF403C135812408BFbE8713b5A23a04b3D48AAE31);
    ICurveRouter public constant CURVE_ROUTER = ICurveRouter(0x16C6521Dff6baB339122a0FE25a9116693265353);

    address public GUSDBeaconCvx;
    address public SCVUSDBeaconCvx;
    address public autoCompoundBeacon;

    address public feeTreasury;

    mapping(ILlamaVault => IERC20) public lentAssetPerLlamaVault;

    mapping(ILlamaVault => uint256) public pidPerLlamaVault;
    mapping(ILlamaVault => ICvxRewardToken) public rewardTokenPerLlamaVault;
    mapping(ILlamaVault => IERC20) public vaultPerLlamaVault;
    mapping(ILlamaVault => IgUSDCvx) public gUSDPerLlamaVault;
    mapping(ILlamaVault => IscvUSD) public scvUSDPerLlamaVault;
    mapping(ILlamaVault => SplitterTokenComp) public scvUSDAutoCompoundPerLlamaVault;

    /// @dev Gives the amount of fee that DAO can withdraw for an ERC20
    mapping(IERC20 => uint256) public daoFeeForToken;
    /// @dev Determines if address is scvUSD or gUSD
    mapping(address => bool) public isLendSplitterToken;
    /// @dev Tokens allowed to be used in zapAndDeposit method.
    mapping(address => bool) public allowedZapToken;

    event DepositGUSD(address indexed account, ILlamaVault llamaVault, ILendRewardSplitter.CVX_TOKEN_TYPE outType, uint256 amount);
    event DepositSCVUSD(address indexed account, ILlamaVault llamaVault, ILendRewardSplitter.CVX_TOKEN_TYPE outType, uint256 amount);
    event WithdrawGUSD(address indexed account, ILlamaVault llamaVault, ILendRewardSplitter.CVX_TOKEN_TYPE outType, uint256 amount);
    event WithdrawSCVUSD(address indexed account, ILlamaVault llamaVault, ILendRewardSplitter.CVX_TOKEN_TYPE outType, uint256 amount);

    event ToggleZapToken(address erc20, bool newState);
    event CreateMarket(ILlamaVault indexed llamaVault, scvUSDCvx scvUSD, SplitterTokenComp scvUSDAutomCompound, gUSDCvx gUSD);

    error NoRewardsToClaimFromContract(address contractAddr);
    error IncorretRewardLength(uint256 rewardLengthInParam, uint256 realRewardLength);
    error NoRewardToMultiClaim();
    error NoRewardToSimpleClaim();
    error NotACurveSplitterToken(address contractAddr);
    error AlreadyCreatedCvxMarket(uint256 pid);
    error CallerNotFeeTreasury();
    error CallerNotLendSplitterToken();
    error NotLendAssetRoute(address token);
    error NotAllowedInToken(address token);
    error NoFeesToWithdraw(address token);

    /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
                        CONSTRUCTOR & INITIALIZER
    =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address _owner,
        address _feeTreasury,
        address _gUSDBeaconCvx,
        address _scvUSDBeaconCvx,
        address _autoCompoundBeacon
    ) external initializer {
        feeTreasury = _feeTreasury;
        GUSDBeaconCvx = _gUSDBeaconCvx;
        SCVUSDBeaconCvx = _scvUSDBeaconCvx;
        autoCompoundBeacon = _autoCompoundBeacon;

        _transferOwnership(_owner);
    }

    /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
                        DEPOSITS
    =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */

    /**
     *  @notice Zap the given asset into lendAsset and use the deposit function. (asset must be listed in allowedZapToken)
     *  @param llamaLendVault Llamalend vault address
     *  @param inAmount Amount of {tokenIn} token you want to deposit. (can be 0 if ETH is sent) )
     *  @param minLendAssetAmount min amount of {lendasset token} accepted for the {inAmout} of {tokenIn} (cf routes[0])
     *  @param isStableReward   IF isStableReward == true THEN   you want the stable part of the reward  ELSE you want the gauge part of the reward.
     *  @param doDeposit  IF doDeposit == true THEN  all the pending asset will be deposited in stakeValut.
     *  @param routes parameters for curve router . (see https://docs.curve.fi/router/CurveRouterNG/#_route) - route must end with the lendAsset.
     *  @param pools parameters for curve router. (see https://docs.curve.fi/router/CurveRouterNG/#exchange)
     *  @param swapParams parameters for curve router (see https://docs.curve.fi/router/CurveRouterNG/#_swap_params)
     */
    function zapAndDeposit(
        ILlamaVault llamaLendVault,
        uint256 inAmount,
        uint256 minLendAssetAmount,
        bool isStableReward,
        bool isAutoCompound,
        bool doDeposit,
        address[11] calldata routes,
        address[5] calldata pools,
        uint256[5][5] calldata swapParams
    ) public payable returns (uint256) {
        {
            address lentAsset = address(lentAssetPerLlamaVault[llamaLendVault]);
            /// @dev Check that the end route is the llenAsset of the market.
            for (uint256 routeIndex = 1; routeIndex < routes.length; ) {
                /// @dev when we find the first 0x0, this is the end of the route.
                if (routes[routeIndex] == address(0)) {
                    require(routes[routeIndex - 1] == lentAsset, NotLendAssetRoute(routes[routeIndex - 1]));
                    break;
                }
                unchecked {
                    ++routeIndex;
                }
            }
        }
        address tokenIn = routes[0];

        /// @dev if not ETH deposit , we tranfer the token to this contract,and allow the router to move it.
        if (msg.value == 0) {
            require(allowedZapToken[tokenIn], NotAllowedInToken(tokenIn));
            IERC20(tokenIn).safeTransferFrom(msg.sender, address(this), inAmount);
        }

        /// @dev Process Swap.
        uint256 lendAssetAmount = CURVE_ROUTER.exchange{value: msg.value}(
            routes,
            swapParams,
            msg.value > 0 ? msg.value : inAmount,
            minLendAssetAmount, // Minimum amount of crvUSD to receive (slippage protection)
            pools,
            address(this)
        );

        /// @dev Continue deposit.
        if (isStableReward) {
            return _depositSCVUSD(llamaLendVault, ILendRewardSplitter.CVX_TOKEN_TYPE.LendAsset, lendAssetAmount, isAutoCompound, doDeposit, true);
        } else {
            return _depositGUSD(llamaLendVault, ILendRewardSplitter.CVX_TOKEN_TYPE.LendAsset, lendAssetAmount, doDeposit, true);
        }
    }

    /**
     *  @notice Deposit an "inAmount" of "inType" asset and mint the "mintedAmount" of gUSD linked to the "llamaVault".
     *  @param llamaVault     Llamalend vault address
     *  @param inType             Type of the token to in with. 0 for the LendAsset and 1 for the Llama LP.
     *  @param inAmount           Amount of asset to mint gUSD tokens with.
     *  @param doDeposit          If true, stakes all Llama LP in convex. Else, only deposits Llama LP in gUSD.
     *  @return mintedAmount of scvUSD minted to the msg.sender
     */
    function depositGUSD(
        ILlamaVault llamaVault,
        ILendRewardSplitter.CVX_TOKEN_TYPE inType,
        uint256 inAmount,
        bool doDeposit
    ) external returns (uint256 mintedAmount) {
        return _depositGUSD(llamaVault, inType, inAmount, doDeposit, false);
    }

    function _depositGUSD(
        ILlamaVault llamaVault,
        ILendRewardSplitter.CVX_TOKEN_TYPE inType,
        uint256 inAmount,
        bool doDeposit,
        bool isZap
    ) internal returns (uint256 mintedAmount) {
        IgUSDCvx gUSD = gUSDPerLlamaVault[llamaVault];

        /// @dev Deposit the 'in' token and retrieve Llama Lend LP. Returns the amount of Llama LP deposited or minted so the amount of shares.
        mintedAmount = _depositTransfer(llamaVault, inType, gUSD, inAmount, isZap);

        // We mint 1 gUSD per equivalent amount of lendAsset represented by "mintedAmount" that is a share so we need to first convertToAssets it.
        mintedAmount = gUSD.mint(msg.sender, mintedAmount, llamaVault, pidPerLlamaVault[llamaVault], doDeposit);

        /// @dev Requires that some tokens are minted
        require(mintedAmount != 0, Errors.ZeroAmount());

        return mintedAmount;
    }

    /**
     *  @notice Deposit an "inAmount" of "inType" asset and mint the "mintedAmount" of scvUSD linked to the "llamaVault".
     *  @param llamaVault     Llamalend vault address
     *  @param inType             Type of the token to in with. 0 for the LendAsset and 1 for the Llama LP.
     *  @param inAmount           Amount of asset to mint scvUSD tokens with.
     *  @param isAutoCompound     If true, rewards will autocompound.
     *  @param doDeposit          If true, stakes all Llama LP in convex. Else, only deposits Llama LP in scvUSD.
     *  @return mintedAmount of scvUSD minted to the msg.sender
     */
    function depositSCVUSD(
        ILlamaVault llamaVault,
        ILendRewardSplitter.CVX_TOKEN_TYPE inType,
        uint256 inAmount,
        bool isAutoCompound,
        bool doDeposit
    ) external returns (uint256 mintedAmount) {
        return _depositSCVUSD(llamaVault, inType, inAmount, isAutoCompound, doDeposit, false);
    }

    function _depositSCVUSD(
        ILlamaVault llamaVault,
        ILendRewardSplitter.CVX_TOKEN_TYPE inType,
        uint256 amount,
        bool isAutoCompound,
        bool doDeposit,
        bool isZap
    ) internal returns (uint256 mintedAmount) {
        IgUSDCvx gUSD = gUSDPerLlamaVault[llamaVault];
        IscvUSD scvUSD = scvUSDPerLlamaVault[llamaVault];
        /// @dev Deposit the 'in' token and retrieve Llama Lend LP. Returns the amount of Llama LP deposited or minted so the amount of shares.
        mintedAmount = _depositTransfer(llamaVault, inType, gUSD, amount, isZap);

        /// @dev We mint 1 scvUSD per share of LlamaVault LP represented by "mintedAmount". We don't have to convert anything here.
        if (isAutoCompound) {
            scvUSDAutoCompoundPerLlamaVault[llamaVault].mintSplitter(msg.sender, mintedAmount, scvUSD);
        } else {
            /// @dev We mint the scvUSD to the message.sender
            scvUSD.mintSplitter(msg.sender, mintedAmount);
        }

        if (doDeposit) {
            gUSD.stakeAll(pidPerLlamaVault[llamaVault]);
        }

        /// @dev Requires that some tokens are deposited

        require(mintedAmount != 0, Errors.ZeroAmount());

        return mintedAmount;
    }

    function _depositTransfer(
        ILlamaVault llamaVault,
        ILendRewardSplitter.CVX_TOKEN_TYPE inType,
        IgUSDCvx gUSD,
        uint256 amount,
        bool isZap
    ) internal returns (uint256) {
        if (inType == ILendRewardSplitter.CVX_TOKEN_TYPE.LlamalendVaultAsset) {
            /// @dev Transfer the vault asset of LlamaLend
            llamaVault.safeTransferFrom(msg.sender, address(gUSD), amount);
            return amount;
        } else {
            /// @dev If a zap is performed before, we don't have to transfer the lendAsset as it's already done
            if (!isZap) {
                /// @dev Transfer the lend asset on the splitter
                lentAssetPerLlamaVault[llamaVault].safeTransferFrom(msg.sender, address(this), amount);
            }

            /// @dev Deposit the lendAsset in the LlamalendVault and returns the amount of vault LP minted.
            return llamaVault.deposit(amount, address(gUSD));
        }
    }

    /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
                        WITHDRAW
    =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */

    /**
     *  @notice Withdraw assets from  the Convergence splitter contract.
     *  @param outType Type of token you want to in with with 4 steps  LendAsset >  LendCurveAsset.
     *  @param amount Amount of gUSD token you want to burn.
     */
    function withdrawGUSD(ILlamaVault llamaVault, ILendRewardSplitter.CVX_TOKEN_TYPE outType, uint256 amount) external returns (uint256) {
        require(amount != 0, Errors.ZeroAmount());

        /// @dev Burns the gUSD and withdraw corresponding asset on the user
        return gUSDPerLlamaVault[llamaVault].burn(msg.sender, amount, outType, llamaVault);
    }

    /**
     *  @notice Withdraw assets from  the Convergence splitter contract.
     *  @param llamaVault     LlamaLend vault address
     *  @param outType        Type of token you want to in with with 2 steps  LendAsset >  LendCurveAsset.
     *  @param amount         Amount of scvUsd or shares in autocompound to burn
     *  @param isAutoCompound Type of position to withdraw
     */
    function withdrawSCVUSD(
        ILlamaVault llamaVault,
        ILendRewardSplitter.CVX_TOKEN_TYPE outType,
        uint256 amount,
        bool isAutoCompound
    ) external returns (uint256) {
        require(amount != 0, Errors.ZeroAmount());

        /// @dev If the withdraw is from the autocompounder
        if (isAutoCompound) {
            SplitterTokenComp _autCompound = scvUSDAutoCompoundPerLlamaVault[llamaVault];
            /// @dev We burn the amount of share from the autoCompounder
            /// @dev Also replace 'amount' by the amount of scvUSD equivalent
            amount = _autCompound.burnSplitter(msg.sender, amount);
            /// @dev Burns the scvUSD from the autoCompounder
            scvUSDPerLlamaVault[llamaVault].burn(address(_autCompound), amount);
        } else {
            /// @dev Burns the scvUSD from the user
            scvUSDPerLlamaVault[llamaVault].burn(msg.sender, amount);
        }
        /// @dev Withdraw from gUSD the LlamaVault Lp or LendAsset
        return gUSDPerLlamaVault[llamaVault].withdraw(amount, msg.sender, outType, llamaVault);
    }

    /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
                        CLAIM REWARDS
    =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */
    /**
     *  @notice Claim rewards on one staking contract only
     *  @param splitterToken The erc20 to claim the rewards on
     */
    function claimSimple(address splitterToken) external {
        require(isLendSplitterToken[splitterToken], NotACurveSplitterToken(splitterToken));

        ICommonStruct.TokenAmount[] memory tokenAmounts = ISplitterToken(splitterToken).getAndUpdateRewards(msg.sender);

        require(tokenAmounts.length != 0, NoRewardToSimpleClaim());

        for (uint256 erc20Id; erc20Id < tokenAmounts.length; ) {
            tokenAmounts[erc20Id].token.safeTransfer(msg.sender, tokenAmounts[erc20Id].amount);
            unchecked {
                ++erc20Id;
            }
        }
    }

    /**
     *  @notice Claim rewards on one staking contract only
     *  @param splitterTokens Array of contract to claim the rewards on
     *  @param rewardLength Amount of different tokens to claim as a reward
     */
    function claimMultiple(address[] calldata splitterTokens, uint256 rewardLength) external {
        /// @dev We save this length on his own variable, to not miss with the assembly manipulations
        uint256 lendTokensLength = splitterTokens.length;
        IERC20[] memory tokenList = new IERC20[](lendTokensLength);
        uint256 actualErc20Index;

        /// @dev Iterates through all of the vaults
        for (uint256 splitterTokenIndex; splitterTokenIndex < lendTokensLength; ) {
            address splitterToken = splitterTokens[splitterTokenIndex];
            /// @dev User input verification
            require(isLendSplitterToken[splitterToken], NotACurveSplitterToken(splitterToken));

            /// @dev Get and update the amount of rewards to claim
            ICommonStruct.TokenAmount[] memory tokenAmountsToClaim = ISplitterToken(splitterToken).getAndUpdateRewards(msg.sender);
            /// @dev If the rewards returned by the gUSD is an empty array,
            require(tokenAmountsToClaim.length != 0, NoRewardsToClaimFromContract(address(splitterToken)));

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
            require(rewardLength == actualErc20Index, IncorretRewardLength(rewardLength, actualErc20Index));

            unchecked {
                ++splitterTokenIndex;
            }
        }

        /// @dev Iterate through tokenList
        bool isSomethingToClaim;
        for (uint256 tokenIndex; tokenIndex < tokenList.length; ) {
            IERC20 token = tokenList[tokenIndex];
            uint256 amountClaim = _tLoadUintForAddress(address(token));

            if (amountClaim != 0) {
                isSomethingToClaim = true;
                token.safeTransfer(msg.sender, amountClaim);
                /// @dev Erase transient for the token
                _tStoreUintForAddress(address(token), 0);
            }

            unchecked {
                ++tokenIndex;
            }
        }
        require(isSomethingToClaim, NoRewardToMultiClaim());
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
        require(isLendSplitterToken[msg.sender], CallerNotLendSplitterToken());
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
     * @notice Create several new Market through a Convex vault.
     *         Deploy on the fly the corresponding streamed tokens: scvUSD (stable) & gUSD (governance)
     * @param pids List of pids associated to markets to create
     */
    function createMarkets(uint256[] calldata pids) external onlyOwner {
        for (uint256 pidIndex = 0; pidIndex < pids.length; ) {
            uint256 pid = pids[pidIndex];

            (address _llamaVaultAddr, address cvxVaultToken, , address rewardTokenAddr, , ) = CVX_BOOSTER.poolInfo(pid);
            ILlamaVault _llamaVault = ILlamaVault(_llamaVaultAddr);
            ICvxRewardToken rewardToken = ICvxRewardToken(rewardTokenAddr);

            require(pidPerLlamaVault[_llamaVault] == 0, AlreadyCreatedCvxMarket(pid));

            IERC20 _lendAsset = IERC20(_llamaVault.asset());

            /// @dev Deploy scvUSD (beaconProxy)
            scvUSDCvx _scvUSD = scvUSDCvx(
                address(
                    new BeaconProxy(
                        SCVUSDBeaconCvx,
                        //TODO: Get name of the lend token to personalize name/symbol for gUSD and scvUSD
                        abi.encodeCall(
                            scvUSDCvx.initialize,
                            (owner(), "Stable USD/CRV", "scvUSD-CRV", ILendRewardSplitter(address(this)), _llamaVault, address(rewardToken))
                        )
                    )
                )
            );

            SplitterTokenComp _scvAutoCompound = SplitterTokenComp(
                address(
                    new BeaconProxy(
                        autoCompoundBeacon,
                        //TODO: Get name of the lend token to personalize name/symbol for gUSD and scvUSD
                        abi.encodeCall(SplitterTokenComp.initialize, (owner(), _scvUSD, ILendRewardSplitter(address(this)), _llamaVault, _lendAsset))
                    )
                )
            );

            /// @dev Deploy gUSD (beaconProxy)
            gUSDCvx _gUSD = gUSDCvx(
                address(
                    new BeaconProxy(
                        GUSDBeaconCvx,
                        //TODO: Get name of the lend token to personalize name/symbol for gUSD and scvUSD
                        abi.encodeCall(
                            gUSDCvx.initialize,
                            (
                                owner(),
                                "Governance USD/CRV",
                                "gUSD-CRV",
                                ILendRewardSplitter(address(this)),
                                rewardToken,
                                _llamaVault,
                                IERC20(cvxVaultToken),
                                _scvUSD
                            )
                        )
                    )
                )
            );

            _scvUSD.setAutoCompoundAndGUSD(address(_scvAutoCompound), address(_gUSD));

            _lendAsset.approve(address(_llamaVault), MAX_UINT);
            _llamaVault.approve(address(CVX_BOOSTER), MAX_UINT);

            pidPerLlamaVault[_llamaVault] = pid;
            lentAssetPerLlamaVault[_llamaVault] = _lendAsset;
            rewardTokenPerLlamaVault[_llamaVault] = rewardToken;
            vaultPerLlamaVault[_llamaVault] = IERC20(cvxVaultToken);

            scvUSDPerLlamaVault[_llamaVault] = _scvUSD;
            gUSDPerLlamaVault[_llamaVault] = _gUSD;
            scvUSDAutoCompoundPerLlamaVault[_llamaVault] = _scvAutoCompound;

            isLendSplitterToken[address(_gUSD)] = true;
            isLendSplitterToken[address(_scvUSD)] = true;

            emit CreateMarket(_llamaVault, _scvUSD, _scvAutoCompound, _gUSD);

            unchecked {
                ++pidIndex;
            }
        }
    }

    /**
     * @notice Withdraw all the balance of the desired fees token and erase the corresponding storage.
     * @param tokens IERC20 array to withdraw
     */
    function withdrawFees(IERC20[] calldata tokens) external {
        require(msg.sender == feeTreasury, CallerNotFeeTreasury());
        for (uint256 erc20Id; erc20Id < tokens.length; ) {
            IERC20 erc20 = tokens[erc20Id];
            uint256 feeAmount = daoFeeForToken[erc20];
            require(feeAmount != 0, NoFeesToWithdraw(address(erc20)));
            erc20.transfer(msg.sender, feeAmount);
            delete daoFeeForToken[erc20];
            unchecked {
                ++erc20Id;
            }
        }
    }

    /**
     * @notice Set a new beacon contract used to deploy scvUSD/gUSD tokens
     *         To use only for emergencys.
     * @param _GUSDBeaconCvx address of the new gUSDBeacon
     */
    function setGUSDBeaconCvx(address _GUSDBeaconCvx) external onlyOwner {
        GUSDBeaconCvx = _GUSDBeaconCvx;
    }

    /**
     * @notice Set a new beacon contract used to deploy scvUSD/gUSD tokens
     *         To use only for emergencys.
     * @param _SCVUSDBeaconCvx address of the new cvUSDBeacon
     */
    function setSCVUSDBeaconCvx(address _SCVUSDBeaconCvx) external onlyOwner {
        SCVUSDBeaconCvx = _SCVUSDBeaconCvx;
    }

    /**
     * @notice Allow owner to Add or disable an token in the zapDeposit function
     * @param _token address of the token (  disable the token if call when enable)
     */
    function toggleZapToken(address _token) external onlyOwner {
        bool newIsZapable = !allowedZapToken[_token];

        allowedZapToken[_token] = newIsZapable;

        /// @dev handle the approve for the curve router.
        IERC20(_token).forceApprove(address(CURVE_ROUTER), newIsZapable ? MAX_UINT : 0);

        emit ToggleZapToken(_token, newIsZapable);
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
