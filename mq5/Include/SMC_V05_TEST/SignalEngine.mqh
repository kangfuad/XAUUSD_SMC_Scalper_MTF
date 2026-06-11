//+------------------------------------------------------------------+
//| SignalEngine.mqh                                                 |
//| V0.1: Evaluate M15 trend and set signal status                   |
//+------------------------------------------------------------------+
#property strict

#include "Types.mqh"
#include "MarketStructure.mqh"

class CSignalEngine {
private:
   CMarketStructure m_ms;
   
public:
   void EvaluateMarketState(StructMarketState &state) {
      // Reset state
      state.m15_trend = TREND_SIDWAYS;
      state.signal_status = STATUS_NO_TRADE;
      state.last_swing_high.price = 0;
      state.last_swing_low.price = 0;
      state.last_bos.price = 0;
      
      // 1. Detect recent swings on M15 (using closed candles, shift >= 1)
      double sh_price = 0, sl_price = 0;
      datetime sh_time = 0, sl_time = 0;
      int min_shift = m_ms.GetSwingPeriod() + 1; // Ensure all compared candles are closed (shift >= 1)
      
      // Look back up to 50 closed candles for swings
      for(int i = min_shift; i < 50; i++) {
         if(m_ms.DetectSwingHigh(PERIOD_M15, i, sh_price, sh_time)) {
            state.last_swing_high.price = sh_price;
            state.last_swing_high.time = sh_time;
            state.last_swing_high.is_high = true;
            break;
         }
      }
      
      for(int i = min_shift; i < 50; i++) {
         if(m_ms.DetectSwingLow(PERIOD_M15, i, sl_price, sl_time)) {
            state.last_swing_low.price = sl_price;
            state.last_swing_low.time = sl_time;
            state.last_swing_low.is_high = false;
            break;
         }
      }
      
      // 2. Detect BOS based on the last swing
      double bos_price = 0;
      datetime bos_time = 0;
      bool bos_found = false;
      
      if(state.last_swing_high.price > 0) {
         // Check for bearish BOS (close below swing low)
         for(int i = 1; i < 50; i++) {
            if(m_ms.DetectBOS(PERIOD_M15, i, state.last_swing_low.price, false, bos_price, bos_time)) {
               state.last_bos.price = bos_price;
               state.last_bos.time = bos_time;
               state.last_bos.is_bullish = false;
               state.m15_trend = TREND_BEARISH;
               bos_found = true;
               break;
            }
         }
      }
      
      if(!bos_found && state.last_swing_low.price > 0) {
         // Check for bullish BOS (close above swing high)
         for(int i = 1; i < 50; i++) {
            if(m_ms.DetectBOS(PERIOD_M15, i, state.last_swing_high.price, true, bos_price, bos_time)) {
               state.last_bos.price = bos_price;
               state.last_bos.time = bos_time;
               state.last_bos.is_bullish = true;
               state.m15_trend = TREND_BULLISH;
               break;
            }
         }
      }
      
      // 3. Set signal status (V0.1: Scanner only, no auto trade)
      // We just reflect the trend bias as allowed direction for logging purposes
      if(state.m15_trend == TREND_BULLISH) {
         state.signal_status = STATUS_BUY_ALLOWED;
      } else if(state.m15_trend == TREND_BEARISH) {
         state.signal_status = STATUS_SELL_ALLOWED;
      } else {
         state.signal_status = STATUS_NO_TRADE;
      }
   }
};