//+------------------------------------------------------------------+
//| SR_Core.mqh — S/R zone detection + ATR helper                    |
//+------------------------------------------------------------------+
#property strict

//--- ATR helper (handle-based for MQL5 strict mode)
double GetATR(string sym, ENUM_TIMEFRAMES tf, int period, int shift) {
   int h = iATR(sym, tf, period);
   if(h == INVALID_HANDLE) return 0;
   double buf[];
   bool ok = CopyBuffer(h, 0, shift, 1, buf);
   IndicatorRelease(h);
   if(ok && ArraySize(buf) > 0) return buf[0];
   return 0;
}

//--- EMA helper (handle-based)
double GetEMA(string sym, ENUM_TIMEFRAMES tf, int period, int shift) {
   int h = iMA(sym, tf, period, 0, MODE_EMA, PRICE_CLOSE);
   if(h == INVALID_HANDLE) return 0;
   double buf[];
   bool ok = CopyBuffer(h, 0, shift, 1, buf);
   IndicatorRelease(h);
   if(ok && ArraySize(buf) > 0) return buf[0];
   return 0;
}

struct SRLevel {
   double price;
   int    touch_count;
   bool   is_support;
   bool   is_resistance;
};

struct SRState {
   SRLevel levels[];
   double  nearest_support;
   double  nearest_resistance;
   double  midpoint;
   int     bias;
};

class CSRCore {
protected:
   int      m_lookback;
   int      m_min_tests;
   double   m_tolerance;
   int      m_max_levels;
   
public:
   void Init(int lookback, int min_tests, double tolerance, int max_levels) {
      m_lookback   = MathMax(lookback, 20);
      m_min_tests  = MathMax(min_tests, 1);
      m_tolerance  = MathMax(tolerance, 0.1);
      m_max_levels = MathMax(max_levels, 3);
   }
   
   void ScanSR(string sym, ENUM_TIMEFRAMES tf, SRState &st) {
      ArrayResize(st.levels, 0);
      st.nearest_support = 0; st.nearest_resistance = 0; st.bias = 0;
      
      int bars = MathMin(m_lookback, Bars(sym, tf) - 3);
      if(bars < 10) return;
      
      double swh[], swl[];
      ArrayResize(swh, 0); ArrayResize(swl, 0);
      
      for(int i = 2; i < bars - 1; i++) {
         double h = iHigh(sym, tf, i);
         if(h > iHigh(sym, tf, i+1) && h >= iHigh(sym, tf, i-1)) {
            ArrayResize(swh, ArraySize(swh)+1);
            swh[ArraySize(swh)-1] = h;
         }
         double l = iLow(sym, tf, i);
         if(l < iLow(sym, tf, i+1) && l <= iLow(sym, tf, i-1)) {
            ArrayResize(swl, ArraySize(swl)+1);
            swl[ArraySize(swl)-1] = l;
         }
      }
      
      if(ArraySize(swh) < 1 && ArraySize(swl) < 1) return;
      
      double atr = GetATR(sym, tf, 14, 1);
      double zw = atr * m_tolerance;
      if(zw <= 0) zw = 10 * _Point;
      
      bool uh[];
      ArrayResize(uh, ArraySize(swh));
      for(int i = 0; i < ArraySize(swh); i++) {
         if(uh[i]) continue;
         double cl = swh[i]; int cnt = 1;
         for(int j = i+1; j < ArraySize(swh); j++) {
            if(uh[j]) continue;
            if(MathAbs(swh[j] - cl) <= zw) {
               cl = (cl * cnt + swh[j]) / (cnt + 1); cnt++; uh[j] = true;
            }
         }
         if(cnt >= m_min_tests) {
            int n = ArraySize(st.levels); ArrayResize(st.levels, n+1);
            st.levels[n].price = NormalizeDouble(cl, (int)SymbolInfoInteger(sym, SYMBOL_DIGITS));
            st.levels[n].touch_count = cnt; st.levels[n].is_resistance = true;
         } else if(atr > 0) {
            // CONDITION B: strong rejection candle (body > 1.5 * ATR)
            double candle_body = MathAbs(iClose(sym, tf, 1) - iOpen(sym, tf, 1));
            if(candle_body > 1.5 * atr) {
               int n = ArraySize(st.levels); ArrayResize(st.levels, n+1);
               st.levels[n].price = NormalizeDouble(cl, (int)SymbolInfoInteger(sym, SYMBOL_DIGITS));
               st.levels[n].touch_count = cnt; st.levels[n].is_resistance = true;
            }
         }
      }
      
      bool ul[];
      ArrayResize(ul, ArraySize(swl));
      for(int i = 0; i < ArraySize(swl); i++) {
         if(ul[i]) continue;
         double cl = swl[i]; int cnt = 1;
         for(int j = i+1; j < ArraySize(swl); j++) {
            if(ul[j]) continue;
            if(MathAbs(swl[j] - cl) <= zw) {
               cl = (cl * cnt + swl[j]) / (cnt + 1); cnt++; ul[j] = true;
            }
         }
         if(cnt >= m_min_tests) {
            int n = ArraySize(st.levels); ArrayResize(st.levels, n+1);
            st.levels[n].price = NormalizeDouble(cl, (int)SymbolInfoInteger(sym, SYMBOL_DIGITS));
            st.levels[n].touch_count = cnt; st.levels[n].is_support = true;
         } else if(atr > 0) {
            double candle_body = MathAbs(iClose(sym, tf, 1) - iOpen(sym, tf, 1));
            if(candle_body > 1.5 * atr) {
               int n = ArraySize(st.levels); ArrayResize(st.levels, n+1);
               st.levels[n].price = NormalizeDouble(cl, (int)SymbolInfoInteger(sym, SYMBOL_DIGITS));
               st.levels[n].touch_count = cnt; st.levels[n].is_support = true;
            }
         }
      }
      
      double curr = SymbolInfoDouble(sym, SYMBOL_BID);
      double sd = DBL_MAX, rd = DBL_MAX;
      for(int i = 0; i < ArraySize(st.levels); i++) {
         double df = st.levels[i].price - curr;
         if(st.levels[i].is_resistance && df > 0 && df < rd) {
            st.nearest_resistance = st.levels[i].price; rd = df;
         }
         if(st.levels[i].is_support && df < 0 && -df < sd) {
            st.nearest_support = st.levels[i].price; sd = -df;
         }
      }
      if(st.nearest_support > 0 && st.nearest_resistance > 0) {
         st.midpoint = (st.nearest_support + st.nearest_resistance) / 2.0;
         st.bias = (curr >= st.midpoint) ? 1 : -1;
      }
   }
};
