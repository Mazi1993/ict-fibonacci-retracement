// ICT-inspired educational indicator. Not affiliated with Inner Circle Trader.
#property copyright "2026"
#property version   "1.00"
#property description "Confirmed liquidity sweep + displacement/MSS + Fibonacci OTE"
#property indicator_chart_window
#property indicator_buffers 7
#property indicator_plots   7
#property indicator_label1  "OTE 62%"
#property indicator_type1   DRAW_LINE
#property indicator_color1 clrDodgerBlue
#property indicator_label2  "OTE 70.5%"
#property indicator_type2   DRAW_LINE
#property indicator_color2 clrGold
#property indicator_style2  STYLE_DASH
#property indicator_label3  "OTE 79%"
#property indicator_type3   DRAW_LINE
#property indicator_color3 clrDodgerBlue
#property indicator_label4  "Invalidation"
#property indicator_type4   DRAW_LINE
#property indicator_color4 clrTomato
#property indicator_style4  STYLE_DOT
#property indicator_label5  "Impulse target"
#property indicator_type5   DRAW_LINE
#property indicator_color5 clrMediumSeaGreen
#property indicator_style5  STYLE_DOT
#property indicator_label6  "Bullish OTE touch"
#property indicator_type6   DRAW_ARROW
#property indicator_color6 clrLimeGreen
#property indicator_width6  2
#property indicator_label7  "Bearish OTE touch"
#property indicator_type7   DRAW_ARROW
#property indicator_color7 clrOrangeRed
#property indicator_width7  2

input int    InpSwingDepth       = 3;     // Bars on each side of confirmed pivot
input int    InpATRPeriod        = 14;
input double InpDisplacementATR  = 1.0;   // MSS candle body / Wilder ATR
input int    InpSweepExpiry      = 12;    // Bars allowed between sweep and MSS
input int    InpSetupExpiry      = 50;    // Bars allowed after MSS
input bool   InpRequireFVG       = false;// MSS candle must form overlapping FVG
input double InpStopPadding      = 10.0; // Symbol points beyond sweep extreme
input int    InpHistoryBars      = 5000; // Maximum replay bars; results use this window
input bool   InpPopupAlerts      = false;
input bool   InpPushAlerts       = false;// Requires terminal Notifications setup

double Fib62[], Fib705[], Fib79[], StopLine[], TargetLine[], BuyArrow[], SellArrow[];
datetime last_open_bar = 0;
datetime last_alert_bar = 0;

int OnInit()
{
   if(InpSwingDepth < 1 || InpATRPeriod < 1 || InpDisplacementATR < 0.0 ||
      InpSweepExpiry < 1 || InpSetupExpiry < 1 || InpStopPadding < 0.0 ||
      InpHistoryBars < 2 * InpSwingDepth + InpATRPeriod + 10)
      return INIT_PARAMETERS_INCORRECT;

   SetIndexBuffer(0, Fib62, INDICATOR_DATA);
   SetIndexBuffer(1, Fib705, INDICATOR_DATA);
   SetIndexBuffer(2, Fib79, INDICATOR_DATA);
   SetIndexBuffer(3, StopLine, INDICATOR_DATA);
   SetIndexBuffer(4, TargetLine, INDICATOR_DATA);
   SetIndexBuffer(5, BuyArrow, INDICATOR_DATA);
   SetIndexBuffer(6, SellArrow, INDICATOR_DATA);
   ArraySetAsSeries(Fib62, false);
   ArraySetAsSeries(Fib705, false);
   ArraySetAsSeries(Fib79, false);
   ArraySetAsSeries(StopLine, false);
   ArraySetAsSeries(TargetLine, false);
   ArraySetAsSeries(BuyArrow, false);
   ArraySetAsSeries(SellArrow, false);
   for(int p = 0; p < 7; p++)
      PlotIndexSetDouble(p, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetInteger(5, PLOT_ARROW, 233);
   PlotIndexSetInteger(6, PLOT_ARROW, 234);
   IndicatorSetInteger(INDICATOR_DIGITS, _Digits);
   IndicatorSetString(INDICATOR_SHORTNAME, "ICT Fibonacci OTE (confirmed bars)");
   last_open_bar = 0;
   last_alert_bar = 0;
   return INIT_SUCCEEDED;
}

int OnCalculate(const int rates_total, const int prev_calculated,
                const datetime &time[], const double &open[],
                const double &high[], const double &low[], const double &close[],
                const long &tick_volume[], const long &volume[], const int &spread[])
{
   // Explicit chronological indexing: index 0 is the oldest available bar.
   ArraySetAsSeries(time, false);
   ArraySetAsSeries(open, false);
   ArraySetAsSeries(high, false);
   ArraySetAsSeries(low, false);
   ArraySetAsSeries(close, false);
   if(rates_total < 2 * InpSwingDepth + InpATRPeriod + 3)
      return 0;
   if(prev_calculated == rates_total && last_open_bar == time[rates_total - 1])
      return rates_total;
   last_open_bar = time[rates_total - 1];

   ArrayInitialize(Fib62, EMPTY_VALUE);
   ArrayInitialize(Fib705, EMPTY_VALUE);
   ArrayInitialize(Fib79, EMPTY_VALUE);
   ArrayInitialize(StopLine, EMPTY_VALUE);
   ArrayInitialize(TargetLine, EMPTY_VALUE);
   ArrayInitialize(BuyArrow, EMPTY_VALUE);
   ArrayInitialize(SellArrow, EMPTY_VALUE);

   double atr[];
   ArrayResize(atr, rates_total);
   atr[0] = high[0] - low[0];
   // Wilder smoothing, seeded with an SMA of the first ATRPeriod true ranges.
   double tr_sum = atr[0];
   for(int i = 1; i < rates_total; i++)
   {
      double tr = MathMax(high[i] - low[i],
                         MathMax(MathAbs(high[i] - close[i-1]), MathAbs(low[i] - close[i-1])));
      if(i < InpATRPeriod)
      {
         tr_sum += tr;
         atr[i] = tr_sum / (i + 1);
      }
      else
         atr[i] = (atr[i-1] * (InpATRPeriod - 1) + tr) / InpATRPeriod;
   }

   double swing_high = 0.0, swing_low = 0.0;
   bool have_high = false, have_low = false;
   int armed = 0, sweep_bar = -1;
   double sweep_extreme = 0.0, structure_level = 0.0;
   int direction = 0, setup_bar = -1;
   double f62 = 0.0, f705 = 0.0, f79 = 0.0, stop = 0.0, target = 0.0;
   bool touched = false;
   int replay_start = MathMax(2 * InpSwingDepth, rates_total - InpHistoryBars);

   // The forming bar is never used for pivots, setups or touch signals.
   for(int i = replay_start; i < rates_total - 1; i++)
   {
      int pivot = i - InpSwingDepth;
      bool pivot_high = true, pivot_low = true;
      for(int j = 1; j <= InpSwingDepth; j++)
      {
         if(high[pivot] <= high[pivot-j] || high[pivot] <= high[pivot+j]) pivot_high = false;
         if(low[pivot] >= low[pivot-j] || low[pivot] >= low[pivot+j]) pivot_low = false;
      }
      if(pivot_high) { swing_high = high[pivot]; have_high = true; }
      if(pivot_low)  { swing_low = low[pivot]; have_low = true; }

      // Invalidation/target wins over a touch on ambiguous OHLC bars.
      if(direction != 0 && i > setup_bar)
      {
         bool invalid = direction == 1 ? low[i] <= stop : high[i] >= stop;
         bool reached = direction == 1 ? high[i] >= target : low[i] <= target;
         if(invalid || reached || i - setup_bar > InpSetupExpiry)
            direction = 0;
         else if(!touched && low[i] <= MathMax(f62, f79) && high[i] >= MathMin(f62, f79))
         {
            touched = true;
            double offset = MathMax(atr[i] * 0.15, _Point * 5);
            if(direction == 1) BuyArrow[i] = low[i] - offset;
            else SellArrow[i] = high[i] + offset;
         }
      }

      if(armed != 0 && i > sweep_bar)
      {
         bool broken = armed == 1 ? low[i] < sweep_extreme : high[i] > sweep_extreme;
         if(broken || i - sweep_bar > InpSweepExpiry)
            armed = 0;
         else
         {
            bool shift = armed == 1 ? close[i] > structure_level && close[i] > open[i]
                                     : close[i] < structure_level && close[i] < open[i];
            bool displacement = MathAbs(close[i] - open[i]) >= InpDisplacementATR * atr[i];
            double tip = armed == 1 ? high[i] : low[i];
            double span = MathAbs(tip - sweep_extreme);
            double candidate62 = tip - armed * span * 0.62;
            double candidate79 = tip - armed * span * 0.79;
            bool fvg = armed == 1 ? low[i] > high[i-2] : high[i] < low[i-2];
            double gap_low = armed == 1 ? high[i-2] : high[i];
            double gap_high = armed == 1 ? low[i] : low[i-2];
            bool overlap = fvg && gap_low <= MathMax(candidate62, candidate79)
                               && gap_high >= MathMin(candidate62, candidate79);
            if(shift && displacement && span > 0.0 && (!InpRequireFVG || overlap))
            {
               direction = armed;
               setup_bar = i;
               f62 = candidate62;
               f705 = tip - direction * span * 0.705;
               f79 = candidate79;
               stop = sweep_extreme - direction * InpStopPadding * _Point;
               target = tip;
               touched = false;
               armed = 0;
               // Break the prior plotted segment when a setup is replaced.
               if(i > replay_start)
               {
                  Fib62[i-1] = EMPTY_VALUE; Fib705[i-1] = EMPTY_VALUE;
                  Fib79[i-1] = EMPTY_VALUE; StopLine[i-1] = EMPTY_VALUE;
                  TargetLine[i-1] = EMPTY_VALUE;
               }
            }
         }
      }

      // A sweep closes back inside a confirmed pivot and freezes the opposing
      // structure level. Outside bars sweeping both sides are deliberately ignored.
      if(have_high && have_low)
      {
         bool bull = low[i] < swing_low && close[i] > swing_low && close[i] < swing_high;
         bool bear = high[i] > swing_high && close[i] < swing_high && close[i] > swing_low;
         if(bull != bear)
         {
            armed = bull ? 1 : -1;
            sweep_bar = i;
            sweep_extreme = bull ? low[i] : high[i];
            structure_level = bull ? swing_high : swing_low;
         }
      }

      if(direction != 0)
      {
         Fib62[i] = f62; Fib705[i] = f705; Fib79[i] = f79;
         StopLine[i] = stop; TargetLine[i] = target;
      }
   }

   // Extend active levels onto the current bar for display only.
   int current = rates_total - 1;
   if(direction != 0)
   {
      Fib62[current] = f62; Fib705[current] = f705; Fib79[current] = f79;
      StopLine[current] = stop; TargetLine[current] = target;
   }
   int closed = rates_total - 2;
   if(prev_calculated > 0 && time[closed] != last_alert_bar &&
      (BuyArrow[closed] != EMPTY_VALUE || SellArrow[closed] != EMPTY_VALUE))
   {
      last_alert_bar = time[closed];
      string side = BuyArrow[closed] != EMPTY_VALUE ? "Bullish" : "Bearish";
      string message = StringFormat("%s %s: %s ICT OTE touch, closed bar %s",
                                    _Symbol, EnumToString(_Period), side, TimeToString(time[closed]));
      if(InpPopupAlerts) Alert(message);
      if(InpPushAlerts && !SendNotification(message))
         Print("ICT OTE notification failed: ", GetLastError());
   }
   return rates_total;
}
