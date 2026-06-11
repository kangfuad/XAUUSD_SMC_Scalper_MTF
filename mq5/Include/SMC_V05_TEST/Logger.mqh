//+------------------------------------------------------------------+
//| Logger.mqh                                                       |
//| V0.2.1: Logging for SMC events + CSV output                      |
//|         Guard against default/empty struct values                |
//+------------------------------------------------------------------+
#property strict

#include "Types.mqh"

class CSMCLogger {
private:
   int m_csv_handle;
   bool m_csv_opened;
   
   //--- Check if chart object already exists
   bool ObjectExists(string name) {
      return ObjectFind(0, name) >= 0;
   }
   
   string TrendToString(ENUM_TREND_BIAS trend) {
      if(trend == TREND_BULLISH) return "BULLISH";
      if(trend == TREND_BEARISH) return "BEARISH";
      return "SIDEWAYS";
   }
   
   string StatusToString(ENUM_SIGNAL_STATUS status) {
      if(status == STATUS_BUY_ALLOWED) return "BUY_ALLOWED";
      if(status == STATUS_SELL_ALLOWED) return "SELL_ALLOWED";
      return "NO_TRADE";
   }
   
   string SweepTypeToString(ENUM_SWEEP_TYPE type) {
      if(type == SWEEP_BULLISH) return "BULLISH";
      if(type == SWEEP_BEARISH) return "BEARISH";
      return "NONE";
   }
   
   string OBTypeToString(ENUM_OB_TYPE type) {
      if(type == OB_BULLISH) return "BULLISH";
      if(type == OB_BEARISH) return "BEARISH";
      return "NONE";
   }
   
   string ZoneStatusToString(ENUM_ZONE_STATUS status) {
      switch(status) {
         case ZONE_NO_TRADE:              return "NO_TRADE";
         case ZONE_SWEEP_FOUND:           return "SWEEP_FOUND";
         case ZONE_BOS_AFTER_SWEEP_FOUND: return "BOS_AFTER_SWEEP_FOUND";
         case ZONE_OB_FOUND:              return "OB_FOUND";
         case ZONE_WAIT_RETRACE:          return "WAIT_RETRACE";
         //--- V0.3 Statuses
         case ZONE_RETRACE_FOUND:         return "RETRACE_FOUND";
         case ZONE_WAIT_CONFIRMATION:     return "WAIT_CONFIRMATION";
         case ZONE_READY_BUY:             return "READY_BUY";
         case ZONE_READY_SELL:            return "READY_SELL";
      }
      return "NO_TRADE";
   }
   
   //--- V0.3: M5 Confirm Type to String
   string M5ConfirmTypeToString(ENUM_M5_CONFIRM_TYPE type) {
      if(type == M5_CONFIRM_BULLISH_MSS) return "BULLISH_MSS";
      if(type == M5_CONFIRM_BEARISH_MSS) return "BEARISH_MSS";
      return "NONE";
   }
   
   //--- V0.3: Candle Confirm Type to String
   string CandleConfirmTypeToString(ENUM_CANDLE_CONFIRM type) {
      if(type == CANDLE_CONFIRM_BUY)  return "BUY";
      if(type == CANDLE_CONFIRM_SELL) return "SELL";
      return "NONE";
   }
   
public:
   //--- V0.4: Zone Status to String (public wrapper)
   string GetSignalStatusString(ENUM_ZONE_STATUS status) {
      return ZoneStatusToString(status);
   }
   
   CSMCLogger() {
      m_csv_handle = INVALID_HANDLE;
      m_csv_opened = false;
   }
   
   ~CSMCLogger() {
      CloseCSV();
   }
   
   //--- Open CSV file for appending
   bool OpenCSV() {
      if(m_csv_opened) return true;
      string filename = "XAUUSD_SMC_V02_SweepOBLog.csv";
      
      bool file_exists = FileIsExist(filename);
      
      m_csv_handle = FileOpen(filename, FILE_WRITE|FILE_READ|FILE_CSV|FILE_ANSI, ',');
      if(m_csv_handle == INVALID_HANDLE) {
         Print("CSV ERROR: Cannot open ", filename, " Error: ", GetLastError());
         return false;
      }
      
      if(!file_exists || FileSize(m_csv_handle) == 0) {
         FileSeek(m_csv_handle, 0, SEEK_END);
         FileWrite(m_csv_handle,
            "time", "symbol", "timeframe", "m15_trend",
            "sweep_type", "sweep_time", "sweep_price",
            "bos_type", "bos_time", "bos_price",
            "ob_type", "ob_time", "ob_high", "ob_low",
            "status");
         FileFlush(m_csv_handle);
      } else {
         FileSeek(m_csv_handle, 0, SEEK_END);
      }
      
      m_csv_opened = true;
      return true;
   }
   
   //--- Close CSV file
   void CloseCSV() {
      if(m_csv_handle != INVALID_HANDLE) {
         FileClose(m_csv_handle);
         m_csv_handle = INVALID_HANDLE;
         m_csv_opened = false;
      }
   }
   
   //--- V0.1 Log: Market state (unchanged)
   void LogMarketState(const string symbol, const StructMarketState &state) {
      string log_msg = StringFormat("[%s] %s | M15 Trend: %s | Last SH: %.5f | Last SL: %.5f | Last BOS: %s @ %.5f | Status: %s",
         TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS),
         symbol,
         TrendToString(state.m15_trend),
         state.last_swing_high.price,
         state.last_swing_low.price,
         state.last_bos.is_bullish ? "BULLISH" : "BEARISH",
         state.last_bos.price,
         StatusToString(state.signal_status)
      );
      Print(log_msg);
   }
   
   //--- V0.2.1 Log: Zone state (Print toExperts tab)
   //         Guard: if OB not valid, print "OB: NONE" instead of garbage
   void LogZoneState(const string symbol,
                     const StructMarketState &mkt,
                     const StructZoneState &zone) {
      
      string trend_str = TrendToString(mkt.m15_trend);
      string sweep_str = SweepTypeToString(zone.last_sweep.type);
      string sweep_time_str = (zone.last_sweep.time > 0) ?
                              TimeToString(zone.last_sweep.time, TIME_DATE|TIME_MINUTES) : "-";
      
      string bos_str = "NONE";
      string bos_time_str = "-";
      double bos_price = 0;
      if(zone.bos_after_sweep.price > 0) {
         bos_str = zone.bos_after_sweep.is_bullish ? "BULLISH" : "BEARISH";
         bos_time_str = (zone.bos_after_sweep.time > 0) ?
                        TimeToString(zone.bos_after_sweep.time, TIME_DATE|TIME_MINUTES) : "-";
         bos_price = zone.bos_after_sweep.price;
      }
      
      // V0.2.1: Guard OB output
      string ob_str = "NONE";
      string ob_detail = "";
      if(IsValidOrderBlock(zone.last_ob)) {
         ob_str = OBTypeToString(zone.last_ob.type);
         ob_detail = StringFormat("H:%.5f L:%.5f (%s)",
                        zone.last_ob.ob_high,
                        zone.last_ob.ob_low,
                        TimeToString(zone.last_ob.time, TIME_DATE|TIME_MINUTES));
      }
      
      string status_str = ZoneStatusToString(zone.zone_status);
      
      string log_msg = StringFormat(
         "[%s] %s M15 | Trend: %s | "
         "Sweep: %s @ %.5f (%s) | "
         "BOS: %s @ %.5f (%s) | "
         "OB: %s %s| "
         "Status: %s",
         TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS),
         symbol,
         trend_str,
         sweep_str,
         zone.last_sweep.price,
         sweep_time_str,
         bos_str,
         bos_price,
         bos_time_str,
         ob_str,
         ob_detail,
         status_str
      );
      
      Print(log_msg);
   }
   
   //--- V0.2.1 Log: Write to CSV
   //         Guard: if OB not valid, write NONE/0/0 instead of 1970/0.00000
   void LogZoneStateCSV(const string symbol,
                        const StructMarketState &mkt,
                        const StructZoneState &zone) {
      if(!OpenCSV()) return;
      
      string time_str    = TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS);
      string trend_str   = TrendToString(mkt.m15_trend);
      
      // Sweep
      string sweep_str   = SweepTypeToString(zone.last_sweep.type);
      string sweep_time  = (zone.last_sweep.time > 0) ?
                            TimeToString(zone.last_sweep.time, TIME_DATE|TIME_SECONDS) : "NONE";
      string sweep_price = (zone.last_sweep.price > 0) ?
                            DoubleToString(zone.last_sweep.price, 5) : "0";
      
      // BOS
      string bos_str     = "NONE";
      string bos_time    = "NONE";
      string bos_price   = "0";
      if(zone.bos_after_sweep.price > 0) {
         bos_str   = zone.bos_after_sweep.is_bullish ? "BULLISH" : "BEARISH";
         bos_time  = (zone.bos_after_sweep.time > 0) ?
                      TimeToString(zone.bos_after_sweep.time, TIME_DATE|TIME_SECONDS) : "NONE";
         bos_price = DoubleToString(zone.bos_after_sweep.price, 5);
      }
      
      // V0.2.1: Guard OB - write NONE/0/0 if invalid
      string ob_str      = "NONE";
      string ob_time     = "NONE";
      string ob_high     = "0";
      string ob_low      = "0";
      if(IsValidOrderBlock(zone.last_ob)) {
         ob_str   = OBTypeToString(zone.last_ob.type);
         ob_time  = TimeToString(zone.last_ob.time, TIME_DATE|TIME_SECONDS);
         ob_high  = DoubleToString(zone.last_ob.ob_high, 5);
         ob_low   = DoubleToString(zone.last_ob.ob_low, 5);
      }
      
      string status_str  = ZoneStatusToString(zone.zone_status);
      
      FileWrite(m_csv_handle,
         time_str,
         symbol,
         "M15",
         trend_str,
         sweep_str,
         sweep_time,
         sweep_price,
         bos_str,
         bos_time,
         bos_price,
         ob_str,
         ob_time,
         ob_high,
         ob_low,
         status_str
      );
      FileFlush(m_csv_handle);
   }

   //--- V0.3: Open V0.3 CSV file with extended headers
   bool OpenCSVV03() {
      if(m_csv_opened) return true;
      string filename = "XAUUSD_SMC_V03_ConfirmationLog.csv";
      
      bool file_exists = FileIsExist(filename);
      
      m_csv_handle = FileOpen(filename, FILE_WRITE|FILE_READ|FILE_CSV|FILE_ANSI, ',');
      if(m_csv_handle == INVALID_HANDLE) {
         Print("CSV ERROR: Cannot open ", filename, " Error: ", GetLastError());
         return false;
      }
      
      if(!file_exists || FileSize(m_csv_handle) == 0) {
         FileSeek(m_csv_handle, 0, SEEK_END);
         FileWrite(m_csv_handle,
            "time", "symbol", "m15_trend",
            "sweep_type", "sweep_time", "sweep_price",
            "bos_type", "bos_time", "bos_price",
            "ob_type", "ob_time", "ob_high", "ob_low",
            "retrace_time", "retrace_price",
            "m5_confirm_type", "m5_confirm_time", "m5_confirm_price",
            "candle_confirm_type", "candle_confirm_time", "candle_confirm_price",
            "status");
         FileFlush(m_csv_handle);
      } else {
         FileSeek(m_csv_handle, 0, SEEK_END);
      }
      
      m_csv_opened = true;
      return true;
   }
   
   //--- V0.3 Log: Confirmation state (Print to Experts tab)
   void LogConfirmationState(const string symbol,
                             const StructMarketState &mkt,
                             const StructConfirmationState &conf) {
      
      string trend_str  = TrendToString(mkt.m15_trend);
      string status_str = ZoneStatusToString(conf.final_status);
      
      // Sweep (from mkt swings via last zone - but we use market state)
      string sweep_str = "NONE";
      string bos_str   = "NONE";
      string ob_str    = "NONE";
      
      // Retrace
      string retrace_str = "NONE";
      string retrace_detail = "";
      if(conf.retrace.is_valid && conf.retrace.time > 0) {
         retrace_str = "FOUND";
         retrace_detail = StringFormat("@ %.5f (%s)",
                           conf.retrace.price,
                           TimeToString(conf.retrace.time, TIME_DATE|TIME_MINUTES));
      }
      
      // M5 Confirm
      string m5_str = "NONE";
      string m5_detail = "";
      if(conf.m5_confirm.is_valid && conf.m5_confirm.time > 0) {
         m5_str = M5ConfirmTypeToString(conf.m5_confirm.type);
         m5_detail = StringFormat("@ %.5f (%s)",
                           conf.m5_confirm.price,
                           TimeToString(conf.m5_confirm.time, TIME_DATE|TIME_MINUTES));
      }
      
      // Candle Confirm
      string candle_str = "NONE";
      string candle_detail = "";
      if(conf.candle_confirm.is_valid && conf.candle_confirm.time > 0) {
         candle_str = CandleConfirmTypeToString(conf.candle_confirm.type);
         candle_detail = StringFormat("@ %.5f (%s)",
                           conf.candle_confirm.close_price,
                           TimeToString(conf.candle_confirm.time, TIME_DATE|TIME_MINUTES));
      }
      
      string log_msg = StringFormat(
         "[%s] %s M15 | Trend: %s | "
         "Retrace: %s %s | "
         "M5_Conf: %s %s | "
         "Candle: %s %s | "
         "Status: %s",
         TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS),
         symbol,
         trend_str,
         retrace_str,
         retrace_detail,
         m5_str,
         m5_detail,
         candle_str,
         candle_detail,
         status_str
      );
      
      Print(log_msg);
   }
   
   //--- V0.3 Log: Write confirmation state to CSV
   void LogConfirmationStateCSV(const string symbol,
                                const StructMarketState &mkt,
                                const StructConfirmationState &conf,
                                const StructOrderBlock &ob) {
      if(!OpenCSVV03()) return;
      
      string time_str    = TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS);
      string trend_str   = TrendToString(mkt.m15_trend);
      
      // Market state sweeps (simplified - use market state swings)
      string sweep_str   = "NONE";
      string sweep_time  = "NONE";
      string sweep_price = "0";
      if(mkt.last_swing_high.price > 0 || mkt.last_swing_low.price > 0) {
         // Not perfect but provides some context
      }
      
      // BOS
      string bos_str     = "NONE";
      string bos_time    = "NONE";
      string bos_price   = "0";
      if(mkt.last_bos.price > 0) {
         bos_str   = mkt.last_bos.is_bullish ? "BULLISH" : "BEARISH";
         bos_time  = (mkt.last_bos.time > 0) ?
                     TimeToString(mkt.last_bos.time, TIME_DATE|TIME_SECONDS) : "NONE";
         bos_price = DoubleToString(mkt.last_bos.price, 5);
      }
      
      // OB (from passed struct)
      string ob_str      = "NONE";
      string ob_time     = "NONE";
      string ob_high     = "0";
      string ob_low      = "0";
      if(IsValidOrderBlock(ob)) {
         ob_str   = OBTypeToString(ob.type);
         ob_time  = TimeToString(ob.time, TIME_DATE|TIME_SECONDS);
         ob_high  = DoubleToString(ob.ob_high, 5);
         ob_low   = DoubleToString(ob.ob_low, 5);
      }
      
      // Retrace
      string retrace_time  = (conf.retrace.is_valid && conf.retrace.time > 0) ?
                              TimeToString(conf.retrace.time, TIME_DATE|TIME_SECONDS) : "NONE";
      string retrace_price = (conf.retrace.is_valid && conf.retrace.price > 0) ?
                              DoubleToString(conf.retrace.price, 5) : "0";
      
      // M5 Confirm
      string m5_type  = (conf.m5_confirm.is_valid) ?
                         M5ConfirmTypeToString(conf.m5_confirm.type) : "NONE";
      string m5_time  = (conf.m5_confirm.is_valid && conf.m5_confirm.time > 0) ?
                         TimeToString(conf.m5_confirm.time, TIME_DATE|TIME_SECONDS) : "NONE";
      string m5_price = (conf.m5_confirm.is_valid && conf.m5_confirm.price > 0) ?
                         DoubleToString(conf.m5_confirm.price, 5) : "0";
      
      // Candle Confirm
      string candle_type  = (conf.candle_confirm.is_valid) ?
                             CandleConfirmTypeToString(conf.candle_confirm.type) : "NONE";
      string candle_time  = (conf.candle_confirm.is_valid && conf.candle_confirm.time > 0) ?
                             TimeToString(conf.candle_confirm.time, TIME_DATE|TIME_SECONDS) : "NONE";
      string candle_price = (conf.candle_confirm.is_valid && conf.candle_confirm.close_price > 0) ?
                             DoubleToString(conf.candle_confirm.close_price, 5) : "0";
      
      string status_str  = ZoneStatusToString(conf.final_status);
      
      FileWrite(m_csv_handle,
         time_str,
         symbol,
         trend_str,
         sweep_str,
         sweep_time,
         sweep_price,
         bos_str,
         bos_time,
         bos_price,
         ob_str,
         ob_time,
         ob_high,
         ob_low,
         retrace_time,
         retrace_price,
         m5_type,
         m5_time,
         m5_price,
         candle_type,
         candle_time,
         candle_price,
         status_str
      );
      FileFlush(m_csv_handle);
   }

   //--- V0.4: Trade Direction to String
   string TradeDirectionToString(ENUM_TRADE_DIRECTION dir) {
      if(dir == TRADE_DIR_BUY)  return "BUY";
      if(dir == TRADE_DIR_SELL) return "SELL";
      return "NONE";
   }
   
   //--- V0.4: Trade Plan Status to String
   string TradePlanStatusToString(ENUM_TRADE_PLAN_STATUS status) {
      if(status == TRADE_PLAN_VALID)    return "VALID";
      if(status == TRADE_PLAN_REJECTED) return "REJECTED";
      return "NONE";
   }
   
   //--- V0.4: Open V0.4 CSV file
   bool OpenCSVV04() {
      if(m_csv_opened) return true;
      string filename = "XAUUSD_SMC_V04_TradePlanLog.csv";
      
      bool file_exists = FileIsExist(filename);
      
      m_csv_handle = FileOpen(filename, FILE_WRITE|FILE_READ|FILE_CSV|FILE_ANSI, ',');
      if(m_csv_handle == INVALID_HANDLE) {
         Print("CSV ERROR: Cannot open ", filename, " Error: ", GetLastError());
         return false;
      }
      
      if(!file_exists || FileSize(m_csv_handle) == 0) {
         FileSeek(m_csv_handle, 0, SEEK_END);
         FileWrite(m_csv_handle,
            "time", "symbol", "signal_status",
            "direction", "entry_price", "sl_price", "tp_price",
            "sl_points", "tp_points", "rr",
            "risk_percent", "risk_money", "lot_size",
            "spread_points", "stop_level_points", "freeze_level_points",
            "plan_status", "reject_reason");
         FileFlush(m_csv_handle);
      } else {
         FileSeek(m_csv_handle, 0, SEEK_END);
      }
      
      m_csv_opened = true;
      return true;
   }
   
   //--- V0.4 Log: Trade Plan Journal (Print)
   void LogTradePlanPrint(const string symbol,
                          const string signal_status,
                          const StructTradePlan &plan) {
      
      if(plan.plan_status == TRADE_PLAN_NONE) return;
      
      string dir_str = TradeDirectionToString(plan.direction);
      string status_str = TradePlanStatusToString(plan.plan_status);
      string time_str = TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS);
      
      string log_msg;
      if(plan.plan_status == TRADE_PLAN_VALID) {
         log_msg = StringFormat(
            "[%s] %s | Signal: %s | %s PLAN VALID | "
            "Entry: %.5f SL: %.5f TP: %.5f | "
            "SL: %.0f pts TP: %.0f pts | "
            "RR: %.2f | Risk: %.2f%% (%.2f) | "
            "Lot: %.2f | Spread: %.0f pts | "
            "StopLvl: %d FreezeLvl: %d",
            time_str, symbol, signal_status, dir_str,
            plan.entry_price, plan.sl_price, plan.tp_price,
            plan.sl_points, plan.tp_points,
            plan.rr,
            plan.risk_percent, plan.risk_money,
            plan.lot_size,
            plan.spread_points,
            plan.stop_level_points, plan.freeze_level_points
         );
      } else {
         log_msg = StringFormat(
            "[%s] %s | Signal: %s | %s PLAN REJECTED | Reason: %s",
            time_str, symbol, signal_status, dir_str, plan.reject_reason
         );
      }
      
      Print(log_msg);
   }
   
   //--- V0.4 Log: Trade Plan CSV
   void LogTradePlanCSV(const string symbol,
                        const string signal_status,
                        const StructTradePlan &plan) {
      
      if(plan.plan_status == TRADE_PLAN_NONE) return;
      if(!OpenCSVV04()) return;
      
      string time_str   = TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS);
      string dir_str    = TradeDirectionToString(plan.direction);
      string status_str = TradePlanStatusToString(plan.plan_status);
      
      string entry_str  = (plan.entry_price > 0) ? DoubleToString(plan.entry_price, 5) : "0";
      string sl_str     = (plan.sl_price > 0) ? DoubleToString(plan.sl_price, 5) : "0";
      string tp_str     = (plan.tp_price > 0) ? DoubleToString(plan.tp_price, 5) : "0";
      
      string sl_pts_str  = (plan.sl_points > 0) ? DoubleToString(plan.sl_points, 0) : "0";
      string tp_pts_str  = (plan.tp_points > 0) ? DoubleToString(plan.tp_points, 0) : "0";
      string rr_str      = (plan.rr > 0) ? DoubleToString(plan.rr, 2) : "0";
      string risk_pct    = (plan.risk_percent > 0) ? DoubleToString(plan.risk_percent, 2) : "0";
      string risk_money  = (plan.risk_money > 0) ? DoubleToString(plan.risk_money, 2) : "0";
      string lot_str     = (plan.lot_size > 0) ? DoubleToString(plan.lot_size, 2) : "0";
      string spread_str  = (plan.spread_points > 0) ? DoubleToString(plan.spread_points, 0) : "0";
      string stop_lvl    = IntegerToString(plan.stop_level_points);
      string freeze_lvl  = IntegerToString(plan.freeze_level_points);
      string reject_str  = (plan.reject_reason != "") ? plan.reject_reason : "-";
      
      FileWrite(m_csv_handle,
         time_str, symbol, signal_status,
         dir_str,
         entry_str, sl_str, tp_str,
         sl_pts_str, tp_pts_str, rr_str,
         risk_pct, risk_money, lot_str,
         spread_str, stop_lvl, freeze_lvl,
         status_str, reject_str
      );
      FileFlush(m_csv_handle);
   }
   
   //--- V0.4: Draw trade plan markers (entry, SL, TP lines)
   void DrawTradePlanMarkers(const StructTradePlan &plan) {
      if(plan.plan_status != TRADE_PLAN_VALID) return;
      if(plan.entry_price <= 0 || plan.sl_price <= 0 || plan.tp_price <= 0) return;
      
      MqlDateTime dt;
      TimeToStruct(plan.signal_time, dt);
      
      // Entry line
      string entry_name = StringFormat("SMC_PLAN_ENTRY_%04d%02d%02d_%02d%02d",
                                       dt.year, dt.mon, dt.day, dt.hour, dt.min);
      if(!ObjectExists(entry_name)) {
         ObjectCreate(0, entry_name, OBJ_HLINE, 0, 0, plan.entry_price);
         ObjectSetInteger(0, entry_name, OBJPROP_COLOR, clrBlue);
         ObjectSetInteger(0, entry_name, OBJPROP_WIDTH, 1);
         ObjectSetInteger(0, entry_name, OBJPROP_STYLE, STYLE_DASHDOT);
         ObjectSetString(0, entry_name, OBJPROP_TEXT, "ENTRY");
      }
      
      // SL line
      string sl_name = StringFormat("SMC_PLAN_SL_%04d%02d%02d_%02d%02d",
                                    dt.year, dt.mon, dt.day, dt.hour, dt.min);
      if(!ObjectExists(sl_name)) {
         ObjectCreate(0, sl_name, OBJ_HLINE, 0, 0, plan.sl_price);
         ObjectSetInteger(0, sl_name, OBJPROP_COLOR, clrRed);
         ObjectSetInteger(0, sl_name, OBJPROP_WIDTH, 1);
         ObjectSetInteger(0, sl_name, OBJPROP_STYLE, STYLE_DASHDOT);
         ObjectSetString(0, sl_name, OBJPROP_TEXT, "SL");
      }
      
      // TP line
      string tp_name = StringFormat("SMC_PLAN_TP_%04d%02d%02d_%02d%02d",
                                    dt.year, dt.mon, dt.day, dt.hour, dt.min);
      if(!ObjectExists(tp_name)) {
         ObjectCreate(0, tp_name, OBJ_HLINE, 0, 0, plan.tp_price);
         ObjectSetInteger(0, tp_name, OBJPROP_COLOR, clrGreen);
         ObjectSetInteger(0, tp_name, OBJPROP_WIDTH, 1);
         ObjectSetInteger(0, tp_name, OBJPROP_STYLE, STYLE_DASHDOT);
         ObjectSetString(0, tp_name, OBJPROP_TEXT, "TP");
      }
   }
   
   //--- V0.4: Draw rejected trade plan marker
   void DrawTradePlanRejected(const StructTradePlan &plan) {
      if(plan.plan_status != TRADE_PLAN_REJECTED) return;
      if(plan.entry_price <= 0) return;
      if(plan.reject_reason == "") return;
      
      MqlDateTime dt;
      TimeToStruct(plan.signal_time, dt);
      
      string obj_name = StringFormat("SMC_PLAN_REJECTED_%04d%02d%02d_%02d%02d",
                                      dt.year, dt.mon, dt.day, dt.hour, dt.min);
      
      if(ObjectExists(obj_name)) return;
      
      // Show reject reason as text
      string short_reason = plan.reject_reason;
      if(StringLen(short_reason) > 30) {
         short_reason = StringSubstr(short_reason, 0, 30) + "...";
      }
      
      ObjectCreate(0, obj_name, OBJ_TEXT, 0, plan.signal_time, plan.entry_price);
      ObjectSetString(0, obj_name, OBJPROP_TEXT, "REJECTED: " + short_reason);
      ObjectSetInteger(0, obj_name, OBJPROP_COLOR, clrGray);
      ObjectSetInteger(0, obj_name, OBJPROP_FONTSIZE, 8);
   }

   //--- V0.5: Execution Status to String
   string ExecutionStatusToString(ENUM_EXECUTION_STATUS status) {
      switch(status) {
         case EXECUTION_DISABLED:        return "DISABLED";
         case EXECUTION_REJECTED:        return "REJECTED";
         case EXECUTION_ORDER_SENT:      return "ORDER_SENT";
         case EXECUTION_ORDER_FAILED:    return "ORDER_FAILED";
         case EXECUTION_POSITION_EXISTS: return "POSITION_EXISTS";
         case EXECUTION_DUPLICATE_SIGNAL: return "DUPLICATE_SIGNAL";
      }
      return "UNKNOWN";
   }
   
   //--- V0.5: Open V0.5 CSV file
   bool OpenCSVV05() {
      if(m_csv_opened) return true;
      string filename = "XAUUSD_SMC_V05_ExecutionLog.csv";
      
      bool file_exists = FileIsExist(filename);
      
      m_csv_handle = FileOpen(filename, FILE_WRITE|FILE_READ|FILE_CSV|FILE_ANSI, ',');
      if(m_csv_handle == INVALID_HANDLE) {
         Print("CSV ERROR: Cannot open ", filename, " Error: ", GetLastError());
         return false;
      }
      
      if(!file_exists || FileSize(m_csv_handle) == 0) {
         FileSeek(m_csv_handle, 0, SEEK_END);
         FileWrite(m_csv_handle,
            "time", "symbol", "mode",
            "signal_time", "direction",
            "entry", "sl", "tp",
            "lot", "rr", "risk_money", "spread_points",
            "magic",
            "execution_status", "ticket", "retcode", "error_code",
            "reason", "balance", "equity");
         FileFlush(m_csv_handle);
      } else {
         FileSeek(m_csv_handle, 0, SEEK_END);
      }
      
      m_csv_opened = true;
      return true;
   }
   
   //--- V0.5 Log: Execution Journal (Print)
   void LogExecutionPrint(const string symbol,
                           const string mode,
                           const StructTradePlan &plan,
                           ENUM_EXECUTION_STATUS exec_status,
                           ulong ticket,
                           uint retcode,
                           int error_code,
                           const string reason) {
      
      if(exec_status == EXECUTION_DISABLED) return;
      
      string time_str   = TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS);
      string status_str = ExecutionStatusToString(exec_status);
      string dir_str    = TradeDirectionToString(plan.direction);
      string signal_str = (plan.direction == TRADE_DIR_BUY) ? "READY_BUY" :
                          (plan.direction == TRADE_DIR_SELL) ? "READY_SELL" : "NONE";
      
      string log_msg;
      if(exec_status == EXECUTION_ORDER_SENT) {
         log_msg = StringFormat(
            "[%s] %s | V0.5 EXECUTION | %s | PLAN VALID | %s | "
            "ticket=%d | lot=%.2f | entry=%.2f | SL=%.2f | TP=%.2f | RR=%.2f",
            time_str, symbol, signal_str, status_str,
            ticket, plan.lot_size,
            plan.entry_price, plan.sl_price, plan.tp_price, plan.rr
         );
      } else {
         log_msg = StringFormat(
            "[%s] %s | V0.5 EXECUTION | %s | %s | %s | reason=%s",
            time_str, symbol, signal_str, status_str, 
            (ticket > 0 ? StringFormat("ticket=%d", ticket) : ""),
            reason
         );
      }
      
      Print(log_msg);
   }
   
   //--- V0.5 Log: Execution CSV
   void LogExecutionCSV(const string symbol,
                        const string mode,
                        const StructTradePlan &plan,
                        ENUM_EXECUTION_STATUS exec_status,
                        ulong ticket,
                        uint retcode,
                        int error_code,
                        const string reason) {
      
      if(exec_status == EXECUTION_DISABLED) return;
      if(!OpenCSVV05()) return;
      
      string time_str   = TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS);
      string sig_str    = TimeToString(plan.signal_time, TIME_DATE|TIME_SECONDS);
      string dir_str    = TradeDirectionToString(plan.direction);
      string status_str = ExecutionStatusToString(exec_status);
      string ticket_str = (ticket > 0) ? IntegerToString(ticket) : "0";
      string retcode_str= (retcode > 0) ? IntegerToString(retcode) : "0";
      string err_str    = (error_code > 0) ? IntegerToString(error_code) : "0";
      
      string entry_s    = (plan.entry_price > 0) ? DoubleToString(plan.entry_price, 5) : "0";
      string sl_s       = (plan.sl_price > 0) ? DoubleToString(plan.sl_price, 5) : "0";
      string tp_s       = (plan.tp_price > 0) ? DoubleToString(plan.tp_price, 5) : "0";
      string lot_s      = (plan.lot_size > 0) ? DoubleToString(plan.lot_size, 2) : "0";
      string rr_s       = (plan.rr > 0) ? DoubleToString(plan.rr, 2) : "0";
      string risk_s     = (plan.risk_money > 0) ? DoubleToString(plan.risk_money, 2) : "0";
      string spread_s   = (plan.spread_points > 0) ? DoubleToString(plan.spread_points, 0) : "0";
      
      double balance = AccountInfoDouble(ACCOUNT_BALANCE);
      double equity  = AccountInfoDouble(ACCOUNT_EQUITY);
      
      FileWrite(m_csv_handle,
         time_str, symbol, mode,
         sig_str, dir_str,
         entry_s, sl_s, tp_s,
         lot_s, rr_s, risk_s, spread_s,
         IntegerToString(plan.stop_level_points),
         status_str, ticket_str, retcode_str, err_str,
         reason,
         DoubleToString(balance, 2),
         DoubleToString(equity, 2)
      );
      FileFlush(m_csv_handle);
   }
};
