XAUUSD_SMC_Scalper_MTF SPEC

Project goal:
Build an MQL5 Expert Advisor for XAUUSD scalping based on Smart Money Concept using three timeframes.

Timeframes:

M15 = trend anchor.
M5 = confirmation.
M1 = execution.

Development rule:
Do not build full auto trading immediately.

Version plan:

V0.1 scanner and logger only.
V0.2 liquidity sweep and Order Block detector.
V0.3 signal engine without order execution.
V0.4 auto trade for Strategy 1 only.
V0.5 break even and Plan B.
V0.6 Strategy 2.
V0.7 Strategy 3.

Core rules:

Use closed candles only.
Do not use candle shift 0 for final signal.
M1 entry is forbidden without M15 bias.
BOS requires candle close beyond valid swing.
Sweep requires wick beyond swing and close back inside.
Log every structure event.
Log every rejected signal.
One position only per symbol and magic number.
