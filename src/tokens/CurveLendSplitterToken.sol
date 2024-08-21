import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IStakeDaoVault} from "../interfaces/IStakeDaoVault.sol";

contract CurveLendSplitterToken is ERC20, Ownable {
    using SafeERC20 for IERC20;
    uint256 MAX_INT = uint256(int256(-1));
    IStakeDaoVault public lpToken;

    constructor(
        string memory _name,
        string memory _symbol,
        address _lpToken
    ) ERC20(_name, _symbol) Ownable(msg.sender) {
        lpToken = IStakeDaoVault(_lpToken);
    }

    /** Determines address allowed to mint/burn. */
    address public splitterContract;

    /**
     *   @notice        Mint gUSD
     *   @param to      Receiver of the minted token
     *   @param amount  Amount of transfered asset.
     **/
    function mint(address to, uint256 amount) public returns (uint256) {
        require(msg.sender == splitterContract, "CALLER_NOT_SPLITTER");
        _mint(to, amount);
        return amount;
    }

    /**
     *   @notice        Burn  gUSD
     *   @param account Owner of the burnt token
     *   @param amount  Amount of  asset to burn .
     **/
    function burn(address account, uint amount) external {
        require(msg.sender == splitterContract, "CALLER_NOT_SPLITTER");
        _burn(account, amount);
    }

    /**
     * @notice set the contract allow to mint/burn
     * @dev Callable by the owner only.
     * @param _splitterContract  Splitter contract allowed to mint.
     **/
    function setSplitterContract(address _splitterContract) external onlyOwner {
        splitterContract = _splitterContract;
    }
}
