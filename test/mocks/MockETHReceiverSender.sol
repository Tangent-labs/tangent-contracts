// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

contract MockETHReceiverSender {
    // Receive ETH sent
    receive() external payable {}

    fallback() external payable {
        (bool isSuccess, ) = payable(msg.sender).call{value: address(this).balance}("");
    }

    function errorPath() external payable {
        revert();
    }
}
