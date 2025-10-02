//+------------------------------------------------------------------+
//|                            SimpleBullishBearishCandle.mq5       |
//|                Displays candle colors based on bull/bear        |
//+------------------------------------------------------------------+
#property copyright ""
#property link      ""
#property version   "1.00"
#property description "Simple bullish/bearish candle indicator"
#property indicator_chart_window 
#property indicator_buffers 5
#property indicator_plots   1

//---- Draw colored bars
#property indicator_type1   DRAW_COLOR_BARS
#property indicator_color1  clrLightSeaGreen, clrRed // Blue for bullish, Red for bearish
#property indicator_label1  "Bullish/Bearish Candle"

//---- Buffers
double OpenBuffer[];
double HighBuffer[];
double LowBuffer[];
double CloseBuffer[];
double ColorBuffer[];

//+------------------------------------------------------------------+
//| Initialization                                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
   // Set buffers
   SetIndexBuffer(0, OpenBuffer, INDICATOR_DATA);
   SetIndexBuffer(1, HighBuffer, INDICATOR_DATA);
   SetIndexBuffer(2, LowBuffer, INDICATOR_DATA);
   SetIndexBuffer(3, CloseBuffer, INDICATOR_DATA);
   SetIndexBuffer(4, ColorBuffer, INDICATOR_COLOR_INDEX);

   // Buffers as series
   ArraySetAsSeries(OpenBuffer, true);
   ArraySetAsSeries(HighBuffer, true);
   ArraySetAsSeries(LowBuffer, true);
   ArraySetAsSeries(CloseBuffer, true);
   ArraySetAsSeries(ColorBuffer, true);

   IndicatorSetString(INDICATOR_SHORTNAME, "Bullish/Bearish Candle");
   IndicatorSetInteger(INDICATOR_DIGITS, _Digits);

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Main Calculation                                                 |
//+------------------------------------------------------------------+
int OnCalculate(
   const int rates_total,
   const int prev_calculated,
   const datetime &time[],
   const double &open[],
   const double &high[],
   const double &low[],
   const double &close[],
   const long &tick_volume[],
   const long &volume[],
   const int &spread[]
)
  {
   int limit = (prev_calculated == 0) ? rates_total - 1 : rates_total - prev_calculated;

   ArraySetAsSeries(open, true);
   ArraySetAsSeries(high, true);
   ArraySetAsSeries(low, true);
   ArraySetAsSeries(close, true);

   for(int i = limit; i >= 0; i--)
     {
      OpenBuffer[i] = open[i];
      HighBuffer[i] = high[i];
      LowBuffer[i] = low[i];
      CloseBuffer[i] = close[i];

      if(close[i] > open[i])
         ColorBuffer[i] = 0; // Blue (bullish)
      else if(close[i] < open[i])
         ColorBuffer[i] = 1; // Red (bearish)
      else
         ColorBuffer[i] = 1; // Treat doji as bearish
     }

   return(rates_total);
  }
//+------------------------------------------------------------------+
