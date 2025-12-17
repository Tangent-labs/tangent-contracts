// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface ILlamaNFT {
    function supportsInterface(bytes4 interface_id) external pure returns (bool);
    function balanceOf(address owner) external view returns (uint256);
    function ownerOf(uint256 token_id) external view returns (address);
    function getApproved(uint256 token_id) external view returns (address);
    function isApprovedForAll(address owner, address operator) external view returns (bool);
    function transferFrom(address from_addr, address to_addr, uint256 token_id) external;
    function safeTransferFrom(address from_addr, address to_addr, uint256 token_id) external;
    function safeTransferFrom(address from_addr, address to_addr, uint256 token_id, bytes memory data) external;
    function approve(address approved, uint256 token_id) external;
    function setApprovalForAll(address operator, bool approved) external;
    function allowlistMint(uint256 mint_amount, uint256 approved_amount, bytes memory sig) external;
    function mint() external returns (uint256);
    function tokenURI(uint256 token_id) external view returns (string memory);
    function contractURI() external view returns (string memory);
    function set_minter(address minter) external;
    function set_al_signer(address al_signer) external;
    function set_base_uri(string memory base_uri) external;
    function set_contract_uri(string memory new_uri) external;
    function set_owner(address new_addr) external;
    function set_revealed(bool flag) external;
    function withdraw() external;
    function admin_withdraw_erc20(address coin, address target, uint256 amount) external;
    function start_al_mint() external;
    function stop_al_mint() external;
    function totalSupply() external view returns (uint256);
    function tokenByIndex(uint256 _index) external view returns (uint256);
    function tokenOfOwnerByIndex(address owner, uint256 index) external view returns (uint256);
    function tokensForOwner(address owner) external view returns (uint256[] memory);
    function symbol() external view returns (string memory);
    function name() external view returns (string memory);
    function owner() external view returns (address);
    function base_uri() external view returns (string memory);
    function revealed() external view returns (bool);
    function default_uri() external view returns (string memory);
    function al_mint_started() external view returns (bool);
    function al_signer() external view returns (address);
    function minter() external view returns (address);
    function al_mint_amount(address arg0) external view returns (uint256);
}
