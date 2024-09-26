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

    function burn(address from, uint256 amount) external;

    function getAndUpdateRewards(address account) external returns (ICommonStruct.TokenAmount[] memory);

    function claimableRewards(address account) external view returns (ICommonStruct.TokenAmount[] memory);

    function processRewards() external;
}
