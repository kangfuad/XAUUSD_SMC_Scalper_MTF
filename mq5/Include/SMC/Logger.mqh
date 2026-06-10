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
};
