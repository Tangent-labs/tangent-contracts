// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {USGInfo} from "../../UsgInfo.sol";
import {IDebtIR} from "../../../interfaces/internals/USG/IDebtIR.sol";
import {IIRCalculator} from "../../../interfaces/internals/USG/IIRCalculator.sol";

struct ERC2626 {
    address token;
    uint256 shares;
}
struct DebtIndex {
    address market;
    uint256 index;
}

contract PointPrices is USGInfo {
    struct PointPricesData {
        ERC2626[] ervc4626shares;
        uint256 usgPrice;
        uint256 sUsgPrice;
        DebtIndex[] debtIndexes;
    }
    struct AddressesInput {
        address usg;
        address usgOracle;
        address sUsg;
        address[] pegKeepers;
    }

    error PointPricesError(PointPricesData output);

    constructor(address[] memory erc4626s, AddressesInput memory addresses, address[] memory markets) {
        (uint256 usgPrice, uint256 sUsgPrice) = getInternalPrice(addresses);

        PointPricesData memory out = PointPricesData({
            ervc4626shares: erc4626SharesToAmounts(erc4626s),
            usgPrice: usgPrice,
            sUsgPrice: sUsgPrice,
            debtIndexes: getMarketDebtIndexes(markets)
        });
        revert PointPricesError(out);
    }

    function getMarketDebtIndexes(address[] memory markets) internal view returns (DebtIndex[] memory) {
        DebtIndex[] memory indexes = new DebtIndex[](markets.length);
        for (uint256 i; i < markets.length; i++) {
            IDebtIR marketDebt = IDebtIR(markets[i]);
            IIRCalculator irCalculator = marketDebt.irCalculator();
            indexes[i] = DebtIndex({market: markets[i], index: irCalculator.debtIndexes(markets[i])});
        }
        return indexes;
    }

    function getInternalPrice(AddressesInput memory addresses) internal returns (uint256 usgPrice, uint256 sUsgPrice) {
        if (addresses.usg != address(0)) {
            USGInfoData memory usgInfo = getUSGInfo(addresses.usg, addresses.usgOracle, addresses.pegKeepers, addresses.sUsg);
            usgPrice = usgInfo.UsgPrice;
            sUsgPrice = usgInfo.sUsgPrice;
        } else {
            usgPrice = 0;
            sUsgPrice = 0;
        }
    }

    function erc4626SharesToAmounts(address[] memory erc4626s) internal view returns (ERC2626[] memory) {
        uint256 erc4629sLen = erc4626s.length;
        ERC2626[] memory shares = new ERC2626[](erc4629sLen);
        for (uint256 i; i < erc4629sLen; i++) {
            IERC4626 erc4626 = IERC4626(erc4626s[i]);
            if (erc4626.totalAssets() > 0) {
                uint256 assets = erc4626.convertToAssets(1 ether);
                shares[i] = ERC2626({token: erc4626s[i], shares: assets});
            } else {
                shares[i] = ERC2626({token: erc4626s[i], shares: 0});
            }
        }
        return shares;
    }
}
