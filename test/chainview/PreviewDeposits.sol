import "forge-std/console.sol";
import "forge-std/Test.sol";
import {ILlamaVault} from "../../src/interfaces/externals/ILlamaVault.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IgUSDCvx} from "../../src/interfaces/internals/IgUSDCvx.sol";

contract PreviewDeposits is Test {
    address userPreview = makeAddr("UserPreview");
    uint256 public douze = 12;
    error CacaError(uint256 sharesMinted, uint256 sharesStaked, uint256 fee, uint256 gUSDExpected);

    function previewDepositThenPreviewMint(ILlamaVault llamaVault, IERC20 lendAsset, IgUSDCvx gUSD, uint256 assetIn, bool isStake) public {
        vm.startPrank(userPreview);
        deal(address(lendAsset), userPreview, assetIn);
        lendAsset.approve(address(llamaVault), assetIn);
        uint256 sharesMinted = llamaVault.deposit(assetIn);
        uint256 fee;
        uint256 sharesStaked;
        if (isStake) {
            fee = gUSD.socFeePending();
            sharesStaked = sharesMinted + fee;
        } else {
            fee = (gUSD.socFeePercentage() * sharesMinted) / gUSD.DENOMINATOR();
            sharesStaked = sharesMinted - fee;
        }
        vm.stopPrank();
        revert CacaError(sharesMinted, sharesStaked, fee, llamaVault.convertToAssets(sharesStaked));
    }
}
