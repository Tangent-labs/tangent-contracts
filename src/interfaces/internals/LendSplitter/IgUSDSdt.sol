import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {ICvxBooster} from "../../externals/Convex/ICvxBooster.sol";
import {ICvxRewardToken} from "../../externals/Convex/ICvxRewardToken.sol";
import {ILlamaVault} from "../../externals/LlamaLend/ILlamaVault.sol";
import {IStakeDaoVault} from "../../externals/StakeDao/IStakeDaoVault.sol";

import {ILendRewardSplitter} from "./ILendRewardSplitter.sol";
import {ISplitterToken} from "./ISplitterToken.sol";

interface IgUSDSdt is ISplitterToken {
    function withdraw(
        uint256 amount,
        address receiver,
        ILendRewardSplitter.SDT_TOKEN_TYPE outType,
        ILlamaVault llamaVault,
        IStakeDaoVault stakeDaoVault
    ) external;

    function claimSCVUSDRewards(uint256 shares, ILlamaVault llamaVault) external;
}
