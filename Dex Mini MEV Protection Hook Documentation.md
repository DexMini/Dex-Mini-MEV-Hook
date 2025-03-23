# Dex Mini MEV Protection Hook

## Advanced Protection Against MEV Exploitation

The Dex Mini MEV Hook is a state-of-the-art solution designed to protect users from Miner Extractable Value (MEV) exploitation, front-running, and sandwich attacks in decentralized finance (DeFi). Built as a Uniswap v4 hook, it adapts to market conditions to provide a safer, more stable trading experience. By combining real-time fee adjustments, adaptive cooldowns, and volatility monitoring, the MEV Hook enables traders, liquidity providers (LPs), and developers to reduce risks and optimize returns in a highly competitive environment.

## Core Features

### Adaptive Fee Mechanism
- **Dynamic Fee Calculation:** Fees adjust in real-time based on market volatility and transaction size using exponential moving averages (EMAs). Larger trades or volatile markets trigger higher fees to discourage exploitative strategies.
- **Volatility-Based Fees:** Fees increase during periods of market turbulence to deter front-running.
- **Size-Based Fees:** Large transactions incur higher fees to mitigate their price impact.

### Adaptive Cooldown Enforcement
- **Frequency Limitation:** A dynamic cooldown period is implemented between swaps, extending during periods of high volatility to prevent rapid, predatory trades.
- **Reduces Sandwich Attacks:** Prevents attackers from exploiting price movements.
- **Stabilizes the Market:** Disrupts high-frequency predatory trading that leads to instability.

### Real-Time Market Monitoring
- **EMA-Powered Tracking:** Constant monitoring of market volatility and transaction size trends ensures fee adjustments are accurate and timely.
- **Volatility EMA:** Smooths price fluctuations to highlight market instability.
- **Swap Size EMA:** Tracks transaction volumes to inform proactive fee changes.

## How It Works

### Mitigating MEV Exploitation
- **Cost Prohibition:** Increased fees during volatile times make MEV strategies economically unprofitable.
- **Market Stabilization:** Cooldown periods reduce drastic price swings from rapid trades.

### Protecting Users
- **Front-Running Resistance:** The combination of fees and cooldowns disrupts malicious front-running attempts.
- **Rebate Opportunities:** Users can earn rewards from back-running activities resulting from their trades.

## Understanding MEV Risks

### What is MEV?
Miner Extractable Value (MEV) is the profit miners/validators make by reordering, censoring, or inserting transactions. Over $1.43 billion has been extracted from Ethereum users through MEV strategies, negatively impacting trades, liquidity provision, and NFT mints.

### Front-Running
Occurs when an attacker detects a pending transaction, executes it first by paying higher gas fees, and profits from the expected price movement.

### Sandwich Attacks
A malicious actor manipulates a victim's trade by placing a transaction before (to alter the price) and one after (to profit from the price distortion).

## Key Components

The MEV Hook is a robust defense mechanism built into Dex Mini. By dynamically adjusting fees and enforcing adaptive cooldowns, it effectively deters front-running, sandwich attacks, and other forms of MEV exploitation—ensuring a fairer, more stable trading environment for liquidity providers and traders alike.

### Example Scenarios

#### Example 1: Preventing Front-Running During High Volatility
Imagine a pool with standard base fees of 0.3%. Suddenly, a large market event spikes volatility. The MEV Hook detects the increased volatility via its EMA and dynamically raises the swap fee to, say, 1.0% for subsequent trades. This increased fee makes it unprofitable for a front-runner to duplicate the trade, thus safeguarding the original swap.

#### Example 2: Throttling Rapid Consecutive Swaps
A trader attempts to execute multiple rapid swaps to exploit price movements (a potential sandwich attack). The adaptive cooldown mechanism is triggered; after the first swap, subsequent swaps within the cooldown window incur extra fees. This throttling effect deters rapid transactions, ensuring that no attacker can manipulate the order flow profitably.

#### Example 3: Mitigating Whale Trade Exploitation
A whale attempts to execute an extremely large swap to induce slippage and profit from front-running. The WhaleWatch AI component detects the unusually high swap size, prompting the MEVProtectionHook to further elevate the fee and impose a longer cooldown period. This adaptive response reduces the profitability of the whale's attempt and protects the pool's liquidity.

## Key Parameters

This section explains the key parameters of the MEVProtectionHook. Each element is designed to dynamically adjust swap fees and enforce cooldowns to mitigate MEV risks.

### Constants

| Parameter | Value | Purpose |
|-----------|-------|---------|
| BASE_MEV_COOLDOWN_TIME | 30 seconds | Sets a minimum delay between swaps to prevent rapid transactions that could enable MEV exploits. |
| BASE_MEV_COOLDOWN_BLOCKS | 2 blocks | Adds an extra layer of protection by enforcing a short delay measured in blocks. |
| MIN_FEE | 500 (0.05%) | Establishes a baseline fee, ensuring every swap pays a minimum fee regardless of market conditions. |
| MAX_FEE | 10000 (1.0%) | Caps the fee to prevent excessive costs during periods of high volatility. |
| FEE_CAPTURE_RATE | 6500 (65%) | Determines the proportion of the MEV opportunity that is converted into a fee. |
| FEE_SCALING_FACTOR | 1e18 | Provides the precision required for accurate fee calculations. |
| SMALL_SWAP_THRESHOLD | 1e18 | Exempts small swaps from cooldown restrictions to improve user experience. |

### Structs

#### FeeState
This struct stores real-time data used to adjust fees dynamically.
- **currentTick (int24):** The current tick of the pool.
- **lastUpdatedTimestamp (uint64):** Timestamp of the most recent swap.
- **lastUpdatedBlock (uint64):** Block number when the last swap occurred.
- **volatilityEMA (uint256):** The exponential moving average (EMA) of tick differences, tracking market volatility.
- **swapSizeEMA (uint256):** The EMA of swap sizes, monitoring transaction volume.

### Mappings

#### feeStates (mapping(bytes32 => FeeState))
- **Purpose:** Maps each pool (identified by a unique bytes32 ID) to its FeeState.
- **Benefit:** Allows quick retrieval and update of fee-related data for each pool.

### Constructor

```solidity
constructor(IPoolManager _poolManager)
```
- **Parameter:** `_poolManager`: The address of the Uniswap v4 PoolManager contract.
- **Behavior:** Initializes the MEVProtectionHook by calling the parent BaseHook constructor to link the hook with Uniswap's PoolManager.
- **Purpose:** Ensures that the hook is correctly set up and ready to execute its dynamic fee and cooldown logic as part of Dex Mini's broader liquidity management system.

## Illustrative Scenarios

### 1. Regular User Swap Walkthrough (Alice)

**Scenario:** Alice wants to swap 1.5 ETH for USDC in the ETH/USDC pool

1. **Alice initiates swap:**
   * Calls Router.swap() with 1.5 ETH
2. **Router processing:**
   * Calls PoolManager.swap()
   * PoolManager checks for hooks
3. **MEV Hook execution:**
   * beforeSwap() triggered:
      * Calculates swap size (1.5 ETH = 1.5e18 wei)
      * Checks against SMALL_SWAP_THRESHOLD (1e18)
      * **Since 1.5e18 > 1e18:**
         * Calculates volatility EMA (historical data)
         * Determines cooldown period (30s base + volatility adjustment)
         * Verifies last swap timestamp/blocks
         * **If recent large swap:** Reverts transaction
         * **If clear:** Proceeds
4. **Dynamic fee calculation:**
   * Gets current tick from pool
   * Calculates tick difference from last swap
   * Computes new fee:
      * MIN_FEE (500) + (volatility * swapSize * 65%)
      * Capped at MAX_FEE (10000)
   * Example result: 850 (0.085%)
5. **Swap execution:**
   * Pool uses 0.085% fee instead of standard 0.05%
   * Updates fee state:
      * Stores new tick (price)
      * Updates volatility EMA
      * Records timestamp & block number
6. **Transaction completes:**
   * Alice receives USDC with MEV-protected pricing
   * Pool now in cooldown for subsequent large swaps

### 2. Liquidity Provider Walkthrough (Bob)

**Scenario:** Bob adds liquidity to ETH/USDC pool

1. **Bob calls Uniswap v4 router to add liquidity:**
   * Calls PoolManager.addLiquidity() with 10 ETH + equivalent USDC
2. **Hook interaction:**
   * Hook permissions show no liquidity hooks:
     * beforeAddLiquidity: false
     * afterAddLiquidity: false
3. **Hook Bypass:**
   * Since the hook has no beforeAddLiquidity/afterAddLiquidity permissions, liquidity is added directly to the pool.
4. **Long-term impact:**
   * Dynamic fees affect LP returns:
      * Higher volatility → Higher fees → More LP earnings
      * MEV protection → Reduced sandwich attacks → Better price execution
   * Example scenario:
      * Normal fee: 0.05% → 0.085% during volatility
      * 70% fee increase for LPs during active periods
5. **Risk management:**
   * Reduced IL from MEV bots front-running
   * More predictable volume from reduced toxic flow

### 3. Bad User Walkthrough (Charlie)

**Scenario:** Charlie tries to execute large arbitrage swap

1. **First attempt:**
   * Tries swapping 50 ETH through pool
   * Hook checks:
      * Large swap size (50e18 > 1e18 threshold)
      * Recent volatility triggers 45s cooldown
      * **Reverts** with "MEV cooldown active"
2. **Second attempt after 30s:**
   * Cooldown still active (needs 45s)
   * **Reverts** again
3. **Successful third attempt:**
   * Waits full 45s + 2 blocks
   * Dynamic fee calculation:
      * High volatility → 0.92% fee (near MAX_FEE)
   * Swap executes with:
      * Higher fee reduces profit margin
      * Updated cooldown timer reset
4. **Strategy impact:**
   * Forced delay prevents instant MEV extraction
   * Fee capture reduces arbitrage profitability
   * Requires larger price discrepancies to be profitable

## Implementation & Usage

### For Traders & LPs
- **Deployment:** Activate the MEV Hook via the Dex Mini dApp when creating liquidity pools. Customize settings like fee multipliers and cooldown thresholds based on your risk preferences.
- **Monitoring:** Track real-time metrics (fees, cooldowns, EMAs) on the Dex Mini dashboard for continuous oversight.

### For Developers
- **Uniswap v4 Integration:** Leverage open-source code and API documentation to embed the MEV Hook into custom applications.
- **Customization:** Tailor EMA time constants, cooldown logic, or fee structures to meet specific market needs.

## MEV Fee Structure: Transparent & Adaptive Pricing

### 1. Fee Overview
Dex Mini uses a modular fee model designed to align costs with the services you utilize, ensuring sustainability while maximizing value for users. Fees are dynamically adjusted based on asset types, market conditions, and pool-specific parameters, offering a tailored and responsive pricing structure.

### 2. Fee Breakdown

#### 2.1 Liquidity Management Fees
- **Action:** Adding, removing, or adjusting liquidity positions.
- **Fee:** 0.25% flat fee per transaction, allocated as follows:
   - **30% → Eigenlayer Operator:** Safeguards users and pools against unexpected risks, such as flash crashes or exploits.
   - **70% → Dex Mini Protocol:** Supports ongoing platform development, security audits, and operational costs.
- **Flexibility:** Fee rates and allocations can be adjusted post-pool creation to adapt to asset volatility or market conditions.

#### 2.2 Trading Fees
- **Action:** Executing swaps.
- **Structure:**
   - **90% → Liquidity Providers (LPs):** Directly rewards LPs for facilitating efficient markets.
   - **10% → Dex Mini Protocol:** Allocated to the MEV Hook to fund real-time protections, such as MEV resistance and rebate mechanisms.
- **Adjustability:** Base trading fees are set at pool creation but can be recalibrated to reflect changing market dynamics.

### 3. Key Features
- **Dynamic Adjustments:** Fees are tailored to asset risk profiles (e.g., stablecoins vs. volatile tokens) and market conditions.
- **Sustainability:** Revenue supports long-term protocol security, ongoing innovation, and user protections.
- **Transparency:** All fee allocations are publicly verifiable on-chain, ensuring full transparency for users.

### 4. Why This Matters
- **Fair Pricing:** Users pay only for the services they use, with no hidden fees or charges.
- **Risk Mitigation:** Insurance funds and hook reserves contribute to a safer ecosystem by protecting against unforeseen risks.
- **LP Incentives:** Competitive rewards for liquidity providers help deepen pools and reduce slippage, fostering a more efficient marketplace.

## Conclusion

The Dex Mini MEV Hook redefines MEV protection with its combination of adaptive fees, cooldown periods, and algorithmic market tracking. It provides:
- **Enhanced Security:** Reduced vulnerability to front-running and sandwich attacks.
- **Market Stability:** Smoother price action for both LPs and traders.
- **Customizable Solutions:** Flexibility for developers and DAOs to adapt protections.

By integrating the Dex Mini MEV Hook, users gain a competitive edge, securing their transactions and optimizing returns in the rapidly evolving DeFi landscape.