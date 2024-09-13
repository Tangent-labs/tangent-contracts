import {ISDLiquidityGauge} from "./ISDLiquidityGauge.sol";
import {ICurveLendVault} from "./ICurveLendVault.sol";
import {IStakeDaoVault} from "./IStakeDaoVault.sol";
import {ICurveLendSplitterToken} from "./ICurveLendSplitterToken.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface ILendRewardSplitter {
    struct MarketStruct {
        IStakeDaoVault stakeDaoVault;
        ICurveLendVault curveLendVault;
        ISDLiquidityGauge liquidityGauge;
        IERC20 lendAsset;
        IERC20 gUSD;
        IERC20 scvUSD;
    }

    function liquidityGauge() external view returns (ISDLiquidityGauge);

    function updateDaoFees(IERC20[] memory tokens, uint256[] memory amounts) external;

    function withdrawForRewards(address _market, uint256 _amount) external;

    function getMarket(address _market) external returns (MarketStruct memory);
}
