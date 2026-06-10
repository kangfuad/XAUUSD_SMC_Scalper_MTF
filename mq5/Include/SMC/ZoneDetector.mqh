//+------------------------------------------------------------------+
//| ZoneDetector.mqh                                                 |
//| V0.2: Liquidity Sweep + Order Block detection                    |
//|       Closed candles only. No entry logic.                       |
//| V0.3: Added retrace detection + M5 confirmation + candle confirm |
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
   
   //--- V0.3: Detect Retrace to Order Block
   //    Bullish: Low of M15 or M5 candle touches OB zone (low enters ob_low..ob_high)
   //    Bearish: High of M15 or M5 candle touches OB zone (high enters ob_low..ob_high)
   //    Closed candles only (shift >= 1)
   //    after_time: only check candles after this time (after OB was found)
   bool DetectRetrace(ENUM_TIMEFRAMES tf,
                      const StructOrderBlock &ob,
                      datetime after_time,
                      StructRetrace &retrace_out) {
      
      retrace_out.time     = 0;
      retrace_out.price    = 0;
      retrace_out.is_valid = false;
      
      if(!IsValidOrderBlock(ob)) return false;
      
      int start_shift = iBarShift(_Symbol, tf, after_time);
      if(start_shift < 0) start_shift = 1;
      
      // Check M15 candles first
      for(int i = 1; i <= start_shift && i < 50; i++) {
         datetime candle_time = iTime(_Symbol, tf, i);
         if(candle_time <= after_time) continue;
         
         double candle_low  = iLow(_Symbol, tf, i);
         double candle_high = iHigh(_Symbol, tf, i);
         
         // Bullish OB retrace: low enters OB zone
         if(ob.type == OB_BULLISH) {
            if(candle_low <= ob.ob_high && candle_low >= ob.ob_low) {
               retrace_out.time     = candle_time;
               retrace_out.price    = candle_low;
               retrace_out.is_valid = true;
               return true;
            }
         }
         
         // Bearish OB retrace: high enters OB zone
         if(ob.type == OB_BEARISH) {
            if(candle_high >= ob.ob_low && candle_high <= ob.ob_high) {
               retrace_out.time     = candle_time;
               retrace_out.price    = candle_high;
               retrace_out.is_valid = true;
               return true;
            }
         }
      }
      
      // Check M5 candles for more granular detection
      for(int i = 1; i < 200; i++) { // max 200 M5 candles (~16 hours)
         datetime candle_time = iTime(_Symbol, PERIOD_M5, i);
         if(candle_time <= after_time) break;
         
         double candle_low  = iLow(_Symbol, PERIOD_M5, i);
         double candle_high = iHigh(_Symbol, PERIOD_M5, i);
         
         // Bullish OB retrace: low enters OB zone
         if(ob.type == OB_BULLISH) {
            if(candle_low <= ob.ob_high && candle_low >= ob.ob_low) {
               retrace_out.time     = candle_time;
               retrace_out.price    = candle_low;
               retrace_out.is_valid = true;
               return true;
            }
         }
         
         // Bearish OB retrace: high enters OB zone
         if(ob.type == OB_BEARISH) {
            if(candle_high >= ob.ob_low && candle_high <= ob.ob_high) {
               retrace_out.time     = candle_time;
               retrace_out.price    = candle_high;
               retrace_out.is_valid = true;
               return true;
            }
         }
      }
      
      return false;
   }
   
   //--- V0.3: Detect M5 Confirmation (MSS/ChoCH)
   //    Bullish: M5 close breaks above last minor swing high M5 after retrace
   //    Bearish: M5 close breaks below last minor swing low M5 after retrace
   //    Closed candles only (shift >= 1)
   bool DetectM5Confirmation(const StructRetrace &retrace,
                              ENUM_OB_TYPE ob_type,
                              StructM5Confirm &confirm_out) {
      
      confirm_out.time     = 0;
      confirm_out.price    = 0;
      confirm_out.type     = M5_CONFIRM_NONE;
      confirm_out.is_valid = false;
      
      if(!retrace.is_valid) return false;
      
      int retrace_shift = iBarShift(_Symbol, PERIOD_M5, retrace.time);
      if(retrace_shift < 0) return false;
      
      // Look for minor swing in the range before retrace
      int search_end = retrace_shift + 50; // search up to 50 candles before retrace
      if(search_end > 200) search_end = 200;
      
      double mss_price = 0;
      datetime mss_time = 0;
      
      if(ob_type == OB_BULLISH) {
         if(m_ms.DetectBullishMSS_M5(1, search_end, retrace.time, mss_price, mss_time)) {
            confirm_out.time     = mss_time;
            confirm_out.price    = mss_price;
            confirm_out.type     = M5_CONFIRM_BULLISH_MSS;
            confirm_out.is_valid = true;
            return true;
         }
      }
      
      if(ob_type == OB_BEARISH) {
         if(m_ms.DetectBearishMSS_M5(1, search_end, retrace.time, mss_price, mss_time)) {
            confirm_out.time     = mss_time;
            confirm_out.price    = mss_price;
            confirm_out.type     = M5_CONFIRM_BEARISH_MSS;
            confirm_out.is_valid = true;
            return true;
         }
      }
      
      return false;
   }
   
   //--- V0.3: Detect Candle Confirmation on M5
   //    BUY: M5 candle is bullish (close > open) AND close > OB high
   //    SELL: M5 candle is bearish (close < open) AND close < OB low
   //    Must happen after M5 confirmation
   //    Closed candle only (shift >= 1)
   bool DetectCandleConfirmation(const StructM5Confirm &m5_confirm,
                                  const StructOrderBlock &ob,
                                  datetime after_time,
                                  StructCandleConfirm &candle_out) {
      
      candle_out.time        = 0;
      candle_out.close_price = 0;
      candle_out.type        = CANDLE_CONFIRM_NONE;
      candle_out.is_valid    = false;
      
      if(!m5_confirm.is_valid || !IsValidOrderBlock(ob)) return false;
      
      int start_shift = iBarShift(_Symbol, PERIOD_M5, after_time);
      if(start_shift < 0) start_shift = 1;
      
      // Check M5 candles after the M5 confirmation
      for(int i = 1; i <= start_shift && i < 50; i++) {
         datetime candle_time = iTime(_Symbol, PERIOD_M5, i);
         if(candle_time <= after_time) continue;
         
         double open_price  = iOpen(_Symbol, PERIOD_M5, i);
         double close_price = iClose(_Symbol, PERIOD_M5, i);
         
         // BUY confirmation: bullish candle close above OB high
         if(ob.type == OB_BULLISH) {
            if(close_price > open_price && close_price > ob.ob_high) {
               candle_out.time        = candle_time;
               candle_out.close_price = close_price;
               candle_out.type        = CANDLE_CONFIRM_BUY;
               candle_out.is_valid    = true;
               return true;
            }
         }
         
         // SELL confirmation: bearish candle close below OB low
         if(ob.type == OB_BEARISH) {
            if(close_price < open_price && close_price < ob.ob_low) {
               candle_out.time        = candle_time;
               candle_out.close_price = close_price;
               candle_out.type        = CANDLE_CONFIRM_SELL;
               candle_out.is_valid    = true;
               return true;
            }
         }
      }
      
      return false;
   }
   
   //--- V0.3: Draw retrace marker
   void DrawRetraceMarker(const StructRetrace &retrace) {
      if(!retrace.is_valid || retrace.time == 0) return;
      
      MqlDateTime dt;
      TimeToStruct(retrace.time, dt);
      string obj_name = StringFormat("SMC_RETRACE_%04d%02d%02d_%02d%02d",
                                     dt.year, dt.mon, dt.day, dt.hour, dt.min);
      
      if(ObjectExists(obj_name)) return;
      
      if(ObjectCreate(0, obj_name, OBJ_ARROW, 0, retrace.time, retrace.price)) {
         ObjectSetInteger(0, obj_name, OBJPROP_ARROWCODE, 159); // small dot
         ObjectSetInteger(0, obj_name, OBJPROP_COLOR, clrGold);
         ObjectSetInteger(0, obj_name, OBJPROP_WIDTH, 2);
         ObjectSetString(0, obj_name, OBJPROP_TEXT, "Retrace");
      }
   }
   
   //--- V0.3: Draw READY marker
   void DrawReadyMarker(ENUM_ZONE_STATUS status, datetime time, double price) {
      if(status != ZONE_READY_BUY && status != ZONE_READY_SELL) return;
      if(time == 0) return;
      
      MqlDateTime dt;
      TimeToStruct(time, dt);
      string obj_name = StringFormat("SMC_READY_%s_%04d%02d%02d_%02d%02d",
                                     (status == ZONE_READY_BUY) ? "BUY" : "SELL",
                                     dt.year, dt.mon, dt.day, dt.hour, dt.min);
      
      if(ObjectExists(obj_name)) return;
      
      if(ObjectCreate(0, obj_name, OBJ_TEXT, 0, time, price)) {
         ObjectSetString(0, obj_name, OBJPROP_TEXT,
                          (status == ZONE_READY_BUY) ? "BUY" : "SELL");
         ObjectSetInteger(0, obj_name, OBJPROP_COLOR,
                           (status == ZONE_READY_BUY) ? clrLime : clrRed);
         ObjectSetInteger(0, obj_name, OBJPROP_FONTSIZE, 10);
         ObjectSetString(0, obj_name, OBJPROP_FONT, "Arial Bold");
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

   //--- V0.3: Full confirmation evaluation (chained: Sweep->BOS->OB->Retrace->M5Confirm->CandleConfirm)
   void EvaluateConfirmation(ENUM_TIMEFRAMES tf,
                              double swing_high_price, datetime swing_high_time,
                              double swing_low_price,  datetime swing_low_time,
                              StructConfirmationState &conf) {

      // Reset all state
      conf.retrace.time     = 0;
      conf.retrace.price    = 0;
      conf.retrace.is_valid = false;
      conf.m5_confirm.time        = 0;
      conf.m5_confirm.price       = 0;
      conf.m5_confirm.type        = M5_CONFIRM_NONE;
      conf.m5_confirm.is_valid    = false;
      conf.candle_confirm.time        = 0;
      conf.candle_confirm.close_price = 0;
      conf.candle_confirm.type        = CANDLE_CONFIRM_NONE;
      conf.candle_confirm.is_valid    = false;
      conf.final_status               = ZONE_NO_TRADE;

      // --- Phase 1: Sweep + BOS + OB (reuse existing logic)
      StructZoneState zone;
      EvaluateZones(tf, swing_high_price, swing_high_time,
                    swing_low_price, swing_low_time, zone);

      if(!IsValidOrderBlock(zone.last_ob)) {
         conf.final_status = zone.zone_status;
         return;
      }

      // We have valid sweep+BOS+OB
      ENUM_OB_TYPE ob_type = zone.last_ob.type;

      // Check if we already hit READY_BUY or READY_SELL from previous call
      // If so, skip recomputation (markers persist)

      // --- Phase 2: Detect Retrace
      datetime ob_found_time = iTime(_Symbol, PERIOD_M15, 0); // time when OB was formed
      if(!DetectRetrace(tf, zone.last_ob, ob_found_time, conf.retrace)) {
         conf.final_status = ZONE_WAIT_RETRACE;
         return;
      }
      conf.final_status = ZONE_RETRACE_FOUND;

      // Draw retrace marker
      DrawRetraceMarker(conf.retrace);

      // --- Phase 3: Detect M5 Confirmation after retrace
      int retrace_shift = iBarShift(_Symbol, PERIOD_M5, conf.retrace.time);
      if(retrace_shift < 0) retrace_shift = 10;
      
      int search_end = retrace_shift + 50;
      if(search_end > 200) search_end = 200;

      double mss_price = 0;
      datetime mss_time = 0;
      bool m5_found = false;

      if(ob_type == OB_BULLISH) {
         if(m_ms.DetectBullishMSS_M5(1, search_end, conf.retrace.time, mss_price, mss_time)) {
            conf.m5_confirm.time     = mss_time;
            conf.m5_confirm.price    = mss_price;
            conf.m5_confirm.type     = M5_CONFIRM_BULLISH_MSS;
            conf.m5_confirm.is_valid = true;
            m5_found = true;
         }
      } else if(ob_type == OB_BEARISH) {
         if(m_ms.DetectBearishMSS_M5(1, search_end, conf.retrace.time, mss_price, mss_time)) {
            conf.m5_confirm.time     = mss_time;
            conf.m5_confirm.price    = mss_price;
            conf.m5_confirm.type     = M5_CONFIRM_BEARISH_MSS;
            conf.m5_confirm.is_valid = true;
            m5_found = true;
         }
      }

      if(!m5_found) {
         conf.final_status = ZONE_WAIT_CONFIRMATION;
         return;
      }

      // --- Phase 4: Detect Candle Confirmation after M5 confirm
      int m5_shift = iBarShift(_Symbol, PERIOD_M5, conf.m5_confirm.time);
      if(m5_shift < 0) m5_shift = 10;

      if(!DetectCandleConfirmation(conf.m5_confirm, zone.last_ob, conf.m5_confirm.time, conf.candle_confirm)) {
         conf.final_status = ZONE_WAIT_CONFIRMATION;
         return;
      }

      // All phases complete!
      if(zone.last_ob.type == OB_BULLISH && conf.candle_confirm.type == CANDLE_CONFIRM_BUY) {
         conf.final_status = ZONE_READY_BUY;
         DrawReadyMarker(ZONE_READY_BUY, conf.candle_confirm.time, conf.candle_confirm.close_price);
      } else if(zone.last_ob.type == OB_BEARISH && conf.candle_confirm.type == CANDLE_CONFIRM_SELL) {
         conf.final_status = ZONE_READY_SELL;
         DrawReadyMarker(ZONE_READY_SELL, conf.candle_confirm.time, conf.candle_confirm.close_price);
      }
   }
};
