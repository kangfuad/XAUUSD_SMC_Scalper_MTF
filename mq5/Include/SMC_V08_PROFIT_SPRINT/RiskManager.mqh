//+------------------------------------------------------------------+
//| RiskManager.mqh                                                  |
//| V0.4: Lot calculation, validation, SL/TP validation              |
//|       No auto trade. Dry run only.                               |
//+------------------------------------------------------------------+
#property strict

#include "Types.mqh"

class CRiskManager {
private:
   //--- Input parameters
   double m_risk_percent;
   double m_min_rr;
   double m_target_rr;
   double m_max_spread_points;
   double m_m1_max_sl_pips;
   double m_m1_ideal_sl_pips;
   double m_m1_tp_pips;
   double m_m5_sl_pips;
   double m_m5_min_tp_pips;
   double m_m5_full_tp_pips;
   int    m_sl_buffer_points;
   
   //--- Cache symbol info
   double m_tick_value;
   double m_tick_size;
   double m_point;
   double m_volume_min;
   double m_volume_max;
   double m_volume_step;
   int    m_digits;
   
   //--- Update symbol info cache
   void UpdateSymbolInfo() {
      m_tick_value = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
      m_tick_size  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
      m_point      = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      m_volume_min = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
      m_volume_max = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
      m_volume_step= SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
      m_digits     = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   }
   
   //--- Convert points to price
   double PointsToPrice(double points) {
      return points * m_point;
   }
   
   //--- Convert price to points
   double PriceToPoints(double price) {
      return price / m_point;
   }
   
   //--- Normalize lot to symbol rules
   double NormalizeLot(double lot) {
      if(lot < m_volume_min) return 0;
      if(lot > m_volume_max) lot = m_volume_max;
      if(m_volume_step > 0) {
         lot = MathFloor(lot / m_volume_step) * m_volume_step;
      }
      // Re-check min after floor
      if(lot < m_volume_min) return 0;
      return NormalizeDouble(lot, 2);
   }
   
   //--- Find nearest swing low below a price (for BUY SL)
   double FindNearestSwingLowBelow(double above_price, int max_lookback) {
      double lowest = 0;
      for(int i = 1; i <= max_lookback; i++) {
         double low = iLow(_Symbol, PERIOD_M1, i);
         if(low < above_price && (lowest == 0 || low > lowest)) {
            lowest = low;
         }
      }
      // If not found on M1, try M5
      if(lowest == 0) {
         for(int i = 1; i <= 30; i++) {
            double low = iLow(_Symbol, PERIOD_M5, i);
            if(low < above_price && (lowest == 0 || low > lowest)) {
               lowest = low;
            }
         }
      }
      return lowest;
   }
   
   //--- Find nearest swing high above a price (for SELL SL)
   double FindNearestSwingHighAbove(double below_price, int max_lookback) {
      double highest = 0;
      for(int i = 1; i <= max_lookback; i++) {
         double high = iHigh(_Symbol, PERIOD_M1, i);
         if(high > below_price && (highest == 0 || high < highest)) {
            highest = high;
         }
      }
      // If not found on M1, try M5
      if(highest == 0) {
         for(int i = 1; i <= 30; i++) {
            double high = iHigh(_Symbol, PERIOD_M5, i);
            if(high > below_price && (highest == 0 || high < highest)) {
               highest = high;
            }
         }
      }
      return highest;
   }
   
public:
   CRiskManager() {
      m_risk_percent    = 1.0;
      m_min_rr          = 1.5;
      m_target_rr       = 2.0;
      m_max_spread_points  = 50;
      m_m1_max_sl_pips = 150;
      m_m1_ideal_sl_pips = 40;
      m_m1_tp_pips     = 150;
      m_m5_sl_pips     = 100;
      m_m5_min_tp_pips = 180;
      m_m5_full_tp_pips= 460;
      m_sl_buffer_points= 30;
      UpdateSymbolInfo();
   }
   
   //--- Initialize with input parameters
   void Init(double risk_percent, double min_rr, double target_rr,
             double max_spread_points, double m1_max_sl_pips,
             double m1_ideal_sl_pips, double m1_tp_pips,
             double m5_sl_pips, double m5_min_tp_pips, double m5_full_tp_pips,
             int sl_buffer_points) {
      m_risk_percent     = risk_percent;
      m_min_rr           = min_rr;
      m_target_rr        = target_rr;
      m_max_spread_points  = max_spread_points;
      m_m1_max_sl_pips   = m1_max_sl_pips;
      m_m1_ideal_sl_pips = m1_ideal_sl_pips;
      m_m1_tp_pips       = m1_tp_pips;
      m_m5_sl_pips       = m5_sl_pips;
      m_m5_min_tp_pips   = m5_min_tp_pips;
      m_m5_full_tp_pips  = m5_full_tp_pips;
      m_sl_buffer_points = sl_buffer_points;
      UpdateSymbolInfo();
   }
   
   //--- Calculate lot size from risk money and SL distance
   double CalculateLotSize(double risk_money, double sl_points, string &error) {
      UpdateSymbolInfo();
      
      if(m_tick_size <= 0 || m_tick_value <= 0) {
         error = "Invalid tick value/size";
         return 0;
      }
      if(sl_points <= 0) {
         error = "SL points must be > 0";
         return 0;
      }
      
      // Loss per lot = sl_points * tick_value / tick_size in points equivalent
      // Actually: loss_per_lot = sl_price_distance * (tick_value / tick_size)
      // sl_price_distance = sl_points * m_point
      double sl_price_distance = sl_points * m_point;
      double loss_per_lot = (sl_price_distance / m_tick_size) * m_tick_value;
      
      if(loss_per_lot <= 0) {
         error = "Loss per lot calculation failed";
         return 0;
      }
      
      double lot = risk_money / loss_per_lot;
      lot = NormalizeLot(lot);
      
      if(lot <= 0) {
         error = "Lot below minimum";
         return 0;
      }
      
      return lot;
   }
   
   //--- Validate spread
   bool ValidateSpread(double spread_points, string &reason) {
      if(spread_points > m_max_spread_points) {
         reason = StringFormat("Spread %.0f > max %.0f pts", spread_points, m_max_spread_points);
         return false;
      }
      return true;
   }
   
   //--- Validate stop level (entry to SL must meet broker's STOPS_LEVEL)
   bool ValidateStopLevel(double entry, double sl, ENUM_TRADE_DIRECTION dir, string &reason) {
      int stop_level = (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
      if(stop_level <= 0) return true; // No restriction
      
      double sl_distance = MathAbs(entry - sl);
      double sl_dist_points = sl_distance / m_point;
      
      if(sl_dist_points < stop_level) {
         reason = StringFormat("SL %.0f pts < stop level %d pts", sl_dist_points, stop_level);
         return false;
      }
      return true;
   }
   
   //--- Validate RR ratio
   bool ValidateRR(double rr, string &reason) {
      if(rr < m_min_rr) {
         reason = StringFormat("RR %.2f < min %.2f", rr, m_min_rr);
         return false;
      }
      return true;
   }
   
   //--- Create BUY trade plan
   void CreateBuyPlan(StructTradePlan &plan, double entry_price_hint) {
      plan.Reset();
      plan.direction = TRADE_DIR_BUY;
      UpdateSymbolInfo();
      
      double spread = (double)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
      plan.spread_points = spread;
      
      // Validate spread
      if(!ValidateSpread(spread, plan.reject_reason)) {
         plan.plan_status = TRADE_PLAN_REJECTED;
         return;
      }
      
      // Entry: current Ask (dry run)
      double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(entry <= 0) {
         plan.reject_reason = "Invalid Ask price";
         plan.plan_status = TRADE_PLAN_REJECTED;
         return;
      }
      plan.entry_price = entry;
      
      // Find nearest swing low below entry
      double swing_low = FindNearestSwingLowBelow(entry, 100);
      if(swing_low <= 0) {
         plan.reject_reason = "No swing low found below entry";
         plan.plan_status = TRADE_PLAN_REJECTED;
         return;
      }
      
      // SL = swing low - buffer
      double sl = swing_low - PointsToPrice(m_sl_buffer_points);
      if(sl >= entry) {
         plan.reject_reason = "SL above entry after buffer";
         plan.plan_status = TRADE_PLAN_REJECTED;
         return;
      }
      plan.sl_price = sl;
      
      // SL distance
      double sl_dist = entry - sl;
      double sl_pts = sl_dist / m_point;
      
      // Validate max SL
      double max_sl_price = m_m1_max_sl_pips * 10 * m_point; // pips * 10 = points
      if(sl_dist > max_sl_price) {
         plan.reject_reason = StringFormat("SL %.0f pts > max %.0f pts", sl_pts, m_m1_max_sl_pips * 10);
         plan.plan_status = TRADE_PLAN_REJECTED;
         return;
      }
      plan.sl_points = sl_pts;
      
      // TP = entry + targetRR * sl_dist
      double target_distance = m_target_rr * sl_dist;
      double tp = entry + target_distance;
      plan.tp_price = tp;
      plan.tp_points = target_distance / m_point;
      
      // RR
      double rr = target_distance / sl_dist;
      plan.rr = rr;
      
      // Validate RR
      if(!ValidateRR(rr, plan.reject_reason)) {
         plan.plan_status = TRADE_PLAN_REJECTED;
         return;
      }
      
      // Stop level validation
      if(!ValidateStopLevel(entry, sl, TRADE_DIR_BUY, plan.reject_reason)) {
         plan.plan_status = TRADE_PLAN_REJECTED;
         return;
      }
      
      // Risk money
      double balance = AccountInfoDouble(ACCOUNT_BALANCE);
      plan.risk_percent = m_risk_percent;
      plan.risk_money = balance * m_risk_percent / 100.0;
      
      // Lot size
      string lot_error = "";
      plan.lot_size = CalculateLotSize(plan.risk_money, sl_pts, lot_error);
      if(plan.lot_size <= 0) {
         if(lot_error != "") plan.reject_reason = lot_error;
         else plan.reject_reason = "Lot calculation failed";
         plan.plan_status = TRADE_PLAN_REJECTED;
         return;
      }
      
      // Stop level
      plan.stop_level_points = (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
      plan.freeze_level_points = (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_FREEZE_LEVEL);
      plan.signal_time = TimeCurrent();
      
      plan.valid = true;
      plan.plan_status = TRADE_PLAN_VALID;
   }
   
   //--- Create SELL trade plan
   void CreateSellPlan(StructTradePlan &plan, double entry_price_hint) {
      plan.Reset();
      plan.direction = TRADE_DIR_SELL;
      UpdateSymbolInfo();
      
      double spread = (double)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
      plan.spread_points = spread;
      
      // Validate spread
      if(!ValidateSpread(spread, plan.reject_reason)) {
         plan.plan_status = TRADE_PLAN_REJECTED;
         return;
      }
      
      // Entry: current Bid (dry run)
      double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(entry <= 0) {
         plan.reject_reason = "Invalid Bid price";
         plan.plan_status = TRADE_PLAN_REJECTED;
         return;
      }
      plan.entry_price = entry;
      
      // Find nearest swing high above entry
      double swing_high = FindNearestSwingHighAbove(entry, 100);
      if(swing_high <= 0) {
         plan.reject_reason = "No swing high found above entry";
         plan.plan_status = TRADE_PLAN_REJECTED;
         return;
      }
      
      // SL = swing high + buffer
      double sl = swing_high + PointsToPrice(m_sl_buffer_points);
      if(sl <= entry) {
         plan.reject_reason = "SL below entry after buffer";
         plan.plan_status = TRADE_PLAN_REJECTED;
         return;
      }
      plan.sl_price = sl;
      
      // SL distance
      double sl_dist = sl - entry;
      double sl_pts = sl_dist / m_point;
      
      // Validate max SL
      double max_sl_price = m_m1_max_sl_pips * 10 * m_point; // pips * 10 = points
      if(sl_dist > max_sl_price) {
         plan.reject_reason = StringFormat("SL %.0f pts > max %.0f pts", sl_pts, m_m1_max_sl_pips * 10);
         plan.plan_status = TRADE_PLAN_REJECTED;
         return;
      }
      plan.sl_points = sl_pts;
      
      // TP = entry - targetRR * sl_dist
      double target_distance = m_target_rr * sl_dist;
      double tp = entry - target_distance;
      plan.tp_price = tp;
      plan.tp_points = target_distance / m_point;
      
      // RR
      double rr = target_distance / sl_dist;
      plan.rr = rr;
      
      // Validate RR
      if(!ValidateRR(rr, plan.reject_reason)) {
         plan.plan_status = TRADE_PLAN_REJECTED;
         return;
      }
      
      // Stop level validation
      if(!ValidateStopLevel(entry, sl, TRADE_DIR_SELL, plan.reject_reason)) {
         plan.plan_status = TRADE_PLAN_REJECTED;
         return;
      }
      
      // Risk money
      double balance = AccountInfoDouble(ACCOUNT_BALANCE);
      plan.risk_percent = m_risk_percent;
      plan.risk_money = balance * m_risk_percent / 100.0;
      
      // Lot size
      string lot_error = "";
      plan.lot_size = CalculateLotSize(plan.risk_money, sl_pts, lot_error);
      if(plan.lot_size <= 0) {
         if(lot_error != "") plan.reject_reason = lot_error;
         else plan.reject_reason = "Lot calculation failed";
         plan.plan_status = TRADE_PLAN_REJECTED;
         return;
      }
      
      // Stop level
      plan.stop_level_points = (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
      plan.freeze_level_points = (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_FREEZE_LEVEL);
      plan.signal_time = TimeCurrent();
      
      plan.valid = true;
      plan.plan_status = TRADE_PLAN_VALID;
   }
};
