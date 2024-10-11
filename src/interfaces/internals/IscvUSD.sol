import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {ISplitterToken} from "../internals/ISplitterToken.sol";

interface IscvUSD is ISplitterToken {
    function mintSplitter(address to, uint256 amount) external;

    function mintAutoCompound(uint256 amount) external;

    function burn(address from, uint256 amount) external;

    function processRewards() external;
}
