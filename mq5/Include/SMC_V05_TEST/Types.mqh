//+------------------------------------------------------------------+
//| Types.mqh                                                        |
//| V0.3: Added retrace, M5 confirm, candle confirm structs          |
//+------------------------------------------------------------------+
#property strict

//--- V0.1 Enums (unchanged)
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

//--- V0.2 Enums (unchanged)
enum ENUM_SWEEP_TYPE {
   SWEEP_NONE,
   SWEEP_BULLISH,
   SWEEP_BEARISH
};

enum ENUM_OB_TYPE {
   OB_NONE,
   OB_BULLISH,
   OB_BEARISH
};

enum ENUM_ZONE_STATUS {
   ZONE_NO_TRADE,
   ZONE_SWEEP_FOUND,
   ZONE_BOS_AFTER_SWEEP_FOUND,
   ZONE_OB_FOUND,
   ZONE_WAIT_RETRACE,
   //--- V0.3 New Statuses
   ZONE_RETRACE_FOUND,
   ZONE_WAIT_CONFIRMATION,
   ZONE_READY_BUY,
   ZONE_READY_SELL
};

//--- V0.3 Enums
enum ENUM_M5_CONFIRM_TYPE {
   M5_CONFIRM_NONE,
   M5_CONFIRM_BULLISH_MSS,
   M5_CONFIRM_BEARISH_MSS
};

enum ENUM_CANDLE_CONFIRM {
   CANDLE_CONFIRM_NONE,
   CANDLE_CONFIRM_BUY,
   CANDLE_CONFIRM_SELL
};

//--- V0.1 Structs (unchanged)
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

//--- V0.2 Structs
struct StructSweep {
   datetime time;
   double price;
   ENUM_SWEEP_TYPE type;
};

struct StructOrderBlock {
   datetime time;
   double ob_high;
   double ob_low;
   ENUM_OB_TYPE type;
   bool is_valid;
};

struct StructZoneState {
   StructSweep last_sweep;
   StructBOS bos_after_sweep;
   StructOrderBlock last_ob;
   ENUM_ZONE_STATUS zone_status;
};

//--- V0.3 Structs
struct StructRetrace {
   datetime time;
   double   price;
   bool     is_valid;
};

struct StructM5Confirm {
   datetime          time;
   double            price;
   ENUM_M5_CONFIRM_TYPE type;
   bool              is_valid;
};

struct StructCandleConfirm {
   datetime           time;
   double             close_price;
   ENUM_CANDLE_CONFIRM type;
   bool               is_valid;
};

struct StructConfirmationState {
   StructRetrace      retrace;
   StructM5Confirm    m5_confirm;
   StructCandleConfirm candle_confirm;
   ENUM_ZONE_STATUS   final_status;
};

//--- V0.2.1: Helper to validate Order Block strictly (unchanged)
bool IsValidOrderBlock(const StructOrderBlock &ob) {
   return (ob.is_valid &&
           ob.time > 0 &&
           ob.ob_high > 0 &&
           ob.ob_low > 0 &&
           ob.ob_high > ob.ob_low &&
           ob.type != OB_NONE);
}

//--- V0.4 Enums
enum ENUM_TRADE_DIRECTION {
   TRADE_DIR_NONE,
   TRADE_DIR_BUY,
   TRADE_DIR_SELL
};

enum ENUM_TRADE_PLAN_STATUS {
   TRADE_PLAN_NONE,
   TRADE_PLAN_VALID,
   TRADE_PLAN_REJECTED
};

//--- V0.5 Enums
enum ENUM_EXECUTION_STATUS {
   EXECUTION_DISABLED,
   EXECUTION_REJECTED,
   EXECUTION_ORDER_SENT,
   EXECUTION_ORDER_FAILED,
   EXECUTION_POSITION_EXISTS,
   EXECUTION_DUPLICATE_SIGNAL
};

//--- V0.4 Struct: Trade Plan
struct StructTradePlan {
   ENUM_TRADE_DIRECTION   direction;
   ENUM_TRADE_PLAN_STATUS plan_status;
   bool                   valid;
   string                 reject_reason;
   datetime               signal_time;
   double                 entry_price;
   double                 sl_price;
   double                 tp_price;
   double                 sl_points;
   double                 tp_points;
   double                 rr;
   double                 risk_percent;
   double                 risk_money;
   double                 lot_size;
   double                 spread_points;
   int                    stop_level_points;
   int                    freeze_level_points;
   
   void Reset() {
      direction         = TRADE_DIR_NONE;
      plan_status       = TRADE_PLAN_NONE;
      valid             = false;
      reject_reason     = "";
      signal_time       = 0;
      entry_price       = 0;
      sl_price          = 0;
      tp_price          = 0;
      sl_points         = 0;
      tp_points         = 0;
      rr                = 0;
      risk_percent      = 0;
      risk_money        = 0;
      lot_size          = 0;
      spread_points     = 0;
      stop_level_points = 0;
      freeze_level_points = 0;
   }
};
