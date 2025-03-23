// SPDX-License-Identifier: MIT
pragma solidity =0.8.26;

import {BaseHook} from "@uniswap/v4-periphery/src/base/hooks/BaseHook.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {Hooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";
import {PoolId, PoolIdLibrary} from "@uniswap/v4-core/src/types/PoolId.sol";
import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import {BeforeSwapDelta, BeforeSwapDeltaLibrary} from "@uniswap/v4-core/src/types/BeforeSwapDelta.sol";
import {Slot0} from "@uniswap/v4-core/src/types/Slot0.sol";

/*////////////////////////////////////////////////////////////////////////////
//                                                                          //
//     ██████╗ ███████╗██╗  ██╗    ███╗   ███╗██╗███╗   ██╗██╗           //
//     ██╔══██╗██╔════╝╚██╗██╔╝    ████╗ ████║██║████╗  ██║██║           //
//     ██║  ██║█████╗   ╚███╔╝     ██╔████╔██║██║██╔██╗ ██║██║           //
//     ██║  ██║██╔══╝   ██╔██╗     ██║╚██╔╝██║██║██║╚██╗██║██║           //
//     ██████╔╝███████╗██╔╝ ██╗    ██║ ╚═╝ ██║██║██║ ╚████║██║           //
//     ╚═════╝ ╚══════╝╚═╝  ╚═╝    ╚═╝     ╚═╝╚═╝╚═╝  ╚═══╝╚═╝           //
//                                                                          //
//     Uniswap V4 Hook - Version 1.0                                       //
//     https://dexmini.com                                                 //
//                                                                          //
////////////////////////////////////////////////////////////////////////////*/

contract DexminiMEVHook is BaseHook {
    using FixedPointMathLib for uint256;
    using PoolIdLibrary for PoolKey;

    // Configuration parameters
    uint256 public constant BASE_MEV_COOLDOWN_TIME = 30; // seconds
    uint256 public constant BASE_MEV_COOLDOWN_BLOCKS = 2; // blocks
    uint24 public constant MIN_FEE = 500; // 0.05% (in hundredths of a basis point)
    uint24 public constant MAX_FEE = 10000; // 1.0% (in hundredths of a basis point)
    uint24 public constant FEE_CAPTURE_RATE = 6500; // 65% in hundredths of a basis point
    uint256 public constant FEE_SCALING_FACTOR = 1e18; // Increased precision
    uint256 public constant SMALL_SWAP_THRESHOLD = 1e18; // 1 token (18 decimals)

    // Fee state tracking
    struct FeeState {
        int24 currentTick;
        uint64 lastUpdatedTimestamp;
        uint64 lastUpdatedBlock;
        uint256 volatilityEMA; // Use uint256 to avoid truncation
        uint256 swapSizeEMA; // Use uint256 to avoid truncation
    }

    mapping(PoolId => FeeState) public feeStates;

    constructor(IPoolManager _poolManager) BaseHook(_poolManager) {
        validateHookAddress(this);
    }

    // Define hook permissions
    function getHookPermissions()
        public
        pure
        override
        returns (Hooks.Permissions memory)
    {
        return
            Hooks.Permissions({
                beforeInitialize: false,
                afterInitialize: false,
                beforeAddLiquidity: false,
                afterAddLiquidity: false,
                beforeRemoveLiquidity: false,
                afterRemoveLiquidity: false,
                beforeSwap: true,
                afterSwap: false,
                beforeDonate: false,
                afterDonate: false,
                beforeSwapReturnDelta: false,
                afterSwapReturnDelta: false,
                afterAddLiquidityReturnDelta: false,
                afterRemoveLiquidityReturnDelta: false
            });
    }

    // Main hook logic executed before swaps
    function beforeSwap(
        address, // sender unused
        PoolKey calldata key,
        IPoolManager.SwapParams calldata params,
        bytes calldata // hookData unused
    )
        external
        override
        onlyPoolManager
        returns (bytes4, BeforeSwapDelta, uint24)
    {
        PoolId poolId = key.toId();
        FeeState storage fee = feeStates[poolId];

        int256 amtSpec = params.amountSpecified;
        uint256 swapSize = amtSpec > 0 ? uint256(amtSpec) : uint256(-amtSpec);

        // Bypass cooldown for small swaps
        if (swapSize >= SMALL_SWAP_THRESHOLD) {
            uint256 cooldownTime = _calculateAdaptiveCooldown(
                fee.volatilityEMA
            );
            if (_isInCooldown(fee, cooldownTime)) {
                revert("MEV cooldown active");
            }
        }

        (uint24 computedFee, int24 tickDiff) = _calculateDynamicFee(
            key,
            fee,
            swapSize
        );
        _updateFeeState(poolId, fee, tickDiff, swapSize);

        // Return the computed fee without calling setFee
        return (
            IHooks.beforeSwap.selector,
            BeforeSwapDeltaLibrary.ZERO_DELTA,
            computedFee
        );
    }

    // Internal helper functions

    function _calculateAdaptiveCooldown(
        uint256 volatilityEMA
    ) internal pure returns (uint256) {
        return
            BASE_MEV_COOLDOWN_TIME +
            (volatilityEMA * BASE_MEV_COOLDOWN_TIME) /
            (1e6 + volatilityEMA);
    }

    function _isInCooldown(
        FeeState storage fee,
        uint256 cooldownTime
    ) internal view returns (bool) {
        return
            block.timestamp < fee.lastUpdatedTimestamp + cooldownTime ||
            block.number < fee.lastUpdatedBlock + BASE_MEV_COOLDOWN_BLOCKS;
    }

    function _calculateDynamicFee(
        PoolKey calldata key,
        FeeState storage fee,
        uint256 swapSize
    ) internal view returns (uint24 computedFee, int24 tickDiff) {
        // Get current tick directly from pool manager
        (, int24 currentTick, , , ) = IUniswapV4Pool(address(poolManager))
            .slot0();

        tickDiff = _abs(currentTick - fee.currentTick);

        // Calculate EMAs with unchecked arithmetic for gas optimization
        unchecked {
            uint256 newVol = (fee.volatilityEMA *
                9 +
                uint256(uint24(tickDiff))) / 10;
            uint256 newSwap = (fee.swapSizeEMA * 9 + swapSize) / 10;
            uint256 mevOpportunity = newVol * newSwap;

            uint256 targetFee = MIN_FEE +
                (mevOpportunity * FEE_CAPTURE_RATE) /
                FEE_SCALING_FACTOR;
            computedFee = uint24(targetFee > MAX_FEE ? MAX_FEE : targetFee);
        }
    }

    function _updateFeeState(
        PoolId poolId,
        FeeState storage fee,
        int24 tickDiff,
        uint256 swapSize
    ) internal {
        unchecked {
            fee.volatilityEMA =
                (fee.volatilityEMA * 9 + uint256(uint24(tickDiff))) /
                10;
            fee.swapSizeEMA = (fee.swapSizeEMA * 9 + swapSize) / 10;
        }
        fee.currentTick += int24(tickDiff); // Track cumulative tick movement
        fee.lastUpdatedTimestamp = uint64(block.timestamp);
        fee.lastUpdatedBlock = uint64(block.number);
    }

    function _abs(int24 value) internal pure returns (int24) {
        return value >= 0 ? value : -value;
    }
}

interface IUniswapV4Pool {
    function slot0()
        external
        view
        returns (
            uint160 sqrtPriceX96,
            int24 tick,
            uint16 observationIndex,
            uint16 observationCardinality,
            uint16 observationCardinalityNext
        );
}
