import {ICommonStruct} from "./../ICommonStruct.sol";

interface ISdtStaking {
    struct CycleInfo {
        uint256 cvgRewardsAmount;
        uint256 totalStaked;
        bool isCvxProcessed;
    }

    struct StakingInfo {
        uint256 tokenId;
        string symbol;
        uint256 pending;
        uint256 totalStaked;
        uint256 cvgClaimable;
        ICommonStruct.TokenAmount[] sdtClaimable;
    }

    struct TokenInfo {
        uint256 amountStaked;
        uint256 pendingStaked;
    }

    function acceptOwnership() external;
    function buffer() external view returns (address);
    function claimCvgRewards(uint256 tokenId) external;
    function cvg() external view returns (address);
    function cvgControlTower() external view returns (address);
    function cycleInfo(uint256 cycleId) external view returns (CycleInfo memory);
    function tokenInfoByCycle(uint256 cycleId, uint256 tokenId) external view returns (TokenInfo memory);
    function deposit(uint256 tokenId, uint256 amount, address operator) external;
    function depositPaused() external view returns (bool);
    function getAllClaimableAmounts(uint256 tokenId) external view returns (uint256, ICommonStruct.TokenAmount[] memory);
    function numberOfSdtRewards() external view returns (uint128);
    function owner() external view returns (address);
    function pendingOwner() external view returns (address);
    function processSdtRewards() external;
    function processStakersRewards(uint256 amount) external;
    function renounceOwnership() external;
    function sdtRewardDistributor() external view returns (address);
    function sdtStakingPositionManager() external view returns (address);
    function setBuffer(address _buffer) external;
    function stakedAmountEligibleAtCycle(uint256 _cycleId, uint256 _tokenId, uint256 _actualCycle) external view returns (uint256);
    function stakingAsset() external view returns (address);
    function stakingCycle() external view returns (uint128);
    function stakingHistoryByToken(uint256 tokenId, uint256 index) external view returns (uint256);
    function stakingInfo(uint256 tokenId) external view returns (StakingInfo memory);
    function symbol() external view returns (string memory);
    function toggleDepositPaused() external;
    function tokenToId(address erc20Address) external view returns (uint256);
    function tokenTotalStaked(uint256 _tokenId) external view returns (uint256);
    function transferOwnership(address newOwner) external;
    function vault() external view returns (address);
    function withdraw(uint256 tokenId, uint256 amount) external;
}
