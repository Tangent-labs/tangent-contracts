// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

import {LightOwnable} from "./abstract/LightOwnable.sol";
import {LightReentrancyGuardTransient} from "./abstract/LightReentrancyGuardTransient.sol";

import {IZappingProxy} from "../../interfaces/internals/USG/IZappingProxy.sol";
import {IPriceOracle} from "../../interfaces/internals/USG/IPriceOracle.sol";
import {ZapStruct} from "../../interfaces/internals/ICommonStruct.sol";
import {IAggregatorStablePriceV3} from "../../interfaces/externals/LlamaLend/IAggregatorStablePriceV3.sol";
import {ICurveStableSwapNG} from "../../interfaces/externals/Curve/ICurveStableSwapNG.sol";

/// @title FeeDispatcherReceiver
/// @notice Receives the USG of the dumps of rewards. Nothing in the protocol sends funds here, so its USG delta during a swap can't be inflated
///         by protocol flows targeting the fee treasury (e.g. `IRCalculator.mintIR`, liquidation fees) called from a malicious route.
contract FeeDispatcherReceiver {
    constructor(IERC20 usg) {
        usg.approve(msg.sender, type(uint256).max);
    }
}

/// @title FeeDispatcher
/// @author Tangent Finance
/// @notice Fee treasury of the protocol.
///         - Anyone can sell the reward tokens held to USG, protected by an oracle floor.
///         - Anyone can dispatch the USG held along a list of actions set by the owner (sUSG report, vsTAN rewards...).
///         - The owner can claim any token held (DAO share, TAN, collaterals...).
contract FeeDispatcher is LightOwnable, LightReentrancyGuardTransient {
    using SafeERC20 for IERC20;

    enum Funding {
        TRANSFER, // USG is transferred to the target before the call
        APPROVE // Target is approved to pull USG during the call
    }

    struct DispatchAction {
        address target;
        uint16 bps;
        Funding funding;
        uint32 amountOffset; // Byte offset in `data` where the amount is written, NO_AMOUNT to skip
        bytes data; // Calldata with constant params, empty for a plain transfer
    }

    struct TokenConfig {
        IPriceOracle oracle;
        uint16 maxSlippageBps;
        uint8 decimals; // Read from the token when configured, saves the external call on each dump
    }

    struct TokenWithConfig {
        IERC20 token;
        TokenConfig config;
        uint256 balance; // Amount held, dumpable
        uint256 floor; // Oracle floor in USG for the whole balance, 0 if the oracle reverts
    }

    struct DumpParams {
        IERC20 tokenIn;
        uint256 amountIn;
        uint256 minAmountOut;
        ZapStruct zap;
    }

    uint256 public constant BPS = 10_000;
    uint256 public constant MAX_SLIPPAGE_BPS = 500;
    uint32 public constant NO_AMOUNT = type(uint32).max;
    uint256 public constant DISPATCH_COOLDOWN = 1 weeks;
    address constant CHAIN_COIN = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    uint256 constant MIN_LIQUIDITY = 20_000 ether; // Same as the AggregatorStablePriceV3

    IERC20 public immutable USG;
    IZappingProxy public immutable zappingProxy;
    IAggregatorStablePriceV3 public immutable usgOracle;
    FeeDispatcherReceiver public immutable receiver;
    address public constant dao = 0xd2c46b4c28f4B7976d9f87687863c46Bb2f71Dbb;

    /// @notice Tokens that can be dumped. Collaterals must NEVER be configured.
    mapping(IERC20 => TokenConfig) public tokenConfigs;

    /// @notice List of the dumpable tokens, kept in sync with `tokenConfigs`
    IERC20[] internal _tokens;

    DispatchAction[] internal _actions;

    uint256 public lastDispatch;

    event Dumped(IERC20 indexed tokenIn, uint256 amountIn, uint256 amountOut);
    event Dispatched(uint256 totalUSG);
    event Claimed(IERC20 indexed token, uint256 amount);
    event SetTokenConfig(IERC20 indexed token, TokenConfig config);
    event SetActions(DispatchAction[] actions);

    error TokenNotDumpable(IERC20 token);
    error SlippageTooHigh();
    error DispatchCooldown();
    error NotHundredPercent();
    error InvalidAction();
    error MinBelowFloor();

    constructor(address _owner, IERC20 _USG, IZappingProxy _zappingProxy, IAggregatorStablePriceV3 _usgOracle) {
        _transferOwnership(_owner);
        USG = _USG;
        zappingProxy = _zappingProxy;
        usgOracle = _usgOracle;
        // Deploys direclty the receiver
        receiver = new FeeDispatcherReceiver(_USG);
    }

    /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
                            DUMP
    =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */

    /**
     * @notice Swaps several reward tokens held to USG through the ZappingProxy, atomically.
     * @dev    Each min amount out must be at least its oracle floor, so any route is accepted.
     *         Every swap pays the receiver, the USG is pulled back once at the end.
     * @param dumps      For each swap:
     *                   - tokenIn      Reward token to dump, must be configured
     *                   - amountIn     Amount of tokenIn to dump
     *                   - minAmountOut Min amount of USG wanted by the caller, reverts with MinBelowFloor if lower than the oracle floor
     *                   - zap          Router and raw call executed by the ZappingProxy
     * @return totalOut  Amount of USG received
     */
    function dump(DumpParams[] calldata dumps) external nonReentrant returns (uint256 totalOut) {
        uint256 _usgPrice = usgPrice();

        for (uint256 i; i < dumps.length; ) {
            DumpParams calldata params = dumps[i];
            IERC20 tokenIn = params.tokenIn;
            TokenConfig memory config = tokenConfigs[tokenIn];
            require(address(config.oracle) != address(0), TokenNotDumpable(tokenIn));

            // Set a floor to the slippage to prevent MEV attacks
            require(params.minAmountOut >= _oracleFloor(params.amountIn, config, _usgPrice), MinBelowFloor());

            tokenIn.safeTransfer(address(zappingProxy), params.amountIn);
            // Send to receiver because some actions claiming USG could be performed in the arbitrary call of ZappingProxy
            // ex : mintIR mint the interest rate directly on the FeeTreasury
            // The ZappingProxy checks the receiver delta of this swap only, so previous swaps don't count
            uint256 amountOut = zappingProxy.zapProxy(tokenIn, USG, params.minAmountOut, address(receiver), params.zap);
            totalOut += amountOut;

            emit Dumped(tokenIn, params.amountIn, amountOut);

            unchecked {
                ++i;
            }
        }

        // Pulls once the USG of all the swaps from the receiver
        USG.safeTransferFrom(address(receiver), address(this), USG.balanceOf(address(receiver)));
    }

    /**
     * @notice Min amount of USG accepted for `amountIn` of `tokenIn`.
     * @dev    tokenIn priced by its oracle (use max(EMA, spot) oracles), USG priced at min(1$, EMA, spots).
     *         Any manipulation or lag can only raise the floor, making the dump revert.
     *           - usdValue = amount * price
     *           - floorUsgOut = usdValue * (1 - slippage) / usgPrice
     */
    function oracleFloor(IERC20 tokenIn, uint256 amountIn) external view returns (uint256) {
        return _oracleFloor(amountIn, tokenConfigs[tokenIn], usgPrice());
    }

    function _oracleFloor(uint256 amountIn, TokenConfig memory config, uint256 _usgPrice) internal view returns (uint256) {
        return _floorFromPrice(amountIn, config.oracle.latestAnswer(false), config, _usgPrice);
    }

    function _floorFromPrice(uint256 amountIn, uint256 tokenPrice, TokenConfig memory config, uint256 _usgPrice) internal pure returns (uint256) {
        uint256 usdValue = Math.mulDiv(amountIn, tokenPrice, 10 ** config.decimals);
        return Math.mulDiv(usdValue, 1e18 * (BPS - config.maxSlippageBps), _usgPrice * BPS);
    }

    /**
     * @notice Lowest plausible price of USG: min(aggregator EMA, spot of every liquid aggregator pool).
     */
    function usgPrice() public view returns (uint256 price) {
        price = Math.min(1e18, usgOracle.price());

        uint256[] memory tvls = usgOracle.ema_tvl();
        for (uint256 i; i < tvls.length; ) {
            if (tvls[i] >= MIN_LIQUIDITY) {
                (address pool, bool isInverse, ) = usgOracle.price_pairs(i);
                uint256 spot = ICurveStableSwapNG(pool).get_p(0);
                if (isInverse) spot = 1e36 / spot;
                price = Math.min(price, spot);
            }
            unchecked {
                ++i;
            }
        }
    }

    /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
                            DISPATCH
    =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */

    /**
     * @notice Dispatches the USG held along the actions.
     * @dev    Once per week, so the vsTAN stream and the sUSG unlock can't be spam-reset.
     */
    function dispatch() external nonReentrant {
        require(block.timestamp >= lastDispatch + DISPATCH_COOLDOWN, DispatchCooldown());
        lastDispatch = block.timestamp;

        IERC20 _USG = USG;
        uint256 total = _USG.balanceOf(address(this));
        uint256 length = _actions.length;

        for (uint256 i; i < length; ) {
            DispatchAction memory action = _actions[i];
            uint256 amount = (total * action.bps) / BPS;

            // Some actions need a direct transfer
            if (action.funding == Funding.TRANSFER)
                _USG.safeTransfer(action.target, amount);

                // Other are pulled via a transferFrom and need an approval
            else _USG.forceApprove(action.target, amount);

            // Action to proceed ( ex : sUSG.process_report, vsTAN.processRewards ...  )
            bytes memory data = action.data;
            if (data.length != 0) {
                // If the amount needs to be passed as a parameter
                uint256 offset = action.amountOffset;
                if (offset != NO_AMOUNT) {
                    // Insert the amount at the right position in the call data
                    assembly {
                        mstore(add(add(data, 32), offset), amount)
                    }
                }
                // Raw call
                Address.functionCall(action.target, data);
            }

            // Clears the allowance left
            if (action.funding == Funding.APPROVE) _USG.forceApprove(action.target, 0);

            unchecked {
                ++i;
            }
        }

        emit Dispatched(total);
    }

    function getActions() external view returns (DispatchAction[] memory) {
        return _actions;
    }

    /**
     * @notice Dumpable tokens with their config, balance held and oracle floor of that balance, for the front end.
     * @dev    A reverting oracle (e.g. stale feed) gives a floor of 0 instead of reverting the whole view.
     */
    function getTokens() external view returns (TokenWithConfig[] memory tokensWithConfig) {
        uint256 _usgPrice = usgPrice();
        uint256 length = _tokens.length;
        tokensWithConfig = new TokenWithConfig[](length);
        for (uint256 i; i < length; ) {
            IERC20 token = _tokens[i];
            TokenConfig memory config = tokenConfigs[token];
            uint256 balance = token.balanceOf(address(this));

            uint256 floor;
            try config.oracle.latestAnswer(false) returns (uint256 tokenPrice) {
                floor = _floorFromPrice(balance, tokenPrice, config, _usgPrice);
            } catch {}

            tokensWithConfig[i] = TokenWithConfig({token: token, config: config, balance: balance, floor: floor});
            unchecked {
                ++i;
            }
        }
    }

    /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
                            OWNER
    =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */

    /**
     * @notice Sets the oracle and max slippage of a dumpable token. Oracle at address(0) makes it not dumpable.
     * @dev    Decimals are read from the token and stored with the config.
     */
    function setTokenConfig(IERC20 token, IPriceOracle oracle, uint16 maxSlippageBps) external onlyOwner {
        require(token != USG, TokenNotDumpable(token));
        require(maxSlippageBps <= MAX_SLIPPAGE_BPS, SlippageTooHigh());

        bool wasConfigured = address(tokenConfigs[token].oracle) != address(0);
        bool isConfigured = address(oracle) != address(0);
        if (!wasConfigured && isConfigured) {
            _tokens.push(token);
        } else if (wasConfigured && !isConfigured) {
            _removeToken(token);
        }

        TokenConfig memory config = TokenConfig({
            oracle: oracle,
            maxSlippageBps: maxSlippageBps,
            decimals: isConfigured ? IERC20Metadata(address(token)).decimals() : 0
        });
        tokenConfigs[token] = config;
        emit SetTokenConfig(token, config);
    }

    function _removeToken(IERC20 token) internal {
        uint256 length = _tokens.length;
        for (uint256 i; i < length; ) {
            if (_tokens[i] == token) {
                _tokens[i] = _tokens[length - 1];
                _tokens.pop();
                return;
            }
            unchecked {
                ++i;
            }
        }
    }

    /**
     * @notice Replaces the whole list of dispatch actions.
     */
    function setActions(DispatchAction[] calldata newActions) external onlyOwner {
        delete _actions;
        uint256 totalBps;
        for (uint256 i; i < newActions.length; ) {
            DispatchAction calldata action = newActions[i];
            require(action.target != address(0), InvalidAction());
            require(action.amountOffset == NO_AMOUNT || uint256(action.amountOffset) + 32 <= action.data.length, InvalidAction());
            totalBps += action.bps;
            _actions.push(action);
            unchecked {
                ++i;
            }
        }
        require(totalBps == BPS, NotHundredPercent());
        emit SetActions(newActions);
    }

    /**
     * @notice Claims any token held, ETH through CHAIN_COIN, collateral from bad debt
     */
    function claim(IERC20 token, uint256 amount) external onlyOwner {
        if (address(token) == CHAIN_COIN) Address.sendValue(payable(dao), amount);
        else token.safeTransfer(dao, amount);

        emit Claimed(token, amount);
    }

    /// @dev ZappingProxy refunds ETH leftovers to the fee treasury
    receive() external payable {}
}
