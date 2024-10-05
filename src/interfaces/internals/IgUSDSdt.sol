import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {ICvxBooster} from "../externals/ICvxBooster.sol";
import {ICvxRewardToken} from "../externals/ICvxRewardToken.sol";
import {ILlamaVault} from "../externals/ILlamaVault.sol";
import {IStakeDaoVault} from "../externals/IStakeDaoVault.sol";

import {ILendRewardSplitter} from "../internals/ILendRewardSplitter.sol";
import {ISplitterToken} from "../internals/ISplitterToken.sol";

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
