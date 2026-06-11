//+------------------------------------------------------------------+
//| TradeManager.mqh                                                 |
//| V0.5: Auto Trade Controlled Mode.                                |
//|       Order execution via MqlTradeRequest/MqlTradeResult.        |
//|       No CTrade. No Trade.mqh.                                   |
//+------------------------------------------------------------------+
#property strict

#include "Types.mqh"

class CTradeManager {
private:
   string  m_symbol;
   int     m_magic;
   int     m_slippage;
   string  m_order_comment;
   
   //--- Track last executed signal to prevent duplicates
   datetime m_last_executed_signal_time;
   
   //--- Track execution stats
   int m_total_attempts;
   int m_total_success;
   int m_total_fail;
   int m_total_rejected;
   
public:
   CTradeManager() {
      m_symbol    = "";
      m_magic     = 40500;
      m_slippage  = 30;
      m_order_comment = "SMC-Scalper";
      m_last_executed_signal_time = 0;
      m_total_attempts = 0;
      m_total_success  = 0;
      m_total_fail     = 0;
      m_total_rejected = 0;
   }
   
   //--- Initialize
   void Init(string symbol, int magic, int slippage) {
      m_symbol   = symbol;
      m_magic    = magic;
      m_slippage = slippage;
      m_order_comment = "SMC-Scalper";
   }
   
   //--- Count open positions by symbol + magic
   int CountOpenPositionsByMagic() {
      int count = 0;
      for(int i = PositionsTotal() - 1; i >= 0; i--) {
         if(PositionSelectByTicket(PositionGetTicket(i))) {
            if(PositionGetString(POSITION_SYMBOL) == m_symbol &&
               PositionGetInteger(POSITION_MAGIC) == m_magic) {
               count++;
            }
         }
      }
      return count;
   }
   
   //--- Check if signal was already executed
   bool IsSignalAlreadyExecuted(datetime signal_time) {
      if(signal_time <= 0) return false;
      if(signal_time == m_last_executed_signal_time) return true;
      return false;
   }
   
   //--- Validate if trade can be executed
   ENUM_EXECUTION_STATUS CanExecute(const StructTradePlan &plan) {
      // Plan must be valid
      if(!plan.valid || plan.plan_status != TRADE_PLAN_VALID) {
         return EXECUTION_REJECTED;
      }
      
      // Lot must be valid
      if(plan.lot_size <= 0) {
         return EXECUTION_REJECTED;
      }
      
      // Prices must be valid (entry known, SL/TP via points)
      if(plan.entry_price <= 0 && plan.sl_points <= 0 && plan.tp_points <= 0) {
         return EXECUTION_REJECTED;
      }
      
      // Check duplicate signal
      if(IsSignalAlreadyExecuted(plan.signal_time)) {
         return EXECUTION_DUPLICATE_SIGNAL;
      }
      
      // Check existing position
      if(CountOpenPositionsByMagic() > 0) {
         return EXECUTION_POSITION_EXISTS;
      }
      
      // Check trade mode
      if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED)) {
         return EXECUTION_REJECTED;
      }
      
      return EXECUTION_ORDER_SENT; // All checks pass
   }
   
   //--- Execute BUY order
   ulong ExecuteBuy(const StructTradePlan &plan, uint &retcode, int &error_code, string &error_detail) {
      MqlTradeRequest req = {};
      MqlTradeResult  res = {};
      
      req.action       = TRADE_ACTION_DEAL;
      req.symbol       = m_symbol;
      req.volume       = plan.lot_size;
      req.price = SymbolInfoDouble(m_symbol, SYMBOL_ASK);
      req.sl = req.price - plan.sl_points * _Point;
      req.tp = req.price + plan.tp_points * _Point;
      req.deviation    = m_slippage;
      req.magic        = m_magic;
      req.type         = ORDER_TYPE_BUY;
      req.comment      = m_order_comment;
      
      m_total_attempts++;
      bool sent = OrderSend(req, res);
      
      retcode      = res.retcode;
      error_code   = GetLastError();
      error_detail = "";
      
      if(sent && res.retcode == TRADE_RETCODE_DONE) {
         m_total_success++;
         m_last_executed_signal_time = plan.signal_time;
         return res.order;
      }
      
      m_total_fail++;
      error_detail = StringFormat("retcode=%d err=%d", res.retcode, error_code);
      return 0;
   }
   
   //--- Execute SELL order
   ulong ExecuteSell(const StructTradePlan &plan, uint &retcode, int &error_code, string &error_detail) {
      MqlTradeRequest req = {};
      MqlTradeResult  res = {};
      
      req.action       = TRADE_ACTION_DEAL;
      req.symbol       = m_symbol;
      req.volume       = plan.lot_size;
      req.price = SymbolInfoDouble(m_symbol, SYMBOL_BID);
      req.sl = req.price + plan.sl_points * _Point;
      req.tp = req.price - plan.tp_points * _Point;
      req.deviation    = m_slippage;
      req.magic        = m_magic;
      req.type         = ORDER_TYPE_SELL;
      req.comment      = m_order_comment;
      
      m_total_attempts++;
      bool sent = OrderSend(req, res);
      
      retcode      = res.retcode;
      error_code   = GetLastError();
      error_detail = "";
      
      if(sent && res.retcode == TRADE_RETCODE_DONE) {
         m_total_success++;
         m_last_executed_signal_time = plan.signal_time;
         return res.order;
      }
      
      m_total_fail++;
      error_detail = StringFormat("retcode=%d err=%d", res.retcode, error_code);
      return 0;
   }
   
   //--- Execute trade (main entry)
   ENUM_EXECUTION_STATUS ExecuteTrade(const StructTradePlan &plan,
                                       ulong &ticket,
                                       uint &retcode,
                                       int &error_code,
                                       string &error_detail) {
      
      ticket        = 0;
      retcode       = 0;
      error_code    = 0;
      error_detail  = "";
      
      // Check if execution is allowed
      ENUM_EXECUTION_STATUS check = CanExecute(plan);
      if(check != EXECUTION_ORDER_SENT) {
         if(check == EXECUTION_POSITION_EXISTS) {
            error_detail = "Position already exists";
         } else if(check == EXECUTION_DUPLICATE_SIGNAL) {
            error_detail = "Signal already executed";
         } else {
            error_detail = "Pre-validation failed";
         }
         m_total_rejected++;
         return check;
      }
      
      // Execute based on direction
      if(plan.direction == TRADE_DIR_BUY) {
         ticket = ExecuteBuy(plan, retcode, error_code, error_detail);
      } else if(plan.direction == TRADE_DIR_SELL) {
         ticket = ExecuteSell(plan, retcode, error_code, error_detail);
      } else {
         error_detail = "Unknown direction";
         return EXECUTION_REJECTED;
      }
      
      if(ticket > 0) {
         return EXECUTION_ORDER_SENT;
      }
      
      return EXECUTION_ORDER_FAILED;
   }
   
   //--- Log execution stats
   string GetExecutionSummary() {
      return StringFormat("Attempts:%d Success:%d Fail:%d Rejected:%d",
                          m_total_attempts, m_total_success,
                          m_total_fail, m_total_rejected);
   }
   
   //--- Check if break-even should be managed
   bool CheckBreakEven(double break_even_at_rr, double break_even_lock_points) {
      for(int i = PositionsTotal() - 1; i >= 0; i--) {
         if(PositionSelectByTicket(PositionGetTicket(i))) {
            if(PositionGetString(POSITION_SYMBOL) == m_symbol &&
               PositionGetInteger(POSITION_MAGIC) == m_magic) {
               
               ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
               double open_price  = PositionGetDouble(POSITION_PRICE_OPEN);
               double current     = (type == POSITION_TYPE_BUY) ?
                                     SymbolInfoDouble(m_symbol, SYMBOL_BID) :
                                     SymbolInfoDouble(m_symbol, SYMBOL_ASK);
               double sl          = PositionGetDouble(POSITION_SL);
               double tp          = PositionGetDouble(POSITION_TP);
               
               // Calculate current RR
               double risk_dist   = MathAbs(open_price - sl);
               double current_profit = (type == POSITION_TYPE_BUY) ?
                                        (current - open_price) : (open_price - current);
               
               if(risk_dist <= 0) return false;
               double current_rr = current_profit / risk_dist;
               
               // If break even level reached, move SL to entry + lock
               if(current_rr >= break_even_at_rr) {
                  double new_sl = (type == POSITION_TYPE_BUY) ?
                                   open_price + break_even_lock_points * _Point :
                                   open_price - break_even_lock_points * _Point;
                  
                  if((type == POSITION_TYPE_BUY && new_sl > sl) ||
                     (type == POSITION_TYPE_SELL && new_sl < sl)) {
                     
                     MqlTradeRequest req = {};
                     MqlTradeResult  res = {};
                     req.action   = TRADE_ACTION_SLTP;
                     req.symbol   = m_symbol;
                     req.position = PositionGetTicket(i);
                     req.sl       = new_sl;
                     req.tp       = tp;
                     req.magic    = m_magic;
                     
                     return OrderSend(req, res);
                  }
               }
            }
         }
      }
      return false;
   }
};
