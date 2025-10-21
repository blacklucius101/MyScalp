//+------------------------------------------------------------------+
//|                                             ColoredLineChart.mq5 |
//|                        Copyright 2023, MetaQuotes Software Corp. |
//|                          Modified by ChatGPT (2025)              |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023, MetaQuotes"
#property link      "https://www.mql5.com"
#property version   "1.00"
#property indicator_chart_window

#property indicator_buffers 2
#property indicator_plots   1

//--- plot Line
#property indicator_label1  "Close Line"
#property indicator_type1   DRAW_COLOR_LINE
#property indicator_color1  clrGreen, clrRed
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2

//--- indicator buffers
double         LineBuffer[];
double         ColorBuffer[];

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
{
   SetIndexBuffer(0, LineBuffer, INDICATOR_DATA);
   SetIndexBuffer(1, ColorBuffer, INDICATOR_COLOR_INDEX);

   PlotIndexSetString(0, PLOT_LABEL, "Close Line");

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
   int start = (prev_calculated > 1) ? prev_calculated - 1 : 1;

   for(int i = start; i < rates_total; i++)
   {
      LineBuffer[i] = close[i];

      if(close[i] > close[i - 1])
         ColorBuffer[i] = 0;  // Green
      else if(close[i] < close[i - 1])
         ColorBuffer[i] = 1;  // Red
      else
         ColorBuffer[i] = ColorBuffer[i - 1]; // No change
   }

   return(rates_total);
}
