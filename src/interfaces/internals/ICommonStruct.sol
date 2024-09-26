import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface ICommonStruct {
    struct TokenAmount {
        IERC20 token;
        uint256 amount;
    }
}
