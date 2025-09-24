//+------------------------------------------------------------------+
//|                                      wajdyss_Ichimoku_Candles.mq5 |
//|                                        Copyright © 2009, Wajdyss |
//|                                                wajdyss@yahoo.com |
//+------------------------------------------------------------------+
#property copyright "Copyright © 2009, Wajdyss"
#property link "wajdyss@yahoo.com"
#property description ""
//---- Indicator version number
#property version   "1.00"
//---- Draw the indicator in the main chart window
#property indicator_chart_window 
//---- Five buffers are used for calculation and rendering
#property indicator_buffers 5
//---- Only one graphical plot is used
#property indicator_plots   1
//+--------------------------------------------+
//|  Indicator drawing parameters              |
//+--------------------------------------------+
//---- Colored candles are used as the indicator
#property indicator_type1   DRAW_COLOR_CANDLES
#property indicator_color1  clrMagenta,clrBrown,clrBlue,clrAqua
//---- Indicator label display
#property indicator_label1  "wajdyss_Ichimoku Open;wajdyss_Ichimoku High;wajdyss_Ichimoku Low;wajdyss_Ichimoku Close"
//+--------------------------------------------+
//|  Constant declarations                     |
//+--------------------------------------------+
#define RESET  0 // Constant for instructing the terminal to recalculate the indicator
//+--------------------------------------------+
//|  INDICATOR INPUT PARAMETERS                |
//+--------------------------------------------+
input uint Kijun=26;
//+--------------------------------------------+
//---- Declaration of dynamic arrays, which will later be used as indicator buffers for Bollinger levels
double ExtOpenBuffer[];
double ExtHighBuffer[];
double ExtLowBuffer[];
double ExtCloseBuffer[];
double ExtColorBuffer[];
//---- Declaration of integer variables for the starting point of data counting
int min_rates_total;
//+------------------------------------------------------------------+   
//| CandleStop initialization function                               | 
//+------------------------------------------------------------------+ 
int OnInit()
  {
//---- Initialize starting point variables for data counting
   min_rates_total=int(Kijun);

//---- Convert dynamic arrays to indicator data buffers
   SetIndexBuffer(0,ExtOpenBuffer,INDICATOR_DATA);
   SetIndexBuffer(1,ExtHighBuffer,INDICATOR_DATA);
   SetIndexBuffer(2,ExtLowBuffer,INDICATOR_DATA);
   SetIndexBuffer(3,ExtCloseBuffer,INDICATOR_DATA);

//---- Convert dynamic array to a color index buffer   
   SetIndexBuffer(4,ExtColorBuffer,INDICATOR_COLOR_INDEX);

//---- Index buffer elements like time series
   ArraySetAsSeries(ExtOpenBuffer,true);
   ArraySetAsSeries(ExtHighBuffer,true);
   ArraySetAsSeries(ExtLowBuffer,true);
   ArraySetAsSeries(ExtCloseBuffer,true);
   ArraySetAsSeries(ExtColorBuffer,true);

//---- Shift the starting point for drawing the indicator by 1
   PlotIndexSetInteger(0,PLOT_DRAW_BEGIN,min_rates_total);

//--- Set the name for display in a separate subwindow and tooltip
   IndicatorSetString(INDICATOR_SHORTNAME,"wajdyss_Ichimoku_Candle");

//--- Define the precision for displaying indicator values
   IndicatorSetInteger(INDICATOR_DIGITS,_Digits+1);
//--- End of initialization
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+ 
//| CandleStop iteration function                                    | 
//+------------------------------------------------------------------+ 
int OnCalculate(
                const int rates_total,    // number of historical bars at current tick
                const int prev_calculated,// number of historical bars at previous tick
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
//--- Check if there are enough bars for calculation
   if(rates_total<min_rates_total) return(RESET);

//---- Declare floating-point variables  
   double kijun,price,High,Low;
//---- Declare integer variables and get
   int limit,bar,to_copy;
  
//---- Calculate the starting index limit for bar recalculation loop
   if(prev_calculated>rates_total || prev_calculated<=0) // check for first-time indicator calculation
     {
      limit=rates_total-min_rates_total-1;               // start index for calculating all bars
     }
   else
     {
      limit=rates_total-prev_calculated;                 // start index for calculating new bars
     }
   to_copy=limit+1;
   
//---- Index array elements like time series 
   ArraySetAsSeries(open,true);
   ArraySetAsSeries(low,true); 
   ArraySetAsSeries(high,true);
   ArraySetAsSeries(close,true);

//---- Main loop for indicator calculation
   for(bar=limit; bar>=0 && !IsStopped(); bar--)
     {
      High=high[bar];
      Low=low[bar];
      int index=bar+int(Kijun)-1;
      while(index>bar)
        {
         price=high[index];
         if(High<price) High=price;
         price=low[index];
         if(Low>price) Low=price;
         index--;
        }
      //----  
      kijun=(High+Low)/2;
      
      ExtOpenBuffer[bar]=open[bar];
      ExtHighBuffer[bar]=high[bar];
      ExtLowBuffer[bar]=low[bar];
      ExtCloseBuffer[bar]=close[bar];
      
      //---- Determine color based on relation to Kijun line
      if(close[bar]>kijun)
        {
         if(close[bar]>=open[bar]) ExtColorBuffer[bar]=3;
         else ExtColorBuffer[bar]=2;
        }
      //----
      if(close[bar]<kijun)
        {
         if(close[bar]<=open[bar]) ExtColorBuffer[bar]=0;
         else ExtColorBuffer[bar]=1;
        }
     }
//----  
   return(rates_total);
  }
//+------------------------------------------------------------------+
