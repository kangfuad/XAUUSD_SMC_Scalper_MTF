//+------------------------------------------------------------------+
//| XAUUSD_SMC_Scalper_MTF.mq5                                       |
//| V0.1: Scanner and Logger only. No auto trade.                    |
//+------------------------------------------------------------------+
#property copyright "Hermes Agent"
#property version   "1.000"
#property strict

#include <SMC/Types.mqh>
#include <SMC/MarketStructure.mqh>
#include <SMC/SignalEngine.mqh>
#include <SMC/Logger.mqh>

input group "=== V0.1 Settings ==="
input bool   InpEnableLogging = true;  // Enable M15 structure logging

CSignalEngine g_signal_engine;
CSMCLogger    g_logger;
StructMarketState g_market_state;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit() {
   Print("XAUUSD_SMC_Scalper_MTF V0.1 Initialized. Scanner & Logger Only.");
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
   Print("XAUUSD_SMC_Scalper_MTF V0.1 Deinitialized.");
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick() {
   // V0.1: Only process on new candle to ensure closed candles logic
   static datetime last_bar_time = 0;
   datetime current_bar_time = iTime(_Symbol, PERIOD_M15, 0);
   
   if(last_bar_time != current_bar_time) {
      last_bar_time = current_bar_time;
      
      // Evaluate market state based on closed candles (shift >= 1)
      g_signal_engine.EvaluateMarketState(g_market_state);
      
      // Log the state
      if(InpEnableLogging) {
         g_logger.LogMarketState(_Symbol, g_market_state);
      }
   }
}
//+------------------------------------------------------------------+