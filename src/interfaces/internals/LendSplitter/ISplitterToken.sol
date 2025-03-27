// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {TokenAmount} from "../ICommonStruct.sol";
import {ILlamaVault} from "../../externals/LlamaLend/ILlamaVault.sol";

interface ISplitterToken is IERC20 {
    struct Reward {
        uint128 lastUpdateTime;
        uint128 periodFinish;
        uint256 rewardRate;
        uint256 rewardPerTokenStored;
    }

    struct Fees {
        uint128 processorFeePercentage;
        uint128 daoFeePercentage;
    }

    function getAndUpdateRewards(address account) external returns (TokenAmount[] memory);

    function claimableRewards(address account) external view returns (TokenAmount[] memory);
    function DENOMINATOR() external view returns (uint256);

    function rewardData(IERC20 erc20) external view returns (uint128 lastUpdateTime, uint128 periodFinish, uint256 rewardRate, uint256 rewardPerTokenStored);

    function llamaVault() external view returns (ILlamaVault);

    function rewardTokens(uint256 index) external view returns (IERC20);
}
