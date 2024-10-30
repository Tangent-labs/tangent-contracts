interface ICvxStaking {
    function CVG() external view returns (address);
    function CVX() external view returns (address);
    function acceptOwnership() external;
    function accountInfoByCycle(uint256, address) external view returns (uint256 amountStaked, uint256 pendingStaked);
    function allowance(address _owner, address _spender) external view returns (uint256);
    function allowances(address, address) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function asset() external view returns (address);
    function balanceOf(address account) external view returns (uint256);
    function buffer() external view returns (address);
    function claimCvgCvxRewards(address account, uint256 _minCvgCvxAmountOut, bool _isConvert) external;
    function claimCvgRewards(address account) external;
    function curvePool() external view returns (address);
    function cvgCVX() external view returns (address);
    function cvgControlTower() external view returns (address);
    function cvx1() external view returns (address);
    function cvxRewardDistributor() external view returns (address);
    function cvxRewardsByCycle(uint256, uint256) external view returns (address token, uint256 amount);
    function cycleInfo(uint256) external view returns (uint256 cvgRewardsAmount, uint256 totalStaked, bool isCvxProcessed);
    function decimals() external view returns (uint256);
    function deposit(uint256 amountIn, uint8 inTokenType, uint256 minCvgCvxAmountOut, uint256 minCvxAmountOut, bool isLock) external;
    function depositCvxRush(uint256 cvxAmountIn, uint256 minCvxAmountOut, bool isLock, uint256 tokenIdCvxRush) external;
    function depositPaused() external view returns (bool);

    function getHistoryLengthForAccount(address account) external view returns (uint256);

    function nextClaims(address) external view returns (uint128 nextClaimableCvg, uint128 nextClaimableCvx);
    function numberOfUnderlyingRewards() external view returns (uint128);
    function owner() external view returns (address);
    function pendingOwner() external view returns (address);
    function poolEthInfo() external view returns (uint8 poolType, address poolCurve, uint88 fee, address token, uint48 indexEth, uint48 indexAsset);
    function processCvxRewards() external;
    function processStakersRewards(uint256 amount) external;
    function setBuffer(address _buffer) external;
    function stakedAmountEligibleAtCycle(uint256 _cycleId, address account, uint256 _actualCycle) external view returns (uint256);
    function stakingCycle() external view returns (uint128);
    function stakingHistoryByAccount(address, uint256) external view returns (uint256);

    function toggleDepositPaused() external;
    function tokenToId(address) external view returns (uint256);
    function totalSupply() external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function transferOwnership(address newOwner) external;
    function withdraw(uint256 amount, uint8 tokenType, uint256 minCvx1AmountOut) external;
}
