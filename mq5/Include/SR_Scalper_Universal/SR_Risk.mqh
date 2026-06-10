//+------------------------------------------------------------------+
//| SR_Risk.mqh — Risk control v1.1 (AutoSpread + spread fix)        |
//+------------------------------------------------------------------+
#property strict

struct RiskSt {
   bool   daily_hit;
   bool   consec_hit;
   bool   max_hit;
   bool   spread_hit;
   int    trades_today;
   int    consec_losses;
   double daily_pnl;
};

class CSRRisk {
protected:
   long    m_magic;
   string  m_sym;
   int     m_max_tr;
   double  m_max_loss;
   int     m_max_cl;
   int     m_max_spr;
   bool    m_auto_spr;
   double  m_spr_atr_ratio;
   bool    m_sess;
   int     m_sess_s;
   int     m_sess_e;
   
public:
   int cnt_Spread, cnt_Session, cnt_MaxTrades, cnt_DailyLoss, cnt_ConsecLoss;
   
   void Init(long magic, string sym,
             int max_tr, double max_loss, int max_cl,
             int max_spr, bool auto_spr, double spr_atr_ratio,
             bool sess, int ss, int se) {
      m_magic    = magic;    m_sym = sym;
      m_max_tr   = MathMax(max_tr, 1);
      m_max_loss = MathMax(max_loss, 1.0);
      m_max_cl   = MathMax(max_cl, 1);
      m_max_spr  = MathMax(max_spr, 5);
      m_auto_spr = auto_spr;
      m_spr_atr_ratio = MathMax(spr_atr_ratio, 0.01);
      m_sess     = sess;     m_sess_s = ss;   m_sess_e = se;
      cnt_Spread = 0; cnt_Session = 0; cnt_MaxTrades = 0;
      cnt_DailyLoss = 0; cnt_ConsecLoss = 0;
   }
   
   int GetMaxSpread() {
      if(!m_auto_spr) return m_max_spr;
      double atr15 = GetATR(m_sym, PERIOD_M15, 14, 1);
      if(atr15 <= 0) return m_max_spr;
      int dyn = (int)(atr15 / _Point * m_spr_atr_ratio);
      return MathMax(dyn, MathMax(m_max_spr, 10));
   }
   
   void Eval(RiskSt &st, string &reject_reason) {
      st.daily_hit = false; st.consec_hit = false;
      st.max_hit = false; st.spread_hit = false;
      st.trades_today = 0; st.consec_losses = 0; st.daily_pnl = 0;
      reject_reason = "";
      
      // 1. Spread — SYMBOL_SPREAD is already in native broker points
      long spr = SymbolInfoInteger(m_sym, SYMBOL_SPREAD);
      int max_spr = GetMaxSpread();
      if(spr > max_spr) {
         st.spread_hit = true; cnt_Spread++;
         reject_reason = "SPREAD"; return;
      }
      
      // 2. Session
      if(m_sess) {
         MqlDateTime dt; TimeGMT(dt);
         int h = dt.hour;
         bool in_sess = (m_sess_s <= m_sess_e) ?
            (h >= m_sess_s && h < m_sess_e) :
            !(h >= m_sess_e && h < m_sess_s);
         if(!in_sess) { st.daily_hit = true; cnt_Session++; reject_reason = "SESSION"; return; }
      }
      
      // 3. Daily
      GetDaily(st);
      if(st.daily_hit) { cnt_DailyLoss++; reject_reason = "DAILY_LOSS"; return; }
      if(st.max_hit) { cnt_MaxTrades++; reject_reason = "MAX_TRADES"; return; }
      
      // 4. Consecutive
      GetCL(st);
      if(st.consec_hit) { cnt_ConsecLoss++; reject_reason = "CONSEC_LOSS"; return; }
   }
   
   void GetDaily(RiskSt &st) {
      MqlDateTime utc; TimeGMT(utc);
      datetime start = StructToTime(utc);
      start -= utc.hour * 3600 + utc.min * 60 + utc.sec;
      HistorySelect(start, TimeCurrent() + 3600);
      double pnl = 0; int tr = 0;
      for(int i = HistoryDealsTotal() - 1; i >= 0; i--) {
         ulong tkt = HistoryDealGetTicket(i);
         if(tkt == 0) continue;
         if(HistoryDealGetString(tkt, DEAL_SYMBOL) != m_sym) continue;
         if(HistoryDealGetInteger(tkt, DEAL_MAGIC) != m_magic) continue;
         long ent = HistoryDealGetInteger(tkt, DEAL_ENTRY);
         if(ent != DEAL_ENTRY_IN && ent != DEAL_ENTRY_OUT) continue;
         datetime dt = (datetime)HistoryDealGetInteger(tkt, DEAL_TIME);
         if(dt < start) continue;
         tr++;
         if(ent == DEAL_ENTRY_OUT) {
            pnl += HistoryDealGetDouble(tkt, DEAL_PROFIT);
            pnl += HistoryDealGetDouble(tkt, DEAL_SWAP);
            pnl += HistoryDealGetDouble(tkt, DEAL_COMMISSION);
         }
      }
      st.trades_today = tr; st.daily_pnl = pnl;
      if(pnl <= -m_max_loss) st.daily_hit = true;
      if(tr >= m_max_tr) st.max_hit = true;
   }
   
   void GetCL(RiskSt &st) {
      int cl = 0;
      // Only count today's closed trades to prevent permanent lock
      MqlDateTime utc; TimeGMT(utc);
      datetime today_start = StructToTime(utc);
      today_start -= utc.hour * 3600 + utc.min * 60 + utc.sec;
      HistorySelect(today_start, TimeCurrent() + 3600);
      
      for(int i = HistoryDealsTotal() - 1; i >= 0; i--) {
         ulong tkt = HistoryDealGetTicket(i);
         if(tkt == 0) continue;
         if(HistoryDealGetString(tkt, DEAL_SYMBOL) != m_sym) continue;
         if(HistoryDealGetInteger(tkt, DEAL_MAGIC) != m_magic) continue;
         if(HistoryDealGetInteger(tkt, DEAL_ENTRY) != DEAL_ENTRY_OUT) continue;
         datetime dt = (datetime)HistoryDealGetInteger(tkt, DEAL_TIME);
         if(dt < today_start) continue;
         double p = HistoryDealGetDouble(tkt, DEAL_PROFIT);
         if(p >= 0) break;  // Winning trade → reset
         cl++;
      }
      st.consec_losses = cl;
      if(cl >= m_max_cl) st.consec_hit = true;
   }
   
   bool CanTrade(RiskSt &st) {
      return !st.daily_hit && !st.consec_hit && !st.max_hit && !st.spread_hit;
   }
};
//+------------------------------------------------------------------+
