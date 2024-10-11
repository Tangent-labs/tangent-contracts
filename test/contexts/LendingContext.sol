import {Test} from "forge-std/Test.sol";
import "forge-std/console.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "../../src/libs/Resources.sol";

contract LendingContext is Test {
    address[] borrowers;

    function createLoan(ILlamaVault _llamaVault) public {
        IERC20Metadata collat = IERC20Metadata(_llamaVault.collateral_token());
        ICrvUSDController crvController = ICrvUSDController(_llamaVault.controller());
        address newBorrower = makeAddr(string.concat("Borrower_", vm.toString(borrowers.length)));

        borrowers.push(newBorrower);

        uint256 collatDeposited = vm.randomUint();
        uint256 amountToBorrow = vm.randomUint();

        // Retrieve the maximum crvUSD borrowable
        uint256 maxBorrowable = IERC20(_llamaVault.borrowed_token()).balanceOf(address(crvController));
        // If utilization is too high, we cannot borrow so we stop here
        if (maxBorrowable <= 100) {
            return;
        }
        // Bound the amount to borrow
        amountToBorrow = bound(amountToBorrow, 100, maxBorrowable / 2);

        // Deduce minimum collateral to deposit
        uint256 minCollat = (amountToBorrow * 10 ** 18) / crvController.amm_price() / 10 ** (18 - collat.decimals());

        collatDeposited = bound(collatDeposited, minCollat + minCollat / 3, minCollat * 2);

        deal(address(collat), newBorrower, collatDeposited);

        vm.startPrank(newBorrower);
        collat.approve(address(crvController), collatDeposited);
        crvController.create_loan(collatDeposited, amountToBorrow, 4);
        vm.stopPrank();
    }

    function repay(ILlamaVault _llamaVault) public {
        // If no borrow created, we cannot repay
        if (borrowers.length == 0) {
            return createLoan(_llamaVault);
        }

        IERC20Metadata borrowedToken = IERC20Metadata(_llamaVault.borrowed_token());
        ICrvUSDController crvController = ICrvUSDController(_llamaVault.controller());

        // Pick a random borrower
        uint256 idBorrower = vm.randomUint();
        idBorrower = bound(idBorrower, 0, borrowers.length - 1);
        address borrower = borrowers[idBorrower];

        uint256 debtToRepay = vm.randomUint();
        debtToRepay = bound(debtToRepay, 0, crvController.debt(borrower));

        vm.startPrank(borrower);
        deal(address(borrowedToken), borrower, debtToRepay);

        borrowedToken.approve(address(crvController), debtToRepay);
        crvController.repay(debtToRepay);
        vm.stopPrank();
    }

    function createLoanOrRepay(ILlamaVault _llamaVault) public {
        uint256 idAction = vm.randomUint();
        idAction = bound(idAction, 0, 1);
        if (idAction == 0) {
            createLoan(_llamaVault);
        } else if (idAction == 1) {
            repay(_llamaVault);
        }
    }
}
