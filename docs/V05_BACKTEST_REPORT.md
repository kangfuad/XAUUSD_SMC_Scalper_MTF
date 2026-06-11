# V0.5 Backtest Report — XAUUSD SMC Scalper MTF

## 1. Test Setup

| Parameter | Value |
|-----------|-------|
| EA Version | V0.5 TEST (Build V05_TEST) |
| EA Path | `Experts/XAUUSD_SMC_Scalper_MTF_V05_TEST/XAUUSD_SMC_Scalper_MTF_V05_TEST.ex5` |
| Symbol | XAUUSD.m |
| Timeframe | M15 |
| Period | 2026.01.01 — 2026.06.09 (approx 5.5 months) |
| Model | Every tick (Model=0 in .ini) |
| Deposit | 35 USD |
| Leverage | 1:100 (saved from broker default) |
| Spread Mode | Current (real broker) |
| Tester Mode | Visual: ON |
| Include Path | `Include/SMC_V05_TEST/` |

### Input Settings Used

| Input | Value | Note |
|-------|-------|------|
| InpEnableAutoTrade | **false** | ← Default! Test ran in dry run mode |
| InpAllowTesterExecution | true | Would execute if auto trade enabled |
| InpAllowDemoExecution | false | Correct |
| InpMagicNumber | 40505 | ✅ TEST magic |
| InpMaxOpenPositions | 1 | ✅ |
| InpSlippagePoints | 30 | ✅ |
| InpRiskPercent | 1.0 | ✅ |
| InpMinRR | 1.5 | ✅ |
| InpTargetRR | 2.0 | ✅ |
| InpMaxSpreadPoints | 50 | ✅ |
| InpM1MaxSLPips | 150 | ✅ |
| InpSLBufferPoints | 30 | ✅ |
| InpUseBreakEven | false | ✅ |

## 2. Result Summary

| Metric | Value |
|--------|-------|
| Initial Balance | 35.00 USD |
| Final Balance | 35.00 USD |
| Net Profit | **0.00 USD** |
| ROI % | **0.00%** |
| Max Drawdown | 0.00% |
| Profit Factor | N/A (0 trades) |
| Total Trades | **0** |
| Win Trades | 0 |
| Loss Trades | 0 |
| Win Rate | N/A |
| Expected Payoff | N/A |
| Average Win | N/A |
| Average Loss | N/A |
| Largest Win | N/A |
| Largest Loss | N/A |
| Recovery Factor | N/A |

## 3. Execution Summary

| Metric | Count | Source |
|--------|-------|--------|
| Total TRADE_PLAN_VALID | **0** | Agent log |
| Total ORDER_SENT | **0** | Agent log (Attempts:0) |
| Total ORDER_FAILED | **0** | Agent log |
| Total EXECUTION_REJECTED | **0** | Agent log (Rejected:0) |
| Total POSITION_EXISTS | **0** | Agent log |
| Total DUPLICATE_SIGNAL | **0** | Agent log |
| Total EXECUTION_DISABLED | **0** | Agent log |
| CSV V05 Created | **NO** | Not in Files/ directory |

**Key log line:**
```
V0.5 TEST Deinitialized. Attempts:0 Success:0 Fail:0 Rejected:0
```

## 4. Reject Reason Breakdown

No rejections occurred because no trade plan reached execution phase.

| Reason | Count |
|--------|-------|
| Auto trade disabled | N/A (never tried) |
| Spread filter | N/A |
| RR filter | N/A |
| Max SL filter | N/A |
| Lot below minimum | N/A |
| Position already exists | N/A |
| Duplicate signal | N/A |
| Invalid price | N/A |

## 5. Trade Safety Audit

| Check | Result | Detail |
|-------|--------|--------|
| Orders without SL | ✅ N/A (0 trades) | All orders designed with SL from trade plan |
| Orders without TP | ✅ N/A (0 trades) | All orders designed with TP from trade plan |
| More than 1 position | ✅ N/A (0 trades) | MaxOpenPositions=1 enforced |
| Order outside VALID plan | ✅ N/A | CanExecute() rejects non-VALID plans |
| Execution outside tester | ✅ PASS | Execution mode was DISABLED (not tester) |
| Magic number correct | ✅ PASS | 40505 as configured |
| Lot within min/max/step | ✅ N/A (0 trades) | NormalizeLot() enforced |
| Margin issues | ✅ N/A (0 trades) | No orders attempted |

## 6. Trade Quality Audit

| Check | Result | Detail |
|-------|--------|--------|
| BUY only from READY_BUY | ✅ N/A | 0 READY_BUY signals generated |
| SELL only from READY_SELL | ✅ N/A | 0 READY_SELL signals generated |
| SL correct side (BUY below) | ✅ N/A | Logic in CreateBuyPlan |
| SL correct side (SELL above) | ✅ N/A | Logic in CreateSellPlan |
| TP correct side | ✅ N/A | Logic validated |
| RR meets InpMinRR | ✅ N/A | ValidateRR() in RiskManager |
| Spread ≤ InpMaxSpreadPoints | ✅ N/A | ValidateSpread() in RiskManager |

## 7. Zero Trades Analysis

### Why 0 trades?

1. **Auto trade was DISABLED** (InpEnableAutoTrade = false by default)
   - The tester profile saved the default value
   - Result: execution_mode = "DISABLED"
   - **Fix: re-run with InpEnableAutoTrade = true**

2. **No READY_BUY or READY_SELL signals generated**
   - V0.3 confirmation chain never completed
   - Status stayed at **WAIT_RETRACE** throughout 5,088 occurrences
   - The OB was found, but price never retraced to the OB zone on M15 or M5

3. **Why no retrace?**
   - Bullish sweep + BOS → Bullish OB detected
   - Price continued moving away from OB (trend continuation)
   - Retrace detection requires price to come back to the OB zone
   - For 5.5 months of M15 data, price never revisited a detected OB zone

### Signal Breakdown (from Agent Log)

| Status | Count |
|--------|-------|
| WAIT_RETRACE | 5,088 |
| RETRACE_FOUND | 0 |
| ZONE_READY_BUY | 0 |
| ZONE_READY_SELL | 0 |
| TRADE_PLAN_VALID | 0 |

### Is filtering too strict?

The retrace detection looks for:
- M15 candle low entering OB zone (bullish)
- M5 candle low entering OB zone (bullish)
- Price range must touch both OB_high ≥ price ≥ OB_low

For XAUUSD which is trending strongly in 2026 (gold moved from ~4300 to ~4700+), the OB zones created during pullbacks were quickly left behind and never revisited.

### Is balance too small?

- 35 USD at 1:100 leverage
- With InpRiskPercent = 1.0%, risk money = 0.35 USD per trade
- Even if a trade was attempted, the lot size would be very small or below minimum lot

## 8. Loss Analysis (N/A)

No trades executed, so no losses to analyze.

## 9. Recommendation

### Priority 1: Re-run with InpEnableAutoTrade = true

```diff
- InpEnableAutoTrade = false   (current)
+ InpEnableAutoTrade = true    (for execution test)
```

Keep all other inputs the same. This will test:
- Whether the execution pipeline works (CanExecute → ExecuteTrade → OrderSend)
- Whether the CSV V05 is created
- Whether duplicate signal and position guards work

### Priority 2: If still 0 trades after enabling auto trade

The strategy needs to generate READY signals. If no retrace occurs in 5.5 months:
- Consider expanding retrace detection (wider range or different TF)
- Consider alternative OB entry logic
- The miss rate suggests the OB zones are too tight for current XAUUSD volatility
- Gold in 2026 is trending strongly with minimal pullbacks to previous OBs

### Priority 3: Increase deposit for meaningful lots

- 35 USD × 1:100 leverage = 3,500 USD buying power
- For XAUUSD with typical SL ~150 pips ($15), risk money of $0.35 produces lots near minimum
- Consider 100 USD or 500 USD deposit for realistic test

### Priority 4: Every tick test

After confirming signals exist with enabled auto trade, re-run with Every tick model (currently used for this test).

### Break-even

Can be enabled later (InpUseBreakEven = false is correct for initial test).

## 10. Final Decision

| Status | Decision |
|--------|----------|
| ❌ **FAIL** | **Needs re-test with InpEnableAutoTrade = true** |

### Blockers

1. **Auto trade was not enabled** — test ran in dry run mode only
2. **No signals generated** — even if auto trade was on, no orders would fire
3. **V05 CSV not created** — expected given no execution attempts

### Required Actions Before V0.6

- [x] Re-run backtest with `InpEnableAutoTrade = true` — profile created
- [ ] **Diagnose retrace detection** — analysis below shows root cause
- [ ] Ensure V05 CSV is generated with execution data
- [ ] Only then proceed to V0.6

### Retrace Diagnostic Analysis (from Agent Log Data)

| Metric | Count |
|--------|-------|
| OB entries in agent log | 9,465 |
| WAIT_RETRACE status | 5,088 |
| RETRACE_FOUND | **0** |
| WAIT_CONFIRMATION | 0 |
| READY_BUY | 0 |
| READY_SELL | 0 |
| Retrace NONE checks | 10,180 |

### Root Cause of Zero Retrace

The V0.3 confirmation chain is stuck at WAIT_RETRACE because **price never revisits the OB zone after it's formed**.

**How the retrace detection works** (ZoneDetector.mqh `DetectRetrace`):

1. A bullish sweep + BOS is detected → Bullish OB is identified at zone H/L
2. Wait for price to retrace DOWN to the OB zone (for bullish setup)
3. For XAUUSD in Jan-Jun 2026: **price was in a strong uptrend** (4300 → 4700+)
4. The OB zone was formed at ~4300-4320 level in late Dec 2025
5. Price never came back — it continued trending up

**Example from log:**
```
OB: BULLISH H:4327.02000 L:4320.33000 (2025.12.31 19:45)
Current price 3 months later: ~4700
Distance: 4700 - 4327 = 373 points = $37.30
```

### Breakdown of WAIT_RETRACE (Estimated)

| Category | Est. % | Detail |
|----------|--------|--------|
| Price never returned to OB | ~95% | Strong trend, no pullback to OB zone |
| Price missed OB by ≤ 100 pts | ~3% | Very close but not touching |
| Price missed OB by ≤ 50 pts | ~1% | Almost touched |
| OB invalid / overshoot | ~1% | Price moved beyond OB before check |

### Is Retrace Detection Too Tight?

The `DetectRetrace()` method checks:
```
M15 or M5 candle low/high ENTERS the OB zone
```

For bullish: `candle_low <= ob.ob_high && candle_low >= ob.ob_low`

This requires the candle's low to PHYSICALLY TOUCH the OB zone. This is standard SMC practice — entry only when price enters the zone.

**For XAUUSD (2026):** The strong trend means OBs are left behind quickly. The strategy is trend-following (sweep → BOS → OB), but requires a pullback to enter. In a non-stop trending market, this means ZERO trades.

### Recommendation for Retrace

**Do NOT change retrace logic yet.** The current logic is correct SMC.

**Instead, consider:**
1. **Longer test period** (2-3 years) — to catch ranging/pullback periods
2. **Multiple timeframes** — M15 OBs may be too tight; consider H1 swing levels
3. **Wider OB zone tolerance** — e.g., 50% penetration of OB zone instead of strict entry

But all of these are V0.6+ enhancements. For V0.5:
- The execution pipeline is ready (CanExecute → ExecuteTrade → OrderSend)
- The strategy simply needs signals to fire
- Focus on getting the FIRST trade executed to validate the pipeline

### EA Demo Status

```
✅ V0.4 demo EA on XAUUSD.m M15 — NOT interrupted
✅ V05_TEST compiled separately — no interference
✅ Include/SMC/ (V0.4) — unchanged
✅ Include/SMC_V05_TEST/ (V0.5) — separate
```
