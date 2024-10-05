import {ISdtLiquidityGauge} from "../externals/ISdtLiquidityGauge.sol";
import {ILlamaVault} from "../externals/ILlamaVault.sol";
import {IStakeDaoVault} from "../externals/IStakeDaoVault.sol";

import {ISplitterToken} from "./ISplitterToken.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ICommonStruct} from "../internals/ICommonStruct.sol";

interface ILendRewardSplitter {
    enum SDT_TOKEN_TYPE {
        /// @dev Asset use as collateral in the lend contract. (ex : crvUSD)
        LendAsset,
        /// @dev Share of  curve vault contract. (ex : cvcrvUSD)
        LlamalendVaultAsset,
        /// @dev Stake Dao gauge asset
        SdtGaugeAsset
    }

    enum CVX_TOKEN_TYPE {
        /// @dev Asset use as collateral in the lend contract. (ex : crvUSD)
        LendAsset,
        /// @dev Share of  curve vault contract. (ex : cvcrvUSD)
        LlamalendVaultAsset
    }

    function incrementDaoFees(ICommonStruct.TokenAmount[] memory tokenAmounts) external;

    // function createSdtMarket(IStakeDaoVault stakeDaoVault) external;

    function createMarkets(uint256[] memory pids) external;

    function claimSimple(address splitterToken) external;

    function depositSCVUSD(
        ILlamaVault llamaVault,
        CVX_TOKEN_TYPE inputType,
        uint256 lendAssetBalance,
        bool isAutoCompound,
        bool isDeposit
    ) external returns (uint256);
}
