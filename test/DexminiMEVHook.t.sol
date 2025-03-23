// SPDX-License-Identifier: MIT
pragma solidity =0.8.26;

import {Test} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";
import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import {Hooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";
import {TickMath} from "@uniswap/v4-core/src/libraries/TickMath.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {PoolManager} from "@uniswap/v4-core/src/PoolManager.sol";
import {PoolId, PoolIdLibrary} from "@uniswap/v4-core/src/types/PoolId.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {Currency, CurrencyLibrary} from "@uniswap/v4-core/src/types/Currency.sol";
import {Constants} from "@uniswap/v4-core/test/utils/Constants.sol";
import {DexminiMEVHook} from "../src/DexminiMEVHook.sol";
import {HookMiner} from "./utils/HookMiner.sol";
import {MockERC20} from "./mocks/MockERC20.sol";
import "forge-std/console.sol";
import {StateLibrary} from "@uniswap/v4-core/src/libraries/StateLibrary.sol";
import {MockPoolManager} from "./mocks/MockPoolManager.sol";

contract DexminiMEVHookTest is Test {
    using PoolIdLibrary for PoolKey;
    using CurrencyLibrary for Currency;
    using StateLibrary for IPoolManager;

    uint160 constant HOOK_ADDRESS_MASK = uint160((1 << 14) - 1);
    uint160 constant SQRT_PRICE_1_1 = 79228162514264337593543950336;

    DexminiMEVHook hook;
    MockPoolManager manager;
    PoolKey key;
    Currency currency0;
    Currency currency1;
    MockERC20 token0;
    MockERC20 token1;

    function setUp() public {
        console.log("Starting test setup...");

        // Deploy the pool manager
        manager = new MockPoolManager();
        console.log("Pool Manager deployed at:", address(manager));

        // Create and mint tokens
        token0 = new MockERC20("TestToken0", "TEST0", 18);
        token1 = new MockERC20("TestToken1", "TEST1", 18);
        token0.mint(address(this), 1000000e18);
        token1.mint(address(this), 1000000e18);

        console.log("Tokens deployed:");
        console.log("- Token0:", address(token0));
        console.log("- Token1:", address(token1));

        // Enable the beforeSwap permission in our hook
        uint160 flags = uint160(Hooks.BEFORE_SWAP_FLAG);
        bytes memory creationCode = type(DexminiMEVHook).creationCode;
        bytes memory constructorArgs = abi.encode(address(manager));
        creationCode = bytes.concat(creationCode, constructorArgs);

        bytes32 salt = HookMiner.find(address(this), creationCode, flags);

        hook = new DexminiMEVHook{salt: salt}(IPoolManager(address(manager)));

        console.log("Hook deployed at:", address(hook));
        console.log("Hook address:", address(hook));
        console.log("Expected flags:", uint160(Hooks.BEFORE_SWAP_FLAG));
        console.log(
            "Actual hook address flags:",
            uint160(address(hook)) & uint160(0xFFFF)
        );
        console.log(
            "Validating hook address:",
            manager.validateHookAddress(address(hook))
        );

        // Create pool key
        currency0 = Currency.wrap(address(token0));
        currency1 = Currency.wrap(address(token1));

        // Ensure tokens are correctly ordered
        if (Currency.unwrap(currency0) > Currency.unwrap(currency1)) {
            (currency0, currency1) = (currency1, currency0);
            (token0, token1) = (token1, token0);
        }

        key = PoolKey({
            currency0: currency0,
            currency1: currency1,
            fee: 3000,
            tickSpacing: 60,
            hooks: IHooks(address(hook))
        });

        PoolId poolId = key.toId();

        console.log("Pool key created:");
        console.log("- Currency0:", Currency.unwrap(currency0));
        console.log("- Currency1:", Currency.unwrap(currency1));
        console.log("- Fee:", key.fee);
        console.log("- TickSpacing:", key.tickSpacing);
        console.log("- Hooks:", address(key.hooks));

        (uint160 sqrtPriceX96, int24 tick, , , ) = manager.slot0();
        console.log("Initial price:", sqrtPriceX96);
        console.log("Initial tick:", tick);

        manager.initialize(key, SQRT_PRICE_1_1);

        // Approve tokens
        token0.approve(address(manager), type(uint256).max);
        token1.approve(address(manager), type(uint256).max);
        console.log("Tokens approved for manager");
    }

    function test_hook_deployment() public {
        // Test hook address flags
        uint160 hookAddr = uint160(address(hook));
        uint160 hookFlags = hookAddr & uint160(HOOK_ADDRESS_MASK);
        uint160 expectedFlags = uint160(Hooks.BEFORE_SWAP_FLAG);

        assertEq(hookFlags, expectedFlags, "Hook address flags do not match");

        // Test hook permissions
        Hooks.Permissions memory perms = hook.getHookPermissions();
        assertTrue(perms.beforeSwap, "Hook should have beforeSwap permission");
        assertFalse(
            perms.afterSwap,
            "Hook should not have afterSwap permission"
        );
        assertFalse(
            perms.beforeInitialize,
            "Hook should not have beforeInitialize permission"
        );
    }

    function test_pool_initialization() public {
        // Verify pool exists and is initialized
        PoolId poolId = key.toId();
        (uint160 sqrtPriceX96, , , , ) = manager.slot0();
        assertEq(
            sqrtPriceX96,
            SQRT_PRICE_1_1,
            "Pool not initialized correctly"
        );

        // Verify tokens are approved
        assertEq(
            token0.allowance(address(this), address(manager)),
            type(uint256).max,
            "Token0 not approved"
        );
        assertEq(
            token1.allowance(address(this), address(manager)),
            type(uint256).max,
            "Token1 not approved"
        );
    }
}
