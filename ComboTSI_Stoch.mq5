//+--------------------------------------------------------------------+
//|                                                 ComboTSI_Stoch.mq5 |
//|                                                        @mobilebass |
//|                                               https://www.mql5.com |
//| Combines Ergodic TSI and Stochastic oscillator to generate         |
//| colored price bars/candles. Rich color when both indicators agree, |
//| and lighter when only TSI gives a signal.                          |
//+--------------------------------------------------------------------+
#property indicator_chart_window
#property indicator_buffers 6  // Changed from 5 to 6 to accommodate new buffer
#property indicator_plots   1

//---- Chart style enum
enum enChartStyle
{
   STYLE_COLOR_BARS,    // DRAW_COLOR_BARS
   STYLE_COLOR_CANDLES  // DRAW_COLOR_CANDLES
};

//---- Input parameters for TSI
enum enColorOn
{
   col_onSignalCross, // TSI: change on signal cross
   col_onZeroCross,   // TSI: change on zero line cross
   col_onSlopeChange  // TSI: change on slope change
};

enum enSignalValues
{
   SIGNAL_STRONG_BULL = 0,    // Both indicators bullish (0)
   SIGNAL_STRONG_BEAR = 1,    // Both indicators bearish (1)
   SIGNAL_WEAK_BULL   = 2,    // Only TSI bullish (2)
   SIGNAL_WEAK_BEAR   = 3,    // Only TSI bearish (3)
   SIGNAL_NONE        = -1    // No clear signal (-1)
};

enum enStochSignalMode
{
   stoch_onKvsD,       // Use %K vs %D crossover
   stoch_onKSlope,     // Use slope of %K
   stoch_onDSlope      // Use slope of %D
};

input int                inpPeriod1      = 25;                // TSI smoothing period ("s")
input int                inpPeriod2      = 13;                // TSI momentum smoothing period ("r")
input int                inpSignalPeriod = 5;                 // TSI signal period
input ENUM_APPLIED_PRICE inpPrice        = PRICE_CLOSE;       // Price for TSI
input enColorOn          inpColorOn      = col_onSlopeChange; // TSI mode
input enStochSignalMode inpStochSignalMode = stoch_onKSlope; // Stochastic signal method

//---- Input parameters for Stochastic oscillator
input int InpKPeriod = 5;   // %K period
input int InpDPeriod = 3;   // %D period
input int InpSlowing = 3;   // Slowing

//---- Chart style selection
input enChartStyle inpChartStyle = STYLE_COLOR_BARS; // Price visualization style

//---- Global buffers for price plotting
double priceOpen[];
double priceHigh[];
double priceLow[];
double priceClose[];
double colorIndex[]; // 0=Strong Bull, 1=Strong Bear, 2=Weak Bull, 3=Weak Bear, -1=No signal
/*
   signalValueBuffer contains trading signals for EA consumption:
   - 0: Strong Bullish (both TSI and Stochastic agree)
   - 1: Strong Bearish (both TSI and Stochastic agree)
   - 2: Weak Bullish (only TSI bullish)
   - 3: Weak Bearish (only TSI bearish)
   - -1: No clear signal
*/
double signalValueBuffer[]; // For EA consumption (same values as colorIndex)

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
{
   //--- Set up indicator buffers
   SetIndexBuffer(0, priceOpen, INDICATOR_DATA);
   SetIndexBuffer(1, priceHigh, INDICATOR_DATA);
   SetIndexBuffer(2, priceLow, INDICATOR_DATA);
   SetIndexBuffer(3, priceClose, INDICATOR_DATA);
   SetIndexBuffer(4, colorIndex, INDICATOR_COLOR_INDEX);
   SetIndexBuffer(5, signalValueBuffer, INDICATOR_CALCULATIONS); // NEW BUFFER: Not for drawing
   
   //--- Set drawing style based on user selection
   if(inpChartStyle == STYLE_COLOR_CANDLES)
   {
      PlotIndexSetInteger(0, PLOT_DRAW_TYPE, DRAW_COLOR_CANDLES);
   }
   else
   {
      PlotIndexSetInteger(0, PLOT_DRAW_TYPE, DRAW_COLOR_BARS);
   }
   
   //--- Set colors for different signal types
   PlotIndexSetInteger(0, PLOT_COLOR_INDEXES, 4);
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, 0, clrGreen);     // Strong Bullish
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, 1, clrCrimson);   // Strong Bearish
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, 2, clrLime);      // Weak Bullish
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, 3, clrOrange);    // Weak Bearish
   
   //--- Set empty value
   PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   
   //--- Set indicator name
   string short_name = "TSI+Stoch Color Bars";
   IndicatorSetString(INDICATOR_SHORTNAME, short_name);
   
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Custom indicator iteration function                              |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
{
   //--- Check if enough bars exist
   if(rates_total < MathMax(2, InpKPeriod + InpSlowing + InpDPeriod))
      return(0);

   //--- Set start position for calculations
   int start;
   if(prev_calculated == 0) // First calculation or full recalculation
   {
      // Initialize buffers on first run
      ArrayInitialize(priceOpen, EMPTY_VALUE);
      ArrayInitialize(priceHigh, EMPTY_VALUE);
      ArrayInitialize(priceLow, EMPTY_VALUE);
      ArrayInitialize(priceClose, EMPTY_VALUE);
      ArrayInitialize(colorIndex, -1);
      ArrayInitialize(signalValueBuffer, -1); // NEW: Initialize signal buffer
      
      start = 1; // Start from 1 because we need previous price for TSI
   }
   else 
   {
      // Only calculate new bars
      start = prev_calculated - 1;
   }

   //--- Copy price data to our buffers
   for(int i = start; i < rates_total; i++)
   {
      priceOpen[i] = open[i];
      priceHigh[i] = high[i];
      priceLow[i] = low[i];
      priceClose[i] = close[i];
      signalValueBuffer[i] = -1; // NEW: Initialize current bar signal value
   }

   //--- TSI arrays - resize only if needed
   static double TSI[], TSI_signal[];
   static int TSI_dir[];
   
   if(ArraySize(TSI) < rates_total)
   {
      ArrayResize(TSI, rates_total);
      ArrayResize(TSI_signal, rates_total);
      ArrayResize(TSI_dir, rates_total);
   }

   //--- Calculate TSI only for needed bars
   double alpha1 = 2.0 / (inpPeriod1 + 1);
   double alpha2 = 2.0 / (inpPeriod2 + 1);
   double alphaSignal = 2.0 / (inpSignalPeriod + 1);

   // Initialize EMAs if starting from beginning
   if(start == 1)
   {
      // Initialize with proper EMA seeding (warm-up period)
      double sum_momentum = 0;
      double sum_abs_momentum = 0;
      int warmup_bars = MathMax(inpPeriod1, inpPeriod2) * 2; // Sufficient warm-up period
   
      for(int i = 0; i < warmup_bars && i < rates_total; i++)
      {
         double currentPrice = GetPrice(inpPrice, open[i], high[i], low[i], close[i]);
         double prevPrice = (i == 0) ? currentPrice : GetPrice(inpPrice, open[i-1], high[i-1], low[i-1], close[i-1]);
         double momentum = currentPrice - prevPrice;
         sum_momentum += momentum;
         sum_abs_momentum += MathAbs(momentum);
      }
   
      TSI[0] = sum_momentum / warmup_bars;
      TSI_signal[0] = TSI[0];
      TSI_dir[0] = (inpColorOn == col_onZeroCross) ? (TSI[0] >= 0 ? 1 : 2) : 0;
   }

   for(int i = start; i < rates_total; i++)
   {
      double currentPrice = GetPrice(inpPrice, open[i], high[i], low[i], close[i]);
      double prevPrice = GetPrice(inpPrice, open[i-1], high[i-1], low[i-1], close[i-1]);
   
      double momentum = currentPrice - prevPrice;
      double abs_momentum = MathAbs(momentum);
   
      // Calculate EMAs
      double ema1 = (i == 1) ? momentum : momentum * alpha1 + TSI[i-1] * (1 - alpha1);
      double emaabs1 = (i == 1) ? abs_momentum : abs_momentum * alpha1 + fabs(TSI[i-1]) * (1 - alpha1);
      double ema2 = (i == 1) ? ema1 : ema1 * alpha2 + TSI_signal[i-1] * (1 - alpha2);
      double emaabs2 = (i == 1) ? emaabs1 : emaabs1 * alpha2 + fabs(TSI_signal[i-1]) * (1 - alpha2);
   
      TSI[i] = (emaabs2 != 0 ? (ema2 / emaabs2) * 100.0 : 0);
      TSI_signal[i] = TSI_signal[i-1] + alphaSignal * (TSI[i] - TSI_signal[i-1]);

      // Determine TSI direction
      if(inpColorOn == col_onSignalCross)
      {
         TSI_dir[i] = (TSI[i] > TSI_signal[i]) ? 1 : (TSI[i] < TSI_signal[i]) ? 2 : TSI_dir[i-1];
      }
      else if(inpColorOn == col_onZeroCross)
      {
         TSI_dir[i] = (TSI[i] > 0) ? 1 : (TSI[i] < 0) ? 2 : TSI_dir[i-1];
      }
      else if(inpColorOn == col_onSlopeChange)
      {
         TSI_dir[i] = (TSI[i] > TSI[i-1]) ? 1 : (TSI[i] < TSI[i-1]) ? 2 : TSI_dir[i-1];
      }
   }

   //--- Stochastic oscillator calculations
   static double stoch_low[], stoch_high[], stoch_K[], stoch_D[];
   if(ArraySize(stoch_low) < rates_total)
   {
      ArrayResize(stoch_low, rates_total);
      ArrayResize(stoch_high, rates_total);
      ArrayResize(stoch_K, rates_total);
      ArrayResize(stoch_D, rates_total);
   }

   // Calculate highest high and lowest low for %K period
   int kStart = (start < InpKPeriod - 1) ? InpKPeriod - 1 : start;
   for(int i = kStart; i < rates_total; i++)
   {
      double dmin = low[i - InpKPeriod + 1];
      double dmax = high[i - InpKPeriod + 1];
      for(int k = i - InpKPeriod + 2; k <= i; k++)
      {
         if(low[k] < dmin) dmin = low[k];
         if(high[k] > dmax) dmax = high[k];
      }
      stoch_low[i] = dmin;
      stoch_high[i] = dmax;
   }

   // Compute %K with slowing
   int kSlowStart = MathMax(InpKPeriod + InpSlowing - 2, start);
   for(int i = kSlowStart; i < rates_total; i++)
   {
      double sum_low = 0.0;
      double sum_high = 0.0;
      for(int k = i - InpSlowing + 1; k <= i; k++)
      {
         sum_low += (close[k] - stoch_low[k]);
         sum_high += (stoch_high[k] - stoch_low[k]);
      }
      stoch_K[i] = (sum_high == 0 ? 100.0 : (sum_low / sum_high) * 100.0);
   }

   // Compute %D as SMA of %K
   int dStart = MathMax((InpKPeriod + InpSlowing - 2) + (InpDPeriod - 1), start);
   for(int i = dStart; i < rates_total; i++)
   {
      double sum = 0.0;
      for(int k = 0; k < InpDPeriod; k++)
      {
         sum += stoch_K[i - k];
      }
      stoch_D[i] = sum / InpDPeriod;
   }

   //--- Generate color signals
   int signalStart = MathMax(MathMax(dStart, 1), start);
   for(int i = signalStart; i < rates_total; i++)
   {
      // Default to no signal
      colorIndex[i] = -1;
      signalValueBuffer[i] = -1; // NEW: Initialize current bar signal value

      // Skip if TSI has no direction
      if(TSI_dir[i] == 0) continue;

      // Determine stochastic direction if available
      int stoch_dir = 0;
      switch(inpStochSignalMode)
      {
         case stoch_onKvsD:
            if(stoch_K[i] != EMPTY_VALUE && stoch_D[i] != EMPTY_VALUE)
               stoch_dir = (stoch_K[i] > stoch_D[i]) ? 1 : (stoch_K[i] < stoch_D[i]) ? 2 : 0;
            break;

         case stoch_onKSlope:
            if(stoch_K[i] != EMPTY_VALUE && stoch_K[i-1] != EMPTY_VALUE)
               stoch_dir = (stoch_K[i] > stoch_K[i-1]) ? 1 : (stoch_K[i] < stoch_K[i-1]) ? 2 : 0;
            break;

         case stoch_onDSlope:
            if(stoch_D[i] != EMPTY_VALUE && stoch_D[i-1] != EMPTY_VALUE)
               stoch_dir = (stoch_D[i] > stoch_D[i-1]) ? 1 : (stoch_D[i] < stoch_D[i-1]) ? 2 : 0;
            break;
      }


      // Set color index based on signal strength
      if(TSI_dir[i] == stoch_dir) // Strong signal
      {
         colorIndex[i] = (TSI_dir[i] == 1) ? 0 : 1; // 0=Strong Bull, 1=Strong Bear
         signalValueBuffer[i] = colorIndex[i]; // NEW: Copy to signal buffer
      }
      else // Weak signal (only TSI)
      {
         colorIndex[i] = (TSI_dir[i] == 1) ? 2 : 3; // 2=Weak Bull, 3=Weak Bear
         signalValueBuffer[i] = colorIndex[i]; // NEW: Copy to signal buffer
      }
   }

   return(rates_total);
}

//+------------------------------------------------------------------+
//| Helper function to get price based on selected price type        |
//+------------------------------------------------------------------+
double GetPrice(ENUM_APPLIED_PRICE priceType, double open, double high, double low, double close)
{
   switch(priceType)
   {
      case PRICE_OPEN:    return open;
      case PRICE_HIGH:    return high;
      case PRICE_LOW:     return low;
      case PRICE_MEDIAN:  return (high + low) / 2.0;
      case PRICE_TYPICAL: return (high + low + close) / 3.0;
      case PRICE_WEIGHTED:return (high + low + close + close) / 4.0;
      default:            return close;
   }
}
//+------------------------------------------------------------------+