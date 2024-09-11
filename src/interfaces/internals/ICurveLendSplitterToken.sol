import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {ICommonStruct} from "./ICommonStruct.sol";

interface ICurveLendSplitterToken is IERC20 {
    struct Reward {
        uint128 lastUpdateTime;
        uint128 periodFinish;
        uint256 rewardRate;
        uint256 rewardPerTokenStored;
    }

    struct Fees {
        uint128 processorFeePercentage;
        uint128 daoFeePercentage;
    }

    function mint(address to, uint256 amount) external returns (uint256);

    function burn(address from, uint256 amount) external;

    function getAndUpdateRewards(address account) external returns (ICommonStruct.TokenAmount[] memory);

    function rewardData(IERC20) external view returns (Reward memory);

    function addReward(IERC20 _rewardToken) external;

    function notifyRewardAmount(IERC20 _rewardToken, uint256 _reward) external;

    function notifyRewards(IERC20[] memory _rewardTokens, uint256[] memory _rewards) external;
}
