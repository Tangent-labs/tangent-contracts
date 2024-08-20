import {ISDLiquidityGauge} from "./ISDLiquidityGauge.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface ILendRewardSplitter {
    function liquidityGauge() external view returns (ISDLiquidityGauge);

    function updateDaoFees(
        IERC20[] memory tokens,
        uint256[] memory amounts
    ) external;

    function approveGovReward(IERC20 token) external;
}
