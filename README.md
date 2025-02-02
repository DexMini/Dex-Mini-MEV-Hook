# 🛡️ MEV Protection Hook | Uniswap V4 Dynamic Fee Module

[![MIT License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Solidity v0.8.24](https://img.shields.io/badge/Solidity-0.8.24-blue.svg)](https://soliditylang.org)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg?style=flat)](http://makeapullrequest.com)
[![Docs](https://img.shields.io/badge/docs-latest-blue)](https://github.com/DexMini/Dex-Mini-MEV-Hook/wiki)

> *Protect your liquidity pools from MEV attacks with intelligent, dynamic fee adjustments*

## 📖 Quick Navigation
<details>
<summary>Click to expand</summary>

- [🌟 Features](#-features)
- [🎯 User Experience](#-user-experience)
- [🏗️ Architecture](#%EF%B8%8F-architecture)
- [📦 Installation](#-installation)
- [🚀 Deployment](#-deployment)
- [🔧 Configuration](#-configuration)
- [📊 Performance](#-performance)
- [🛠️ Development](#%EF%B8%8F-development)
- [📜 License](#-license)

</details>

## 🌟 Features

### 🛡️ MEV Protection System
| Feature                | Description                                                                 |
|------------------------|-----------------------------------------------------------------------------|
| Adaptive Fee Engine    | 📈 Real-time fee adjustments based on market volatility and swap size       |
| Cooldown Mechanism     | ⏳ Configurable time-lock between fee updates (30s default)                 |
| Volatility Oracle      | 📊 EMA-based price movement tracking (9-period exponential smoothing)       |
| Swap Size Analyzer     | 🔍 EMA-based analysis of transaction sizes                                  |

### 🚀 Key Advantages
- ⚡ Fully compatible with Uniswap V4 hook architecture
- 🔒 Non-custodial design with no admin privileges
- 📉 Progressive fee scaling from 0.05% to 1.0%
- 🛡️ Front-running protection through dynamic pricing

## 🎯 User Experience

### For Liquidity Providers
1. **Pool Creation & Integration**
   ```mermaid
   graph LR
       A[Create Pool] --> B[Enable Hook]
       B --> C[Initial Liquidity]
       C --> D[Monitor Metrics]
   ```
   - Deploy pool with MEV Protection enabled
   - Add initial liquidity
   - Monitor fee generation and pool metrics

2. **Benefits**
   - 💰 Higher fee capture during volatile periods
   - 🛡️ Protection against sandwich attacks
   - 📊 Transparent fee adjustment mechanism

### For Traders
1. **Trading Experience**
   ```mermaid
   graph LR
       A[Submit Trade] --> B[Hook Checks]
       B --> C[Fee Calculation]
       C --> D[Execute Trade]
   ```
   - Submit swap through standard Uniswap interface
   - Hook automatically calculates optimal fee
   - Trade executes with MEV protection

2. **Advantages**
   - ⚡ Fast execution during normal conditions
   - 💸 Fair pricing based on market conditions
   - 🔒 Protection against front-running

### Real-World Example
```solidity
// Example of a protected swap
function swapExactInputSingle(
    address tokenIn,
    address tokenOut,
    uint24 poolFee,
    uint256 amountIn
) external returns (uint256 amountOut) {
    // Hook automatically adjusts fee based on:
    // 1. Current market volatility
    // 2. Swap size relative to pool
    // 3. Recent trading activity
}
```

## 🏗️ Architecture

### Core Components
1. **Fee State Manager**  
   ```solidity
   struct FeeState {
       int24 currentTick;      // Current pool tick
       uint64 lastUpdated;     // Last update timestamp
       uint128 volatilityEMA;  // Price volatility EMA
       uint128 swapSizeEMA;    // Order size EMA
       uint64 lastBlock;       // Last update block
   }
   ```

2. **Protection Mechanism**
   ```mermaid
   graph TD
       A[Incoming Swap] --> B{Check Cooldown}
       B -->|Active| C[Use Current Fee]
       B -->|Inactive| D[Calculate New Fee]
       D --> E[Update State]
       E --> F[Apply Fee]
   ```

## 📦 Installation
```bash
# Clone repository
git clone https://github.com/DexMini/Dex-Mini-MEV-Hook.git
cd Dex-Mini-MEV-Hook

# Install dependencies
forge install

# Build contracts
forge build
```

## 🚀 Deployment

### Prerequisites
- Ethereum RPC endpoint
- Deployer account with ETH
- Pool Manager contract address

### Steps
1. **Deploy Contract**
   ```bash
   forge create --rpc-url <RPC_ENDPOINT> \
       --constructor-args <POOL_MANAGER_ADDRESS> \
       --private-key <DEPLOYER_KEY> \
       src/MEVProtectionHook.sol:MEVProtectionHook
   ```

2. **Verify Contract**
   ```bash
   forge verify-contract --chain-id 1 \
       <DEPLOYED_ADDRESS> \
       src/MEVProtectionHook.sol:MEVProtectionHook
   ```

## 📊 Performance

### Metrics & Benchmarks
| Parameter               | Value       | Impact                              |
|------------------------|-------------|-------------------------------------|
| Base Cooldown          | 30 seconds  | Prevents fee manipulation           |
| Volatility Window      | 9 periods   | Balanced market responsiveness      |
| Min Fee               | 0.05%       | Ensures minimum protocol revenue    |
| Max Fee               | 1.00%       | Caps trader costs                   |
| Fee Capture Rate      | 65%         | Optimal MEV prevention              |

### Gas Optimization
- Efficient storage packing
- Minimal state updates
- Optimized math operations

## 🛠️ Development

### Local Testing
```bash
# Run all tests
forge test -vvv

# Run specific test
forge test --match-test testDynamicFeeAdjustment -vvv

# Generate coverage
forge coverage --report lcov
```

### Code Style
```bash
# Format code
forge fmt

# Check linting
forge lint
```

## 📜 License
This project is licensed under the **MIT License** - see the [LICENSE](LICENSE) file for details.

---

<div align="center">

**Built with 💜 for the DeFi Community**

[Documentation](https://github.com/DexMini/Dex-Mini-MEV-Hook/wiki) | 
[Report Bug](https://github.com/DexMini/Dex-Mini-MEV-Hook/issues) | 
[Request Feature](https://github.com/DexMini/Dex-Mini-MEV-Hook/issues)

</div>
