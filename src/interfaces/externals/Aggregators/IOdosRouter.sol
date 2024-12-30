// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
interface IOdosRouter {
    struct TokenInfo {
        address inputToken;
        uint256 inputAmount;
        address inputReceiver;
        address outputToken;
        uint256 outputQuote;
        uint256 outputMin;
        address outputReceiver;
    }
    function FEE_DENOM() external view returns (uint256);
    function REFERRAL_WITH_FEE_THRESHOLD() external view returns (uint256);
    function addressList(uint256) external view returns (address);
    function owner() external view returns (address);
    function referralLookup(uint32) external view returns (uint64 referralFee, address beneficiary, bool registered);
    function registerReferralCode(uint32 _referralCode, uint64 _referralFee, address _beneficiary) external;
    function renounceOwnership() external;
    function setSwapMultiFee(uint256 _swapMultiFee) external;
    function swap(TokenInfo memory tokenInfo, bytes memory pathDefinition, address executor, uint32 referralCode) external returns (uint256 amountOut);
    function swapCompact() external returns (uint256);
    function swapMulti(
        TokenInfo[] memory inputs,
        TokenInfo[] memory outputs,
        uint256 valueOutMin,
        bytes memory pathDefinition,
        address executor,
        uint32 referralCode
    ) external returns (uint256[] memory amountsOut);
    function swapMultiCompact() external returns (uint256[] memory amountsOut);
    function swapMultiFee() external view returns (uint256);

    function swapRouterFunds(
        TokenInfo[] memory inputs,
        TokenInfo[] memory outputs,
        uint256 valueOutMin,
        bytes memory pathDefinition,
        address executor
    ) external returns (uint256[] memory amountsOut);
}
