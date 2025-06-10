//+------------------------------------------------------------------+
//|                                      Single_Level_ZZ_Semafor.mq5 |
//|                                                      @mobilebass |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "@mobilebass"
#property link      "https://www.mql5.com"
#property version   "1.01" // Version updated for sound alerts
#property indicator_chart_window
#property indicator_buffers 4
#property indicator_plots   2

//+----------------------------------------------+
//|  Bullish indicator drawing parameters        |
//+----------------------------------------------+
#property indicator_type1   DRAW_ARROW
#property indicator_color1  Aqua
#property indicator_width1  1
#property indicator_label1  "Low"

//+----------------------------------------------+
//|  Bearish indicator drawing parameters        |
//+----------------------------------------------+
#property indicator_type2   DRAW_ARROW
#property indicator_color2  Magenta
#property indicator_width2  1
#property indicator_label2  "High"

//+----------------------------------------------+
//|  Indicator input parameters                  |
//+----------------------------------------------+
input int    Period1 = 2;        // Depth
input int    Deviation1 = 1;     // Deviation (points)
input int    Backstep1 = 1;      // Back Step
input int    HighSymbol1 = 159;  // High arrow symbol
input int    LowSymbol1 = 159;   // Low arrow symbol
input bool   EnableAlerts = true;// Enable Sound Alerts

//+----------------------------------------------+
//|  Indicator buffers                           |
//+----------------------------------------------+
double HighBuffer1[];         // High extremes buffer
double LowBuffer1[];          // Low extremes buffer
double HighMapBuffer[];       // Calculation buffer for highs
double LowMapBuffer[];        // Calculation buffer for lows
int    ArrowShiftPixels = 10;  // Arrow shift in pixels

//+----------------------------------------------+
//|  Global variables for alert management       |
//+----------------------------------------------+
enum ENUM_ALERT_STATE {ALERT_NONE, ALERT_BUY, ALERT_SELL};
ENUM_ALERT_STATE AlertState = ALERT_NONE;

//+----------------------------------------------+
//|  Custom indicator initialization function    |
//+----------------------------------------------+
void OnInit()
{
   // Initialize buffers
   SetIndexBuffer(0, LowBuffer1, INDICATOR_DATA);
   SetIndexBuffer(1, HighBuffer1, INDICATOR_DATA);
   SetIndexBuffer(2, HighMapBuffer, INDICATOR_CALCULATIONS);
   SetIndexBuffer(3, LowMapBuffer, INDICATOR_CALCULATIONS);

   // Set arrow shifts (new additions)
   PlotIndexSetInteger(1, PLOT_ARROW_SHIFT, -ArrowShiftPixels); // Low arrows shift DOWN (below price)
   PlotIndexSetInteger(0, PLOT_ARROW_SHIFT, ArrowShiftPixels);  // High arrows shift UP (above price)
   
   // Set drawing properties for lows
   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, Period1);
   PlotIndexSetString(0, PLOT_LABEL, "Low1");
   PlotIndexSetInteger(0, PLOT_ARROW, LowSymbol1);
   ArraySetAsSeries(LowBuffer1, true);
   
   // Set drawing properties for highs
   PlotIndexSetInteger(1, PLOT_DRAW_BEGIN, Period1);
   PlotIndexSetString(1, PLOT_LABEL, "High1");
   PlotIndexSetInteger(1, PLOT_ARROW, HighSymbol1);
   ArraySetAsSeries(HighBuffer1, true);
   
   // Set calculation buffers as timeseries
   ArraySetAsSeries(HighMapBuffer, true);
   ArraySetAsSeries(LowMapBuffer, true);
   
   // Set indicator properties
   IndicatorSetString(INDICATOR_SHORTNAME, "SelfContained_ZZ_Semafor(" + 
                      string(Period1) + "," + string(Deviation1) + "," + string(Backstep1) + ")");
   IndicatorSetInteger(INDICATOR_DIGITS, _Digits);
}

//+------------------------------------------------------------------+
//|  Custom indicator iteration function                             |
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
   // Check for minimum bars required
   if(rates_total < Period1 + Deviation1 + Backstep1 + 1)
      return(0);
      
   // Set array as series
   ArraySetAsSeries(high, true);
   ArraySetAsSeries(low, true);
   
   // Initialization
   int limit;
   if(prev_calculated == 0)
   {
      // First calculation - initialize all buffers
      ArrayInitialize(HighBuffer1, 0.0);
      ArrayInitialize(LowBuffer1, 0.0);
      ArrayInitialize(HighMapBuffer, 0.0);
      ArrayInitialize(LowMapBuffer, 0.0);
      limit = rates_total - Period1 - 1;
      AlertState = ALERT_NONE; // Reset alert state on full recalculation
   }
   else
   {
      // Subsequent calculations - only process new bars
      limit = rates_total - prev_calculated + 1;
   }
   
   // Main calculation loop
   for(int shift = limit; shift >= 0 && !IsStopped(); shift--)
   {
      // Process lows (buy signals)
      int lowest = iLowest(low, Period1, shift);
      double current_low = low[lowest];
      
      if(MathAbs(current_low - low[shift]) <= Deviation1 * _Point)
      {
         bool valid_low = true;
         for(int back = 1; back <= Backstep1; back++)
         {
            if(LowMapBuffer[shift + back] != 0.0 && LowMapBuffer[shift + back] < current_low)
            {
               LowMapBuffer[shift + back] = 0.0;
               valid_low = false;
            }
         }
         
         if(valid_low && lowest == shift)
         {
            LowMapBuffer[shift] = current_low;
            LowBuffer1[shift] = current_low;
            
            for(int back = 1; back <= Backstep1; back++)
            {
               if(LowBuffer1[shift + back] != 0.0 && LowBuffer1[shift + back] > current_low)
                  LowBuffer1[shift + back] = 0.0;
            }
            
            // Check for new buy signal
            if(EnableAlerts && AlertState != ALERT_BUY && shift == 0) // Only alert on current bar
            {
               PlaySound("buy_alert.wav");
               AlertState = ALERT_BUY;
            }
         }
         else
         {
            LowMapBuffer[shift] = 0.0;
            LowBuffer1[shift] = 0.0;
         }
      }
      else
      {
         LowMapBuffer[shift] = 0.0;
         LowBuffer1[shift] = 0.0;
      }
      
      // Process highs (sell signals)
      int highest = iHighest(high, Period1, shift);
      double current_high = high[highest];
      
      if(MathAbs(current_high - high[shift]) <= Deviation1 * _Point)
      {
         bool valid_high = true;
         for(int back = 1; back <= Backstep1; back++)
         {
            if(HighMapBuffer[shift + back] != 0.0 && HighMapBuffer[shift + back] > current_high)
            {
               HighMapBuffer[shift + back] = 0.0;
               valid_high = false;
            }
         }
         
         if(valid_high && highest == shift)
         {
            HighMapBuffer[shift] = current_high;
            HighBuffer1[shift] = current_high;
            
            for(int back = 1; back <= Backstep1; back++)
            {
               if(HighBuffer1[shift + back] != 0.0 && HighBuffer1[shift + back] < current_high)
                  HighBuffer1[shift + back] = 0.0;
            }
            
            // Check for new sell signal
            if(EnableAlerts && AlertState != ALERT_SELL && shift == 0) // Only alert on current bar
            {
               PlaySound("sell_alert.wav");
               AlertState = ALERT_SELL;
            }
         }
         else
         {
            HighMapBuffer[shift] = 0.0;
            HighBuffer1[shift] = 0.0;
         }
      }
      else
      {
         HighMapBuffer[shift] = 0.0;
         HighBuffer1[shift] = 0.0;
      }
   }
   
   return(rates_total);
}

//+------------------------------------------------------------------+
//|  Finds the index of the highest value in array                   |
//+------------------------------------------------------------------+
int iHighest(const double &array[], int period, int shift)
{
   int index = shift;
   double max = array[shift];
   
   for(int i = shift + 1; i < shift + period && i < ArraySize(array); i++)
   {
      if(array[i] > max)
      {
         index = i;
         max = array[i];
      }
   }
   
   return index;
}

//+------------------------------------------------------------------+
//|  Finds the index of the lowest value in array                    |
//+------------------------------------------------------------------+
int iLowest(const double &array[], int period, int shift)
{
   int index = shift;
   double min = array[shift];
   
   for(int i = shift + 1; i < shift + period && i < ArraySize(array); i++)
   {
      if(array[i] < min)
      {
         index = i;
         min = array[i];
      }
   }
   
   return index;
}
//+------------------------------------------------------------------+
