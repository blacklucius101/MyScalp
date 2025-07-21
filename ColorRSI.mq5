//+------------------------------------------------------------------+
//|                                                     ColorRSI.mq5 |
//|                        Copyright 2023, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023, MetaQuotes Software Corp."
#property link      "https://www.mql5.com"
#property version   "1.00"
#property indicator_separate_window
#property indicator_buffers 4 // Adjusted for manual RSI: RSI_Buffer, Color_Buffer, PosBuffer, NegBuffer
#property indicator_plots   1
#property indicator_type1   DRAW_COLOR_LINE // Confirmed
#property indicator_color1  clrDimGray,clrGreen,clrRed // Neutral, Up (Green), Down (Red)
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2 // Increased width for better visibility
#property indicator_minimum 0
#property indicator_maximum 100
#property indicator_level1 30.0
#property indicator_level2 70.0
#property indicator_levelcolor clrSilver
#property indicator_levelstyle STYLE_DOT

//--- input parameters
input int RSIPeriod = 14;    // RSI Period

//--- indicator buffers
double RSIData[];      // Buffer for final RSI values
double RSIColor[];     // Buffer for color indices
double PosBuffer[];    // Buffer for positive price changes (used in manual RSI)
double NegBuffer[];    // Buffer for negative price changes (used in manual RSI)

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
  {
//--- indicator buffers mapping
   SetIndexBuffer(0, RSIData, INDICATOR_DATA);
   SetIndexBuffer(1, RSIColor, INDICATOR_COLOR_INDEX); // Map the color buffer
   SetIndexBuffer(2, PosBuffer, INDICATOR_CALCULATIONS); // Map buffer for positive changes
   SetIndexBuffer(3, NegBuffer, INDICATOR_CALCULATIONS); // Map buffer for negative changes

//--- Set short name
   IndicatorSetString(INDICATOR_SHORTNAME, "ColorRSI(" + (string)RSIPeriod + ")");

//--- plot properties
   PlotIndexSetString(0, PLOT_LABEL, "ColorRSI"); // Changed label
   PlotIndexSetInteger(0, PLOT_DRAW_TYPE, DRAW_COLOR_LINE);
   PlotIndexSetInteger(0, PLOT_LINE_STYLE, STYLE_SOLID);
   PlotIndexSetInteger(0, PLOT_LINE_WIDTH, 2);
   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, RSIPeriod); // Set draw begin

   // Define colors for the plot (index 0 for Neutral, 1 for Up, 2 for Down)
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, 0, clrDimGray);       // Neutral slope
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, 1, clrGreen); // Upward slope
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, 2, clrRed);         // Downward slope

//--- Set indicator levels from #property values
   IndicatorSetInteger(INDICATOR_LEVELS, 2);
   IndicatorSetDouble(INDICATOR_LEVELVALUE, 0, 30.0); // Corresponds to #property indicator_level1
   IndicatorSetDouble(INDICATOR_LEVELVALUE, 1, 70.0); // Corresponds to #property indicator_level2
   IndicatorSetInteger(INDICATOR_LEVELCOLOR, clrSilver); // Corresponds to #property indicator_levelcolor
   IndicatorSetInteger(INDICATOR_LEVELSTYLE, STYLE_DOT); // Corresponds to #property indicator_levelstyle
   IndicatorSetInteger(INDICATOR_LEVELWIDTH, 1);


//--- initialization done
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
   // Ensure arrays are treated as non-series (index 0 is oldest)
   ArraySetAsSeries(close, false);
   ArraySetAsSeries(RSIData, false);
   ArraySetAsSeries(RSIColor, false);
   ArraySetAsSeries(PosBuffer, false);
   ArraySetAsSeries(NegBuffer, false);

   // Not enough data for even one RSI value.
   // PLOT_DRAW_BEGIN is RSIPeriod, meaning RSIData[RSIPeriod] is the first drawable value.
   // We need at least RSIPeriod bars of history *before* the first calculable point.
   // So, rates_total must be at least RSIPeriod + 1 for close[RSIPeriod] and close[RSIPeriod-1] etc. to be valid.
   if(rates_total < RSIPeriod + 1) // Adjusted this condition slightly for clarity
      return(0);

   int pos;

   // Initial calculation part: executed if prev_calculated is small (first run or history update)
   if(prev_calculated < RSIPeriod + 1) // Check if initial calculation steps are needed
   {
      // Initialize bars from 0 to RSIPeriod-1. These are not drawn.
      for(int i = 0; i < RSIPeriod; i++)
      {
         RSIData[i] = 0.0; 
         PosBuffer[i] = 0.0;
         NegBuffer[i] = 0.0;
         RSIColor[i] = 0; // Neutral color
      }

      // Calculate the very first RSI value at index RSIPeriod
      double sum_pos = 0.0;
      double sum_neg = 0.0;
      // Sum changes for the first RSIPeriod periods.
      // Example: RSIPeriod=14. Sum changes for price[1]-price[0], price[2]-price[1], ..., price[14]-price[13].
      // These are indices k=1 to k=RSIPeriod for close[k] and close[k-1].
      for(int k = 1; k <= RSIPeriod; k++) 
      {
         double diff = close[k] - close[k-1]; // Correct indexing for historical data access
         sum_pos += (diff > 0) ? diff : 0.0;
         sum_neg += (diff < 0) ? -diff : 0.0;
      }

      PosBuffer[RSIPeriod] = sum_pos / RSIPeriod;
      NegBuffer[RSIPeriod] = sum_neg / RSIPeriod;

      if(NegBuffer[RSIPeriod] == 0.0)
         RSIData[RSIPeriod] = (PosBuffer[RSIPeriod] == 0.0) ? 50.0 : 100.0;
      else
         RSIData[RSIPeriod] = 100.0 - (100.0 / (1.0 + PosBuffer[RSIPeriod] / NegBuffer[RSIPeriod]));
      
      RSIColor[RSIPeriod] = 0; // Neutral color for the first calculated RSI value

      // Set starting position for the main loop for remaining bars
      pos = RSIPeriod + 1;
   }
   else // Standard incremental calculation
   {
      pos = prev_calculated - 1;
   }

   // Main calculation loop: from older uncalculated bars to the most recent bar
   for(int i = pos; i < rates_total && !IsStopped(); i++)
   {
      // Ensure i > 0 for accessing [i-1] elements.
      // This condition should be naturally met if 'pos' is correctly determined
      // (e.g., RSIPeriod + 1 or prev_calculated - 1, where prev_calculated > 1).
      if (i == 0) continue; // Should not be strictly necessary if pos is always >= 1 here.

      double price_diff = close[i] - close[i-1];
      double current_positive_change = (price_diff > 0) ? price_diff : 0.0;
      double current_negative_change = (price_diff < 0) ? -price_diff : 0.0;

      // Wilder's smoothing using previous smoothed values PosBuffer[i-1] and NegBuffer[i-1]
      PosBuffer[i] = (PosBuffer[i-1] * (RSIPeriod - 1) + current_positive_change) / RSIPeriod;
      NegBuffer[i] = (NegBuffer[i-1] * (RSIPeriod - 1) + current_negative_change) / RSIPeriod;

      // Calculate RSI
      if(NegBuffer[i] == 0.0)
         RSIData[i] = (PosBuffer[i] == 0.0) ? 50.0 : 100.0;
      else
         RSIData[i] = 100.0 - (100.0 / (1.0 + PosBuffer[i] / NegBuffer[i])); // Corrected: PosBuffer[i] / NegBuffer[i]

      // Slope Detection and Color Indexing
      // RSIData[i-1] is the RSI of the previous bar.
      // Need to ensure RSIData[i-1] is a valid calculated value and not an initial 0.0.
      // The first point with slope is RSIData[RSIPeriod+1] compared to RSIData[RSIPeriod].
      if (i <= RSIPeriod) // RSIData[RSIPeriod] is the first point, its color is already neutral.
      {
          // RSIColor[RSIPeriod] is set during initial calculation.
          // For any i < RSIPeriod, colors are also set to neutral.
          // If i == RSIPeriod, this will re-set to neutral if not already, which is fine.
          RSIColor[i] = 0; 
      }
      else // i > RSIPeriod, so RSIData[i-1] is a valid calculated RSI.
      {
          if (RSIData[i] > RSIData[i-1]) 
          {
             RSIColor[i] = 1; // Upward slope color index
          }
          else if (RSIData[i] < RSIData[i-1])
          {
             RSIColor[i] = 2; // Downward slope color index
          }
          else // RSIData[i] == RSIData[i-1]
          {
             RSIColor[i] = RSIColor[i-1]; // Same color as previous for flat slope
          }
      }
   }
   return(rates_total);
}
//+------------------------------------------------------------------+
//| Custom indicator deinitialization function                       |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//---
  }
//+------------------------------------------------------------------+
