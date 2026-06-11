//+------------------------------------------------------------------+
//| TradePlan.mqh                                                    |
//| V0.4: Trade plan orchestration                                   |
//|       Dry run only. No auto trade.                               |
//+------------------------------------------------------------------+
#property strict

#include "Types.mqh"
#include "RiskManager.mqh"

class CTradePlan {
private:
   CRiskManager m_risk;
   
public:
   CTradePlan() {}
   
   //--- Initialize risk manager with input params
   void Init(double risk_percent, double min_rr, double target_rr,
             double max_spread_points, double m1_max_sl_pips,
             double m1_ideal_sl_pips, double m1_tp_pips,
             double m5_sl_pips, double m5_min_tp_pips, double m5_full_tp_pips,
             int sl_buffer_points) {
      m_risk.Init(risk_percent, min_rr, target_rr,
                  max_spread_points, m1_max_sl_pips,
                  m1_ideal_sl_pips, m1_tp_pips,
                  m5_sl_pips, m5_min_tp_pips, m5_full_tp_pips,
                  sl_buffer_points);
   }
   
   //--- Create trade plan based on signal status
   //    Only triggers on READY_BUY or READY_SELL
   void CreateTradePlan(ENUM_ZONE_STATUS signal_status,
                        StructTradePlan &plan,
                        double entry_price_hint = 0) {
      
      plan.Reset();
      
      if(signal_status == ZONE_READY_BUY) {
         m_risk.CreateBuyPlan(plan, entry_price_hint);
      } else if(signal_status == ZONE_READY_SELL) {
         m_risk.CreateSellPlan(plan, entry_price_hint);
      } else {
         plan.plan_status = TRADE_PLAN_NONE;
         plan.reject_reason = "No valid signal";
      }
   }
};
