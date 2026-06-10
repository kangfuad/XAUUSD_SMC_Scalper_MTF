//+------------------------------------------------------------------+
//| ZoneDetector.mqh                                                 |
//| V0.2: Liquidity Sweep + Order Block detection                    |
//|       Closed candles only. No entry logic.                       |
//+------------------------------------------------------------------+
#property strict

#include "Types.mqh"
#include "MarketStructure.mqh"

class CZoneDetector {
private:
   CMarketStructure m_ms;
   int              m_max_lookback;  // Max candles to look back
   
   //--- Helper: Check if OB object already exists
   bool ObjectExists(string name) {
      return ObjectFind(0, name) >= 0;
   }
   
   //--- Helper: Generate OB object name
   string MakeOBName(ENUM_OB_TYPE type, datetime ob_time) {
      MqlDateTime dt;
      TimeToStruct(ob_time, dt);
      string type_str = (type == OB_BULLISH) ? "BULLISH" : "BEARISH";
      return StringFormat("SMC_OB_%s_%04d%02d%02d_%02d%02d",
                          type_str, dt.year, dt.mon, dt.day, dt.hour, dt.min);
   }
   
public:
   CZoneDetector() {
      m_max_lookback = 50;
   }
   
   //--- Detect Liquidity Sweep (bullish or bearish)
   //    All candles must be closed (shift >= 1)
   bool DetectSweep(ENUM_TIMEFRAMES tf,
                    double swing_high_price, datetime swing_high_time,
                    double swing_low_price,  datetime swing_low_time,
                    StructSweep &sweep_out) {
      
      sweep_out.time  = 0;
      sweep_out.price = 0;
      sweep_out.type  = SWEEP_NONE;
      
      //--- Check each closed candle from shift 1 backwards
      //--- Look for bullish sweep: wick penetrates swing low, body closes above it
      if(swing_low_price > 0) {
         for(int i = 1; i < m_max_lookback; i++) {
            double candle_low   = iLow(_Symbol, tf, i);
            double candle_close = iClose(_Symbol, tf, i);
            
            // Bullish sweep: low wick goes below swing low, but closes above
            if(candle_low < swing_low_price && candle_close > swing_low_price) {
               sweep_out.time  = iTime(_Symbol, tf, i);
               sweep_out.price = candle_low;
               sweep_out.type  = SWEEP_BULLISH;
               return true;
            }
         }
      }
      
      //--- Check for bearish sweep: wick penetrates swing high, body closes below it
      if(swing_high_price > 0) {
         for(int i = 1; i < m_max_lookback; i++) {
            double candle_high  = iHigh(_Symbol, tf, i);
            double candle_close = iClose(_Symbol, tf, i);
            
            // Bearish sweep: high wick goes above swing high, but closes below
            if(candle_high > swing_high_price && candle_close < swing_high_price) {
               sweep_out.time  = iTime(_Symbol, tf, i);
               sweep_out.price = candle_high;
               sweep_out.type  = SWEEP_BEARISH;
               return true;
            }
         }
      }
      
      return false;
   }
   
   //--- Detect BOS after sweep
   //    After bullish sweep -> look for bullish BOS (close above swing high)
   //    After bearish sweep -> look for bearish BOS (close below swing low)
   //    BOS candle must be between sweep candle and shift 1 (closed)
   bool DetectBOSAfterSweep(ENUM_TIMEFRAMES tf,
                            const StructSweep &sweep,
                            double swing_high_price,
                            double swing_low_price,
                            StructBOS &bos_out) {
      
      bos_out.time      = 0;
      bos_out.price     = 0;
      bos_out.is_bullish = false;
      
      if(sweep.type == SWEEP_NONE) return false;
      
      // Find the sweep candle shift
      int sweep_shift = iBarShift(_Symbol, tf, sweep.time);
      if(sweep_shift < 0) return false;
      
      //--- After bullish sweep: look for bullish BOS (close above swing high)
      if(sweep.type == SWEEP_BULLISH && swing_high_price > 0) {
         // BOS must happen AFTER the sweep (closer to current bar, lower shift)
         for(int i = 1; i < sweep_shift; i++) {
            double close_price = iClose(_Symbol, tf, i);
            if(close_price > swing_high_price) {
               bos_out.time       = iTime(_Symbol, tf, i);
               bos_out.price      = close_price;
               bos_out.is_bullish = true;
               return true;
            }
         }
      }
      
      //--- After bearish sweep: look for bearish BOS (close below swing low)
      if(sweep.type == SWEEP_BEARISH && swing_low_price > 0) {
         for(int i = 1; i < sweep_shift; i++) {
            double close_price = iClose(_Symbol, tf, i);
            if(close_price < swing_low_price) {
               bos_out.time       = iTime(_Symbol, tf, i);
               bos_out.price      = close_price;
               bos_out.is_bullish = false;
               return true;
            }
         }
      }
      
      return false;
   }
   
   //--- Detect Order Block
   //    Bullish OB: last bearish candle before bullish displacement that caused BOS
   //    Bearish OB: last bullish candle before bearish displacement that caused BOS
   bool DetectOrderBlock(ENUM_TIMEFRAMES tf,
                         const StructBOS &bos,
                         StructOrderBlock &ob_out) {
      
      ob_out.time    = 0;
      ob_out.ob_high = 0;
      ob_out.ob_low  = 0;
      ob_out.type    = OB_NONE;
      ob_out.is_valid = false;
      
      if(bos.price == 0) return false;
      
      int bos_shift = iBarShift(_Symbol, tf, bos.time);
      if(bos_shift < 0) return false;
      
      //--- Bullish OB: after bullish BOS, find the last bearish candle before it
      if(bos.is_bullish) {
         // Search backwards from BOS shift for the last bearish candle
         for(int i = bos_shift + 1; i < bos_shift + 20; i++) {
            double open_price  = iOpen(_Symbol, tf, i);
            double close_price = iClose(_Symbol, tf, i);
            
            // Bearish candle: close < open
            if(close_price < open_price) {
               ob_out.time     = iTime(_Symbol, tf, i);
               ob_out.ob_high  = iHigh(_Symbol, tf, i);
               ob_out.ob_low   = iLow(_Symbol, tf, i);
               ob_out.type     = OB_BULLISH;
               ob_out.is_valid = true;
               return true;
            }
         }
      }
      
      //--- Bearish OB: after bearish BOS, find the last bullish candle before it
      if(!bos.is_bullish) {
         for(int i = bos_shift + 1; i < bos_shift + 20; i++) {
            double open_price  = iOpen(_Symbol, tf, i);
            double close_price = iClose(_Symbol, tf, i);
            
            // Bullish candle: close > open
            if(close_price > open_price) {
               ob_out.time     = iTime(_Symbol, tf, i);
               ob_out.ob_high  = iHigh(_Symbol, tf, i);
               ob_out.ob_low   = iLow(_Symbol, tf, i);
               ob_out.type     = OB_BEARISH;
               ob_out.is_valid = true;
               return true;
            }
         }
      }
      
      return false;
   }
   
   //--- Draw OB rectangle on chart
   //    Only draws if object does not already exist
   void DrawOBRectangle(const StructOrderBlock &ob) {
      if(!ob.is_valid || ob.type == OB_NONE) return;
      
      string obj_name = MakeOBName(ob.type, ob.time);
      
      // Skip if object already exists
      if(ObjectExists(obj_name)) return;
      
      // Create rectangle from OB time extending to current time + 100 bars
      datetime time_start = ob.time;
      datetime time_end   = iTime(_Symbol, PERIOD_M15, 0) + (100 * 900); // +100 M15 bars
      
      color ob_color = (ob.type == OB_BULLISH) ? clrDodgerBlue : clrTomato;
      
      if(ObjectCreate(0, obj_name, OBJ_RECTANGLE, 0,
                       time_start, ob.ob_high,
                       time_end,   ob.ob_low)) {
         ObjectSetInteger(0, obj_name, OBJPROP_COLOR, ob_color);
         ObjectSetInteger(0, obj_name, OBJPROP_FILL,  false);
         ObjectSetInteger(0, obj_name, OBJPROP_WIDTH, 1);
         ObjectSetString(0, obj_name, OBJPROP_TEXT,
                          (ob.type == OB_BULLISH) ? "OB Bullish" : "OB Bearish");
         ObjectSetInteger(0, obj_name, OBJPROP_BACK, true);
      }
   }
   
   //--- Full zone evaluation: Sweep -> BOS -> OB
   void EvaluateZones(ENUM_TIMEFRAMES tf,
                      double swing_high_price, datetime swing_high_time,
                      double swing_low_price,  datetime swing_low_time,
                      StructZoneState &zone) {
      
      // Reset zone state
      zone.last_sweep.time       = 0;
      zone.last_sweep.price      = 0;
      zone.last_sweep.type       = SWEEP_NONE;
      zone.bos_after_sweep.time  = 0;
      zone.bos_after_sweep.price = 0;
      zone.bos_after_sweep.is_bullish = false;
      zone.last_ob.time          = 0;
      zone.last_ob.ob_high       = 0;
      zone.last_ob.ob_low        = 0;
      zone.last_ob.type          = OB_NONE;
      zone.last_ob.is_valid      = false;
      zone.zone_status           = ZONE_NO_TRADE;
      
      //--- Step 1: Detect sweep
      if(!DetectSweep(tf, swing_high_price, swing_high_time,
                       swing_low_price, swing_low_time,
                       zone.last_sweep)) {
         zone.zone_status = ZONE_NO_TRADE;
         return;
      }
      zone.zone_status = ZONE_SWEEP_FOUND;
      
      //--- Step 2: Detect BOS after sweep
      if(!DetectBOSAfterSweep(tf, zone.last_sweep,
                               swing_high_price, swing_low_price,
                               zone.bos_after_sweep)) {
         return;
      }
      zone.zone_status = ZONE_BOS_AFTER_SWEEP_FOUND;
      
      //--- Step 3: Detect Order Block from BOS displacement
      if(!DetectOrderBlock(tf, zone.bos_after_sweep, zone.last_ob)) {
         return;
      }
      
      //--- V0.2.1: Validate OB strictly before accepting
      if(!IsValidOrderBlock(zone.last_ob)) {
         zone.last_ob.type     = OB_NONE;
         zone.last_ob.is_valid = false;
         return; // status stays BOS_AFTER_SWEEP_FOUND
      }
      zone.zone_status = ZONE_OB_FOUND;
      
      //--- Step 4: Draw OB on chart
      DrawOBRectangle(zone.last_ob);
      
      //--- Step 5: Set status to WAIT_RETRACE (OB found, waiting for price to return)
      zone.zone_status = ZONE_WAIT_RETRACE;
   }
};
