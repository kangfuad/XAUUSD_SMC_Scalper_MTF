# CHANGELOG

## [V0.2.1] - 2026-06-10
### Fixed
- Logger: Guard OB output against default/empty struct values (1970.01.01, 0.00000).
  - `LogZoneState()`: If OB not valid, prints "OB: NONE" instead of garbage timestamps/prices.
  - `LogZoneStateCSV()`: If OB not valid, writes NONE/0/0 for ob_type/ob_time/ob_high/ob_low.
  - BOS fields also guarded: prints/writes "NONE" when BOS price is 0.
- Types.mqh: Added `IsValidOrderBlock()` helper function. Validates: `is_valid`, `time > 0`, `ob_high > 0`, `ob_low > 0`, `ob_high > ob_low`, `type != OB_NONE`.
- ZoneDetector.mqh: `EvaluateZones()` now calls `IsValidOrderBlock()` before accepting OB. Invalid OB resets to `OB_NONE` and status stays `BOS_AFTER_SWEEP_FOUND`.
### Rules Enforced
- Status `WAIT_RETRACE` only appears when OB passes strict validation.
- No auto-trade logic. No entry. No OrderSend/CTrade.
- All signals use closed candles only (shift >= 1).
- V0.1 and V0.2 core detection logic unchanged.

## [V0.2.0] - 2026-06-10
### Added
- `ZoneDetector.mqh`: Liquidity Sweep detection (bullish/bearish) using closed candles only (shift >= 1).
- `ZoneDetector.mqh`: Order Block detection (bullish/bearish) from BOS displacement candles.
- `ZoneDetector.mqh`: OB rectangle drawing on chart with names `SMC_OB_BULLISH_YYYYMMDD_HHMM` / `SMC_OB_BEARISH_YYYYMMDD_HHMM`. No duplicate objects.
- `Types.mqh`: New enums (`ENUM_SWEEP_TYPE`, `ENUM_OB_TYPE`, `ENUM_ZONE_STATUS`) and structs (`StructSweep`, `StructOrderBlock`, `StructZoneState`).
- `Logger.mqh`: `LogZoneState()` for detailed Print output (sweep, BOS-after-sweep, OB, status).
- `Logger.mqh`: CSV logger writing to `MQL5/Files/XAUUSD_SMC_V02_SweepOBLog.csv` with 15 columns.
- `XAUUSD_SMC_Scalper_MTF.mq5`: V0.2 integration - calls `EvaluateZones()` on new M15 candle, logs to Print and CSV, draws OB rectangles.
- New input parameters: `InpEnableCSVLog`, `InpEnableOBDraw`.
### Fixed
- Version format updated to `"2.000"` for MQL5 Market compliance.
### Rules Enforced
- No auto-trade logic included.
- No OrderSend, CTrade.Buy, CTrade.Sell, or any entry logic.
- No Strategy 2 or 3 logic included.
- No Risk Manager included.
- All signals use closed candles only (shift >= 1).
- Final signal does not use candle shift 0.
- Status values limited to: NO_TRADE, SWEEP_FOUND, BOS_AFTER_SWEEP_FOUND, OB_FOUND, WAIT_RETRACE.
- READY_BUY / READY_SELL status NOT implemented (reserved for V0.3+).
- V0.1 logic (MarketStructure, SignalEngine) unchanged except for new include.

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
