import {Test} from "forge-std/Test.sol";
import "forge-std/console.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "../../../src/libs/Resources/ResourcesGlobal.sol";
import "../../../src/libs/Resources/ResourcesYieldSplitter.sol";
import "../../utils/LowLevel.sol";
import "../chainview/PreviewDeposits.sol";

contract SpecialViews is Test, LowLevel {
    PreviewDeposits public previewDeposits;

    function previewDepositThenPreviewMint(
        ILlamaVault llamaVault,
        IERC20 lendAsset,
        IgUSDCvx gUSD,
        uint256 amountIn,
        bool isStake
    ) public returns (uint256 sharesIn, uint256 sharesToConvert, uint256 fee, uint256 gUSDExpected) {
        try previewDeposits.previewDepositThenPreviewMint(llamaVault, lendAsset, gUSD, amountIn, isStake) {} catch (bytes memory data) {
            // Decode the custom error
            return abi.decode(removeFirst4Bytes(data), (uint256, uint256, uint256, uint256));
        }
    }
}
