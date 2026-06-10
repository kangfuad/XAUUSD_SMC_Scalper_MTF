//+------------------------------------------------------------------+
//| XAUUSD_SMC_Scalper_MTF.mq5                                       |
//| V0.2: Scanner, Logger, Liquidity Sweep + Order Block.            |
//|       No auto trade.                                             |
//+------------------------------------------------------------------+
#property copyright "Hermes Agent"
#property version   "2.000"
#property strict

#include <SMC/Types.mqh>
#include <SMC/MarketStructure.mqh>
#include <SMC/SignalEngine.mqh>
#include <SMC/ZoneDetector.mqh>
#include <SMC/Logger.mqh>

input group "=== V0.1 Settings ==="
input bool   InpEnableLogging = true;  // Enable M15 structure logging

input group "=== V0.2 Settings ==="
input bool   InpEnableCSVLog  = true;  // Enable CSV logging to Files/XAUUSD_SMC_V02_SweepOBLog.csv
input bool   InpEnableOBDraw  = true;  // Enable Order Block rectangle drawing

//--- V0.1 Globals (unchanged)
CSignalEngine   g_signal_engine;
CSMCLogger      g_logger;
StructMarketState g_market_state;

//--- V0.2 Globals
CZoneDetector   g_zone_detector;
StructZoneState g_zone_state;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit() {
   Print("XAUUSD_SMC_Scalper_MTF V0.2 Initialized. Scanner + Sweep + OB Logger Only.");
   
   // Open CSV if enabled
   if(InpEnableCSVLog) {
      if(!g_logger.OpenCSV()) {
         Print("WARNING: CSV logging disabled due to file error.");
      }
   }
   
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
   g_logger.CloseCSV();
   Print("XAUUSD_SMC_Scalper_MTF V0.2 Deinitialized.");
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
   }
}
//+------------------------------------------------------------------+
