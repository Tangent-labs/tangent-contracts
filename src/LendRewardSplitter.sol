// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {BeaconProxy} from "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ICurveLendVault} from "./interfaces/ICurveLendVault.sol";
import {IStakeDaoVault} from "./interfaces/IStakeDaoVault.sol";
import {ICrvPoolPlain} from "./interfaces/ICrvPoolPlain.sol";
import {ISDLiquidityGauge} from "./interfaces/ISDLiquidityGauge.sol";
import {IWETH} from "./interfaces/IWETH.sol";
import {CurveLendSplitterToken} from "./tokens/CurveLendSplitterToken.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import{OwnableUpgradeable} from  "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract LendRewardSplitter is Ownable2StepUpgradeable { 
    
    
    IWETH private constant WETH = IWETH(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    address private constant USDT = 0xdAC17F958D2ee523a2206206994597C13D831ec7; // USDT contract address
    ICrvPoolPlain private constant TRYCRYTO2_CURVE_POOL = ICrvPoolPlain(0xd51a44d3fae010294c616388b506acda1bfaae46); // Curve 3pool contract address
    ICrvPoolPlain public constant USDT_CRVUSD_CURVE_POOL = ICrvPoolPlain(0x4dece678ceceb27446b35c672dc7d61f30bad69e); // Curve USDT/crvUSD pool contract address
    address public constant CRVUSD = 0x1234567890abcdef1234567890abcdef12345678; // Replace with actual crvUSD token address


    using SafeERC20 for IERC20;
    using SafeERC20 for ICurveLendVault;

    uint256 constant MAX_UINT = uint256(int256(-1));
    uint256 constant TOKENS_TO_CLAIM_SLOT = 0;
   
    mapping(address => uint256) /* transient */ tokensToClaim;

    address public beaconCurveLendSplitterToken;
    mapping(IERC20 => uint256) public daoFeeForToken;
    mapping(address => MarketStruct) public markets;
    mapping(address => bool) public isSpecialUpdater;
    /// @dev Token allowed in the zap function, each token is associated with is curve pool. 
    mapping(IERC20 => ICrvPoolPlain) public zapPools;

    struct MarketStruct {
        IStakeDaoVault stakeDaoVault;
        ICurveLendVault curveLendVault;
        ISDLiquidityGauge liquidityGauge;
        IERC20 lendAsset;
        CurveLendSplitterToken gUSD;
        CurveLendSplitterToken scvUSD;
    }

    event Deposit(address indexed account, bool isStableReward, uint256 amount);
    event Withdraw(address indexed account, bool isStableReward, TOKEN_TYPE outType, uint256 amount);
    event RewardWithdraw(address market,uint256 amount);
    event zapPoolChange(address token,address pool);

    enum TOKEN_TYPE {
        /// @dev Asset use as collateral in the lend contract. (ex : crvUSD)
        LendAsset,
        /// @dev share of  curve vault contract. (ex : cvcrvUSD)
        LendCurveAsset,
        /// @dev share of  curve vault contract. (ex : sdcvcrvUSD)
        LendStakeDaoAsset
    }


    error WrongCaller();
    error EmptyAmount();
    error NoZeroAddress(string parameters);
    error MarketNotExists(address requestedMarket);
    error TokenNotAllowed();

    error MinAmountNotMet();

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

     /**
     *  @notice zapAndDeposit zap the given asset into lendAsset and use the deposit function.
     *  @param stakeDaoVault Market to deposit to
     *  @param tokenIn Address  to zap to the lendAsset token (can be 0x0 if ETH is sent) 
     *  @param inAmout Amount  of {toklenIn} token you want to deposit. (can be 0 if ETH is sent) )
     *  @param minLendAssetAmount min amount of {lendasset token } accpeted for the {inAmout} of {inTOken}
     *  @param isStableReward   IF isStableReward == true THEN   you want the stable part of the reward  ELSE you want the gauge part of the reward.
     *  @param doDeposit  IF doDeposit == true THEN  all the pending asset will be deposited in stakeValut.
     */
    function zapAndDeposit(address stakeDaoVault , address tokenIn, uint256 inAmout, uint256 minLendAssetAmount,
    bool isStableReward,bool doDeposit) public payable
        returns (uint256){
        /// @dev find the matching market.
        MarketStruct memory market = markets[stakeDaoVault];
        if(address(market.stakeDaoVault)!=stakeDaoVault)
            revert MarketNotExists(stakeDaoVault);

        /// @dev Check amounts.
        uint256 ethAmount = msg.value;
        if(ethAmount + inAmout == 0)
            revert EmptyAmount();

        /// @dev Check token.
        if(inAmout>0 && address(zapPools[IERC20(tokenIn)])==address(0))
            revert TokenNotAllowed();

        /// @dev Process ETH.
        uint256 lendAssetFromEth =0;
        if(ethAmount>0)
           lendAssetFromEth =  _zapEth(ethAmount);

        /// @dev Process Token.
        uint256 lendAssetFromToken =0;
        if(inAmout>0)
           lendAssetFromToken = _zapToken(tokenIn,inAmout);

        /// @dev Check mint amount.
        if(lendAssetFromEth+lendAssetFromToken < minLendAssetAmount )
            revert MinAmountNotMet();

        /// @dev Continue deposit.
        return  deposit(stakeDaoVault, TOKEN_TYPE.LendAsset, lendAssetFromToken + lendAssetFromEth, isStableReward, doDeposit);
    
      }

    /**
     *  @notice Deposit asset into the Convergence splitter contract in order to get one part of the reawrd from the lend contract.
     *  @param stakeDaoVault Market to deposit to
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
        if(address(market.stakeDaoVault)!=stakeDaoVault )
            revert MarketNotExists(stakeDaoVault);


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
    

    function withdrawForRewards(address _market,uint256 _amount) external {

        /// @dev We get the market from the mapping.
        MarketStruct memory  market = markets[_market];
        if (address(market.lendAsset) == address(0)) revert MarketNotExists(_market);

        /// @dev We check that the method is call via processStableReward on the scvUSD.
         if(msg.sender != address(market.scvUSD))
            revert WrongCaller();

        /// @dev We redeem the {lendAsset} and update the balance of the scvUSD.
        _withdraw(market, TOKEN_TYPE.LendAsset, _amount, true);
         emit RewardWithdraw(_market,_amount);
      
    }


    /**
     *  @notice Withdraw assets from  the Convergence splitter contract. 
        @param _market StakeDao valut for the requested market.
     *  @param outType Type of token you want to in with with 4 steps  LendAsset >  LendCurveAsset.
     *  @param amount Amount  of {gUSD|scvUsd} token you want to withdraw.
     *  @param isStableReward  If isStableReward == true THEN   scvUsd of user is used   ELSE  gUSD of user is used.
     */
    function withdraw(address _market, TOKEN_TYPE outType, uint256 amount, bool isStableReward) public {
        /// @dev We check the prerequesite.
        require(amount != 0, "WITHDRAW_LTE_0");

        MarketStruct memory market = markets[_market];

        CurveLendSplitterToken recipeToken = isStableReward ? market.scvUSD : market.gUSD;
        require(amount <= recipeToken.balanceOf(msg.sender), "NOT_ENOUGH_BALANCE");

        /// @dev We burn the corresponding token.
        recipeToken.burn(msg.sender, amount);

        _withdraw(market,outType,amount,isStableReward);
       
        emit Withdraw(msg.sender, isStableReward, outType, amount);
    }

    function _withdraw(MarketStruct memory market, TOKEN_TYPE outType, uint256 amount, bool isStableReward) internal {
        /// @dev We process the amounts.
        uint256 shareAmount = isStableReward ? amount : market.curveLendVault.convertToShares(amount);

        if (outType == TOKEN_TYPE.LendStakeDaoAsset) {
            /// @dev we transfer the stake share to the user.
             IERC20(address(market.liquidityGauge)).safeTransfer(msg.sender, shareAmount);
        } else {
            /// @dev We withdraw the share from stakeDAO vault.
            market.stakeDaoVault.withdraw(shareAmount);
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
    }


    //TODO: notice
    function claimSimple(address stakeDaoVault, bool isGovRewards, address claimer) external {
        CurveLendSplitterToken.TokenAmount[] memory tokenAmounts = isGovRewards
            ? markets[stakeDaoVault].gUSD.getReward(claimer)
            : markets[stakeDaoVault].scvUSD.getReward(claimer);

        require(tokenAmounts.length != 0, "NOTHING_TO_CLAIM");

        for (uint256 i; i < tokenAmounts.length; ) {
            tokenAmounts[i].token.safeTransfer(claimer, tokenAmounts[i].amount);
            unchecked {
                ++i;
            }
        }
    }

    /// QUESTION: Reward receiver can be different on multiple stakings,
    /// so are we allowing the rewards redirection to always do the safeTransfer to the same receiver ?

    

    function claimMultiple(address[] memory stakeDaoVaults, address claimer) external {
        /// @dev We save this length on his own variable, to not miss with the assembly manipulations
        uint256 stakeDaoVaultsLength = stakeDaoVaults.length;
        address[] memory tokenList;
        uint256 tokenListLength;
        for (uint256 i; i < stakeDaoVaultsLength; ) {
            //gUSD rewards
            CurveLendSplitterToken.TokenAmount[] memory tokenAmounts = markets[stakeDaoVaults[i]].gUSD.getReward(
                claimer
            );
            require(tokenAmounts.length != 0, "VAULT_HAS_NOTHING_TO_CLAIM");
            for (uint256 x; x < tokenAmounts.length; ) {
                address tokenAddress = address(tokenAmounts[x].token);
                /// @dev If token is seen the first time (tokensToClaim[token] == 0)
                if (_tloadMapping(tokenAddress) == 0) {
                    /// @dev Increment tokenList length & add new token on new index
                    _incrementArrayMemory(tokenList, tokenAddress, tokenListLength++);
                }
                /// @dev Increment mapping
                _tStoreMappingIncrement(tokenAddress, tokenAmounts[x].amount);
                unchecked {
                    ++x;
                }
            }

            //TODO: scvUSD rewards
            // markets[vaults[i]].scvUSD.getReward(claimer)
            unchecked {
                ++i;
            }
        }

        /// @dev Iterate through tokenList
        bool isClaim;
        for (uint256 i; i < tokenList.length; ) {
            uint256 amountClaim = _tloadMapping(tokenList[i]);
            if (amountClaim != 0) {
                isClaim = true;
                /// @dev Transfer sum of token to user
                /// TODO: redirect rewards ???
                IERC20(tokenList[i]).safeTransfer(claimer, amountClaim);
                /// @dev Erase transient mapping key
                _tStoreMappingRemove(tokenList[i]);
            }

            unchecked {
                ++i;
            }
        }
        require(isClaim, "NOTHING_TO_CLAIM");
        /// @dev Et voilà, mon nom Borat !
    }

    /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
                            INTERNALS
    =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */
    function _tStoreMappingIncrement(address key, uint256 value) internal {
        bytes32 location = keccak256(abi.encode(key, TOKENS_TO_CLAIM_SLOT));
        assembly {
            let exValue := tload(location)
            tstore(location, add(value, exValue))
        }
    }
    function _tloadMapping(address key) internal view returns (uint256 ret) {
        bytes32 location = keccak256(abi.encode(key, TOKENS_TO_CLAIM_SLOT));
        assembly {
            ret := tload(location)
        }
    }
    function _tStoreMappingRemove(address key) internal {
        bytes32 location = keccak256(abi.encode(key, TOKENS_TO_CLAIM_SLOT));
        assembly {
            tstore(location, 0)
        }
    }
    function _incrementArrayMemory(
        address[] memory tokenList,
        address tokenAddress,
        uint256 currentLen
    ) internal pure returns (address[] memory) {
        assembly {
            // Calculate the new length
            let newLen := add(currentLen, 1)

            // Update the length in memory
            mstore(tokenList, newLen)

            // Calculate the position for the new element
            let elementPtr := add(add(tokenList, 0x20), mul(currentLen, 0x20))

            // Store the new value in the calculated position
            mstore(elementPtr, tokenAddress)
        }

        // Return the modified array
        return tokenList;
    }

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


    function _zapEth(uint256 ethAmount) internal returns(uint256 lendAssetAmount){

        /// @dev : convert ETH =>  WETH 
        WETH.deposit{value: ethAmount}();

        /// @dev : WETH =>  USDT with 3Crypto pool
        WETH.approve(address(TRYCRYTO2_CURVE_POOL), msg.value);
        uint256 usdtAmount = TRYCRYTO2_CURVE_POOL.exchange(0, 2, ethAmount, 0);

        /// @dev :  USDT =>  crvUSD 
        IERC20(USDT).approve(address(USDT_CRVUSD_CURVE_POOL), usdtAmount);
        lendAssetAmount=  USDT_CRVUSD_CURVE_POOL.exchange(0, 1, usdtAmount, 0);

    }

    function _zapToken(address token, uint256 amount) internal returns(uint256 lendAssetAmount){
        /// @dev transfer token to this contract.
        IERC20(token).safeTransferFrom(msg.sender, address(this),amount);
      
        /// @dev : swap for lendAsset
        ICrvPoolPlain curvePool = zapPools[token];
        lendAssetAmount = curvePool.exchange(0, 1, amount, 0, address(this));
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
                            UPDATER
   =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */
    /**
     * @notice Increment dao fees that will be transferred in this contract during a process rewards.
     *         This function is only callable by an updater (scvUSD or gUSD).
     * @param tokens array of token to update
     * @param amounts array of amount to update
     */
    function updateDaoFees(IERC20[] memory tokens, uint256[] memory amounts) external {
        require(isSpecialUpdater[msg.sender], "NOT_UPDATER");
        for (uint256 i; i < tokens.length; ) {
            daoFeeForToken[tokens[i]] += amounts[i];
            unchecked {
                ++i;
            }
        }
    }

    /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
                            OWNER
   =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */

    /**
     * @notice Create a new Market through a StakeDao vault (only for collatered vaults).
     *         Deploy on the fly the corresponding streamed tokens: scvUSD (stable) & gUSD (governance)
     * @param stakeDaoVault address
     */
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
                        ("Governance USD/CRV", "gUSD-CRV", address(this), address(_liquidityGauge),true)
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
                        ("Stable USD/CRV", "scvUSD-CRV",  address(this), address(_liquidityGauge),false)
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
            stakeDaoVault : _stakeDaoVault,
            curveLendVault: _curveLendVault,
            liquidityGauge: _liquidityGauge,
            lendAsset: _lendAsset,
            gUSD: _gUSD,
            scvUSD: _scvUSD
        });

        /// @dev WL gUSD as an special updater
        isSpecialUpdater[address(_gUSD)] = true;
        isSpecialUpdater[address(_scvUSD)] = true;
    }

    /**
     * @notice Withdraw all the balance of the desired fees token and erase the corresponding storage.
     * @param tokens IERC20 array to withdraw
     */
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

    /**
     * @notice Set a new beacon contract used to deploy scvUSD/gUSD tokens
     *         To use only for emergencys.
     * @param _beaconCurveLendSplitterToken address of the new beacon
     */
    function setBeaconCurveLendSplitterToken(address _beaconCurveLendSplitterToken) external onlyOwner {
        beaconCurveLendSplitterToken = _beaconCurveLendSplitterToken;
    }

    /**
     * @notice Allow owner to Add or disable an token in the zapDeposit function     
     * @param _token address of the token 
     * @param _pool address of the curve pool (can be set to 0x0 to disable this toekn in zapDeposit)
     */
    function addZapPool(address _token , address _pool) external onlyOwner{
        if(_token==address(0))
            revert NoZeroAddress('_token');

        zapPools[IERC20(_token)] = ICrvPoolPlain(_pool);
        emit zapPoolChange(_token,_pool);

    }
}
