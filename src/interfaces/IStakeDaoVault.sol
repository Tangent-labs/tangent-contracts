import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IStakeDaoVault is IERC20 {
    function DENOMINATOR() external view returns (uint256);
    function DOMAIN_SEPARATOR() external view returns (bytes32 result);
    function EARN_INCENTIVE_FEE() external view returns (uint256);
    function allowance(
        address owner,
        address spender
    ) external view returns (uint256 result);
    function approve(address spender, uint256 amount) external returns (bool);
    function balanceOf(address owner) external view returns (uint256 result);
    function decimals() external view returns (uint8);

    function deposit(address _receiver, uint256 _amount, bool _doEarn) external;

    function incentiveTokenAmount() external view returns (uint256);
    function initialize() external;
    function liquidityGauge() external pure returns (address _liquidityGauge);
    function name() external view returns (string memory);
    function nonces(address owner) external view returns (uint256 result);
    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;
    function strategy() external pure returns (address _strategy);
    function symbol() external view returns (string memory);
    function token() external pure returns (address _token);
    function totalSupply() external view returns (uint256 result);
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external returns (bool);
    function withdraw(uint256 _shares) external;
}
