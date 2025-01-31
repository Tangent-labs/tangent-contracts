// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {OFT} from "@layerzerolabs/oft-evm/contracts/OFT.sol";
import {SendParam, OFTReceipt} from "@layerzerolabs/oft-evm/contracts/interfaces/IOFT.sol";
import {MessagingFee, MessagingReceipt} from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/ILayerZeroEndpointV2.sol";
import {ITgUSD} from "../../interfaces/internals/tgUSD/ITgUSD.sol";
import {IDebtIR} from "../../interfaces/internals/tgUSD/IDebtIR.sol";
import {IControlTower} from "../../interfaces/internals/tgUSD/IControlTower.sol";
import {IBridgeChecker} from "../../interfaces/internals/tgUSD/IBridgeChecker.sol";
import "forge-std/console.sol";
/// @notice OFT is an ERC-20 token that extends the OFTCore contract.
contract TgUSD is OFT, ITgUSD {
    IControlTower public controlTower;

    uint256 public mintableInterests;

    bool public isBridgePermisionless;

    IBridgeChecker public bridgeChecker;

    error CallerNotMinterBurner();
    error OnlyOwnerCanBridgeIfPermisionlessNotActive();
    error BridgingNotAllowed();

    constructor(
        string memory _name,
        string memory _symbol,
        address _lzEndpoint,
        address _delegate,
        address _owner,
        IControlTower _controlTower
    ) OFT(_name, _symbol, _lzEndpoint, _delegate) Ownable(_owner) {
        controlTower = _controlTower;
    }

    modifier onlyMarketCaller() {
        require(controlTower.isMarket(msg.sender), CallerNotMinterBurner());
        _;
    }

    function burn(uint256 amount) external {
        _burn(msg.sender, amount);
    }

    function mintIR() external {
        _mint(controlTower.feeTreasury(), mintableInterests);
        delete mintableInterests;
    }

    function mint(address to, uint256 amount) external onlyMarketCaller {
        _mint(to, amount);
    }

    function burnFrom(address from, uint256 amount) external onlyMarketCaller {
        _burn(from, amount);
    }

    function increaseMintableInterests(uint256 interests) external onlyMarketCaller {
        mintableInterests += interests;
    }

    /**
     * @dev Executes the send operation.
     * @param _sendParam The parameters for the send operation.
     * @param _fee The calculated fee for the send() operation.
     *      - nativeFee: The native fee.
     *      - lzTokenFee: The lzToken fee.
     * @param _refundAddress The address to receive any excess funds.
     * @return msgReceipt The receipt for the send operation.
     * @return oftReceipt The OFT receipt information.
     *
     * @dev MessagingReceipt: LayerZero msg receipt
     *  - guid: The unique identifier for the sent message.
     *  - nonce: The nonce of the sent message.
     *  - fee: The LayerZero fee incurred for the message.
     */
    function send(
        SendParam calldata _sendParam,
        MessagingFee calldata _fee,
        address _refundAddress
    ) external payable override returns (MessagingReceipt memory msgReceipt, OFTReceipt memory oftReceipt) {
        // When the bridge is restricted to the DAO, only the owner of the contract can bridge some tgUSD
        if (!isBridgePermisionless) {
            require(msg.sender == owner(), OnlyOwnerCanBridgeIfPermisionlessNotActive());
        }
        // When the bridge is setup as permisionless, it needs to match some conditions given by the bridge checker contract.
        else {
            require(
                msg.sender == owner() || bridgeChecker.isBridgingAllowed(msg.sender, _refundAddress, _sendParam.amountLD, _sendParam.minAmountLD, _sendParam.dstEid),
                BridgingNotAllowed()
            );
        }
        // Applies the token transfers regarding this send() operation.
        // - amountSentLD is the amount in local decimals that was ACTUALLY sent/debited from the sender.
        // - amountReceivedLD is the amount in local decimals that will be received/credited to the recipient on the remote OFT instance.
        (uint256 amountSentLD, uint256 amountReceivedLD) = _debit(msg.sender, _sendParam.amountLD, _sendParam.minAmountLD, _sendParam.dstEid);

        // Builds the options and OFT message to quote in the endpoint.
        (bytes memory message, bytes memory options) = _buildMsgAndOptions(_sendParam, amountReceivedLD);

        // Sends the message to the LayerZero endpoint and returns the LayerZero msg receipt.
        msgReceipt = _lzSend(_sendParam.dstEid, message, options, _fee, _refundAddress);
        // Formulate the OFT receipt.
        oftReceipt = OFTReceipt(amountSentLD, amountReceivedLD);

        emit OFTSent(msgReceipt.guid, _sendParam.dstEid, msg.sender, amountSentLD, amountReceivedLD);
    }
}
