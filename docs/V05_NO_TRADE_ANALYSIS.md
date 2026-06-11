# V0.5 NO TRADE Analysis — XAUUSD SMC Scalper MTF

## Test Setup

| Parameter | Value |
|-----------|-------|
| EA | XAUUSD_SMC_Scalper_MTF_V05_TEST |
| Profile | `autotrade.set` (InpEnableAutoTrade=true) |
| Symbol | XAUUSD.m |
| Timeframe | M15 |
| Period | 2025.06.10 → 2026.06.09 |
| Deposit | 35 USD |
| Leverage | 1:500 |
| Model | 1 minute OHLC |

---

## 1. Signal Summary

<!-- Isi setelah test selesai -->

| Metric | Count | % of Total Bars |
|--------|-------|-----------------|
| OB_FOUND | [TODO] | [TODO]% |
| WAIT_RETRACE | [TODO] | [TODO]% |
| RETRACE_FOUND | [TODO] | [TODO]% |
| WAIT_CONFIRMATION | [TODO] | [TODO]% |
| READY_BUY | [TODO] | [TODO]% |
| READY_SELL | [TODO] | [TODO]% |
| TRADE_PLAN_VALID | [TODO] | [TODO]% |
| ORDER_SENT | [TODO] | — |
| ORDER_FAILED | [TODO] | — |
| EXECUTION_REJECTED | [TODO] | — |
| **Total Trades** | **[TODO]** | **—** |

---

## 2. Final Account

| Metric | Value |
|--------|-------|
| Initial Balance | 35.00 USD |
| Final Balance | [TODO] USD |
| Net Profit | [TODO] USD |
| Max Drawdown | [TODO]% |
| Profit Factor | [TODO] |

---

## 3. Sample Untouched OB (10 Examples)

<!-- Isi 10 sampel OB yang tidak disentuh harga -->
| No | Date | OB Type | OB High | OB Low | Nearest Price | Min Distance (pts) | Bars Since OB |
|----|------|---------|---------|--------|---------------|-------------------|---------------|
| 1 | [TODO] | [TODO] | [TODO] | [TODO] | [TODO] | [TODO] | [TODO] |
| 2 | [TODO] | [TODO] | [TODO] | [TODO] | [TODO] | [TODO] | [TODO] |
| 3 | [TODO] | [TODO] | [TODO] | [TODO] | [TODO] | [TODO] | [TODO] |
| 4 | [TODO] | [TODO] | [TODO] | [TODO] | [TODO] | [TODO] | [TODO] |
| 5 | [TODO] | [TODO] | [TODO] | [TODO] | [TODO] | [TODO] | [TODO] |
| 6 | [TODO] | [TODO] | [TODO] | [TODO] | [TODO] | [TODO] | [TODO] |
| 7 | [TODO] | [TODO] | [TODO] | [TODO] | [TODO] | [TODO] | [TODO] |
| 8 | [TODO] | [TODO] | [TODO] | [TODO] | [TODO] | [TODO] | [TODO] |
| 9 | [TODO] | [TODO] | [TODO] | [TODO] | [TODO] | [TODO] | [TODO] |
| 10 | [TODO] | [TODO] | [TODO] | [TODO] | [TODO] | [TODO] | [TODO] |

---

## 4. Miss Distance Breakdown

| Distance to OB | Count | % of Total OB |
|----------------|-------|---------------|
| Miss ≤ 50 points | [TODO] | [TODO]% |
| Miss ≤ 100 points | [TODO] | [TODO]% |
| Miss ≤ 200 points | [TODO] | [TODO]% |
| Miss > 200 points | [TODO] | [TODO]% |
| Price never returned | [TODO] | [TODO]% |

---

## 5. OB Zone Lifetime Analysis

| Metric | Value |
|--------|-------|
| Average OB active bars | [TODO] bars |
| Max OB active bars | [TODO] bars |
| OB expired before retrace? | [TODO] (no expiry implemented) |
| Reason: OB not refreshed | EvaluateZone creates new OB each call |

---

## 6. Diagnostic Questions

### Apakah perlu OB expiry?
- Current: OB stays active indefinitely (no timeout)
- Effect: Old OB zones (weeks/months old) are checked for retrace on every new bar
- **V0.6 proposal:** Add OB expiry (e.g., 50 bars) to focus on recent zones

### Apakah perlu retrace tolerance?
- Current: Strict entry (candle must enter OB zone)
- **V0.6 proposal:** Add tolerance (e.g., 50% zone penetration or 10-point slip)

### Apakah perlu continuation entry?
- Current: Only entry on retrace to OB
- **V0.6 proposal:** Continuation entry — when price breaks OB in trend direction (momentum entry)
  - For bullish: break above OB high after sweep+BOS = direct entry

### Apakah filter terlalu ketat?
- [ ] Spread filter (50 pts) — OK for XAUUSD (~18-30 typical spread)
- [ ] RR filter (1.5 min) — needs pullback size for reasonable RR
- [ ] Max SL (150 pips) — sufficient for M15
- [ ] Min lot — depends on balance (35 USD may be too small)

---

## 7. Balance Adequacy Check

| Scenario | Balance | Risk 1% | Risk Money | Lot (SL=150pts) | Feasible? |
|----------|---------|---------|------------|-----------------|-----------|
| Current | 35 USD | 1.0% | 0.35 USD | ~0.00 | ❌ Below min lot |
| Suggested | 100 USD | 1.0% | 1.00 USD | ~0.05 | ⚠️ Minimal |
| Suggested | 500 USD | 1.0% | 5.00 USD | ~0.05 | ✅ Realistic |

---

## 8. Recommendation

<!-- Isi setelah test selesai -->
- [ ] Layak lanjut V0.6
- [ ] Perlu fix retrace detection
- [ ] Perlu tuning parameter
- [ ] Perlu OB expiry
- [ ] Perlu continuation entry
- [ ] Perlu balance > 35 USD
- [ ] Perlu longer test period
