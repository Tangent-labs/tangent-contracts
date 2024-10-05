import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ICvxRewardToken} from "../externals/ICvxRewardToken.sol";
import {ILlamaVault} from "../externals/ILlamaVault.sol";
import {ILendRewardSplitter} from "../internals/ILendRewardSplitter.sol";
import {ISplitterToken} from "../internals/ISplitterToken.sol";

interface IgUSDCvx is ISplitterToken {
    function stakeAll(uint256 pid) external;

    function mint(address receiver, uint256 amount, ILlamaVault llamaVault, uint256 pid, bool isStake) external returns (uint256);

    function withdraw(uint256 amount, address receiver, ILendRewardSplitter.CVX_TOKEN_TYPE outType, ILlamaVault llamaVault) external returns (uint256);

    function burn(address from, uint256 amount, ILendRewardSplitter.CVX_TOKEN_TYPE outType, ILlamaVault llamaVault) external returns (uint256);
}
