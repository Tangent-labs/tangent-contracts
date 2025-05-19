// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface ICurveTwoCryptoMathOptimized {
    function newton_y(uint256 ANN, uint256 gamma, uint256[2] memory x, uint256 D, uint256 i) external pure returns (uint256);
    function get_y(uint256 _ANN, uint256 _gamma, uint256[2] memory _x, uint256 _D, uint256 i) external pure returns (uint256[2] memory);
    function newton_D(uint256 ANN, uint256 gamma, uint256[2] memory x_unsorted) external view returns (uint256);
    function newton_D(uint256 ANN, uint256 gamma, uint256[2] memory x_unsorted, uint256 K0_prev) external view returns (uint256);
    function get_p(uint256[2] memory _xp, uint256 _D, uint256[2] memory _A_gamma) external view returns (uint256);
    function wad_exp(int256 x) external pure returns (int256);
    function version() external view returns (string memory);
}
