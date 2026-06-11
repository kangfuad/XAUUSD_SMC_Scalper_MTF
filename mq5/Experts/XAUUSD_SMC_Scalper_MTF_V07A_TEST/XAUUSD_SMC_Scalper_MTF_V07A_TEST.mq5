//+------------------------------------------------------------------+
//| XAUUSD_SMC_Scalper_MTF_V07A_TEST.mq5                             |
//| V0.7A.2 TEST: Fixed SL + Entry Filter (modular).                 |
//+------------------------------------------------------------------+
#property copyright "Hermes Agent"
#property version   "7.002"
#property strict
#property description "V0.7A.2 TEST — Fixed SL base."
#property description "Use only in Strategy Tester."

#include <SMC_V07A_TEST/Types.mqh>
#include <SMC_V07A_TEST/MarketStructure.mqh>
#include <SMC_V07A_TEST/SignalEngine.mqh>
#include <SMC_V07A_TEST/ZoneDetector.mqh>
#include <SMC_V07A_TEST/Logger.mqh>
#include <SMC_V07A_TEST/RiskManager.mqh>
#include <SMC_V07A_TEST/TradePlan.mqh>
#include <SMC_V07A_TEST/TradeManager.mqh>

input group "=== V0.1-V0.7 Settings ==="
input bool   InpEnableLogging = true;
input bool   InpEnableCSVLog  = true;
input bool   InpEnableOBDraw  = true;
input bool   InpEnableRetraceLog = true;
input bool   InpEnableTradePlanDryRun = true;
input double InpRiskPercent       = 1.0;
input double InpMinRR             = 1.5;
input double InpTargetRR          = 2.0;
input double InpMaxSpreadPoints   = 50;
input double InpM1MaxSLPips       = 150;
input double InpM1IdealSLPips     = 40;
input double InpM1TPPips          = 150;
input double InpM5SLPips          = 100;
input double InpM5MinTPPips       = 180;
input double InpM5FullTPPips      = 460;
input int    InpSLBufferPoints    = 30;
input bool   InpEnableAutoTrade       = false;
input bool   InpAllowTesterExecution  = true;
input bool   InpAllowDemoExecution    = false;
input int    InpMagicNumber           = 40701;
input int    InpMaxOpenPositions      = 1;
input int    InpSlippagePoints        = 30;
input bool   InpCloseOnOppositeSignal = false;
input bool   InpUseBreakEven          = false;
input double InpBreakEvenAtRR         = 1.0;
input double InpBreakEvenLockPoints   = 10;
input bool   InpEnableContinuationEntry     = true;
input bool   InpEnableRetraceEntry          = true;
input int    InpContinuationMaxBarsAfterBOS = 8;
input int    InpContinuationMinDisplacementPoints = 100;
input int    InpContinuationSLLookbackBars  = 20;
input double InpContinuationTargetRR        = 1.5;
input bool   InpUseFixedMinSL            = true;
input int    InpFixedMinSLPoints         = 150;
input int    InpFixedMinTPPoints         = 300;
input bool   InpForceMinSLForContinuation = true;

CSignalEngine   g_signal_engine;
CSMCLogger      g_logger;
StructMarketState g_market_state;
CZoneDetector   g_zone_detector;
StructZoneState g_zone_state;
StructConfirmationState g_conf_state;
StructConfirmationState g_cont_conf_state;
CTradePlan      g_trade_plan;
StructTradePlan g_trade_plan_state;
CTradeManager   g_trade_manager;
string          g_execution_mode;
ENUM_ENTRY_MODE         g_entry_mode;
ENUM_CONTINUATION_STATUS g_cont_status;

int OnInit() {
   Print("V0.7A.2 Init. Magic=", InpMagicNumber, " SL=", InpFixedMinSLPoints, " TP=", InpFixedMinTPPoints);
   if(InpEnableCSVLog) g_logger.OpenCSV();
   if(InpEnableRetraceLog) g_logger.OpenCSVV03();
   g_trade_plan.Init(InpRiskPercent, InpMinRR, InpTargetRR, InpMaxSpreadPoints, InpM1MaxSLPips, InpM1IdealSLPips, InpM1TPPips, InpM5SLPips, InpM5MinTPPips, InpM5FullTPPips, InpSLBufferPoints);
   g_trade_manager.Init(_Symbol, InpMagicNumber, InpSlippagePoints);
   g_zone_detector.InitContinuation(InpContinuationMaxBarsAfterBOS, InpContinuationMinDisplacementPoints, InpContinuationSLLookbackBars, InpContinuationTargetRR);
   g_execution_mode = "DISABLED";
   if(InpEnableAutoTrade) {
      if(MQLInfoInteger(MQL_TESTER)) { if(InpAllowTesterExecution) g_execution_mode = "TESTER"; }
      else { if((int)AccountInfoInteger(ACCOUNT_TRADE_MODE) == ACCOUNT_TRADE_MODE_DEMO && InpAllowDemoExecution) g_execution_mode = "DEMO"; }
   }
   Print("Mode: ", g_execution_mode);
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason) {
   g_logger.CloseCSV();
   Print("Deinit: ", g_trade_manager.GetExecutionSummary());
}

void OnTick() {
   static datetime last_bar = 0;
   datetime bt = iTime(_Symbol, PERIOD_M15, 0);
   if(last_bar == bt) return;
   last_bar = bt;
   
   g_signal_engine.EvaluateMarketState(g_market_state);
   if(InpEnableLogging) g_logger.LogMarketState(_Symbol, g_market_state);
   
   g_zone_detector.EvaluateZones(PERIOD_M15, g_market_state.last_swing_high.price, g_market_state.last_swing_high.time, g_market_state.last_swing_low.price, g_market_state.last_swing_low.time, g_zone_state);
   if(InpEnableCSVLog) g_logger.LogZoneStateCSV(_Symbol, g_market_state, g_zone_state);
   
   if(InpEnableRetraceEntry) {
      g_zone_detector.EvaluateConfirmation(PERIOD_M15, g_market_state.last_swing_high.price, g_market_state.last_swing_high.time, g_market_state.last_swing_low.price, g_market_state.last_swing_low.time, g_conf_state);
      g_logger.LogConfirmationStateCSV(_Symbol, g_market_state, g_conf_state, g_zone_state.last_ob);
   }
   
   ENUM_ZONE_STATUS sig = ZONE_NO_TRADE;
   ENUM_ENTRY_MODE em = ENTRY_MODE_NONE;
   if(InpEnableContinuationEntry) {
      g_entry_mode = ENTRY_MODE_NONE; g_cont_status = CONTINUATION_NONE;
      g_zone_detector.EvaluateContinuation(PERIOD_M15, g_market_state.last_swing_high.price, g_market_state.last_swing_high.time, g_market_state.last_swing_low.price, g_market_state.last_swing_low.time, g_cont_conf_state, g_entry_mode, g_cont_status);
      if(g_cont_status == CONTINUATION_CONFIRMED && (g_cont_conf_state.final_status == ZONE_READY_BUY || g_cont_conf_state.final_status == ZONE_READY_SELL)) {
         sig = g_cont_conf_state.final_status; em = ENTRY_MODE_CONTINUATION;
      }
   }
   
   if(sig == ZONE_READY_BUY || sig == ZONE_READY_SELL) {
      g_trade_plan.CreateTradePlan(sig, g_trade_plan_state);
      g_trade_plan_state.entry_mode = em;
      if(InpUseFixedMinSL && InpForceMinSLForContinuation && em == ENTRY_MODE_CONTINUATION && g_trade_plan_state.plan_status == TRADE_PLAN_VALID)
         g_trade_plan.ApplyFixedMinSL(g_trade_plan_state, InpFixedMinSLPoints, InpTargetRR);
      g_logger.LogTradePlanCSV(_Symbol, "", g_trade_plan_state);
      if(g_execution_mode != "DISABLED" && g_trade_plan_state.plan_status == TRADE_PLAN_VALID) {
         ulong ticket = 0; uint retcode = 0; int err = 0; string detail = "";
         ENUM_EXECUTION_STATUS exec = g_trade_manager.ExecuteTrade(g_trade_plan_state, ticket, retcode, err, detail);
         g_logger.LogExecutionPrint(_Symbol, g_execution_mode, g_trade_plan_state, exec, ticket, retcode, err, detail);
         g_logger.LogExecutionCSV(_Symbol, g_execution_mode, g_trade_plan_state, exec, ticket, retcode, err, detail);
      }
   }
}
