//+------------------------------------------------------------------+
//|                                          CandleTypeHistogram.mq5 |
//|                        Copyright 2023, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property indicator_separate_window
#property indicator_buffers 2
#property indicator_plots   1

#property indicator_label1  "CandleTypeHistogram"
#property indicator_type1   DRAW_COLOR_HISTOGRAM   // <- Must be DRAW_COLOR_HISTOGRAM
#property indicator_color1  clrDarkSlateGray, clrMaroon, clrGray
#property indicator_width1  2

double candleBuffer[];  // Data buffer (heights of histogram bars)
double colorBuffer[];   // Color index buffer

double openBuffer[], closeBuffer[];

int OnInit()
  {
   SetIndexBuffer(0, candleBuffer, INDICATOR_DATA);
   SetIndexBuffer(1, colorBuffer, INDICATOR_COLOR_INDEX);  // Important for color-based plotting

   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, 1);

   ArraySetAsSeries(candleBuffer, true);
   ArraySetAsSeries(colorBuffer, true);
   ArraySetAsSeries(openBuffer, true);
   ArraySetAsSeries(closeBuffer, true);

   return(INIT_SUCCEEDED);
  }

int OnCalculate(const int rates_total,
                const int prev_calculated,
                const int begin,
                const double &price[])
  {
   if(CopyOpen(_Symbol, _Period, 0, rates_total, openBuffer) <= 0) return(0);
   if(CopyClose(_Symbol, _Period, 0, rates_total, closeBuffer) <= 0) return(0);

   int limit = rates_total - prev_calculated;
   if(prev_calculated > 0) limit++;

   for(int i = 0; i < limit && i < rates_total; i++)
     {
      double open  = openBuffer[i];
      double close = closeBuffer[i];

      if(close > open)
        {
         candleBuffer[i] = 50.0;
         colorBuffer[i]  = 0; // Green
        }
      else if(close < open)
        {
         candleBuffer[i] = -50.0;
         colorBuffer[i]  = 1; // Red
        }
      else
        {
         candleBuffer[i] = 0.0;
         colorBuffer[i]  = 2; // Gray
        }
     }

   return(rates_total);
  }
