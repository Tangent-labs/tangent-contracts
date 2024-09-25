import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {ICurveLendSplitterToken} from "../internals/ICurveLendSplitterToken.sol";

interface IscvUSD is ICurveLendSplitterToken {
    function setGUSD(address _gUSD) external;

    function getStreamableShares() external view returns(uint256);
}
