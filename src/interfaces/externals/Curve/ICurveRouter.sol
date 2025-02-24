// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
interface ICurveRouter {
    function exchange(
        address[11] calldata _route,
        uint256[5][5] calldata _swap_params,
        uint256 _amount,
        uint256 _min_dy,
        address[5] calldata _pools,
        address _receiver
    ) external payable returns (uint256);

    function get_dy(address[11] calldata _route, uint256[5][5] calldata _swap_params, uint256 _amount, address[5] calldata _pools) external view returns (uint256);
}
