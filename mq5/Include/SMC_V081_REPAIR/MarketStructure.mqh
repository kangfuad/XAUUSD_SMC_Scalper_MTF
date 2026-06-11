//+------------------------------------------------------------------+
//| MarketStructure.mqh                                              |
//| V0.1: Swing and BOS detection (closed candles only)              |
//| V0.3: Added M5 minor swing + MSS/ChoCH detection                 |
//+------------------------------------------------------------------+
#property strict

#include "Types.mqh"

class CMarketStructure {
private:
   int m_swing_period;
   int m_minor_swing_period; // V0.3: shorter swing period for M5
   
public:
   CMarketStructure() {
      m_swing_period = 5;        // Standard swing detection period (M15)
      m_minor_swing_period = 3;  // V0.3: Minor swing for M5 (shorter)
   }
   
   int GetSwingPeriod() const {
      return m_swing_period;
   }
   
   //--- V0.3: Detect minor swing high on any TF (for M5 ChoCH/MSS)
   bool DetectMinorSwingHigh(ENUM_TIMEFRAMES tf, int shift, double &price, datetime &time) {
      double current_high = iHigh(_Symbol, tf, shift);
      for(int i = 1; i <= m_minor_swing_period; i++) {
         if(iHigh(_Symbol, tf, shift - i) >= current_high) return false;
         if(iHigh(_Symbol, tf, shift + i) >= current_high) return false;
      }
      price = current_high;
      time = iTime(_Symbol, tf, shift);
      return true;
   }
   
   //--- V0.3: Detect minor swing low on any TF (for M5 ChoCH/MSS)
   bool DetectMinorSwingLow(ENUM_TIMEFRAMES tf, int shift, double &price, datetime &time) {
      double current_low = iLow(_Symbol, tf, shift);
      for(int i = 1; i <= m_minor_swing_period; i++) {
         if(iLow(_Symbol, tf, shift - i) <= current_low) return false;
         if(iLow(_Symbol, tf, shift + i) <= current_low) return false;
      }
      price = current_low;
      time = iTime(_Symbol, tf, shift);
      return true;
   }
   
   //--- V0.3: Detect M5 MSS (Market Structure Shift) bullish
   //    Bullish MSS: close M5 breaks above last minor swing high M5
   //    All candles closed (shift >= 1)
   //    after_time: only check candles after this time (after retrace)
   bool DetectBullishMSS_M5(int start_shift, int end_shift, datetime after_time,
                            double &mss_price, datetime &mss_time) {
      // Find the last minor swing high on M5 before start_shift
      double minor_sh = 0;
      datetime minor_sh_time = 0;
      int min_shift = m_minor_swing_period + 1;
      
      // Search for minor swing high from end_shift backwards
      for(int i = end_shift; i >= min_shift; i--) {
         if(DetectMinorSwingHigh(PERIOD_M5, i, minor_sh, minor_sh_time)) {
            break;
         }
      }
      
      if(minor_sh == 0) return false;
      
      // Now check if any closed M5 candle (between after_time and start_shift)
      // closes above this minor swing high
      for(int i = start_shift; i >= 1; i--) {
         datetime candle_time = iTime(_Symbol, PERIOD_M5, i);
         if(candle_time <= after_time) break; // stop if we go before retrace time
         
         double close_price = iClose(_Symbol, PERIOD_M5, i);
         if(close_price > minor_sh) {
            mss_price = close_price;
            mss_time  = candle_time;
            return true;
         }
      }
      
      return false;
   }
   
   //--- V0.3: Detect M5 MSS (Market Structure Shift) bearish
   //    Bearish MSS: close M5 breaks below last minor swing low M5
   //    All candles closed (shift >= 1)
   bool DetectBearishMSS_M5(int start_shift, int end_shift, datetime after_time,
                            double &mss_price, datetime &mss_time) {
      // Find the last minor swing low on M5
      double minor_sl = 0;
      datetime minor_sl_time = 0;
      int min_shift = m_minor_swing_period + 1;
      
      for(int i = end_shift; i >= min_shift; i--) {
         if(DetectMinorSwingLow(PERIOD_M5, i, minor_sl, minor_sl_time)) {
            break;
         }
      }
      
      if(minor_sl == 0) return false;
      
      // Check if any closed M5 candle closes below this minor swing low
      for(int i = start_shift; i >= 1; i--) {
         datetime candle_time = iTime(_Symbol, PERIOD_M5, i);
         if(candle_time <= after_time) break;
         
         double close_price = iClose(_Symbol, PERIOD_M5, i);
         if(close_price < minor_sl) {
            mss_price = close_price;
            mss_time  = candle_time;
            return true;
         }
      }
      
      return false;
   }
   
   //--- V0.1 original methods (unchanged) ---
   
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