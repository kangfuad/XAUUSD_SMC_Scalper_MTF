//+------------------------------------------------------------------+
//| SR_Logger.mqh — CSV logging for closed trades                    |
//+------------------------------------------------------------------+
#property strict

class CSRLogger {
protected:
   int    m_csv;
   string m_filename;
   
public:
   void Init(string filename) {
      m_filename = filename;
      m_csv = INVALID_HANDLE;
   }
   
   void Open() {
      if(m_csv != INVALID_HANDLE) return;
      m_csv = FileOpen(m_filename, FILE_WRITE|FILE_READ|FILE_CSV|FILE_ANSI, ',');
      if(m_csv != INVALID_HANDLE) {
         FileWrite(m_csv,
            "time","symbol","direction","m15_bias","m5_setup","m1_trigger",
            "entry_time","exit_time","entry_price","sl","tp",
            "sl_points","tp_points","lot","spread",
            "profit","balance","equity","drawdown_percent",
            "exit_reason","be_moved","be_exit",
            "daily_loss_stop","consecutive_losses","magic","reason");
         FileFlush(m_csv);
      }
   }
   
   void LogClose(string sym, int direction,
                  string m15_bias_str, string m5_setup_str, string m1_trigger_str,
                  datetime entry_time, datetime exit_time,
                  double entry_price, double sl, double tp,
                  int sl_pts, int tp_pts, double lot, int spread,
                  double profit, double balance, double equity, double dd,
                  string exit_reason, 
                  bool be_moved, bool be_exit,
                  bool daily_loss_stop, int consec_losses, long magic,
                  string reason) {
      if(m_csv == INVALID_HANDLE) return;
      
      FileWrite(m_csv,
         TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS),
         sym,
         (direction == ORDER_TYPE_BUY) ? "BUY" : "SELL",
         m15_bias_str,
         m5_setup_str,
         m1_trigger_str,
         TimeToString(entry_time),
         TimeToString(exit_time),
         DoubleToString(entry_price, (int)SymbolInfoInteger(sym, SYMBOL_DIGITS)),
         DoubleToString(sl, (int)SymbolInfoInteger(sym, SYMBOL_DIGITS)),
         DoubleToString(tp, (int)SymbolInfoInteger(sym, SYMBOL_DIGITS)),
         IntegerToString(sl_pts),
         IntegerToString(tp_pts),
         DoubleToString(lot, 2),
         IntegerToString(spread),
         DoubleToString(profit, 2),
         DoubleToString(balance, 2),
         DoubleToString(equity, 2),
         DoubleToString(dd, 2),
         exit_reason,
         be_moved ? "YES" : "NO",
         be_exit ? "YES" : "NO",
         daily_loss_stop ? "YES" : "NO",
         IntegerToString(consec_losses),
         IntegerToString((int)magic),
         reason);
      FileFlush(m_csv);
   }
   
   void Close() {
      if(m_csv != INVALID_HANDLE) {
         FileClose(m_csv);
         m_csv = INVALID_HANDLE;
      }
   }
};
//+------------------------------------------------------------------+
