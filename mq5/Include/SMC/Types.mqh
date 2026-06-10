//+------------------------------------------------------------------+
//| Types.mqh                                                        |
//| V0.1: Core data structures for SMC Scalper MTF                   |
//+------------------------------------------------------------------+
#property strict

enum ENUM_TREND_BIAS {
   TREND_BULLISH,
   TREND_BEARISH,
   TREND_SIDWAYS
};

enum ENUM_SIGNAL_STATUS {
   STATUS_BUY_ALLOWED,
   STATUS_SELL_ALLOWED,
   STATUS_NO_TRADE
};

struct StructSwing {
   datetime time;
   double price;
   bool is_high;
};

struct StructBOS {
   datetime time;
   double price;
   bool is_bullish;
};

struct StructMarketState {
   ENUM_TREND_BIAS m15_trend;
   StructSwing last_swing_high;
   StructSwing last_swing_low;
   StructBOS last_bos;
   ENUM_SIGNAL_STATUS signal_status;
};