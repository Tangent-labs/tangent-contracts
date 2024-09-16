import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {ICvxBooster} from "../externals/ICvxBooster.sol";
import {ICvxRewardToken} from "../externals/ICvxRewardToken.sol";
import {ILlamaLendVault} from "../externals/ILlamaLendVault.sol";
import {IStakeDaoVault} from "../externals/IStakeDaoVault.sol";

import {ILendRewardSplitter} from "../internals/ILendRewardSplitter.sol";
import {ICurveLendSplitterToken} from "../internals/ICurveLendSplitterToken.sol";

interface IgUSDSdt is ICurveLendSplitterToken {
    function withdraw(
        uint256 amount,
        address receiver,
        ILendRewardSplitter.SDT_TOKEN_TYPE outType,
        ILlamaLendVault llamaVault,
        IStakeDaoVault stakeDaoVault
    ) external;

    function claimSCVUSDRewards(uint256 shares, ILlamaLendVault llamaVault) external;
}
