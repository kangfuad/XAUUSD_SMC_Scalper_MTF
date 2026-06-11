//+------------------------------------------------------------------+
//| XAUUSD_SMC_Scalper_MTF_V08_PROFIT_SPRINT.mq5                    |
//| V0.8 PROFIT SPRINT: M15 bias + M5 setup + M1 execution.         |
//|       Strategy Tester only.                                      |
//+------------------------------------------------------------------+
#property copyright "Hermes Agent"
#property version   "8.800"
#property strict
#property description "V0.8 PROFIT SPRINT — M1 scalping, M15 bias."
#property description "Use only in Strategy Tester."

#include <SMC_V08_PROFIT_SPRINT/Types.mqh>
#include <SMC_V08_PROFIT_SPRINT/MarketStructure.mqh>
#include <SMC_V08_PROFIT_SPRINT/SignalEngine.mqh>
#include <SMC_V08_PROFIT_SPRINT/ZoneDetector.mqh>
#include <SMC_V08_PROFIT_SPRINT/Logger.mqh>
#include <SMC_V08_PROFIT_SPRINT/RiskManager.mqh>
#include <SMC_V08_PROFIT_SPRINT/TradePlan.mqh>
#include <SMC_V08_PROFIT_SPRINT/TradeManager.mqh>

input group "=== Core Settings ==="
input int    InpMagicNumber           = 40880;
input bool   InpEnableAutoTrade       = false;
input bool   InpAllowTesterExecution  = true;
input bool   InpAllowDemoExecution    = false;
input int    InpMaxOpenPositions      = 1;
input int    InpSlippagePoints        = 30;
input double InpRiskPercent           = 1.0;

input group "=== Strategy TF ==="
input ENUM_TIMEFRAMES InpBiasTF   = PERIOD_M15;
input ENUM_TIMEFRAMES InpSetupTF  = PERIOD_M5;
input ENUM_TIMEFRAMES InpEntryTF  = PERIOD_M1;

input group "=== SL/TP ==="
input int    InpScalpSLPoints        = 100;
input int    InpScalpTPPoints        = 150;
input bool   InpUseFixedSLTP         = true;

input group "=== Entry Filters ==="
input bool   InpUseM1CandleConfirm   = true;
input double InpMinM1BodyRatio       = 0.45;
input bool   InpUseM5TrendConfirm    = true;
input int    InpMaxBarsAfterM5BOS    = 6;
input bool   InpAvoidOverextended    = true;
input int    InpMaxDistFromM5BOS     = 150;
input bool   InpUseSessionFilter     = true;
input int    InpSessionStart         = 7;
input int    InpSessionEnd           = 23;

//--- Globals
CSignalEngine   g_signal_engine;
CSMCLogger      g_logger;
StructMarketState g_mkt;
CZoneDetector   g_zone;
StructZoneState g_zone_st;
CTradePlan      g_trade_plan;
StructTradePlan g_plan;
CTradeManager   g_trade_mgr;
string          g_mode;
int             g_setup_bars;

//+------------------------------------------------------------------+
//| Init                                                            |
//+------------------------------------------------------------------+
int OnInit() {
   Print("V0.8 PROFIT SPRINT Init. Magic=", InpMagicNumber,
         " SL=", InpScalpSLPoints, " TP=", InpScalpTPPoints,
         " Risk=", InpRiskPercent, "%");
   
   g_logger.OpenCSV();
   g_trade_plan.Init(InpRiskPercent, 1.0, 2.0, 50, 150, 40, 150, 100, 180, 460, 30);
   g_trade_mgr.Init(_Symbol, InpMagicNumber, InpSlippagePoints);
   
   g_setup_bars = (InpSetupTF == PERIOD_M5) ? 6 : 12;
   
   g_mode = "DISABLED";
   if(InpEnableAutoTrade) {
      if(MQLInfoInteger(MQL_TESTER) && InpAllowTesterExecution) g_mode = "TESTER";
      else {
         int acc = (int)AccountInfoInteger(ACCOUNT_TRADE_MODE);
         if(acc == ACCOUNT_TRADE_MODE_DEMO && InpAllowDemoExecution) g_mode = "DEMO";
      }
   }
   Print("Mode: ", g_mode);
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason) {
   g_logger.CloseCSV();
   Print("Deinit: ", g_trade_mgr.GetExecutionSummary());
}

//+------------------------------------------------------------------+
//| M15 bias: trend direction                                        |
//+------------------------------------------------------------------+
int GetBias() {
   double close1 = iClose(_Symbol, InpBiasTF, 1);
   double close2 = iClose(_Symbol, InpBiasTF, 12);
   double diff = (close1 - close2) / _Point;
   if(diff > 80) return 1;    // BULLISH
   if(diff < -80) return -1;  // BEARISH
   return 0;
}

//+------------------------------------------------------------------+
//| Check M5 for sweep + BOS in bias direction                       |
//+------------------------------------------------------------------+
bool HasM5Setup(int bias) {
   double bos_price = 0;
   datetime bos_time = 0;
   bool bos_found = false;

   for(int b = 1; b < MathMin(InpMaxBarsAfterM5BOS + 10, Bars(_Symbol, InpSetupTF)); b++) {
      double high = iHigh(_Symbol, InpSetupTF, b);
      double low  = iLow(_Symbol, InpSetupTF, b);
      double close = iClose(_Symbol, InpSetupTF, b);
      double open = iOpen(_Symbol, InpSetupTF, b);
      
      // Bullish BOS: close > high of previous 2 bars
      if(bias > 0 && b >= 2) {
         double prev_high = MathMax(iHigh(_Symbol, InpSetupTF, b+1), iHigh(_Symbol, InpSetupTF, b+2));
         if(close > prev_high && high > prev_high) {
            bos_price = high;
            bos_time = iTime(_Symbol, InpSetupTF, b);
            bos_found = true;
            break;
         }
      }
      // Bearish BOS: close < low of previous 2 bars
      if(bias < 0 && b >= 2) {
         double prev_low = MathMin(iLow(_Symbol, InpSetupTF, b+1), iLow(_Symbol, InpSetupTF, b+2));
         if(close < prev_low && low < prev_low) {
            bos_price = low;
            bos_time = iTime(_Symbol, InpSetupTF, b);
            bos_found = true;
            break;
         }
      }
   }
   
   // Guard: BOS too old
   if(bos_found && bos_time > 0) {
      int bars_since = iBarShift(_Symbol, InpSetupTF, bos_time, false);
      if(bars_since > InpMaxBarsAfterM5BOS) bos_found = false;
   }
   
   return bos_found;
}

//+------------------------------------------------------------------+
//| Get M1 candle body ratio                                         |
//+------------------------------------------------------------------+
double GetM1BodyRatio() {
   double o = iOpen(_Symbol, InpEntryTF, 1);
   double c = iClose(_Symbol, InpEntryTF, 1);
   double h = iHigh(_Symbol, InpEntryTF, 1);
   double l = iLow(_Symbol, InpEntryTF, 1);
   double range = h - l;
   if(range <= 0) return 0;
   return MathAbs(c - o) / range;
}

//+------------------------------------------------------------------+
//| M1 entry direction                                               |
//+------------------------------------------------------------------+
int GetM1Direction() {
   double o = iOpen(_Symbol, InpEntryTF, 1);
   double c = iClose(_Symbol, InpEntryTF, 1);
   if(c > o) return 1;    // Bullish
   if(c < o) return -1;   // Bearish
   return 0;
}

//+------------------------------------------------------------------+
//| Check session filter                                             |
//+------------------------------------------------------------------+
bool InSession() {
   if(!InpUseSessionFilter) return true;
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   return (dt.hour >= InpSessionStart && dt.hour < InpSessionEnd);
}

//+------------------------------------------------------------------+
//| Check overextension                                              |
//+------------------------------------------------------------------+
bool IsOverextended(int bias) {
   if(!InpAvoidOverextended) return false;
   double m5_close1 = iClose(_Symbol, InpSetupTF, 1);
   double price_now = (bias > 0) ? iHigh(_Symbol, InpEntryTF, 1) : iLow(_Symbol, InpEntryTF, 1);
   double m1_close = iClose(_Symbol, InpEntryTF, 1);
   double ref = (bias > 0) ? MathMax(m5_close1, price_now) : MathMin(m5_close1, price_now);
   double entry_ref = (bias > 0) ? MathMax(m1_close, iHigh(_Symbol, InpEntryTF, 1)) : MathMin(m1_close, iLow(_Symbol, InpEntryTF, 1));
   double dist = (bias > 0) ? (entry_ref - MathMin(m5_close1, iLow(_Symbol, InpSetupTF, 1))) : (MathMax(m5_close1, iHigh(_Symbol, InpSetupTF, 1)) - entry_ref);
   if(dist / _Point > InpMaxDistFromM5BOS) return true;
   return false;
}

//+------------------------------------------------------------------+
//| OnTick                                                           |
//+------------------------------------------------------------------+
void OnTick() {
   static datetime last_m1 = 0;
   datetime m1_time = iTime(_Symbol, InpEntryTF, 0);
   if(last_m1 == m1_time) return;
   last_m1 = m1_time;
   
   //--- 1. M15 Bias
   int bias = GetBias();
   if(bias == 0) return; // Neutral → skip
   
   //--- 2. Session filter
   if(!InSession()) return;
   
   //--- 3. M5 Setup
   if(InpUseM5TrendConfirm && !HasM5Setup(bias)) return;
   
   //--- 4. Overextension guard
   if(IsOverextended(bias)) return;
   
   //--- 5. M1 candle confirmation
   int m1_dir = GetM1Direction();
   if(m1_dir == 0) return;
   if(bias > 0 && m1_dir < 0) return;  // Bias BUY but M1 bearish
   if(bias < 0 && m1_dir > 0) return;  // Bias SELL but M1 bullish
   
   if(InpUseM1CandleConfirm) {
      double ratio = GetM1BodyRatio();
      if(ratio < InpMinM1BodyRatio) return;
   }
   
   //--- 6. Determine entry
   double entry = 0, sl = 0, tp = 0;
   
   if(bias > 0) {
      entry = iClose(_Symbol, InpEntryTF, 1) + _Point;
      sl    = entry - InpScalpSLPoints * _Point;
      tp    = entry + InpScalpTPPoints * _Point;
   } else {
      entry = iClose(_Symbol, InpEntryTF, 1) - _Point;
      sl    = entry + InpScalpSLPoints * _Point;
      tp    = entry - InpScalpTPPoints * _Point;
   }
   
   //--- 7. Max 1 position guard
   if(g_trade_mgr.CountOpenPositionsByMagic() >= InpMaxOpenPositions) {
      if(InpEnableAutoTrade) Print("SKIP: position exists");
      return;
   }
   
   //--- 8. Execute
   if(g_mode != "DISABLED") {
      string symbol = _Symbol;
      double lot = 0.01;
      
      double risk_money = AccountInfoDouble(ACCOUNT_BALANCE) * InpRiskPercent / 100.0;
      double loss_per_lot = InpScalpSLPoints * _Point * 100000; // simplified
      
      ENUM_ORDER_TYPE cmd = (bias > 0) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
      
      MqlTradeRequest req = {};
      MqlTradeResult res = {};
      req.action = TRADE_ACTION_DEAL;
      req.symbol = symbol;
      req.volume = lot;
      req.type = cmd;
      req.price = (cmd == ORDER_TYPE_BUY) ? SymbolInfoDouble(symbol, SYMBOL_ASK) : SymbolInfoDouble(symbol, SYMBOL_BID);
      req.sl = sl;
      req.tp = tp;
      req.deviation = InpSlippagePoints;
      req.magic = InpMagicNumber;
      
      if(OrderSend(req, res)) {
         Print(StringFormat("ORDER_SENT: %s lot=%.2f entry=%.5f SL=%.5f TP=%.5f ticket=%d",
               (cmd == ORDER_TYPE_BUY ? "BUY" : "SELL"), lot, req.price, sl, tp, res.order));
      } else {
         Print("ORDER_FAIL: retcode=", res.retcode, " err=", GetLastError());
      }
   }
}
//+------------------------------------------------------------------+
