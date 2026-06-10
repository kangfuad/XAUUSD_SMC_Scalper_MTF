//+------------------------------------------------------------------+
//| Logger.mqh                                                       |
//| V0.1: Simple logging for SMC events                              |
//+------------------------------------------------------------------+
#property strict

#include "Types.mqh"

class CSMCLogger {
public:
   void LogMarketState(const string symbol, const StructMarketState &state) {
      string trend_str = "UNKNOWN";
      if(state.m15_trend == TREND_BULLISH) trend_str = "BULLISH";
      else if(state.m15_trend == TREND_BEARISH) trend_str = "BEARISH";
      else if(state.m15_trend == TREND_SIDWAYS) trend_str = "SIDEWAYS";

      string status_str = "NO_TRADE";
      if(state.signal_status == STATUS_BUY_ALLOWED) status_str = "BUY_ALLOWED";
      else if(state.signal_status == STATUS_SELL_ALLOWED) status_str = "SELL_ALLOWED";

      string log_msg = StringFormat("[%s] %s | M15 Trend: %s | Last SH: %.5f | Last SL: %.5f | Last BOS: %s @ %.5f | Status: %s",
         TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS),
         symbol,
         trend_str,
         state.last_swing_high.price,
         state.last_swing_low.price,
         state.last_bos.is_bullish ? "BULLISH" : "BEARISH",
         state.last_bos.price,
         status_str
      );
      
      Print(log_msg);
   }
};