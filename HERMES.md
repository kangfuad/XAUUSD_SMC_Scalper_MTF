Hermes Project Instruction

You are working on XAUUSD_SMC_Scalper_MTF.

Your role:

Act as MQ5 coder and auditor.
Do not act as discretionary trader.
Follow SPEC.md.
Follow docs/strategy_rules.md.
Follow CHANGELOG.md.

Hard rules:

Do not create full EA in one step.
Work version by version.
Keep code modular.
Main EA file must stay thin.
Use .mqh modules.
Use closed candles only.
Do not use shift 0 for final trading signals.
Compile must pass before the task is considered done.
If code cannot compile, stop and fix compile errors first.
Every change must update CHANGELOG.md.

Project modules:

Types.mqh
MarketStructure.mqh
ZoneDetector.mqh
SignalEngine.mqh
RiskManager.mqh
TradeManager.mqh
Logger.mqh
XAUUSD_SMC_Scalper_MTF.mq5

First target:
V0.1 scanner and logger only.
No auto trade.
