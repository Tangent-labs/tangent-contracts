import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/interfaces/IERC20.sol";

import {CurveLendSplitterToken} from "./CurveLendSplitterToken.sol";
//import {ICurveLendSplitterToken} from "../interfaces/ICurveLendSplitterToken.sol";

contract TokengUsd is CurveLendSplitterToken {
    using SafeERC20 for IERC20;

    constructor(
        string memory _collateral,
        address _lpToken
    )
        CurveLendSplitterToken(
            string.concat("TokengUsd-", _collateral),
            string.concat("gUSD-", _collateral),
            _lpToken
        )
    {}
}
