interface ICrvStrategy {
    function DENOMINATOR() external view returns (uint256);

    function SDTDistributor() external view returns (address);

    function acceptGovernance() external;

    function acceptRewardDistributorOwnership(address rewardDistributor) external;

    function accumulator() external view returns (address);

    function addRewardReceiver(address gauge, address rewardReceiver) external;

    function addRewardToken(address gauge, address extraRewardToken) external;

    function allowAddress(address _address) external;

    function allowed(address) external view returns (bool);

    function balanceOf(address asset) external view returns (uint256 _balanceOf);

    function claimIncentiveFee() external view returns (uint256);

    function claimNativeRewards() external;

    function claimProtocolFees() external;

    function deposit(address asset, uint256 amount) external;

    function disallowAddress(address _address) external;

    function execute(address to, uint256 value, bytes memory data) external returns (bool, bytes memory);

    function factory() external view returns (address);

    function feeDistributor() external view returns (address);

    function feeReceiver() external view returns (address);

    function feeRewardToken() external view returns (address);

    function feesAccrued() external view returns (uint256);

    function futureGovernance() external view returns (address);

    function gauges(address) external view returns (address);

    function getVersion() external pure returns (string memory);

    function governance() external view returns (address);

    function harvest(address asset, bool distributeSDT, bool claimExtra) external;

    function harvest(address asset, bool distributeSDT, bool claimExtra, bool claimFallbacksRewards) external;

    function initialize(address owner) external;

    function lGaugeType(address) external view returns (uint256);

    function locker() external view returns (address);

    function migrateLP(address asset) external;

    function minter() external view returns (address);

    function optimizer() external view returns (address);

    function protocolFeesPercent() external view returns (uint256);

    function proxiableUUID() external view returns (bytes32);

    function rebalance(address asset) external;

    function rewardDistributors(address) external view returns (address);

    function rewardReceivers(address) external view returns (address);

    function rewardToken() external view returns (address);

    function setAccumulator(address newAccumulator) external;

    function setFactory(address _factory) external;

    function setFeeDistributor(address newFeeDistributor) external;

    function setFeeReceiver(address _feeReceiver) external;

    function setFeeRewardToken(address newCurveRewardToken) external;

    function setGauge(address token, address gauge) external;

    function setLGtype(address gauge, uint256 gaugeType) external;

    function setOptimizer(address _optimizer) external;

    function setRewardDistributor(address gauge, address rewardDistributor) external;

    function setSdtDistributor(address newSdtDistributor) external;

    function toggleVault(address vault) external;

    function transferGovernance(address _governance) external;

    function updateClaimIncentiveFee(uint256 _claimIncentiveFee) external;

    function updateProtocolFee(uint256 protocolFee) external;

    function upgradeToAndCall(address newImplementation, bytes memory data) external;

    function vaults(address) external view returns (bool);

    function veToken() external view returns (address);

    function withdraw(address asset, uint256 amount) external;
}
