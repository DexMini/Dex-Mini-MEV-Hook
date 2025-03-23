// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {Currency} from "@uniswap/v4-core/src/types/Currency.sol";
import {PoolId} from "@uniswap/v4-core/src/types/PoolId.sol";
import {BeforeSwapDelta} from "@uniswap/v4-core/src/types/BeforeSwapDelta.sol";
import {BalanceDelta} from "@uniswap/v4-core/src/types/BalanceDelta.sol";
import "forge-std/console.sol";

contract MockPoolManager {
    int24 private currentTick;
    uint160 private sqrtPriceX96;

    // Flags for hook permissions and validation
    uint160 public constant BEFORE_SWAP_FLAG = 1 << 7;

    function setTick(int24 _tick) external {
        currentTick = _tick;
    }

    function setSqrtPrice(uint160 _sqrtPrice) external {
        sqrtPriceX96 = _sqrtPrice;
    }

    function getPool(PoolKey calldata) external view returns (address) {
        return address(this);
    }

    // Match the signature from IUniswapV4Pool in DexminiMEVHook.sol
    function slot0()
        external
        view
        returns (
            uint160 _sqrtPriceX96,
            int24 tick,
            uint16 observationIndex,
            uint16 observationCardinality,
            uint16 observationCardinalityNext
        )
    {
        return (sqrtPriceX96 == 0 ? 1 : sqrtPriceX96, currentTick, 0, 0, 0);
    }

    function initialize(
        PoolKey calldata,
        uint160 _sqrtPriceX96
    ) external returns (int24) {
        sqrtPriceX96 = _sqrtPriceX96;
        return currentTick;
    }

    // Add a basic implementation of the swap method
    function swap(
        PoolKey calldata,
        IPoolManager.SwapParams calldata,
        bytes calldata
    ) external returns (BalanceDelta, bytes memory) {
        return (BalanceDelta.wrap(0), bytes(""));
    }

    // Hook address validation
    function validateHookAddress(
        address hookAddress
    ) public view returns (bool) {
        // Check if hook address has BEFORE_SWAP_FLAG bit set
        uint160 flags = uint160(hookAddress) & 0xFFFF;
        uint160 expectedFlags = uint160(BEFORE_SWAP_FLAG);

        console.log("validateHookAddress called with:", uint160(hookAddress));
        console.log("Extracted flags:", flags);
        console.log("Expected flags:", expectedFlags);
        console.log(
            "Has expected flag:",
            (flags & expectedFlags) == expectedFlags
        );

        return (flags & expectedFlags) == expectedFlags;
    }

    // Extsload implementation to support StateLibrary usage
    function extsload(bytes32) external view returns (bytes32) {
        return bytes32(0);
    }

    function extsload(
        bytes32,
        uint256
    ) external view returns (bytes32[] memory) {
        bytes32[] memory data = new bytes32[](1);
        return data;
    }
}
