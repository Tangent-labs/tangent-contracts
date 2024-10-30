import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IOperator {
    function token() external view returns (IERC20);

    function deposit(uint256 amount, bool isLock, bool isStake, address receiver) external;

    function lockIncentivePercent() external view returns (uint256);

    function incentiveToken() external view returns (uint256);
}
