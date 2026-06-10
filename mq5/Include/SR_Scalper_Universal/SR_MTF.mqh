//+------------------------------------------------------------------+
//| SR_MTF.mqh — MTF analysis v1.1 (zone-relative bias + EMA)       |
//+------------------------------------------------------------------+
#property strict

#include "SR_Core.mqh"

struct MTFState {
   int     m15_bias;
   double  m15_support;
   double  m15_resistance;
   double  m15_atr;
   double  m15_ema;
   
   int     m5_setup;
   int     m5_tier;
   double  m5_zone_dist;
   double  m5_atr;
   
   int     m1_trigger;
   bool    entry_allowed;
};

class CSRMTF {
protected:
   CSRCore  m_core;
   double   m_max_dist_mult;
   bool     m_allow_weak;
   int      m_pattern_lb;
   double   m_bias_thresh;
   bool     m_use_trend;
   int      m_trend_ema;
   double m_m5_mom;
   bool   m_allow_consec;
   bool   m_allow_engulf, m_allow_pinbar, m_allow_momentum, m_allow_consec_close;
   
public:
   void Init(int sr_lb, int sr_min, double zt, int ml, double mdm,
             bool allow_weak, int pattern_lb,
             double bias_thresh, bool use_trend, int trend_ema,
             double m5_mom, bool allow_consec,
             bool allow_engulf, bool allow_pinbar,
             bool allow_momentum, bool allow_consec_close) {
      m_core.Init(sr_lb, sr_min, zt, ml);
      m_max_dist_mult = MathMax(mdm, 0.1);
      m_allow_weak = allow_weak;
      m_pattern_lb = MathMax(pattern_lb, 2);
      m_bias_thresh = MathMax(MathMin(bias_thresh, 0.49), 0.1);
      m_use_trend = use_trend;
      m_trend_ema = MathMax(trend_ema, 10);
      m_m5_mom = MathMax(m5_mom, 0.05);
      m_allow_consec = allow_consec;
      m_allow_engulf = allow_engulf;
      m_allow_pinbar = allow_pinbar;
      m_allow_momentum = allow_momentum;
      m_allow_consec_close = allow_consec_close;
   }
   
   //--- Main analysis
   void Analyze(string sym, MTFState &st) {
      st.m15_bias = 0; st.m5_setup = 0; st.m1_trigger = 0; st.entry_allowed = false;
      st.m5_tier = 0;
      
      SRState sr;
      m_core.ScanSR(sym, PERIOD_M15, sr);
      st.m15_atr = GetATR(sym, PERIOD_M15, 14, 1);
      
      // EMA trend
      if(m_use_trend && st.m15_atr > 0) {
         st.m15_ema = GetEMA(sym, PERIOD_M15, m_trend_ema, 1);
      } else st.m15_ema = 0;
      
      double curr = SymbolInfoDouble(sym, SYMBOL_BID);
      
      //--- Bias via zone-relative logic
      st.m15_bias = 0;
      if(sr.nearest_support > 0 && sr.nearest_resistance > 0) {
         double dr = sr.nearest_resistance - curr;
         double ds = curr - sr.nearest_support;
         double total = dr + ds;
         if(total > 0) {
            if(ds / total < m_bias_thresh) st.m15_bias = 1;    // near support = BUY
            else if(dr / total < m_bias_thresh) st.m15_bias = -1; // near resistance = SELL
         }
      } else if(sr.nearest_support > 0) {
         st.m15_bias = 1;  // Only support visible → BUY bias
      } else if(sr.nearest_resistance > 0) {
         st.m15_bias = -1; // Only resistance visible → SELL bias
      }
      
      // EMA confirmation
      if(st.m15_bias != 0 && m_use_trend && st.m15_ema > 0) {
         if(st.m15_bias > 0 && curr < st.m15_ema) st.m15_bias = 0;
         if(st.m15_bias < 0 && curr > st.m15_ema) st.m15_bias = 0;
      }
      
      st.m15_support    = sr.nearest_support;
      st.m15_resistance = sr.nearest_resistance;
      
      if(st.m15_bias == 0 || st.m15_atr <= 0) return;
      
      //--- M5 zone distance
      st.m5_atr = GetATR(sym, PERIOD_M5, 14, 1);
      if(st.m5_atr <= 0) return;
      
      double max_dist = st.m5_atr * m_max_dist_mult;
      
      if(st.m15_bias > 0 && sr.nearest_support > 0)
         st.m5_zone_dist = curr - sr.nearest_support;
      else if(st.m15_bias < 0 && sr.nearest_resistance > 0)
         st.m5_zone_dist = sr.nearest_resistance - curr;
      else return;
      
      if(st.m5_zone_dist < 0 || st.m5_zone_dist > max_dist) return;
      
      //--- M5 tiered pattern
      int setup = 0, tier = 0;
      M5Pattern(sym, st.m15_bias, setup, tier,
                m_allow_engulf, m_allow_pinbar,
                m_allow_momentum, m_allow_consec_close);
      if(setup == 0 || setup != st.m15_bias) return;
      if(tier == 3 && !m_allow_weak) return;
      
      st.m5_setup = setup;
      st.m5_tier  = tier;
      
      //--- M1 trigger
      st.m1_trigger = CheckM1Trigger(sym, st.m15_bias);
      if(st.m1_trigger == 0 || st.m1_trigger != st.m15_bias) return;
      
      st.entry_allowed = true;
   }
   
   //--- Tiered M5 pattern detection v1.1
   void M5Pattern(string sym, int bias, int &setup, int &tier,
                   bool allow_engulf, bool allow_pinbar,
                   bool allow_momentum, bool allow_consec) {
      setup = 0; tier = 0;
      
      double o0 = iOpen(sym, PERIOD_M5, 1);
      double c0 = iClose(sym, PERIOD_M5, 1);
      double h0 = iHigh(sym, PERIOD_M5, 1);
      double l0 = iLow(sym, PERIOD_M5, 1);
      double o1 = iOpen(sym, PERIOD_M5, 2);
      double c1 = iClose(sym, PERIOD_M5, 2);
      
      double body0 = MathAbs(c0 - o0);
      double upper = h0 - MathMax(o0, c0);
      double lower = MathMin(o0, c0) - l0;
      double mid   = (h0 + l0) / 2.0;
      double atr5  = GetATR(sym, PERIOD_M5, 14, 1);
      
      // Check if Tier 1 exists in lookback window
      bool tier1_recent = false;
      int max_b = MathMin(m_pattern_lb, Bars(sym, PERIOD_M5) - 3);
      for(int b = 1; b <= max_b; b++) {
         double bo = iOpen(sym, PERIOD_M5, b);
         double bc = iClose(sym, PERIOD_M5, b);
         double bp_bo = iOpen(sym, PERIOD_M5, b+1);
         double bp_bc = iClose(sym, PERIOD_M5, b+1);
         if(bias > 0) {
            if(bc > bo && bc > bp_bo && bo < bp_bc) { tier1_recent = true; break; }
         } else {
            if(bc < bo && bc < bp_bo && bo > bp_bc) { tier1_recent = true; break; }
         }
      }
      
      //--- TIER 1: Strong
      if(bias > 0) {
         if(allow_engulf && c0 > o0 && c0 > o1 && o0 < c1 && body0 > 0) { setup = 1; tier = 1; return; }
         if(allow_pinbar && c0 > o0 && lower > 2.0 * body0 && body0 > 0 && c0 > mid) { setup = 1; tier = 1; return; }
      } else {
         if(allow_engulf && c0 < o0 && c0 < o1 && o0 > c1 && body0 > 0) { setup = -1; tier = 1; return; }
         if(allow_pinbar && c0 < o0 && upper > 2.0 * body0 && body0 > 0 && c0 < mid) { setup = -1; tier = 1; return; }
      }
      
      //--- TIER 2: Moderate
      if(!tier1_recent) {
         if(allow_momentum && atr5 > 0 && body0 > m_m5_mom * atr5) {
            if(c0 > o0 && c0 > c1 && bias > 0) { setup = 1; tier = 2; return; }
            if(c0 < o0 && c0 < c1 && bias < 0) { setup = -1; tier = 2; return; }
         }
         if(allow_consec) {
            if(bias > 0 && c0 > o0 && c1 > o1 && c0 > c1) { setup = 1; tier = 2; return; }
            if(bias < 0 && c0 < o0 && c1 < o1 && c0 < c1) { setup = -1; tier = 2; return; }
         }
      }
      
      //--- TIER 3: Weak (only if m_allow_weak)
      if(m_allow_weak && !tier1_recent) {
         if(bias > 0 && c0 > o0 && c1 > o1) { setup = 1; tier = 3; return; }
         if(bias < 0 && c0 < o0 && c1 < o1) { setup = -1; tier = 3; return; }
      }
   }
   
   //--- M1 trigger
   int CheckM1Trigger(string sym, int bias) {
      double o1 = iOpen(sym, PERIOD_M1, 1);
      double c1 = iClose(sym, PERIOD_M1, 1);
      if(c1 > o1 && bias > 0) return 1;
      if(c1 < o1 && bias < 0) return -1;
      return 0;
   }
};
//+------------------------------------------------------------------+
