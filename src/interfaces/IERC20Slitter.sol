import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";

interface IERC20Splitter is IERC20 {
    function burn(address _account, uint _amount) external;
    function mintFrom(
        address from,
        address to,
        uint256 amount
    ) external returns (uint256);
}
