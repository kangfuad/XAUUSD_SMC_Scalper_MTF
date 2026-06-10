//+------------------------------------------------------------------+
//| MarketStructure.mqh                                              |
//| V0.1: Swing and BOS detection (closed candles only)              |
//+------------------------------------------------------------------+
#property strict

#include "Types.mqh"

class CMarketStructure {
private:
   int m_swing_period;
   
public:
   CMarketStructure() {
      m_swing_period = 5; // Standard swing detection period
   }
   
   int GetSwingPeriod() const {
      return m_swing_period;
   }
   
   bool DetectSwingHigh(ENUM_TIMEFRAMES tf, int shift, double &price, datetime &time) {
      // Check if current shift is a swing high based on surrounding closed candles
      double current_high = iHigh(_Symbol, tf, shift);
      for(int i = 1; i <= m_swing_period; i++) {
         if(iHigh(_Symbol, tf, shift - i) >= current_high) return false;
         if(iHigh(_Symbol, tf, shift + i) >= current_high) return false;
      }
      price = current_high;
      time = iTime(_Symbol, tf, shift);
      return true;
   }
   
   bool DetectSwingLow(ENUM_TIMEFRAMES tf, int shift, double &price, datetime &time) {
      // Check if current shift is a swing low based on surrounding closed candles
      double current_low = iLow(_Symbol, tf, shift);
      for(int i = 1; i <= m_swing_period; i++) {
         if(iLow(_Symbol, tf, shift - i) <= current_low) return false;
         if(iLow(_Symbol, tf, shift + i) <= current_low) return false;
      }
      price = current_low;
      time = iTime(_Symbol, tf, shift);
      return true;
   }
   
   bool DetectBOS(ENUM_TIMEFRAMES tf, int shift, double ref_price, bool is_bullish_ref, double &bos_price, datetime &bos_time) {
      // BOS requires candle close beyond valid swing
      double close_price = iClose(_Symbol, tf, shift);
      
      if(is_bullish_ref) {
         if(close_price > ref_price) {
            bos_price = close_price;
            bos_time = iTime(_Symbol, tf, shift);
            return true;
         }
      } else {
         if(close_price < ref_price) {
            bos_price = close_price;
            bos_time = iTime(_Symbol, tf, shift);
            return true;
         }
      }
      return false;
   }
};