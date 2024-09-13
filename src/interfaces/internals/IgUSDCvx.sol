import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ICvxBooster} from "../externals/ICvxBooster.sol";
import {ICvxRewardToken} from "../externals/ICvxRewardToken.sol";
import {ILlamaLendVault} from "../externals/ILlamaLendVault.sol";
import {ILendRewardSplitter} from "../internals/ILendRewardSplitter.sol";
import {ICurveLendSplitterToken} from "../internals/ICurveLendSplitterToken.sol";

interface IgUSDCvx is ICurveLendSplitterToken {
    function depositAndStake(ICvxRewardToken _cvxRewardToken, uint256 pid, uint256 depositedAmount) external returns (uint256);

    function depositNoStake(IERC20 _cvxVault, uint256 pid, uint256 depositedAmount) external returns (uint256);

    function withdraw(uint256 amount, address receiver, ILendRewardSplitter.CVX_TOKEN_TYPE outType, ILlamaLendVault llamaVault) external;

    function claimSCVUSDRewards(uint256 amount, ILlamaLendVault llamaVault) external;
}
