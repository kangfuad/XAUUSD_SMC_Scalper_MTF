//+------------------------------------------------------------------+
//| XAUUSD_SMC_Scalper_MTF_V05_TEST.mq5                              |
//| V0.5 TEST: Auto Trade Controlled Mode (separate build).          |
//|       Strategy Tester only. Does not affect live V0.4 EA.        |
//+------------------------------------------------------------------+
#property copyright "Hermes Agent"
#property version   "5.000"
#property strict
#property description "V0.5 TEST BUILD — Separate from V0.4 demo EA."
#property description "Use only in Strategy Tester."

#include <SMC_V05_TEST/Types.mqh>
#include <SMC_V05_TEST/MarketStructure.mqh>
#include <SMC_V05_TEST/SignalEngine.mqh>
#include <SMC_V05_TEST/ZoneDetector.mqh>
#include <SMC_V05_TEST/Logger.mqh>
#include <SMC_V05_TEST/RiskManager.mqh>
#include <SMC_V05_TEST/TradePlan.mqh>
#include <SMC_V05_TEST/TradeManager.mqh>

input group "=== V0.1 Settings ==="
input bool   InpEnableLogging = true;  // Enable M15 structure logging

input group "=== V0.2 Settings ==="
input bool   InpEnableCSVLog  = true;  // Enable CSV logging to Files/XAUUSD_SMC_V02_SweepOBLog.csv
input bool   InpEnableOBDraw  = true;  // Enable Order Block rectangle drawing

input group "=== V0.3 Settings ==="
input bool   InpEnableRetraceLog = true;  // Enable Retrace + M5 Confirm logging

input group "=== V0.4 Settings ==="
input bool   InpEnableTradePlanDryRun = true;  // Enable trade plan dry run
input double InpRiskPercent       = 1.0;       // Risk percentage per trade
input double InpMinRR             = 1.5;       // Minimum risk/reward ratio
input double InpTargetRR          = 2.0;       // Target risk/reward ratio
input double InpMaxSpreadPoints   = 50;        // Max spread in points
input double InpM1MaxSLPips       = 150;       // Max M1 SL in pips
input double InpM1IdealSLPips     = 40;        // Ideal M1 SL in pips
input double InpM1TPPips          = 150;       // M1 TP in pips
input double InpM5SLPips          = 100;       // M5 SL in pips
input double InpM5MinTPPips       = 180;       // M5 min TP in pips
input double InpM5FullTPPips      = 460;       // M5 full TP in pips
input int    InpSLBufferPoints    = 30;        // SL buffer in points

input group "=== V0.5 Settings ==="
input bool   InpEnableAutoTrade       = false;   // Enable auto trade (master switch)
input bool   InpAllowTesterExecution  = true;    // Allow execution in Strategy Tester
input bool   InpAllowDemoExecution    = false;   // Allow execution on demo account
input int    InpMagicNumber           = 40505;   // Magic number for orders (V05 TEST)
input int    InpMaxOpenPositions      = 1;       // Max open positions per symbol+magic
input int    InpSlippagePoints        = 30;      // Max slippage in points
input bool   InpCloseOnOppositeSignal = false;   // Close position on opposite signal
input bool   InpUseBreakEven          = false;   // Enable break-even management
input double InpBreakEvenAtRR         = 1.0;     // RR level to trigger break-even
input double InpBreakEvenLockPoints   = 10;      // Lock profit points after break-even

//--- V0.1 Globals (unchanged)
CSignalEngine   g_signal_engine;
CSMCLogger      g_logger;
StructMarketState g_market_state;

//--- V0.2 Globals
CZoneDetector   g_zone_detector;
StructZoneState g_zone_state;

//--- V0.3 Globals
StructConfirmationState g_conf_state;

//--- V0.4 Globals
CTradePlan      g_trade_plan;
StructTradePlan g_trade_plan_state;

//--- V0.5 Globals
CTradeManager   g_trade_manager;
string          g_execution_mode;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit() {
   Print("XAUUSD_SMC_Scalper_MTF V0.5 TEST Initialized. Scanner + Sweep + OB + Retrace + M5 Confirm + Auto Trade Controlled.");
   
   // Open CSV if enabled
   if(InpEnableCSVLog) {
      if(!g_logger.OpenCSV()) {
         Print("WARNING: CSV logging disabled due to file error.");
      }
   }
   
   // Open V0.3 CSV if retrace logging enabled
   if(InpEnableRetraceLog) {
      if(!g_logger.OpenCSVV03()) {
         Print("WARNING: V0.3 CSV logging disabled due to file error.");
      }
   }
   
   // Init trade plan with inputs
   g_trade_plan.Init(InpRiskPercent, InpMinRR, InpTargetRR,
                     InpMaxSpreadPoints, InpM1MaxSLPips,
                     InpM1IdealSLPips, InpM1TPPips,
                     InpM5SLPips, InpM5MinTPPips, InpM5FullTPPips,
                     InpSLBufferPoints);
   
   // Init trade manager with separate magic number
   g_trade_manager.Init(_Symbol, InpMagicNumber, InpSlippagePoints);
   
   // Determine execution mode
   g_execution_mode = "DISABLED";
   if(InpEnableAutoTrade) {
      if(MQLInfoInteger(MQL_TESTER)) {
         if(InpAllowTesterExecution) {
            g_execution_mode = "TESTER";
         }
      } else {
         int trade_mode = (int)AccountInfoInteger(ACCOUNT_TRADE_MODE);
         if(trade_mode == ACCOUNT_TRADE_MODE_DEMO && InpAllowDemoExecution) {
            g_execution_mode = "DEMO";
         }
      }
   }
   
   Print("Execution mode: ", g_execution_mode);
   if(InpEnableAutoTrade) {
      Print("WARNING: Auto trade enabled. Magic number: ", InpMagicNumber);
   }
   
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
   g_logger.CloseCSV();
   Print("XAUUSD_SMC_Scalper_MTF V0.5 TEST Deinitialized. ",
         g_trade_manager.GetExecutionSummary());
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick() {
   // Only process on new M15 candle (closed candles, shift >= 1)
   static datetime last_bar_time = 0;
   datetime current_bar_time = iTime(_Symbol, PERIOD_M15, 0);
   
   if(last_bar_time != current_bar_time) {
      last_bar_time = current_bar_time;
      
      //--- V0.1: Evaluate market state (trend, swings, BOS)
      g_signal_engine.EvaluateMarketState(g_market_state);
      
      if(InpEnableLogging) {
         g_logger.LogMarketState(_Symbol, g_market_state);
      }
      
      //--- V0.2: Evaluate zones (sweep -> BOS -> OB)
      g_zone_detector.EvaluateZones(PERIOD_M15,
                                     g_market_state.last_swing_high.price,
                                     g_market_state.last_swing_high.time,
                                     g_market_state.last_swing_low.price,
                                     g_market_state.last_swing_low.time,
                                     g_zone_state);
      
      // Log zone state to Experts tab
      if(InpEnableLogging) {
         g_logger.LogZoneState(_Symbol, g_market_state, g_zone_state);
      }
      
      // Log zone state to CSV
      if(InpEnableCSVLog) {
         g_logger.LogZoneStateCSV(_Symbol, g_market_state, g_zone_state);
      }
      
      //--- V0.3: Evaluate confirmation chain (retrace -> M5 confirm -> candle confirm)
      if(InpEnableRetraceLog) {
         g_zone_detector.EvaluateConfirmation(PERIOD_M15,
                                              g_market_state.last_swing_high.price,
                                              g_market_state.last_swing_high.time,
                                              g_market_state.last_swing_low.price,
                                              g_market_state.last_swing_low.time,
                                              g_conf_state);
         
         // Log confirmation state to Experts tab
         if(InpEnableLogging) {
            g_logger.LogConfirmationState(_Symbol, g_market_state, g_conf_state);
         }
         
         // Log confirmation state to CSV
         g_logger.LogConfirmationStateCSV(_Symbol, g_market_state, g_conf_state, g_zone_state.last_ob);
      }
      
      //--- V0.4: Create Trade Plan if signal is READY
      {
         ENUM_ZONE_STATUS signal = g_conf_state.final_status;
         
         if(signal == ZONE_READY_BUY || signal == ZONE_READY_SELL) {
            g_trade_plan.CreateTradePlan(signal, g_trade_plan_state);
            
            // Log to Journal
            if(InpEnableLogging) {
               string signal_str = g_logger.GetSignalStatusString(signal);
               g_logger.LogTradePlanPrint(_Symbol, signal_str, g_trade_plan_state);
            }
            
            // Log to CSV
            g_logger.LogTradePlanCSV(_Symbol, "", g_trade_plan_state);
            
            // Draw markers (only if dry run mode)
            if(InpEnableTradePlanDryRun) {
               g_logger.DrawTradePlanMarkers(g_trade_plan_state);
               g_logger.DrawTradePlanRejected(g_trade_plan_state);
            }
            
            //--- V0.5: Execute trade if mode allows
            if(g_execution_mode != "DISABLED" && g_trade_plan_state.plan_status == TRADE_PLAN_VALID) {
               ulong ticket = 0;
               uint retcode = 0;
               int error_code = 0;
               string error_detail = "";
               
               ENUM_EXECUTION_STATUS exec = g_trade_manager.ExecuteTrade(
                  g_trade_plan_state, ticket, retcode, error_code, error_detail
               );
               
               // Build reason string
               string reason = error_detail;
               if(exec == EXECUTION_ORDER_FAILED && reason == "") {
                  reason = StringFormat("retcode=%d err=%d", retcode, error_code);
               }
               
               // Log execution
               g_logger.LogExecutionPrint(_Symbol, g_execution_mode,
                                           g_trade_plan_state, exec,
                                           ticket, retcode, error_code, reason);
               
               // Log to CSV
               g_logger.LogExecutionCSV(_Symbol, g_execution_mode,
                                         g_trade_plan_state, exec,
                                         ticket, retcode, error_code, reason);
            }
         }
      }
   }
}
//+------------------------------------------------------------------+
