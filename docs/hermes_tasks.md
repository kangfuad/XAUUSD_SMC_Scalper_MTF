Hermes Tasks

Task V0.1:
Create scanner and logger only.

Requirements:

Create main EA file:
mq5/Experts/XAUUSD_SMC_Scalper_MTF.mq5
Create include files:
mq5/Include/SMC/Types.mqh
mq5/Include/SMC/MarketStructure.mqh
mq5/Include/SMC/SignalEngine.mqh
mq5/Include/SMC/Logger.mqh
EA must read M15, M5, and M1 candles.
Detect:
swing high
swing low
BOS bullish
BOS bearish
M15 trend bias
Trend rule:
Bullish if last valid structure shows bullish BOS.
Bearish if last valid structure shows bearish BOS.
Sideways if unclear.
No trading allowed.
Print log:
time
symbol
M15 trend
last swing high
last swing low
last BOS
status BUY_ALLOWED, SELL_ALLOWED, or NO_TRADE
Must compile in MetaEditor without error.
