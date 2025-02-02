# MEV Protection Hook

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Solidity Version](https://img.shields.io/badge/Solidity-0.8.24-blue.svg)](https://docs.soliditylang.org/en/v0.8.24/)
[![Foundry Build](https://img.shields.io/badge/Forge-Build-success-brightgreen)](https://github.com/foundry-rs/foundry)

> **Protect your liquidity pools from MEV attacks with dynamic fee adjustments!**

The **MEV Protection Hook** is a Uniswap V4 hook designed to safeguard pools against front-running and Miner Extractable Value (MEV) attacks by dynamically adjusting pool fees based on market conditions.

---

## Table of Contents

- [Overview](#overview)
- [Key Features](#key-features)
- [Architecture & Code Structure](#architecture--code-structure)
- [Deployment & Usage](#deployment--usage)
- [Project Structure](#project-structure)
- [Potential Enhancements](#potential-enhancements)
- [License](#license)

---

## Overview

In decentralized finance, MEV poses significant risks to liquidity providers and traders alike. The MEV Protection Hook monitors the pool state during swap operations and implements a dynamic fee mechanism based on:

- **Volatility EMA:** An exponential moving average of price fluctuations.
- **Swap Size EMA:** An exponential moving average of incoming swap order sizes.
- **Cooldown Mechanism:** A time-based restriction to prevent too frequent fee changes.

Together, these components help maintain fair trading conditions in Uniswap V4 pools while discouraging malicious behavior.

---

## Key Features

- **Dynamic Fee Adjustment:**  
  Leverages real-time pool metrics to calculate optimal fees, ensuring a balance between market liquidity and protection.
  
- **Cooldown Period:**  
  Applies a configurable cooldown to prevent rapid fee updates, guarding against flash-attacks.
  
- **Optimized Performance:**  
  Uses internal helper functions and strategic code blocks to mitigate Solidity's "stack too deep" issues.
  
- **Seamless Uniswap V4 Integration:**  
  Fully compliant with Uniswap V4's hook interface, ensuring smooth integration with pool managers.

---

## Architecture & Code Structure

### **Contract: `MEVProtectionHook`**

- **Inheritance:**  
  Extends `BaseHook` from Uniswap V4 periphery.

- **State Management:**  
  The `FeeState` struct holds:
  - `currentTick`: Current pool tick.
  - `lastUpdated`: Timestamp for the last fee update.
  - `volatilityEMA`: Exponential moving average for price volatility.
  - `swapSizeEMA`: Exponential moving average for swap sizes.
  - `lastBlock`: Block number of the last update.

- **Core Functions:**
  - **`getHookPermissions`:**  
    Configures permissions such that only the `beforeSwap` hook is active.
    
  - **`beforeSwap`:**  
    - Enforces a cooldown period.
    - Retrieves pool state via the `IUniswapV4Pool` interface.
    - Computes a new fee based on volatility and swap metrics.
    - Updates fee state through `_updateFeeState` (extracted to reduce stack usage).
    - Calls `setFee` on an extended pool manager interface (`IPoolManagerExtended`).
    
  - **`_updateFeeState`:**  
    An internal helper that updates `FeeState` fields individually, keeping the main function lean.

- **Utility:**
  - **`_abs`:**  
    Computes the absolute value of a tick difference.

### **Interfaces**

- **`IUniswapV4Pool`:**  
  Exposes the `slot0()` function to read pool state (e.g., current price and tick).

- **`IPoolManagerExtended`:**  
  Extends the basic pool manager interface to include:
  - `pools`: A getter returning the address of a pool by its ID.
  - `setFee`: A method to dynamically update pool fees.

---

## Deployment & Usage

### Prerequisites

- **Foundry (Forge):**  
  [Install Foundry](https://github.com/foundry-rs/foundry) and run `forge install` to set up dependencies.
  
- **Dependencies:**  
  Ensure compatible versions of Uniswap V4 core & periphery libraries, as well as Solmate.

### Compile

Use the following command to compile:

```bash
$ forge build
```

### Deploy

Deploy the contract by providing the pool manager's address:

```solidity
IPoolManager poolManager = IPoolManager(poolManagerAddress);
MEVProtectionHook mevHook = new MEVProtectionHook(poolManager);
```

### Integration

1. **Configure Hooks:**  
   Set the pool's hooks to your deployed `MEVProtectionHook` address.

2. **Dynamic Fee Updates:**  
   The pool manager will automatically call `beforeSwap` during a swap, dynamically adjusting fees based on live market conditions.

---

## Project Structure

```
Dex-Mini-MEV-Hook/
├── foundry.toml         # Foundry configuration
├── .gitignore           # Git ignore rules
├── README.md            # Project documentation (this file)
└── src/                 # Solidity source code
    └── MEVProtectionHook.sol
```

---

## Potential Enhancements

- **Parameter Adjustments:**  
  Introduce governance controls to modify cooldown times and fee thresholds dynamically.

- **Event Logging:**  
  Emit events during fee state updates to improve transparency and off-chain monitoring.

- **Extended Testing:**  
  Develop comprehensive tests simulating variable market conditions for optimal fee calculation.

---

## License

This project is licensed under the [MIT License](LICENSE).

---

**Happy Trading!**  
Protecting liquidity and ensuring fair markets one swap at a time.
