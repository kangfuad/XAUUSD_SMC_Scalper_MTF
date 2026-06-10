# SR Scalper Universal V1.3 Forensic Report

## Source: v1.2 ExecutionLog CSV (198 trades)

---

## 1. P&L by Symbol

| Symbol   | Trades | Wins | Losses | WR    | P&L       | Avg Win | Avg Loss |
|----------|--------|------|--------|-------|-----------|---------|----------|
| XAUUSD.m | 71     | 16   | 55     | 22.5% | **-$113** | +$2.74  | -$1.94   |
| AUDUSD.m | 103    | 31   | 72     | 30.1% | **-$11**  | +$0.61  | -$0.42   |
| EURUSD.m | 22     | 7    | 15     | 31.8% | **-$2**   | +$0.40  | -$0.35   |

**TOTAL:** 196 trades, 54W/142L, 27.6% WR, **-$126.85 P&L**

---

## 2. P&L by Setup Type ⭐

| Setup       | Trades | WR    | P&L       | Verdict      |
|-------------|--------|-------|-----------|--------------|
| **SELL_T1** | 14     | **35.7%** | **+$7.31**  | ✅ **ONLY PROFITABLE** |
| SELL_T2     | 32     | 15.6% | -$44.65   | ❌ DESTROYS P&L |
| BUY_T2      | 25     | 20.0% | -$4.31    | ❌ LOSS      |
| BUY_T1      | 16     | 18.8% | -$10.56   | ❌ LOSS      |
| NONE*       | 109    | 33.0% | -$74.64   | ⚠️ LOG ARTIFACT |

*\*NONE = trades logged after MTF state changed between entry/exit*

**Action: Disable BUY_T1, BUY_T2, SELL_T2. Keep SELL_T1 only.**

---

## 3. P&L by Direction

| Direction | Trades | WR    | P&L       |
|-----------|--------|-------|-----------|
| **BUY**   | 108    | 24.1% | -$73.69   |
| **SELL**  | 88     | 31.8% | -$53.16   |

SELL outperforms BUY by 7.7% WR.

---

## 4. Exit Reason Analysis

| Exit | Trades | P&L       | Notes            |
|------|--------|-----------|------------------|
| SL   | 142    | -$274.85  | Avg loss -$1.94  |
| TP   | 54     | +$148.00  | Avg win +$2.74   |

RR ratio: $2.74/$1.94 = 1.41. Breakeven WR: 41.5%.
Current WR: 27.6%. **Below breakeven by 14 points.**

---

## 5. Root Cause Summary

| Issue | Impact |
|-------|--------|
| **Tier 2 (momentum) destroys P&L** | -$48.96 from SELL_T2 + BUY_T2 |
| **BUY setups underperform** | BUY WR 24.1% vs SELL 31.8% |
| **XAUUSD worst performer** | -$113 from -$126 total (89% of losses) |
| **AUDUSD near breakeven** | -$11 loss — closest to profitability |

---

## 6. V1.3 Action Plan

1. **Disable all Tier 2** — momentum and consecutive close
2. **Keep Tier 1 only** — engulfing + pin bar
3. **Tighten zone distance** from 1.0 ATR to 0.5 ATR
4. **Reduce MaxTradesDay** from 5 to 2
5. **Session filter** 07-20 UTC to avoid low quality hours
6. **Test P1-P4** to isolate which Tier 1 pattern (if any) has edge

---

## 7. Benchmark vs Target

| Metric | v1.2 | Target v1.3 |
|--------|------|-------------|
| Total trades | 196 | < 40 |
| Win rate | 27.6% | > 30% |
| Net P&L | -$126.85 | > -$50 |
| Profit factor | 0.54 | > 0.80 |
