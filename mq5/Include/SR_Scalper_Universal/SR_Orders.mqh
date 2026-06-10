//+------------------------------------------------------------------+
//| SR_Orders.mqh — Order execution, SL/TP, break even               |
//+------------------------------------------------------------------+
#property strict

struct PosInfo {
   ulong   ticket;
   int     type;
   double  open_price;
   double  sl;
   double  tp;
   bool    be_moved;
};

class CSROrders {
protected:
   long    m_magic;
   string  m_sym;
   int     m_slip;
   double  m_atr_sl;
   double  m_atr_tp;
   bool    m_ovr;
   int     m_man_sl;
   int     m_man_tp;
   bool    m_be;
   double  m_be_trig;
   int     m_be_plus;
   double  m_lot;
   
   PosInfo m_pos;
   bool    m_have_pos;
   
public:
   void Init(long magic, string sym, int slip,
             double atr_sl, double atr_tp,
             bool ovr, int man_sl, int man_tp,
             bool be, double be_trig, int be_plus,
             double lot) {
      m_magic   = magic;
      m_sym     = sym;
      m_slip    = MathMax(slip, 10);
      m_atr_sl  = MathMax(atr_sl, 0.1);
      m_atr_tp  = MathMax(atr_tp, 0.1);
      m_ovr     = ovr;
      m_man_sl  = MathMax(man_sl, 10);
      m_man_tp  = MathMax(man_tp, 10);
      m_be      = be;
      m_be_trig = MathMax(be_trig, 0.1);
      m_be_plus = be_plus;
      m_lot     = lot;
      m_have_pos = false;
   }
   double GetLot(double balance = 0) {
      double min_l = SymbolInfoDouble(m_sym, SYMBOL_VOLUME_MIN);
      double max_l = SymbolInfoDouble(m_sym, SYMBOL_VOLUME_MAX);
      double step  = SymbolInfoDouble(m_sym, SYMBOL_VOLUME_STEP);
      
      // User-specified lot or adaptive from balance
      double lot = m_lot;
      if(lot < min_l) lot = min_l;
      if(lot > max_l) lot = max_l;
      
      // Normalize to step (handle sub-step values safely)
      if(step > 0 && lot >= step) {
         lot = MathRound(lot / step) * step;
      }
      if(lot < min_l) lot = min_l;
      
      return NormalizeDouble(lot, 2);
   }
   
   void CalcSLTP(int dir, double &sl_pr, double &tp_pr, int &sl_pt, int &tp_pt) {
      double entry = (dir == ORDER_TYPE_BUY) ?
                     SymbolInfoDouble(m_sym, SYMBOL_ASK) : SymbolInfoDouble(m_sym, SYMBOL_BID);
      int digits = (int)SymbolInfoInteger(m_sym, SYMBOL_DIGITS);
      
      if(m_ovr) {
         sl_pt = m_man_sl; tp_pt = m_man_tp;
      } else {
         double atr = GetATR(m_sym, PERIOD_M15, 14, 1);
         if(atr <= 0) atr = 100 * _Point;
         sl_pt = (int)(atr / _Point * m_atr_sl);
         tp_pt = (int)(atr / _Point * m_atr_tp);
         sl_pt = MathMax(sl_pt, 10);
         tp_pt = MathMax(tp_pt, 10);
      }
      
      int stl = (int)SymbolInfoInteger(m_sym, SYMBOL_TRADE_STOPS_LEVEL);
      if(stl > sl_pt) { sl_pt = stl + 5; tp_pt = MathMax(tp_pt, sl_pt); }
      
      if(dir == ORDER_TYPE_BUY) {
         sl_pr = NormalizeDouble(entry - sl_pt * _Point, digits);
         tp_pr = NormalizeDouble(entry + tp_pt * _Point, digits);
      } else {
         sl_pr = NormalizeDouble(entry + sl_pt * _Point, digits);
         tp_pr = NormalizeDouble(entry - tp_pt * _Point, digits);
      }
   }
   
   bool SendOrder(int dir, double sl, double tp, ulong &ticket) {
      MqlTradeRequest req = {};
      MqlTradeResult  res = {};
      
      req.action   = TRADE_ACTION_DEAL;
      req.symbol   = m_sym;
      req.volume   = GetLot();
      req.type     = (ENUM_ORDER_TYPE)dir;
      req.price    = (dir == ORDER_TYPE_BUY) ?
                     SymbolInfoDouble(m_sym, SYMBOL_ASK) : SymbolInfoDouble(m_sym, SYMBOL_BID);
      req.sl       = sl;
      req.tp       = tp;
      req.deviation = m_slip;
      req.magic    = m_magic;
      
      if(OrderSend(req, res) && res.retcode == TRADE_RETCODE_DONE) {
         ticket = res.order; return true;
      }
      ticket = 0; return false;
   }
   
   void Update() {
      m_have_pos = false;
      for(int i = PositionsTotal() - 1; i >= 0; i--) {
         if(PositionSelectByTicket(PositionGetTicket(i))) {
            if(PositionGetString(POSITION_SYMBOL) == m_sym &&
               PositionGetInteger(POSITION_MAGIC) == m_magic) {
               m_have_pos = true;
               m_pos.ticket     = PositionGetTicket(i);
               m_pos.type       = (int)PositionGetInteger(POSITION_TYPE);
               m_pos.open_price = PositionGetDouble(POSITION_PRICE_OPEN);
               m_pos.sl         = PositionGetDouble(POSITION_SL);
               m_pos.tp         = PositionGetDouble(POSITION_TP);
               m_pos.be_moved   = (m_pos.sl != 0);
               return;
            }
         }
      }
   }
   
   bool HasPos() { return m_have_pos; }
   PosInfo GetPos() { return m_pos; }
   
   void CheckBE() {
      if(!m_be || !m_have_pos || m_pos.be_moved) return;
      
      double atr = GetATR(m_sym, PERIOD_M15, 14, 1);
      if(atr <= 0) return;
      
      double entry = m_pos.open_price;
      double curr  = (m_pos.type == ORDER_TYPE_BUY) ?
                     SymbolInfoDouble(m_sym, SYMBOL_BID) : SymbolInfoDouble(m_sym, SYMBOL_ASK);
      double trig  = atr * m_be_trig;
      int digits   = (int)SymbolInfoInteger(m_sym, SYMBOL_DIGITS);
      int stl      = (int)SymbolInfoInteger(m_sym, SYMBOL_TRADE_STOPS_LEVEL);
      
      double new_sl = 0;
      bool move = false;
      
      if(m_pos.type == ORDER_TYPE_BUY && curr >= entry + trig) {
         new_sl = NormalizeDouble(entry + m_be_plus * _Point, digits);
         move = true;
      }
      if(m_pos.type == ORDER_TYPE_SELL && curr <= entry - trig) {
         new_sl = NormalizeDouble(entry - m_be_plus * _Point, digits);
         move = true;
      }
      
      if(!move || MathAbs(new_sl - entry) < stl * _Point) return;
      
      MqlTradeRequest req = {};
      MqlTradeResult  res = {};
      req.action   = TRADE_ACTION_SLTP;
      req.symbol   = m_sym;
      req.sl       = new_sl;
      req.tp       = m_pos.tp;
      req.magic    = m_magic;
      req.position = m_pos.ticket;
      
      if(OrderSend(req, res) && res.retcode == TRADE_RETCODE_DONE) {
         m_pos.be_moved = true; m_pos.sl = new_sl;
      }
   }
};
//+------------------------------------------------------------------+
