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
      }
      return "NO_TRADE";
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
};
