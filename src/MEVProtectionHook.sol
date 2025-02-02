// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {BaseHook} from "@uniswap/v4-periphery/src/base/hooks/BaseHook.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {Hooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {BalanceDelta} from "@uniswap/v4-core/src/types/BalanceDelta.sol";
import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";
import {PoolId, PoolIdLibrary} from "@uniswap/v4-core/src/types/PoolId.sol";
import {Pool} from "@uniswap/v4-core/src/libraries/Pool.sol";
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

contract MEVProtectionHook is BaseHook {
    using FixedPointMathLib for uint256;
    using PoolIdLibrary for PoolKey;

    uint256 public constant BASE_MEV_COOLDOWN_TIME = 30;
    uint256 public constant BASE_MEV_COOLDOWN_BLOCKS = 2;
    uint24 public constant MIN_FEE = 5; // 0.05%
    uint24 public constant MAX_FEE = 100; // 1.0%
    uint24 public constant FEE_CAPTURE_RATE = 650; // 65% in basis points
    uint256 public constant FEE_SCALING_FACTOR = 1e12;

    struct FeeState {
        int24 currentTick;
        uint64 lastUpdated;
        uint128 volatilityEMA;
        uint128 swapSizeEMA;
        uint64 lastBlock;
    }

    mapping(bytes32 => FeeState) public feeStates;

    constructor(IPoolManager _poolManager) BaseHook(_poolManager) {}

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
        bytes32 poolId = keccak256(abi.encode(key));
        FeeState storage fee = feeStates[poolId];

        // Adaptive cooldown with sigmoid decay
        uint256 cooldownTime = BASE_MEV_COOLDOWN_TIME +
            (fee.volatilityEMA * BASE_MEV_COOLDOWN_TIME) /
            (1e6 + fee.volatilityEMA);

        if (block.timestamp < fee.lastUpdated + cooldownTime) {
            revert("MEV cooldown active");
        }

        // Extract amountSpecified into a local variable to reduce stack usage
        int256 amtSpec = params.amountSpecified;

        // Declare computedFee variable in outer scope
        uint24 computedFee;
        {
            // Begin inner block to reduce stack usage
            address poolAddress = IPoolManagerExtended(address(poolManager))
                .pools(PoolId.unwrap(key.toId()));
            (, int24 currentTick, , , ) = IUniswapV4Pool(poolAddress).slot0();
            int24 tickDiff = _abs(currentTick - fee.currentTick);
            uint128 newVol = (fee.volatilityEMA *
                9 +
                uint128(uint24(tickDiff))) / 10;
            uint128 swapSize = uint128(
                amtSpec > 0 ? uint256(amtSpec) : uint256(-amtSpec)
            );
            uint128 newSwap = (fee.swapSizeEMA * 9 + swapSize) / 10;
            uint256 mevOpportunity = uint256(newVol) * swapSize;
            uint256 targetFee = MIN_FEE +
                (mevOpportunity * FEE_CAPTURE_RATE) /
                FEE_SCALING_FACTOR;
            computedFee = uint24(targetFee > MAX_FEE ? MAX_FEE : targetFee);

            // Update fee state using internal function to reduce stack usage
            _updateFeeState(poolId, currentTick, newVol, newSwap);
        }
        // End of inner block; heavy local variables are now out of scope.

        // Update the fee in the pool manager
        IPoolManagerExtended(address(poolManager)).setFee(key, computedFee);

        return (
            IHooks.beforeSwap.selector,
            BeforeSwapDeltaLibrary.ZERO_DELTA,
            computedFee
        );
    }

    function _abs(int24 value) internal pure returns (int24) {
        return value >= 0 ? value : -value;
    }

    function _updateFeeState(
        bytes32 poolId,
        int24 currentTick,
        uint128 newVol,
        uint128 newSwap
    ) internal {
        FeeState storage f = feeStates[poolId];
        f.currentTick = currentTick;
        f.lastUpdated = uint64(block.timestamp);
        f.volatilityEMA = newVol;
        f.swapSizeEMA = newSwap;
        f.lastBlock = uint64(block.number);
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

interface IPoolManagerExtended is IPoolManager {
    // Getter for the public mapping 'pools'
    function pools(bytes32 poolId) external view returns (address);
    // Extension: set the fee for a pool
    function setFee(PoolKey calldata key, uint24 fee) external;
}
