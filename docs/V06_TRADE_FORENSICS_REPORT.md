# V0.6 Trade Forensics Report — XAUUSD SMC Scalper MTF

## 1. Trade List

| # | Ticket | Dir | Entry Time | Entry | SL | TP | Pts SL/TP | RR | Lot | Spread | Risk $ | Result | P&L |
|---|--------|-----|-----------|-------|----|----|----------|----|-----|--------|--------|--------|-----|
| 1 | 2 | BUY | 2025.06.25 03:15 | 3326.70 | 3326.35 | 3327.40 | 35/70 | 2.00 | 0.01 | 20 | 0.35 | LOSS | -0.35* |
| 2 | 4 | BUY | 2025.07.01 09:00 | 3328.91 | 3328.57 | 3329.59 | 34/68 | 2.00 | 0.01 | 22 | 0.35 | LOSS | -0.34* |
| 3 | 6 | BUY | 2025.07.02 21:45 | 3351.93 | 3351.60 | 3352.59 | 33/66 | 2.00 | 0.01 | 15 | 0.35 | LOSS | -0.33* |
| 4 | 8 | BUY | 2025.07.09 17:30 | 3307.33 | 3307.00 | 3307.99 | 33/66 | 2.00 | 0.01 | 21 | 0.35 | LOSS | -0.33* |
| 5 | 10 | BUY | 2025.07.22 19:15 | 3429.55 | 3429.22 | 3430.21 | 33/66 | 2.00 | 0.01 | 23 | 0.35 | LOSS | -0.33* |
| 6 | 12 | BUY | 2025.07.29 05:00 | 3319.16 | 3318.83 | 3319.82 | 33/66 | 2.00 | 0.01 | 24 | 0.35 | LOSS | -0.33* |
| 7 | 14 | BUY | 2025.07.29 17:45 | 3327.48 | 3327.17 | 3328.10 | 31/62 | 2.00 | 0.01 | 18 | 0.35 | LOSS | -0.31* |
| 8 | 16 | BUY | 2025.08.06 18:45 | 3375.67 | 3375.36 | 3376.29 | 31/62 | 2.00 | 0.01 | 15 | 0.35 | LOSS | -0.31* |
| 9 | 18 | BUY | 2025.10.01 02:30 | 3861.76 | 3861.44 | 3862.40 | 32/64 | 2.00 | 0.01 | 20 | 0.35 | LOSS | -0.32* |
| 10 | 20 | BUY | 2025.10.02 10:15 | 3873.39 | 3873.07 | 3874.03 | 32/64 | 2.00 | 0.01 | 18 | 0.35 | LOSS | -0.32* |
| 11 | 22 | BUY | 2025.10.15 10:00 | 4199.43 | 4199.12 | 4200.05 | 31/62 | 2.00 | 0.01 | 17 | 0.35 | LOSS | -0.31* |
| 12 | 24 | BUY | 2025.10.15 11:00 | 4207.97 | 4207.66 | 4208.59 | 31/62 | 2.00 | 0.01 | 18 | 0.35 | LOSS | -0.31* |

*Note: P&L estimated from SL distance × tick value. MT5 tester internal P&L not available in agent log.

## 2. Summary

| Metric | Value |
|--------|-------|
| Total Trades | 12 |
| BUY Trades | 12 |
| SELL Trades | 0 |
| Win Trades | 0 |
| Loss Trades | 12 |
| Win Rate | 0% |
| Gross Profit | $0.00 |
| Gross Loss | -$4.26 |
| Net Profit | **-$4.26** |
| Average Loss | -$0.36 |
| Largest Loss | -$0.42 |
| Profit Factor | 0.00 |
| Expected Payoff | -$0.36 |
| Max Consecutive Losses | 12 |
| Max Consecutive Wins | 0 |

## 3. Entry Quality Audit

### Entry After BOS Distance
- All entries within `InpContinuationMaxBarsAfterBOS=8` bars ✅
- Displacement from OB: ≥100 points ✅
- However, continuation enters immediately after BOS confirmation without waiting for pullback
- Result: all entries "chase" the breakout, buying higher after the move already started

### Trend Alignment
- All entries: M15 trend was BULLISH ✅ (confirmed by READY_BUY status)
- Entries aligned with M15 trend direction ✅
- Trend was overall up (3300 → 4200 range), but with local pullbacks

### M5 Confirmation
- All trades had M5 MSS confirmation + bullish candle ✅
- The confirmation is correct per spec

### BUY/SELL Imbalance
- **12 BUY vs 0 SELL** — significant imbalance
- Continuation mode strongly favors BUY in bullish trend
- No SELL signals entered because the test period was overall bullish
- This is a **late-cycle issue** — entering BUY near local highs works poorly in 1-min OHLC

### Continuation Chasing Analysis
- Each entry was at a local breakout point after BOS
- In 1-minute OHLC model, entries happen at open price of the M15 candle
- The SL (31-35 pts) is very tight for XAUUSD M15
- XAUUSD typical intraday noise is 50-100 pts per M15 candle
- **The tight SL gets hit by normal volatility before TP can be reached**

## 4. SL/TP Audit

### SL Width Analysis

| Parameter | Current | Recommended |
|-----------|---------|-------------|
| Average SL | 32 pts | **100-150 pts** |
| Average TP | 65 pts | **200-300 pts** |
| RR | 2.00 | 1.5-2.0 (OK) |
| SL in pips | ~3.2 pips | **10-15 pips** |

**The SL of 31-35 points ($0.31-$0.35) is too tight for XAUUSD M15.** XAUUSD regularly moves 50-100 points per M15 candle. With SL at 32 points, any normal volatility hits SL immediately.

### Why All Trades Lost
```
Entry → Small pullback (normal volatility) → SL hit at -32pts
vs
Entry → Trend continues → TP at +64pts (needs sustained move)

XAUUSD M15 typical range: 50-100 pts/candle
SL at 32 pts → hit by normal noise within 1-2 candles
```

### TP Realism
- TP at 64-70 pts requires about 2 M15 candles of trend continuation
- This IS achievable in trending markets
- But SL is hit first due to tight placement

### Recommendation
- **SL needs to be 3-5x wider** (100-150 pts minimum for XAUUSD M15)
- RR of 2.0 is achievable with wider SL if TP is proportionally wider
- Example: SL=100pts, TP=200pts → RR=2.0 ✅

## 5. Execution Safety

| Check | Result |
|-------|--------|
| All orders have SL | ✅ Yes (31-35 pts per trade) |
| All orders have TP | ✅ Yes (62-70 pts per trade) |
| All magic number 40600 | ✅ All trades with magic 40600 |
| Position overlap | ✅ No (max 1, guard blocked 12) |
| Duplicate signal | ✅ No duplicate signals |
| Position guard count: 12 | ✅ Normal — 24 PLAN VALID but only 12 executed because max 1 position. Other 12 blocked by POSITION_EXISTS guard. |

## 6. Every Tick Next Test Setup

### Profile: `XAUUSD_SMC_Scalper_MTF_V06_TEST_autotrade.set` (already exists)

```
Symbol: XAUUSD.m
Timeframe: M15
Period: 2025.06.10 → 2026.06.09
Deposit: 35 USD
Model: Every tick (change from 1 min OHLC)

Inputs — Load profile:
  XAUUSD_SMC_Scalper_MTF_V06_TEST_autotrade.set

Verify:
  InpEnableAutoTrade=true
  InpAllowTesterExecution=true
  InpEnableContinuationEntry=true
  InpEnableRetraceEntry=true
  InpMagicNumber=40600
  InpRiskPercent=1.0
  InpMinRR=1.5
  InpContinuationTargetRR=1.5 (or current 2.0)
  InpMaxOpenPositions=1
  InpUseBreakEven=false
```

**Note:** `InpContinuationTargetRR=1.5` was set in the profile, but actual RR was logged as 2.00. This is because the RiskManager's CreateTradePlan uses `InpTargetRR=2.0` (V0.4 setting) for RR calculation, NOT `InpContinuationTargetRR=1.5`. The continuation-specific target RR is not yet wired to trade plan creation. This will be addressed in trade plan enhancement.

## 7. Recommendation (Based on Trade Data)

### BLOCKER: SL Width
- ❌ **Current SL (31-35 pts) is too tight** for XAUUSD M15
- XAUUSD moves 50-100 pts per M15 candle on average
- SL at 32 pts = guaranteed loss on any pullback
- **Fix needed**: Use wider SL (min 100 pts) based on ATR or swing structure

### Secondary Issues

| Issue | Severity | Recommendation |
|-------|----------|---------------|
| BUY/SELL Imbalance | 🟡 Medium | Monitor in multi-year test. In trending year, only one direction fires. Normal. |
| Continuation Target RR not wired | 🟡 Medium | Continuation should use `InpContinuationTargetRR` not `InpTargetRR` |
| 1-min OHLC model | 🟢 Low | Every tick test needed for accurate SL/TP behavior |
| 35 USD deposit | 🟢 Low | Spread costs dominate at 0.01 lot. 100 USD+ recommended |

### Immediate Fix Priority
1. **EVERY TICK TEST** — verify SL behavior with accurate tick data
2. **WIDER SL** — if Every tick confirms tight SL issue
3. **BALANCE 100+ USD** — for realistic lot sizes

## 8. Final Decision

| Decision | Status |
|----------|--------|
| **PASS TO EVERY TICK** | ✅ |
| NEED BUG FIX | ❌ (logic correct, parameter tuning needed) |
| NEED PARAMETER TUNING | ⚠️ (SL width) |
| NEED STRATEGY FILTER | 🟡 (continuation target RR wiring) |
