import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IOperator} from "./IOperator.sol";

interface ISdAsset is IERC20 {
    function sdAssetGauge() external view returns (IERC20);

    function setSdAssetBuffer(address _sdAssetBuffer) external;

    function mint(address to, uint256 amount) external;

    function operator() external view returns (IOperator);
}
