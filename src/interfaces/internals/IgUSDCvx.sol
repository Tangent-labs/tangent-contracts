import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ICvxRewardToken} from "../externals/ICvxRewardToken.sol";
import {ILlamaLendVault} from "../externals/ILlamaLendVault.sol";
import {ILendRewardSplitter} from "../internals/ILendRewardSplitter.sol";
import {ICurveLendSplitterToken} from "../internals/ICurveLendSplitterToken.sol";

interface IgUSDCvx is ICurveLendSplitterToken {
    function stakeAll(uint256 pid) external;

    function mint(address receiver, uint256 amount, uint256 pid, bool isStake) external returns (uint256);

    function withdraw(uint256 amount, address receiver, ILendRewardSplitter.CVX_TOKEN_TYPE outType, uint256 pid, ILlamaLendVault llamaVault) external;

    function claimSCVUSDRewards(uint256 shares, ILlamaLendVault llamaVault) external;
}
