# CHANGELOG

## [V0.1.0] - 2026-06-10
### Added
- Initial V0.1 implementation: Scanner and Logger only.
- `Types.mqh`: Core data structures (`ENUM_TREND_BIAS`, `ENUM_SIGNAL_STATUS`, `StructSwing`, `StructBOS`, `StructMarketState`).
- `MarketStructure.mqh`: Swing High/Low and BOS detection logic using closed candles only (shift >= 1).
- `SignalEngine.mqh`: M15 trend evaluation and signal status mapping.
- `Logger.mqh`: Formatting and printing of M15 trend, last swing high, last swing low, last BOS, and signal status.
- `XAUUSD_SMC_Scalper_MTF.mq5`: Thin main EA file that triggers evaluation on new M15 candle close.
### Fixed
- **Repaint Risk**: Adjusted swing detection loop to start at `shift = m_swing_period + 1` (e.g., shift 6 for period 5). This ensures that all candles used for swing comparison (left and right) are strictly closed candles, eliminating any potential repaint risk from comparing against the currently forming candle (shift 0).
- **Compilation Warnings**: Updated version format to `"1.000"` to comply with MQL5 Market `xxx.yyy` requirements. Fixed `ENUM_TIMEFRAMES` type mismatch in `MarketStructure.mqh` functions.
### Rules Enforced
- No auto-trade logic included.
- No Strategy 2 or 3 logic included.
- No Risk Manager included.
- Final signals/evaluations strictly use closed candles (shift >= 1).