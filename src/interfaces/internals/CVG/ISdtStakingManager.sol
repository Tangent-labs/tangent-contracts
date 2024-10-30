import "./ISdtStaking.sol";

interface ISdtStakingManager {
    struct TokenStaking {
        ISdtStaking stakingContract;
        uint256 tokenId;
    }

    function BUFFER() external view returns (uint256);
    function acceptOwnership() external;
    function approve(address to, uint256 tokenId) external;
    function balanceOf(address owner) external view returns (uint256);
    function burn(uint256 _tokenId) external;
    function checkIncreaseDepositCompliance(uint256 tokenId, address receiver) external view;
    function checkTokenFullCompliance(uint256 tokenId, address receiver) external view;
    function cvgControlTower() external view returns (address);
    function getApproved(uint256 tokenId) external view returns (address);
    function getTokenIdsAndStakingContracts(address account) external view returns (TokenStaking[] memory);
    function getTokenIdsForWallet(address _wallet) external view returns (uint256[] memory);
    function initialize(address _cvgControlTower) external;
    function isApprovedForAll(address owner, address operator) external view returns (bool);
    function maxLockingTime() external view returns (uint256);
    function mint(address account) external;
    function name() external view returns (string memory);
    function nextId() external view returns (uint256);
    function owner() external view returns (address);
    function ownerOf(uint256 tokenId) external view returns (address);
    function pendingOwner() external view returns (address);
    function renounceOwnership() external;
    function safeTransferFrom(address from, address to, uint256 tokenId) external;
    function safeTransferFrom(address from, address to, uint256 tokenId, bytes memory data) external;
    function setApprovalForAll(address operator, bool approved) external;
    function setBaseURI(string memory newBaseURI) external;
    function setLock(uint256 tokenId, uint256 timestamp) external;
    function setLogo(address _logo) external;
    function setMaxLockingTime(uint256 newMaxLockingTime) external;
    function stakingPerTokenId(uint256) external view returns (address);
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
    function symbol() external view returns (string memory);
    function tokenByIndex(uint256 index) external view returns (uint256);
    function tokenOfOwnerByIndex(address owner, uint256 index) external view returns (uint256);
    function tokenURI(uint256 tokenId) external view returns (string memory);
    function totalSupply() external view returns (uint256);
    function transferFrom(address from, address to, uint256 tokenId) external;
    function transferOwnership(address newOwner) external;
    function unlockingTimestampPerToken(uint256) external view returns (uint256);
}
