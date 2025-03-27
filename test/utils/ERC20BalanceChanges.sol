import {Test} from "forge-std/Test.sol";
import "forge-std/console.sol";
import {IERC20Metadata, IERC20} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {TokenAmount} from "../../src/interfaces/internals/ICommonStruct.sol";

contract ERC20BalanceChanges {
    mapping(address => TokenAmount[]) public tokenReceived;
    mapping(address => TokenAmount[]) public tokenSent;

    function getErc20Balances(address account, IERC20[] calldata tokens) external view returns (TokenAmount[] memory) {
        uint256 len = tokens.length;
        TokenAmount[] memory bals = new TokenAmount[](len);

        for (uint256 index = 0; index < tokens.length; index++) {
            IERC20 token = tokens[index];
            bals[index] = TokenAmount({token: token, amount: token.balanceOf(account)});
        }

        return bals;
    }

    function trackReceiveERC20(address account, IERC20[] calldata tokens) external {
        for (uint256 index = 0; index < tokens.length; index++) {
            IERC20 token = tokens[index];
            tokenReceived[account].push(TokenAmount({token: token, amount: token.balanceOf(account)}));
        }
    }

    function trackSentERC20(address account, IERC20[] memory tokens) external {
        for (uint256 index = 0; index < tokens.length; index++) {
            IERC20 token = tokens[index];
            tokenSent[account].push(TokenAmount({token: token, amount: token.balanceOf(account)}));
        }
    }

    function getReceivedERC20(address account) external returns (TokenAmount[] memory) {
        uint256 len = tokenReceived[account].length;
        TokenAmount[] memory balChange = new TokenAmount[](len);
        for (uint256 index = 0; index < len; index++) {
            IERC20 token = tokenReceived[account][index].token;
            balChange[index] = TokenAmount({token: token, amount: token.balanceOf(account) - tokenReceived[account][index].amount});
        }
        delete tokenReceived[account];
        return balChange;
    }

    function getSentERC20(address account) external returns (TokenAmount[] memory) {
        uint256 len = tokenSent[account].length;
        TokenAmount[] memory balChange = new TokenAmount[](len);
        for (uint256 index = 0; index < len; index++) {
            IERC20 token = tokenSent[account][index].token;
            balChange[index] = TokenAmount({token: token, amount: tokenSent[account][index].amount - token.balanceOf(account)});
        }
        delete tokenSent[account];
        return balChange;
    }

    function areTokenAmountsArrayEquals(TokenAmount[] memory arr1, TokenAmount[] memory arr2) external pure returns (bool) {
        for (uint256 index = 0; index < arr1.length; index++) {
            if (arr1[index].token != arr2[index].token || arr1[index].amount != arr2[index].amount) {
                return false;
            }
        }
        return true;
    }
}
