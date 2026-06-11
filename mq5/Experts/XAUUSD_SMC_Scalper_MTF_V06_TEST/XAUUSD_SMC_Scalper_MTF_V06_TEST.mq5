//+------------------------------------------------------------------+
//| XAUUSD_SMC_Scalper_MTF_V06_TEST.mq5                              |
//| V0.6 TEST: Continuation Entry Mode (separate build).             |
//|       Strategy Tester only.                                      |
//+------------------------------------------------------------------+
#property copyright "Hermes Agent"
#property version   "6.000"
#property strict
#property description "V0.6 TEST BUILD — Continuation Entry Mode."
#property description "Use only in Strategy Tester."

#include <SMC_V06_TEST/Types.mqh>
#include <SMC_V06_TEST/MarketStructure.mqh>
#include <SMC_V06_TEST/SignalEngine.mqh>
#include <SMC_V06_TEST/ZoneDetector.mqh>
#include <SMC_V06_TEST/Logger.mqh>
#include <SMC_V06_TEST/RiskManager.mqh>
#include <SMC_V06_TEST/TradePlan.mqh>
#include <SMC_V06_TEST/TradeManager.mqh>

input group "=== V0.1 Settings ==="
input bool   InpEnableLogging = true;

input group "=== V0.2 Settings ==="
input bool   InpEnableCSVLog  = true;
input bool   InpEnableOBDraw  = true;

input group "=== V0.3 Settings ==="
input bool   InpEnableRetraceLog = true;

input group "=== V0.4 Settings ==="
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

input group "=== V0.5 Settings ==="
input bool   InpEnableAutoTrade       = false;
input bool   InpAllowTesterExecution  = true;
input bool   InpAllowDemoExecution    = false;
input int    InpMagicNumber           = 40600;
input int    InpMaxOpenPositions      = 1;
input int    InpSlippagePoints        = 30;
input bool   InpCloseOnOppositeSignal = false;
input bool   InpUseBreakEven          = false;
input double InpBreakEvenAtRR         = 1.0;
input double InpBreakEvenLockPoints   = 10;

input group "=== V0.6 Settings ==="
input bool   InpEnableContinuationEntry     = true;
input bool   InpEnableRetraceEntry          = true;
input int    InpContinuationMaxBarsAfterBOS = 8;
input int    InpContinuationMinDisplacementPoints = 100;
input int    InpContinuationSLLookbackBars  = 20;
input double InpContinuationTargetRR        = 1.5;

//--- V0.1 Globals
CSignalEngine   g_signal_engine;
CSMCLogger      g_logger;
StructMarketState g_market_state;

//--- V0.2 Globals
CZoneDetector   g_zone_detector;
StructZoneState g_zone_state;

//--- V0.3 Globals
StructConfirmationState g_conf_state;
StructConfirmationState g_cont_conf_state; // Separate state for continuation

//--- V0.4 Globals
CTradePlan      g_trade_plan;
StructTradePlan g_trade_plan_state;

//--- V0.5 Globals
CTradeManager   g_trade_manager;
string          g_execution_mode;

//--- V0.6 Globals
ENUM_ENTRY_MODE         g_entry_mode;
ENUM_CONTINUATION_STATUS g_cont_status;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit() {
   Print("XAUUSD_SMC_Scalper_MTF V0.6 TEST Initialized. Retrace + Continuation Modes.");
   
   if(InpEnableCSVLog) { g_logger.OpenCSV(); }
   if(InpEnableRetraceLog) { g_logger.OpenCSVV03(); }
   
   g_trade_plan.Init(InpRiskPercent, InpMinRR, InpTargetRR,
                     InpMaxSpreadPoints, InpM1MaxSLPips,
                     InpM1IdealSLPips, InpM1TPPips,
                     InpM5SLPips, InpM5MinTPPips, InpM5FullTPPips,
                     InpSLBufferPoints);
   
   g_trade_manager.Init(_Symbol, InpMagicNumber, InpSlippagePoints);
   g_zone_detector.InitContinuation(InpContinuationMaxBarsAfterBOS,
                                     InpContinuationMinDisplacementPoints,
                                     InpContinuationSLLookbackBars,
                                     InpContinuationTargetRR);
   
   // Execution mode
   g_execution_mode = "DISABLED";
   if(InpEnableAutoTrade) {
      if(MQLInfoInteger(MQL_TESTER)) {
         if(InpAllowTesterExecution) g_execution_mode = "TESTER";
      } else {
         int mode = (int)AccountInfoInteger(ACCOUNT_TRADE_MODE);
         if(mode == ACCOUNT_TRADE_MODE_DEMO && InpAllowDemoExecution)
            g_execution_mode = "DEMO";
      }
   }
   Print("Execution mode: ", g_execution_mode);
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
   g_logger.CloseCSV();
   Print("XAUUSD_SMC_Scalper_MTF V0.6 TEST Deinitialized. ",
         g_trade_manager.GetExecutionSummary());
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick() {
   static datetime last_bar_time = 0;
   datetime current_bar_time = iTime(_Symbol, PERIOD_M15, 0);
   
   if(last_bar_time != current_bar_time) {
      last_bar_time = current_bar_time;
      
      //--- V0.1: Market state
      g_signal_engine.EvaluateMarketState(g_market_state);
      if(InpEnableLogging) g_logger.LogMarketState(_Symbol, g_market_state);
      
      //--- V0.2: Zones
      g_zone_detector.EvaluateZones(PERIOD_M15,
                                     g_market_state.last_swing_high.price,
                                     g_market_state.last_swing_high.time,
                                     g_market_state.last_swing_low.price,
                                     g_market_state.last_swing_low.time,
                                     g_zone_state);
      if(InpEnableLogging) g_logger.LogZoneState(_Symbol, g_market_state, g_zone_state);
      if(InpEnableCSVLog) g_logger.LogZoneStateCSV(_Symbol, g_market_state, g_zone_state);
      
      //--- V0.3: Retrace confirmation (if enabled)
      if(InpEnableRetraceEntry && InpEnableRetraceLog) {
         g_zone_detector.EvaluateConfirmation(PERIOD_M15,
                                              g_market_state.last_swing_high.price,
                                              g_market_state.last_swing_high.time,
                                              g_market_state.last_swing_low.price,
                                              g_market_state.last_swing_low.time,
                                              g_conf_state);
         if(InpEnableLogging)
            g_logger.LogConfirmationState(_Symbol, g_market_state, g_conf_state);
         g_logger.LogConfirmationStateCSV(_Symbol, g_market_state, g_conf_state, g_zone_state.last_ob);
      }
      
      //--- V0.6: Continuation entry (if enabled)
      if(InpEnableContinuationEntry) {
         g_entry_mode  = ENTRY_MODE_NONE;
         g_cont_status = CONTINUATION_NONE;
         
         g_zone_detector.EvaluateContinuation(PERIOD_M15,
                                              g_market_state.last_swing_high.price,
                                              g_market_state.last_swing_high.time,
                                              g_market_state.last_swing_low.price,
                                              g_market_state.last_swing_low.time,
                                              g_cont_conf_state,
                                              g_entry_mode,
                                              g_cont_status);
         
         if(g_entry_mode != ENTRY_MODE_NONE && InpEnableLogging) {
            string cont_detail = StringFormat("DispPts:%d",
               InpContinuationMinDisplacementPoints);
            g_logger.LogContinuationPrint(_Symbol,
               g_logger.GetSignalStatusString(g_cont_conf_state.final_status),
               g_entry_mode, g_cont_status, cont_detail);
         }
         
         // Log continuation state to CSV
         if(g_entry_mode != ENTRY_MODE_NONE) {
            g_logger.LogContinuationCSV(_Symbol,
               g_logger.GetTrendString(g_market_state.m15_trend),
               g_cont_conf_state, g_entry_mode, g_cont_status,
               "", "", "",
               (g_cont_status == CONTINUATION_CONFIRMED ? "" : "Waiting for confirmation"));
         }
      }
      
      //--- Determine which signal to use (retrace takes priority, then continuation)
      ENUM_ZONE_STATUS final_signal = ZONE_NO_TRADE;
      ENUM_ENTRY_MODE active_entry_mode = ENTRY_MODE_NONE;
      
      if(InpEnableRetraceEntry && (g_conf_state.final_status == ZONE_READY_BUY ||
                                    g_conf_state.final_status == ZONE_READY_SELL)) {
         final_signal = g_conf_state.final_status;
         active_entry_mode = ENTRY_MODE_RETRACE;
      } else if(InpEnableContinuationEntry && g_cont_status == CONTINUATION_CONFIRMED &&
                 (g_cont_conf_state.final_status == ZONE_READY_BUY ||
                  g_cont_conf_state.final_status == ZONE_READY_SELL)) {
         final_signal = g_cont_conf_state.final_status;
         active_entry_mode = ENTRY_MODE_CONTINUATION;
      }
      
      //--- V0.4/V0.5: Trade plan + execution
      if(final_signal == ZONE_READY_BUY || final_signal == ZONE_READY_SELL) {
         g_trade_plan.CreateTradePlan(final_signal, g_trade_plan_state);
         g_trade_plan_state.entry_mode = active_entry_mode;
         
         if(InpEnableLogging) {
            string sig_str = g_logger.GetSignalStatusString(final_signal);
            g_logger.LogTradePlanPrint(_Symbol, sig_str, g_trade_plan_state);
         }
         g_logger.LogTradePlanCSV(_Symbol, "", g_trade_plan_state);
         
         if(InpEnableTradePlanDryRun) {
            g_logger.DrawTradePlanMarkers(g_trade_plan_state);
            g_logger.DrawTradePlanRejected(g_trade_plan_state);
         }
         
         // Execute if mode allows
         if(g_execution_mode != "DISABLED" && g_trade_plan_state.plan_status == TRADE_PLAN_VALID) {
            ulong ticket = 0; uint retcode = 0; int err_code = 0; string err_detail = "";
            ENUM_EXECUTION_STATUS exec = g_trade_manager.ExecuteTrade(
               g_trade_plan_state, ticket, retcode, err_code, err_detail);
            
            string reason = err_detail;
            if(exec == EXECUTION_ORDER_FAILED && reason == "")
               reason = StringFormat("retcode=%d err=%d", retcode, err_code);
            
            g_logger.LogExecutionPrint(_Symbol, g_execution_mode, g_trade_plan_state,
                                        exec, ticket, retcode, err_code, reason);
            g_logger.LogExecutionCSV(_Symbol, g_execution_mode, g_trade_plan_state,
                                      exec, ticket, retcode, err_code, reason);
            g_logger.LogExecutionCSVV06(_Symbol, g_execution_mode, g_trade_plan_state,
                                         exec, ticket, retcode, err_code, reason);
         }
      }
   }
}
//+------------------------------------------------------------------+
