//+------------------------------------------------------------------+
//| XAUUSD_SMC_Scalper_MTF_V081_REPAIR.mq5                          |
//| V0.8.1 REPAIR SPRINT: M1 execution via CTradeManager.           |
//+------------------------------------------------------------------+
#property copyright "Hermes Agent"
#property version   "8.100"
#property strict
#property description "V0.8.1 REPAIR — M1 sprint via CTradeManager"
#property description "Use only in Strategy Tester."

#include <SMC_V081_REPAIR/Types.mqh>
#include <SMC_V081_REPAIR/MarketStructure.mqh>
#include <SMC_V081_REPAIR/SignalEngine.mqh>
#include <SMC_V081_REPAIR/ZoneDetector.mqh>
#include <SMC_V081_REPAIR/Logger.mqh>
#include <SMC_V081_REPAIR/RiskManager.mqh>
#include <SMC_V081_REPAIR/TradePlan.mqh>
#include <SMC_V081_REPAIR/TradeManager.mqh>

input group "=== Core ==="
input int       InpMagicNumber         = 40881;
input bool      InpEnableAutoTrade     = false;
input bool      InpAllowTesterExec     = true;
input bool      InpAllowDemoExec       = false;
input double    InpRiskPercent         = 1.0;
input int       InpMaxOpenPositions    = 1;
input int       InpSlippagePoints      = 30;
input int       InpMinBarsBetweenTrades = 6; // Min M5 bars between entries

input group "=== M1 Sprint ==="
input bool      InpUseM1Execution      = true;
input int       InpScalpSLPoints       = 100;
input int       InpScalpTPPoints       = 150;
input bool      InpUseM1CandleConfirm  = true;
input double    InpMinM1BodyRatio      = 0.45;
input int       InpMaxBarsAfterM5BOS   = 6;

//--- Globals
CSignalEngine   g_se;
CSMCLogger      g_log;
StructMarketState g_mkt;
CZoneDetector   g_zd;
StructZoneState g_zs;
CTradePlan      g_tp;
StructTradePlan g_plan;
CTradeManager   g_tm;
string          g_mode;
datetime        g_last_entry_bar = 0;

//--- Config CSV handle
int g_cfg_csv = -1;

//+------------------------------------------------------------------+
//| OnInit                                                           |
//+------------------------------------------------------------------+
int OnInit() {
   // Print config for verification
   Print("=== V0.8.1 REPAIR CONFIG ===");
   Print("Version: 8.100");
   Print("Magic: ", InpMagicNumber);
   Print("SL: ", InpScalpSLPoints, " pts");
   Print("TP: ", InpScalpTPPoints, " pts");
   Print("M1 Exec: ", InpUseM1Execution);
   Print("AutoTrade: ", InpEnableAutoTrade);
   Print("TesterExec: ", InpAllowTesterExec);
   Print("DemoExec: ", InpAllowDemoExec);
   Print("MaxPos: ", InpMaxOpenPositions);
   Print("Symbol: ", _Symbol);
   Print("Period: ", EnumToString(Period()));
   Print("M1Candle: ", InpUseM1CandleConfirm, " minRatio=", InpMinM1BodyRatio);
   Print("M5MaxBars: ", InpMaxBarsAfterM5BOS);
   
   // Config CSV
   g_cfg_csv = FileOpen("XAUUSD_SMC_V081_ConfigLog.csv", FILE_WRITE|FILE_READ|FILE_CSV|FILE_ANSI, ',');
   if(g_cfg_csv != INVALID_HANDLE) {
      FileWrite(g_cfg_csv,
         "time","test_name","symbol","magic","sl_pts","tp_pts",
         "m1_exec","auto_trade","tester_exec","demo_exec","max_pos",
         "m1_candle","min_m1_body","m5_max_bars");
      string ts = TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS);
      FileWrite(g_cfg_csv,
         ts, "REPAIR", _Symbol, (int)InpMagicNumber, InpScalpSLPoints, InpScalpTPPoints,
         InpUseM1Execution, InpEnableAutoTrade, InpAllowTesterExec, InpAllowDemoExec, InpMaxOpenPositions,
         InpUseM1CandleConfirm, InpMinM1BodyRatio, InpMaxBarsAfterM5BOS);
      FileFlush(g_cfg_csv);
   }
   
   // Init modules
   g_log.OpenCSV();
   g_tp.Init(InpRiskPercent, 1.0, 2.0, 50, 150, 40, 150, 100, 180, 460, 30);
   g_tm.Init(_Symbol, InpMagicNumber, InpSlippagePoints);
   
   // Execution mode
   g_mode = "DISABLED";
   if(InpEnableAutoTrade) {
      if(MQLInfoInteger(MQL_TESTER) && InpAllowTesterExec) g_mode = "TESTER";
      else {
         int m = (int)AccountInfoInteger(ACCOUNT_TRADE_MODE);
         if(m == ACCOUNT_TRADE_MODE_DEMO && InpAllowDemoExec) g_mode = "DEMO";
      }
   }
   Print("Mode: ", g_mode);
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| OnDeinit                                                         |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
   if(g_cfg_csv != INVALID_HANDLE) FileClose(g_cfg_csv);
   g_log.CloseCSV();
   Print("Deinit: ", g_tm.GetExecutionSummary());
}

//+------------------------------------------------------------------+
//| Get M15 bias                                                     |
//+------------------------------------------------------------------+
int GetBias() {
   double c1 = iClose(_Symbol, PERIOD_M15, 1);
   double c12 = iClose(_Symbol, PERIOD_M15, 12);
   double d = (c1 - c12) / _Point;
   if(d > 80) return 1;
   if(d < -80) return -1;
   return 0;
}

//+------------------------------------------------------------------+
//| Check M5 BOS                                                     |
//+------------------------------------------------------------------+
bool HasM5BOS(int bias) {
   int max_b = MathMin(InpMaxBarsAfterM5BOS + 10, Bars(_Symbol, PERIOD_M5));
   for(int b = 1; b < max_b; b++) {
      double hi = iHigh(_Symbol, PERIOD_M5, b);
      double lo = iLow(_Symbol, PERIOD_M5, b);
      double cl = iClose(_Symbol, PERIOD_M5, b);
      if(bias > 0 && b >= 2) {
         double pv = MathMax(iHigh(_Symbol, PERIOD_M5, b+1), iHigh(_Symbol, PERIOD_M5, b+2));
         if(cl > pv && hi > pv) return true;
      }
      if(bias < 0 && b >= 2) {
         double pv = MathMin(iLow(_Symbol, PERIOD_M5, b+1), iLow(_Symbol, PERIOD_M5, b+2));
         if(cl < pv && lo < pv) return true;
      }
   }
   return false;
}

//+------------------------------------------------------------------+
//| OnTick                                                           |
//+------------------------------------------------------------------+
void OnTick() {
   static datetime last_m1 = 0;
   datetime t = iTime(_Symbol, PERIOD_M1, 0);
   if(last_m1 == t) return;
   last_m1 = t;
   if(!InpUseM1Execution) return;
   
   // 1. M15 bias
   int bias = GetBias();
   if(bias == 0) return;
   
   // 2. M5 BOS
   if(!HasM5BOS(bias)) return;
   
   // 3. M1 direction
   double m1o = iOpen(_Symbol, PERIOD_M1, 1);
   double m1c = iClose(_Symbol, PERIOD_M1, 1);
   double m1h = iHigh(_Symbol, PERIOD_M1, 1);
   double m1l = iLow(_Symbol, PERIOD_M1, 1);
   
   int m1dir = (m1c > m1o) ? 1 : (m1c < m1o) ? -1 : 0;
   if(m1dir == 0) return;
   if(bias > 0 && m1dir < 0) return;
   if(bias < 0 && m1dir > 0) return;
   
   // 4. M1 body
   if(InpUseM1CandleConfirm) {
      double rng = m1h - m1l;
      if(rng <= 0) return;
      double body = MathAbs(m1c - m1o);
      if(body / rng < InpMinM1BodyRatio) return;
   }
   
   // 6. Min bars between trades
   if(InpMinBarsBetweenTrades > 0 && g_last_entry_bar > 0) {
      int bars = iBarShift(_Symbol, PERIOD_M5, g_last_entry_bar, false);
      if(bars < InpMinBarsBetweenTrades) return;
   }
   g_last_entry_bar = iTime(_Symbol, PERIOD_M5, 0); // Track this bar as attempted
   
   // 7. Build trade plan
   ENUM_ZONE_STATUS sig = (bias > 0) ? ZONE_READY_BUY : ZONE_READY_SELL;
   g_plan.Reset();
   g_plan.direction = (bias > 0) ? TRADE_DIR_BUY : TRADE_DIR_SELL;
   g_plan.signal_time = TimeCurrent();
   g_plan.entry_price = SymbolInfoDouble(_Symbol, (bias > 0) ? SYMBOL_ASK : SYMBOL_BID);
   
   //--- SL/TP points (TradeManager applies these to actual execution price)
   g_plan.sl_points = InpScalpSLPoints;
   g_plan.tp_points = InpScalpTPPoints;
   g_plan.rr = (double)InpScalpTPPoints / InpScalpSLPoints;
   g_plan.lot_size = 0.01;
   g_plan.risk_money = AccountInfoDouble(ACCOUNT_BALANCE) * InpRiskPercent / 100.0;
   g_plan.spread_points = (int)((SymbolInfoDouble(_Symbol, SYMBOL_ASK) - SymbolInfoDouble(_Symbol, SYMBOL_BID)) / _Point);
   g_plan.stop_level_points = (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   g_plan.freeze_level_points = (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_FREEZE_LEVEL);
   g_plan.plan_status = TRADE_PLAN_VALID;
   g_plan.valid = true;
   g_plan.entry_mode = ENTRY_MODE_CONTINUATION;
   
   // 6. Position guard
   if(g_tm.CountOpenPositionsByMagic() >= InpMaxOpenPositions) return;
   
   // 7. Execute via CTradeManager
   if(g_mode != "DISABLED" && g_plan.plan_status == TRADE_PLAN_VALID) {
      ulong ticket = 0; uint retcode = 0; int err = 0; string detail = "";
      ENUM_EXECUTION_STATUS exec = g_tm.ExecuteTrade(g_plan, ticket, retcode, err, detail);
      string reason = detail;
      if(exec == EXECUTION_ORDER_FAILED && reason == "")
         reason = StringFormat("retcode=%d err=%d", retcode, err);
      
      g_log.LogExecutionPrint(_Symbol, g_mode, g_plan, exec, ticket, retcode, err, reason);
      g_log.LogExecutionCSV(_Symbol, g_mode, g_plan, exec, ticket, retcode, err, reason);
   }
}
//+------------------------------------------------------------------+
