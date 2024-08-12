import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {CurveLendSplitterToken} from "./CurveLendSplitterToken.sol";
//import {ICurveLendSplitterToken} from "../interfaces/ICurveLendSplitterToken.sol";

contract TokensvcUSD is CurveLendSplitterToken {
    using SafeERC20 for IERC20;

    constructor(
        string memory _collateral,
        address _lpToken
    )
        CurveLendSplitterToken(
            string.concat("TokenScvUsd-", _collateral),
            string.concat("svcUSD-", _collateral),
            _lpToken
        )
    {}
}
