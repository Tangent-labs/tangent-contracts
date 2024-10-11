import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {ICommonStruct} from "./ICommonStruct.sol";

interface ISplitterToken is IERC20 {
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

    function getAndUpdateRewards(address account) external returns (ICommonStruct.TokenAmount[] memory);

    function claimableRewards(address account) external view returns (ICommonStruct.TokenAmount[] memory);
    function DENOMINATOR() external view returns (uint256);
}
