// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {USGInfo} from "../../UsgInfo.sol";
//import {IERC20, IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

struct Shares {
    address token;
    uint256 shares;
}

contract PointPrices is USGInfo {
    struct PointPricesData {
        Shares[] ervc4626shares;
        uint256 usgPrice;
        uint256 sUsgPrice;
    }
    struct AddressesInput {
        address usg;
        address usgOracle;
        address sUsg;
        address[] pegKeepers;
    }

    error PointPricesError(PointPricesData output);

    constructor(address[] memory erc4626s, AddressesInput memory addresses) {
        (uint256 usgPrice, uint256 sUsgPrice) = getInternalPrice(addresses);

        PointPricesData memory out = PointPricesData({ervc4626shares: getErc4626Shares(erc4626s), usgPrice: usgPrice, sUsgPrice: sUsgPrice});

        revert PointPricesError(out);
    }

    function getInternalPrice(AddressesInput memory addresses) internal  returns (uint256 usgPrice, uint256 sUsgPrice) {
        if (addresses.usg != address(0)) {
            USGInfoData memory usgInfo = getUSGInfo(addresses.usg, addresses.usgOracle, addresses.pegKeepers, addresses.sUsg);
            usgPrice = usgInfo.UsgPrice;
            sUsgPrice = usgInfo.sUsgPrice;
        } else {
            usgPrice = 0;
            sUsgPrice = 0;
        }
    }

    function getErc4626Shares(address[] memory erc4626s) internal view returns (Shares[] memory) {
        uint256 erc4629sLen = erc4626s.length;
        Shares[] memory shares = new Shares[](erc4629sLen);
        for (uint256 i; i < erc4629sLen; i++) {
            IERC4626 erc4626 = IERC4626(erc4626s[i]);
            if (erc4626.totalAssets() > 0) {
                uint256 assets = erc4626.convertToAssets(1 ether);
                shares[i] = Shares({token: erc4626s[i], shares: assets});
            } else {
                shares[i] = Shares({token: erc4626s[i], shares: 0});
            }
        }

        return shares;
    }
}
