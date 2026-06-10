//+------------------------------------------------------------------+
//| SR_Scalper_Universal.mq5 — Universal S/R Scalper EA v1.3      |
//+------------------------------------------------------------------+
#property copyright "Hermes Agent"
#property version   "1.300"
#property strict
#property description "SR Scalper Universal v1.3 — ProfitGate"

#include <SR_Scalper_Universal/SR_MTF.mqh>
#include <SR_Scalper_Universal/SR_Orders.mqh>
#include <SR_Scalper_Universal/SR_Risk.mqh>
#include <SR_Scalper_Universal/SR_Logger.mqh>

input group "=== SL/TP ==="
input bool   InpOverrideSLTP     = false;
input int    InpManualSLPoints   = 100;
input int    InpManualTPPoints   = 180;
input double InpATR_SL_Mult      = 0.8;
input double InpATR_TP_Mult      = 1.5;

input group "=== Lot ==="
input double InpFixedLot         = 0.01;

input group "=== S/R ==="
input int    InpSRLookback       = 100;
input int    InpSRMinTests       = 2;
input double InpZoneTolerance    = 0.3;
input int    InpMaxSRLevels      = 5;

input group "=== Entry ==="
input int    InpMaxSpreadPts     = 30;
input bool   InpAutoSpread       = true;
input double InpSpreadATRRatio   = 0.05;
input double InpMaxDistATRMult   = 1.0;
input bool   InpAllowWeakSetup   = false;
input int    InpPatternLookback  = 3;
input double InpM5MomentumMult   = 0.15;
input bool   InpAllowConsecClose = false;

input group "=== ProfitGate (V1.3) ==="
input bool   InpUseProfitGate       = true;
input bool   InpAllowEngulfingSetup = true;
input bool   InpAllowPinBarSetup    = true;
input bool   InpAllowMomentumSetup  = false;
input bool   InpAllowConsecCloseSetup = false;
input double InpMaxZoneDistanceATR  = 0.50;
input bool   InpRequireZoneSide     = true;
input bool   InpUseStrictSession    = true;
input int    InpStrictSessionStart  = 7;
input int    InpStrictSessionEnd    = 20;

input group "=== Bias ==="
input double InpBiasThreshold    = 0.45;
input bool   InpUseTrendFilter   = true;
input int    InpTrendEMAPeriod   = 50;

input group "=== Session ==="
input bool   InpUseSession       = false;
input int    InpSessionStart     = 7;
input int    InpSessionEnd       = 22;

input group "=== Risk ==="
input int    InpMaxTradesDay     = 2;
input double InpMaxDailyLossUSD  = 50.0;
input int    InpMaxConsecLoss    = 5;

input group "=== BE ==="
input bool   InpUseBE            = true;
input double InpBE_TrigMult      = 0.6;
input int    InpBE_PlusPoints    = 10;

input group "=== System ==="
input long   InpMagic            = 40900;
input bool   InpAutoTrade        = false;
input bool   InpEnableCSV        = true;

CSRMTF    g_mtf;
CSROrders g_ord;
CSRRisk   g_risk;
CSRLogger g_log;

MTFState  g_mtf_st;
RiskSt    g_rst;
int       g_last_m1;
string    g_mode;

string g_bias_s, g_setup_s, g_trig_s, g_reject_reason;

// Rejection counters (diagnostic)
int g_rej_no_m15, g_rej_no_m5, g_rej_no_m1, g_rej_no_zone;

//+------------------------------------------------------------------+
int OnInit() {
   Print("=== SR Scalper Universal v1.002 ===");
   Print("Magic=", InpMagic, " Lot=", InpFixedLot, " SL=", InpManualSLPoints, " TP=", InpManualTPPoints);
   Print("BE=", InpUseBE, " Session=", InpUseSession, " WeakSetup=", InpAllowWeakSetup);
   Print("Spread=", InpMaxSpreadPts, " ATRRatio=", InpSpreadATRRatio, " MaxTr=", InpMaxTradesDay);
   
   g_mtf.Init(InpSRLookback, InpSRMinTests, InpZoneTolerance, InpMaxSRLevels,
               InpMaxDistATRMult, InpAllowWeakSetup, InpPatternLookback,
               InpBiasThreshold, InpUseTrendFilter, InpTrendEMAPeriod,
               InpM5MomentumMult, InpAllowConsecClose,
               InpAllowEngulfingSetup, InpAllowPinBarSetup,
               InpAllowMomentumSetup, InpAllowConsecCloseSetup);
   g_ord.Init(InpMagic, _Symbol, 30,
               InpATR_SL_Mult, InpATR_TP_Mult,
               InpOverrideSLTP, InpManualSLPoints, InpManualTPPoints,
               InpUseBE, InpBE_TrigMult, InpBE_PlusPoints, InpFixedLot);
   g_risk.Init(InpMagic, _Symbol,
               InpMaxTradesDay, InpMaxDailyLossUSD, InpMaxConsecLoss,
               InpMaxSpreadPts, InpAutoSpread, InpSpreadATRRatio,
               InpUseSession, InpSessionStart, InpSessionEnd);
   g_log.Init("SR_Scalper_Universal_ExecutionLog.csv");
   if(InpEnableCSV) g_log.Open();
   
   g_last_m1 = 0;
   g_rej_no_m15 = 0; g_rej_no_m5 = 0; g_rej_no_m1 = 0; g_rej_no_zone = 0;
   g_bias_s = "NEUTRAL"; g_setup_s = "NONE"; g_trig_s = "NONE"; g_reject_reason = "";

   g_mode = "DISABLED";
   if(InpAutoTrade) {
      if(MQLInfoInteger(MQL_TESTER)) g_mode = "TESTER";
      else {
         int m = (int)AccountInfoInteger(ACCOUNT_TRADE_MODE);
         if(m == ACCOUNT_TRADE_MODE_DEMO) g_mode = "DEMO";
      }
   }
   Print("Mode: ", g_mode);
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
   if(InpEnableCSV) g_log.Close();
   Print("=== REJECTION SUMMARY ===");
   Print("Spread reject    : ", g_risk.cnt_Spread);
   Print("Session reject   : ", g_risk.cnt_Session);
   Print("Max trades reject: ", g_risk.cnt_MaxTrades);
   Print("Daily loss reject: ", g_risk.cnt_DailyLoss);
   Print("Consec loss rej  : ", g_risk.cnt_ConsecLoss);
   Print("No M15 bias      : ", g_rej_no_m15);
   Print("No M5 setup      : ", g_rej_no_m5);
   Print("No M1 trigger    : ", g_rej_no_m1);
   Print("No S/R zone      : ", g_rej_no_zone);
   Print("=========================");
   Print("Deinit: SR Scalper Universal");
}

//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction &trans,
                         const MqlTradeRequest &req,
                         const MqlTradeResult &res) {
   if(trans.type != TRADE_TRANSACTION_DEAL_ADD) return;
   if(trans.deal == 0) return;
   
   ulong did = trans.deal;
   if(did == 0) return;
   if(HistoryDealGetString(did, DEAL_SYMBOL) != _Symbol) return;
   if(HistoryDealGetInteger(did, DEAL_MAGIC) != InpMagic) return;
   if(HistoryDealGetInteger(did, DEAL_ENTRY) != DEAL_ENTRY_OUT) return;
   
   double pr = HistoryDealGetDouble(did, DEAL_PROFIT);
   double sw = HistoryDealGetDouble(did, DEAL_SWAP);
   double cm = HistoryDealGetDouble(did, DEAL_COMMISSION);
   double total = pr + sw + cm;
   
   datetime ex_t = (datetime)HistoryDealGetInteger(did, DEAL_TIME);
   double   op = HistoryDealGetDouble(did, DEAL_PRICE);
   long     dt = HistoryDealGetInteger(did, DEAL_TYPE);
   double   vol = HistoryDealGetDouble(did, DEAL_VOLUME);
   double   bal = AccountInfoDouble(ACCOUNT_BALANCE);
   double   eq  = AccountInfoDouble(ACCOUNT_EQUITY);
   double   dd  = (bal > 0) ? (1 - eq / bal) * 100 : 0;
   int      spr = (int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   string   er = (total > 0) ? "TP" : "SL";
   
   if(InpEnableCSV) {
      g_log.LogClose(_Symbol, (int)dt,
                     g_bias_s, g_setup_s, g_trig_s,
                     0, ex_t, op, 0, 0,
                     0, 0, vol, spr,
                     total, bal, eq, dd, er,
                     false, false,
                     g_rst.daily_hit, g_rst.consec_losses, InpMagic,
                     g_reject_reason != "" ? g_reject_reason : "PASS");
   }
}

//+------------------------------------------------------------------+
void OnTick() {
   int m1 = (int)iTime(_Symbol, PERIOD_M1, 0);
   if(m1 == g_last_m1) return;
   g_last_m1 = m1;
   
   //--- Position & BE
   g_ord.Update();
   g_ord.CheckBE();
   
   //--- Risk check with reject reason
   g_risk.Eval(g_rst, g_reject_reason);
   if(!g_risk.CanTrade(g_rst)) return;
   
   //--- MTF analysis
   g_mtf.Analyze(_Symbol, g_mtf_st);
   
   g_bias_s = (g_mtf_st.m15_bias > 0) ? "BULLISH" : (g_mtf_st.m15_bias < 0) ? "BEARISH" : "NEUTRAL";
   
   if(g_mtf_st.m15_bias == 0) { g_rej_no_m15++; return; }
   g_reject_reason = "";
   
   if(g_mtf_st.m5_zone_dist <= 0 && g_mtf_st.m15_support <= 0 && g_mtf_st.m15_resistance <= 0) {
      g_rej_no_zone++; return;
   }
   
   string tier_s = (g_mtf_st.m5_tier > 0) ? IntegerToString(g_mtf_st.m5_tier) : "";
   g_setup_s = (g_mtf_st.m5_setup > 0) ? "BUY_T"+tier_s : (g_mtf_st.m5_setup < 0) ? "SELL_T"+tier_s : "NONE";
   
   if(g_mtf_st.m5_setup == 0) { g_rej_no_m5++; return; }
   
   if(InpUseProfitGate) {
      // Strict session (UTC)
      if(InpUseStrictSession) {
         MqlDateTime dt; TimeGMT(dt);
         int h = dt.hour;
         if(h < InpStrictSessionStart || h >= InpStrictSessionEnd) return;
      }
      
      // Zone side rule: BUY only near support, SELL only near resistance
      if(InpRequireZoneSide && g_mtf_st.m15_bias != 0) {
         double curr = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         double dist_to_resist = (g_mtf_st.m15_resistance > 0) ? g_mtf_st.m15_resistance - curr : 1e9;
         double dist_to_support = (g_mtf_st.m15_support > 0) ? curr - g_mtf_st.m15_support : 1e9;
         if(g_mtf_st.m15_bias > 0 && dist_to_support > dist_to_resist) return;  // BUY but closer to resistance
         if(g_mtf_st.m15_bias < 0 && dist_to_resist > dist_to_support) return; // SELL but closer to support
      }
      
      // Zone distance rule
      if(g_mtf_st.m5_atr > 0) {
         double max_zone = InpMaxZoneDistanceATR * g_mtf_st.m5_atr;
         if(g_mtf_st.m5_zone_dist > 0 && g_mtf_st.m5_zone_dist > max_zone) return;
      }
   }
   
   g_trig_s = (g_mtf_st.m1_trigger > 0) ? "BUY_TRIG" : (g_mtf_st.m1_trigger < 0) ? "SELL_TRIG" : "NONE";
   if(g_mtf_st.m1_trigger == 0) { g_rej_no_m1++; return; }
   
   if(!g_mtf_st.entry_allowed) return;
   if(g_ord.HasPos()) return;
   
   //--- Execute
   if(g_mode != "DISABLED") {
      int dir = (g_mtf_st.m15_bias > 0) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
      double sp, tp; int sp_pt, tp_pt;
      g_ord.CalcSLTP(dir, sp, tp, sp_pt, tp_pt);
      
      ulong tkt = 0;
      if(g_ord.SendOrder(dir, sp, tp, tkt)) {
         Print("ORDER_SENT ", (dir == ORDER_TYPE_BUY ? "BUY" : "SELL"),
               " lot=", g_ord.GetLot(), " ticket=", tkt);
      }
   }
}
//+------------------------------------------------------------------+
