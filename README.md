# MEV Protection Hook

The **MEV Protection Hook** is a Uniswap V4 hook designed to protect against front-running and other Miner Extractable Value (MEV) attacks. It dynamically adjusts pool fees based on market conditions—namely, the volatility of pool price changes and the size of incoming swap orders. This adaptive fee mechanism discourages malicious actors from exploiting the pool while maintaining market liquidity.

---

## Table of Contents

- [Overview](#overview)
- [Key Features](#key-features)
- [Architecture & Code Structure](#architecture--code-structure)
- [Deployment & Usage](#deployment--usage)
- [Potential Enhancements](#potential-enhancements)
- [License](#license)

---

## Overview

The MEV Protection Hook is implemented as a smart contract on Ethereum (written in Solidity 0.8.24) that integrates directly with Uniswap V4 pools via the pool manager interface. It monitors the market state at the time of a swap and calculates a dynamic fee based on:

- **Volatility EMA:** An exponential moving average of observed price fluctuations.
- **Swap Size EMA:** An exponential moving average of incoming swap sizes.
- **Cooldown Mechanism:** A time-based lock to prevent fees from being updated too frequently.

By adjusting fees dynamically, this hook aims to mitigate the risk of MEV and help maintain fair trading conditions.

---

## Key Features

- **Dynamic Fee Adjustment:**  
  Calculates swap fees based on in-protocol metrics like volatility and swap size.
  
- **Cooldown Period:**  
  Implements a cooldown mechanism (with configurable parameters) to avoid rapid fee changes.
  
- **Optimized Stack Management:**  
  Uses internal helper functions and inner blocks to overcome Solidity's "stack too deep" issues.
  
- **Seamless Integration:**  
  Implements the Uniswap V4 hook interface, ensuring compatibility with existing liquidity pools.

---

## Architecture & Code Structure

### Contract: `MEVProtectionHook`

- **Inheritance:**  
  Inherits from `BaseHook`, ensuring that it meets the Uniswap V4 hook specifications.

- **FeeState Struct:**  
  Tracks key metrics for fee calculation:
  - `currentTick`: The current pool tick.
  - `lastUpdated`: The timestamp when fees were last updated.
  - `volatilityEMA`: Exponential moving average of price volatility.
  - `swapSizeEMA`: Exponential moving average of swap sizes.
  - `lastBlock`: The block number when the fee was last updated.

- **Primary Functions:**
  - **`getHookPermissions`:**  
    Configures the hook permissions. Only the `beforeSwap` hook is enabled.
    
  - **`beforeSwap`:**  
    - Enforces a cooldown period before recalculating the fee.
    - Retrieves pool state via the `IUniswapV4Pool` interface.
    - Computes the new fee based on the EMA of volatility and swap sizes.
    - Updates the fee state by delegating to the internal function `_updateFeeState`.
    - Calls the extended pool manager (`IPoolManagerExtended`) to set the newly computed fee.
    
  - **`_updateFeeState`:**  
    Updates fee state in storage field-by-field. This logic is moved into an internal function to release stack pressure.

- **Utility Function:**
  - **`_abs`:**  
    A helper to compute the absolute value of a given tick difference.

### Interfaces

- **`IUniswapV4Pool`:**  
  Minimal interface to read pool state (`slot0`), which returns the current sqrtPrice and tick.

- **`IPoolManagerExtended`:**  
  Extends the base `IPoolManager` interface with two key functions:
  - `pools`: Getter for the pool address (using a pool ID).
  - `setFee`: Updates the pool fee dynamically.

---

## Deployment & Usage

### Prerequisites

- **Foundry (Forge):** Ensure you have [Foundry](https://github.com/foundry-rs/foundry) installed.
- **Dependencies:**  
  Install compatible versions of Uniswap V4 core, periphery libraries, and Solmate.

### Compilation

Compile the contract using Forge:

```shell
$ forge build
```

### Deploying the Contract

Deploy the MEV Protection Hook by passing the address of the pool manager:

```solidity
IPoolManager poolManager = IPoolManager(poolManagerAddress);
MEVProtectionHook mevHook = new MEVProtectionHook(poolManager);
```

### Integration with Uniswap V4 Pools

To integrate, update the pool's hooks configuration:
- Set the pool hooks to the deployed `MEVProtectionHook` address.
- The pool manager will call `beforeSwap` during swap operations, which dynamically adjusts the fee based on the on-chain market state.

---

## Potential Enhancements

- **Parameter Adjustments:**  
  Allow governance to adjust constants (cooldown time, fee thresholds) to best adapt to changing market conditions.
  
- **Event Emissions:**  
  Emit events upon fee state updates for better off-chain monitoring and analytics.
  
- **Extended Testing:**  
  Develop a suite of tests simulating various market conditions to ensure optimal fee calculations.

---

## License

This project is licensed under the [MIT License](LICENSE).

---

Happy trading and enjoy safer, fairer markets!
