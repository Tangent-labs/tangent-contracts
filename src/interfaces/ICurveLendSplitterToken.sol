import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";

interface ICurveLendSplitterToken is IERC20 {
    function mint(address to, uint256 amount) external returns (uint256);
    function setSplitterContract(address _splitterContract) external;
    function burn(address _account, uint _amount) external;
}
