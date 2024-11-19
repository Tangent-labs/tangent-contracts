// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ItgUSD} from "../../interfaces/internals/tgUSD/ItgUSD.sol";

import {IDebtIR} from "../../interfaces/internals/tgUSD/IDebtIR.sol";

import "forge-std/console.sol";

contract IRMinter is Ownable {
    ItgUSD public tgUSD;

    address public feeTreasury;

    mapping(address => bool) isIrProducer;

    error NotIRProducer(address irProducer);

    constructor(address _owner, address _feeTreasury, ItgUSD _tgUSD) Ownable(_owner) {
        tgUSD = _tgUSD;
        feeTreasury = _feeTreasury;
    }

    function toggleIRProducers(address[] calldata _irProducers) external onlyOwner {
        for (uint256 i; i < _irProducers.length; ) {
            address _irProducer = _irProducers[i];

            isIrProducer[_irProducer] = !isIrProducer[_irProducer];

            unchecked {
                ++i;
            }
        }
    }

    function mintIR(address[] calldata _irProducers) external {
        uint256 totalInterests;
        for (uint256 i; i < _irProducers.length; ) {
            address _irProducer = _irProducers[i];
            require(isIrProducer[_irProducer], NotIRProducer(_irProducer));

            totalInterests += IDebtIR(_irProducer).mintPendingInterests();

            unchecked {
                ++i;
            }
        }

        tgUSD.mint(feeTreasury, totalInterests);
    }
}
