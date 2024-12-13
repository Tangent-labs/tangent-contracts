// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import {ICommonStruct} from "./../ICommonStruct.sol";
interface ISdtBuffer {
    function acceptOwnership() external;
    function cvgControlTower() external view returns (address);
    function gaugeAsset() external view returns (address);
    function initialize(address _cvgControlTower, address _sdtStaking, address _gaugeAsset, address _sdt) external;
    function owner() external view returns (address);
    function pendingOwner() external view returns (address);
    function processorRewardsPercentage() external view returns (uint256);
    function pullRewards(address processor) external returns (ICommonStruct.TokenAmount[] memory);
    function renounceOwnership() external;
    function sdt() external view returns (address);
    function sdtStaking() external view returns (address);
    function setProcessorRewardsPercentage(uint256 _percentage) external;
    function transferOwnership(address newOwner) external;
}
