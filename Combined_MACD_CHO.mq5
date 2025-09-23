//+--------------------------------------------------------------------+
//|                                        Combined_MACD_CHO.mq5 |
//|                                                        @Jules AI |
//|                                               https://www.mql5.com|
//| Combines MACD and Chaikin Oscillator signals to generate colored |
//| price bars/candles.                                              |
//+--------------------------------------------------------------------+

/*
For Expert Advisor access:
- Use iCustom() to access buffer 5 (signalValueBuffer)
- Returns values from enSignalValues enum:
  SIGNAL_GREEN   = 0 (MACD bullish, CHO bullish)
  SIGNAL_CRIMSON = 1 (MACD bearish, CHO bearish)
  SIGNAL_ORANGE  = 2 (MACD bullish, CHO bearish)
  SIGNAL_LIME    = 3 (MACD bearish, CHO bullish)
  SIGNAL_NONE    = -1 (No clear signal)
*/

#property indicator_chart_window
#property indicator_buffers 6 // Open, High, Low, Close, ColorIndex, SignalValue
#property indicator_plots   1
#property version           "1.0"
#property description       "Colors bars/candles based on MACD and Chaikin Oscillator signals."
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
   SIGNAL_GREEN   = 0, // MACD Bullish, CHO Bullish
   SIGNAL_CRIMSON = 1, // MACD Bearish, CHO Bearish
   SIGNAL_ORANGE  = 2, // MACD Bullish, CHO Bearish
   SIGNAL_LIME    = 3, // MACD Bearish, CHO Bullish
   SIGNAL_NONE    = -1 // No clear signal
};

//---- Input parameters for Long MACD
input group                "Long MACD Settings"
input int                InpLongFastEMA      = 12;          // Fast EMA period
input int                InpLongSlowEMA      = 26;          // Slow EMA period
input int                InpLongSignalSMA    = 9;           // Signal SMA period
input ENUM_APPLIED_PRICE InpLongAppliedPrice = PRICE_CLOSE; // Applied price for MACD

//---- Input parameters for Chaikin Oscillator
input group               "Chaikin Oscillator Settings"
input int                 InpCHOFastMA        = 3;           // Fast MA period
input int                 InpCHOSlowMA        = 10;          // Slow MA period
input ENUM_MA_METHOD      InpCHOSmoothMethod  = MODE_EMA;    // MA method
input ENUM_APPLIED_VOLUME InpCHOVolumeType    = VOLUME_TICK; // Volumes

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
double AD(double high,double low,double close,long volume);
void AverageOnArray(const int mode,const int rates_total,const int prev_calculated,const int begin, const int period,const double& source[],double& destination[]);


//+------------------------------------------------------------------+
//| calculate AD                                                     |
//+------------------------------------------------------------------+
double AD(double high,double low,double close,long volume)
  {
   double res=0.0;
//---
   double sum=(close-low)-(high-close);
   if(sum!=0.0)
     {
      if(high!=low)
         res=(sum/(high-low))*volume;
     }
//---
   return(res);
  }
//+------------------------------------------------------------------+
//| calculate average on array                                       |
//+------------------------------------------------------------------+
void AverageOnArray(const int mode,const int rates_total,const int prev_calculated,const int begin,
                    const int period,const double& source[],double& destination[])
  {
   switch(mode)
     {
      case MODE_EMA:
         ExponentialMAOnBuffer(rates_total,prev_calculated,begin,period,source,destination);
         break;
      case MODE_SMMA:
         SmoothedMAOnBuffer(rates_total,prev_calculated,begin,period,source,destination);
         break;
      case MODE_LWMA:
         LinearWeightedMAOnBuffer(rates_total,prev_calculated,begin,period,source,destination);
         break;
      default:
         SimpleMAOnBuffer(rates_total,prev_calculated,begin,period,source,destination);
     }
  }
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
   string short_name = StringFormat("MACD+CHO Clr (%d,%d,%d | %d,%d)", 
                                    InpLongFastEMA, InpLongSlowEMA, InpLongSignalSMA,
                                    InpCHOFastMA, InpCHOSlowMA);
   IndicatorSetString(INDICATOR_SHORTNAME, short_name);
   PlotIndexSetString(0, PLOT_LABEL, "Combined MACD+CHO Colored Bars");

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
   int min_rates_for_cho = InpCHOSlowMA;
   int min_total = MathMax(min_rates_for_long_macd, min_rates_for_cho) + 1;

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
   
   //--- Chaikin Oscillator Calculation Buffers ---
   static double choBuffer[], choFastMA[], choSlowMA[], adBuffer[];

   if(ArraySize(choBuffer) < rates_total) ArrayResize(choBuffer, rates_total);
   if(ArraySize(choFastMA) < rates_total) ArrayResize(choFastMA, rates_total);
   if(ArraySize(choSlowMA) < rates_total) ArrayResize(choSlowMA, rates_total);
   if(ArraySize(adBuffer) < rates_total) ArrayResize(adBuffer, rates_total);
   
   if(prev_calculated == 0)
   {
      ArrayInitialize(choBuffer, EMPTY_VALUE);
      ArrayInitialize(choFastMA, EMPTY_VALUE);
      ArrayInitialize(choSlowMA, EMPTY_VALUE);
      ArrayInitialize(adBuffer, EMPTY_VALUE);
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

   //--- Calculate Chaikin Oscillator ---
   int cho_start_idx = (prev_calculated < 2) ? 0 : prev_calculated - 2;

   if(InpCHOVolumeType == VOLUME_TICK)
   {
      for(int i = cho_start_idx; i < rates_total; i++)
      {
         adBuffer[i] = AD(high[i], low[i], close[i], tick_volume[i]);
         if(i > 0)
            adBuffer[i] += adBuffer[i-1];
      }
   }
   else
   {
      for(int i = cho_start_idx; i < rates_total; i++)
      {
         adBuffer[i] = AD(high[i], low[i], close[i], volume[i]);
         if(i > 0)
            adBuffer[i] += adBuffer[i-1];
      }
   }

   AverageOnArray(InpCHOSmoothMethod, rates_total, prev_calculated, 0, InpCHOFastMA, adBuffer, choFastMA);
   AverageOnArray(InpCHOSmoothMethod, rates_total, prev_calculated, 0, InpCHOSlowMA, adBuffer, choSlowMA);

   for(int i = cho_start_idx; i < rates_total; i++)
   {
      if (choFastMA[i] != EMPTY_VALUE && choSlowMA[i] != EMPTY_VALUE)
         choBuffer[i] = choFastMA[i] - choSlowMA[i];
      else
         choBuffer[i] = EMPTY_VALUE;
   }
   
   //--- Generate color signals ---
   int final_signal_start_idx = 1;
   final_signal_start_idx = MathMax(final_signal_start_idx, long_macd_signal_calc_start_idx +1);
   final_signal_start_idx = MathMax(final_signal_start_idx, InpCHOSlowMA);
   final_signal_start_idx = MathMax(final_signal_start_idx, start_idx);


   for(int i = final_signal_start_idx; i < rates_total; i++)
   {
      bool long_is_bullish = (longMacdLine[i] > longMacdLine[i-1] && longMacdLine[i] > longSignalLine[i]) || (longMacdLine[i] > longMacdLine[i-1] && longMacdLine[i] < longSignalLine[i]);
      bool long_is_bearish = (longMacdLine[i] < longMacdLine[i-1] && longMacdLine[i] > longSignalLine[i]) || (longMacdLine[i] < longMacdLine[i-1] && longMacdLine[i] < longSignalLine[i]);

      bool cho_is_bullish = choBuffer[i] > 0;
      bool cho_is_bearish = choBuffer[i] < 0;
      
      colorIndex[i] = SIGNAL_NONE;
      
      if(long_is_bullish && cho_is_bullish)
         colorIndex[i] = SIGNAL_GREEN;
      else if(long_is_bearish && cho_is_bearish)
         colorIndex[i] = SIGNAL_CRIMSON;
      else if(long_is_bullish && cho_is_bearish)
         colorIndex[i] = SIGNAL_ORANGE;
      else if(long_is_bearish && cho_is_bullish)
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
