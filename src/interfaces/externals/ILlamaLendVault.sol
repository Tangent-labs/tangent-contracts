// SPDX-License-Identifier: MIT

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface ILlamaLendVault is IERC20 {
    function borrow_apr() external view returns (uint256);

    function lend_apr() external view returns (uint256);

    function asset() external view returns (address);

    function totalAssets() external view returns (uint256);

    function pricePerShare() external view returns (uint256);

    function pricePerShare(bool is_floor) external view returns (uint256);

    function convertToShares(uint256 assets) external view returns (uint256);

    function convertToAssets(uint256 shares) external view returns (uint256);

    function maxDeposit(address receiver) external view returns (uint256);

    function previewDeposit(uint256 assets) external view returns (uint256);

    function deposit(uint256 assets) external returns (uint256);

    function deposit(uint256 assets, address receiver) external returns (uint256);

    function maxMint(address receiver) external view returns (uint256);

    function previewMint(uint256 shares) external view returns (uint256);

    function mint(uint256 shares) external returns (uint256);

    function mint(uint256 shares, address receiver) external returns (uint256);

    function maxWithdraw(address owner) external view returns (uint256);

    function previewWithdraw(uint256 assets) external view returns (uint256);

    function withdraw(uint256 assets) external returns (uint256);

    function withdraw(uint256 assets, address receiver) external returns (uint256);

    function withdraw(uint256 assets, address receiver, address owner) external returns (uint256);

    function maxRedeem(address owner) external view returns (uint256);

    function previewRedeem(uint256 shares) external view returns (uint256);

    function redeem(uint256 shares) external returns (uint256);

    function redeem(uint256 shares, address receiver) external returns (uint256);

    function redeem(uint256 shares, address receiver, address owner) external returns (uint256);

    function transferFrom(address _from, address _to, uint256 _value) external returns (bool);

    function transfer(address _to, uint256 _value) external returns (bool);

    function approve(address _spender, uint256 _value) external returns (bool);

    function increaseAllowance(address _spender, uint256 _add_value) external returns (bool);

    function decreaseAllowance(address _spender, uint256 _sub_value) external returns (bool);

    function admin() external view returns (address);

    function borrowed_token() external view returns (address);

    function collateral_token() external view returns (address);

    function price_oracle() external view returns (address);

    function amm() external view returns (address);

    function controller() external view returns (address);

    function factory() external view returns (address);

    function decimals() external view returns (uint8);

    function name() external view returns (string memory);

    function symbol() external view returns (string memory);

    function allowance(address arg0, address arg1) external view returns (uint256);

    function balanceOf(address arg0) external view returns (uint256);

    function totalSupply() external view returns (uint256);
}
