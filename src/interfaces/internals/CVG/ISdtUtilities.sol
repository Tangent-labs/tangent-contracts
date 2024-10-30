interface ISdtUtilities {
    function acceptOwnership() external;
    function convertAndStakeCvgSdt(uint256 _tokenId, uint256 _cvgSdtAmount, uint256 _minCvgSdtAmountReceivedDuringSwap, uint256 _sdtAmount) external;
    function convertAndStakeLpAsset(uint256 _tokenId, address _lpStaking, uint256 _gaugeAssetAmount, uint256 _lpAssetAmount, bool _isEarn) external;
    function convertAndStakeSdAsset(
        uint256 _tokenId,
        address _sdAssetStaking,
        uint256 _gaugeAssetAmount,
        uint256 _minSdAssetAmountReceivedDuringSwap,
        uint256 _sdAssetAmount,
        uint256 _assetAmount,
        bool isLock
    ) external;
    function cvgControlTower() external view returns (address);
    function cvgSdt() external view returns (address);
    function owner() external view returns (address);
    function pendingOwner() external view returns (address);
    function percentageDepeg() external view returns (uint256);
    function renounceOwnership() external;
    function sdt() external view returns (address);
    function setPercentageDepeg(uint256 newPercentageDepeg) external;
    function stablePoolPerAsset(address) external view returns (address);
    function transferOwnership(address newOwner) external;
}
