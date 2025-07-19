//+--------------------------------------------------------------------+
//|                                     Combined_MACD_Color_Bars.mq5 |
//|                                                        @Jules AI |
//|                                               https://www.mql5.com|
//| Combines Long-MACD and Short-MACD signals to generate colored    |
//| price bars/candles.                                              |
//+--------------------------------------------------------------------+

/*
For Expert Advisor access:
- Use iCustom() to access buffer 5 (signalValueBuffer)
- Returns values from enSignalValues enum:
  SIGNAL_GREEN   = 0 (Both MACDs bullish)
  SIGNAL_CRIMSON = 1 (Both MACDs bearish)
  SIGNAL_ORANGE  = 2 (Long bullish, Short bearish)
  SIGNAL_LIME    = 3 (Long bearish, Short bullish)
  SIGNAL_NONE    = -1 (No clear signal)
*/

#property indicator_chart_window
#property indicator_buffers 6 // Open, High, Low, Close, ColorIndex, SignalValue
#property indicator_plots   1
#property version           "1.0"
#property description       "Colors bars/candles based on Long and Short MACD signals."
#property copyright         "Jules AI"

#include <MovingAverages.mqh> // For standard MA methods

//---- Chart style enum
enum enChartStyle
{
   STYLE_COLOR_BARS,    // DRAW_COLOR_BARS
   STYLE_COLOR_CANDLES  // DRAW_COLOR_CANDLES
};

//---- Signal values
enum enSignalValues
{
   SIGNAL_GREEN   = 0, // Long-MACD Lime/Green and Short-MACD Lime/Green
   SIGNAL_CRIMSON = 1, // Long-MACD Orange/Crimson and Short-MACD Orange/Crimson
   SIGNAL_ORANGE  = 2, // Long-MACD Lime/Green and Short-MACD Orange/Crimson
   SIGNAL_LIME    = 3, // Long-MACD Orange/Crimson and Short-MACD Lime/Green
   SIGNAL_NONE    = -1 // No clear signal
};

//---- Input parameters for Long MACD
input group                "Long MACD Settings"
input int                InpLongFastEMA      = 12;          // Fast EMA period
input int                InpLongSlowEMA      = 26;          // Slow EMA period
input int                InpLongSignalSMA    = 9;           // Signal SMA period
input ENUM_APPLIED_PRICE InpLongAppliedPrice = PRICE_CLOSE; // Applied price for MACD

//---- Input parameters for Short MACD
input group                "Short MACD Settings"
input int                InpShortFastEMA      = 12;          // Fast EMA period
input int                InpShortSlowEMA      = 26;          // Slow EMA period
input int                InpShortSignalSMA    = 9;           // Signal SMA period
input ENUM_APPLIED_PRICE InpShortAppliedPrice = PRICE_CLOSE; // Applied price for MACD

//---- Chart style selection
input group           "Chart Style"
input enChartStyle    inpChartStyle   = STYLE_COLOR_BARS; // Price visualization style

//---- Global buffers for price plotting
double priceOpen[];
double priceHigh[];
double priceLow[];
double priceClose[];
double colorIndex[];
double signalValueBuffer[]; // For EA consumption

//---- Forward declarations for helper functions ----
void GetPriceArray(ENUM_APPLIED_PRICE priceType, const double &open[], const double &high[], const double &low[], const double &close[], int total_rates, double &result[]);

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
   SetIndexBuffer(5, signalValueBuffer, INDICATOR_DATA);
   
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
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, 0, clrGreen);
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, 1, clrCrimson);
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, 2, clrOrange);
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, 3, clrLime);
   
   //--- Configure signal buffer for EA access (not drawn on chart)
   PlotIndexSetInteger(5, PLOT_DRAW_TYPE, DRAW_NONE);
   PlotIndexSetString(5, PLOT_LABEL, "Signal Values");
   
   //--- Set empty value
   PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetDouble(5, PLOT_EMPTY_VALUE, SIGNAL_NONE);
   
   //--- Set indicator name
   string short_name = StringFormat("Combined MACD Clr (%d,%d,%d | %d,%d,%d)", 
                                    InpLongFastEMA, InpLongSlowEMA, InpLongSignalSMA,
                                    InpShortFastEMA, InpShortSlowEMA, InpShortSignalSMA);
   IndicatorSetString(INDICATOR_SHORTNAME, short_name);
   PlotIndexSetString(0, PLOT_LABEL, "Combined MACD Colored Bars");

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
   //--- Define minimum_rates_total
   int min_rates_for_long_macd = InpLongSlowEMA + InpLongSignalSMA;
   int min_rates_for_short_macd = InpShortSlowEMA + InpShortSignalSMA;
   int min_total = MathMax(min_rates_for_long_macd, min_rates_for_short_macd) + 1;

   if(rates_total < min_total)
      return(0);

   //--- Set start position for calculations
   int start_idx;
   if(prev_calculated == 0)
   {
      ArrayInitialize(priceOpen, EMPTY_VALUE);
      ArrayInitialize(priceHigh, EMPTY_VALUE);
      ArrayInitialize(priceLow, EMPTY_VALUE);
      ArrayInitialize(priceClose, EMPTY_VALUE);
      ArrayInitialize(colorIndex, SIGNAL_NONE);
      ArrayInitialize(signalValueBuffer, SIGNAL_NONE);
      start_idx = 0;
   }
   else 
   {
      start_idx = prev_calculated - 1;
   }

   //--- Copy price data to our buffers
   for(int i = start_idx; i < rates_total; i++)
   {
      priceOpen[i] = open[i];
      priceHigh[i] = high[i];
      priceLow[i] = low[i];
      priceClose[i] = close[i];
      if (prev_calculated == 0 || i >= rates_total - (rates_total - prev_calculated +1) )
      {
         colorIndex[i] = SIGNAL_NONE; 
         signalValueBuffer[i] = SIGNAL_NONE;
      }
   }

   //--- Long MACD Calculation Buffers ---
   static double longMacdLine[], longSignalLine[], longFastMA[], longSlowMA[];
   static double price_arr_for_long_macd[];

   if(ArraySize(price_arr_for_long_macd) != rates_total) ArrayResize(price_arr_for_long_macd, rates_total);
   GetPriceArray(InpLongAppliedPrice, open, high, low, close, rates_total, price_arr_for_long_macd);

   if(ArraySize(longMacdLine) < rates_total) ArrayResize(longMacdLine, rates_total);
   if(ArraySize(longSignalLine) < rates_total) ArrayResize(longSignalLine, rates_total);
   if(ArraySize(longFastMA) < rates_total) ArrayResize(longFastMA, rates_total);
   if(ArraySize(longSlowMA) < rates_total) ArrayResize(longSlowMA, rates_total);
   
   if(prev_calculated == 0)
   {
      ArrayInitialize(longMacdLine, EMPTY_VALUE);
      ArrayInitialize(longSignalLine, EMPTY_VALUE);
      ArrayInitialize(longFastMA, EMPTY_VALUE);
      ArrayInitialize(longSlowMA, EMPTY_VALUE);
   }
   
   //--- Short MACD Calculation Buffers ---
   static double shortMacdLine[], shortSignalLine[], shortFastMA[], shortSlowMA[];
   static double price_arr_for_short_macd[];

   if(ArraySize(price_arr_for_short_macd) != rates_total) ArrayResize(price_arr_for_short_macd, rates_total);
   GetPriceArray(InpShortAppliedPrice, open, high, low, close, rates_total, price_arr_for_short_macd);

   if(ArraySize(shortMacdLine) < rates_total) ArrayResize(shortMacdLine, rates_total);
   if(ArraySize(shortSignalLine) < rates_total) ArrayResize(shortSignalLine, rates_total);
   if(ArraySize(shortFastMA) < rates_total) ArrayResize(shortFastMA, rates_total);
   if(ArraySize(shortSlowMA) < rates_total) ArrayResize(shortSlowMA, rates_total);
   
   if(prev_calculated == 0)
   {
      ArrayInitialize(shortMacdLine, EMPTY_VALUE);
      ArrayInitialize(shortSignalLine, EMPTY_VALUE);
      ArrayInitialize(shortFastMA, EMPTY_VALUE);
      ArrayInitialize(shortSlowMA, EMPTY_VALUE);
   }

   //--- Calculate Long MACD ---
   ExponentialMAOnBuffer(rates_total, prev_calculated, 0, InpLongFastEMA, price_arr_for_long_macd, longFastMA);
   ExponentialMAOnBuffer(rates_total, prev_calculated, 0, InpLongSlowEMA, price_arr_for_long_macd, longSlowMA);

   int long_macd_calc_start_idx = InpLongSlowEMA -1; 
   for(int i = (prev_calculated == 0 ? long_macd_calc_start_idx : start_idx); i < rates_total; i++)
   {
      if(i < long_macd_calc_start_idx) { longMacdLine[i] = EMPTY_VALUE; continue;}
      if(longFastMA[i] != EMPTY_VALUE && longSlowMA[i] != EMPTY_VALUE)
         longMacdLine[i] = longFastMA[i] - longSlowMA[i];
      else
         longMacdLine[i] = EMPTY_VALUE;
   }
   
   int long_macd_signal_calc_start_idx = long_macd_calc_start_idx + InpLongSignalSMA - 1;
   SimpleMAOnBuffer(rates_total, prev_calculated, long_macd_calc_start_idx, InpLongSignalSMA, longMacdLine, longSignalLine);

   //--- Calculate Short MACD ---
   ExponentialMAOnBuffer(rates_total, prev_calculated, 0, InpShortFastEMA, price_arr_for_short_macd, shortFastMA);
   ExponentialMAOnBuffer(rates_total, prev_calculated, 0, InpShortSlowEMA, price_arr_for_short_macd, shortSlowMA);

   int short_macd_calc_start_idx = InpShortSlowEMA -1; 
   for(int i = (prev_calculated == 0 ? short_macd_calc_start_idx : start_idx); i < rates_total; i++)
   {
      if(i < short_macd_calc_start_idx) { shortMacdLine[i] = EMPTY_VALUE; continue;}
      if(shortFastMA[i] != EMPTY_VALUE && shortSlowMA[i] != EMPTY_VALUE)
         shortMacdLine[i] = shortFastMA[i] - shortSlowMA[i];
      else
         shortMacdLine[i] = EMPTY_VALUE;
   }
   
   int short_macd_signal_calc_start_idx = short_macd_calc_start_idx + InpShortSignalSMA - 1;
   SimpleMAOnBuffer(rates_total, prev_calculated, short_macd_calc_start_idx, InpShortSignalSMA, shortMacdLine, shortSignalLine);
   
   //--- Generate color signals ---
   int final_signal_start_idx = 1;
   final_signal_start_idx = MathMax(final_signal_start_idx, long_macd_signal_calc_start_idx +1);
   final_signal_start_idx = MathMax(final_signal_start_idx, short_macd_signal_calc_start_idx +1);
   final_signal_start_idx = MathMax(final_signal_start_idx, start_idx);


   for(int i = final_signal_start_idx; i < rates_total; i++)
   {
      bool long_is_bullish = (longMacdLine[i] > longMacdLine[i-1] && longMacdLine[i] > longSignalLine[i]) || (longMacdLine[i] > longMacdLine[i-1] && longMacdLine[i] < longSignalLine[i]);
      bool long_is_bearish = (longMacdLine[i] < longMacdLine[i-1] && longMacdLine[i] > longSignalLine[i]) || (longMacdLine[i] < longMacdLine[i-1] && longMacdLine[i] < longSignalLine[i]);

      double short_osma = shortMacdLine[i] - shortSignalLine[i];
      double prev_short_osma = shortMacdLine[i-1] - shortSignalLine[i-1];
      
      bool short_is_bullish = (short_osma > 0 && short_osma > prev_short_osma) || (short_osma < 0 && short_osma > prev_short_osma);
      bool short_is_bearish = (short_osma < 0 && short_osma < prev_short_osma) || (short_osma > 0 && short_osma < prev_short_osma);
      
      colorIndex[i] = SIGNAL_NONE;
      
      if(long_is_bullish && short_is_bullish)
         colorIndex[i] = SIGNAL_GREEN;
      else if(long_is_bearish && short_is_bearish)
         colorIndex[i] = SIGNAL_CRIMSON;
      else if(long_is_bullish && short_is_bearish)
         colorIndex[i] = SIGNAL_ORANGE;
      else if(long_is_bearish && short_is_bullish)
         colorIndex[i] = SIGNAL_LIME;

      signalValueBuffer[i] = colorIndex[i];
   }

   int lastBar = rates_total - 1;
   //--- Write current signal to global variable for EA access
   string gv_name = Symbol() + "_MACD_SIGNAL";

   GlobalVariableSet(gv_name, signalValueBuffer[lastBar]);

   return(rates_total);
}

//+------------------------------------------------------------------+
//| Helper function to get price array based on selected price type  |
//+------------------------------------------------------------------+
void GetPriceArray(ENUM_APPLIED_PRICE priceType, const double &open[], const double &high[], const double &low[], const double &close[], int total_rates, double &result[])
{
   //Ensure result array is adequately sized;
   if(ArraySize(result) != total_rates)
      ArrayResize(result, total_rates);

   for(int i=0; i<total_rates; i++)
   {
      switch(priceType)
      {
         case PRICE_OPEN:    result[i] = open[i]; break;
         case PRICE_HIGH:    result[i] = high[i]; break;
         case PRICE_LOW:     result[i] = low[i]; break;
         case PRICE_MEDIAN:  result[i] = (high[i] + low[i]) / 2.0; break;
         case PRICE_TYPICAL: result[i] = (high[i] + low[i] + close[i]) / 3.0; break;
         case PRICE_WEIGHTED:result[i] = (high[i] + low[i] + close[i] + close[i]) / 4.0; break;
         default:            result[i] = close[i]; break;
      }
   }
}

//+------------------------------------------------------------------+
