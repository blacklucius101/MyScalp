//+------------------------------------------------------------------+
//|                                               ATR_Volatility.mq5 |
//|                        Copyright 2018, MetaQuotes Software Corp. |
//|                                                 https://mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2018, MetaQuotes Software Corp."
#property link      "https://mql5.com"
#property version   "1.00"
#property description "ATR Volatility oscillator"
#property indicator_separate_window
#property indicator_buffers 2
#property indicator_plots   1
//--- plot AATR
#property indicator_label1  "AATR"
#property indicator_type1   DRAW_COLOR_HISTOGRAM
#property indicator_color1  clrPurple,clrGreen,clrDodgerBlue,clrRed
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2
//--- enums
enum ENUM_MODE
  {
   MODE_POINTS,   // In points
   MODE_PERCENT   // In percents
  };
//--- input parameters
input uint        InpPeriod   =  12;            // ATR period
input double      InpLevelH   =  6200.0;         // Higher level
input double      InpLevelM   =  3700.0;         // Middle level
input double      InpLevelL   =  2700.0;         // Lower level
input ENUM_MODE   InpMode     =  MODE_POINTS;   // Calculation mode
input uint        InpMaxBars  =  1000.0;        // Maximum bars
//--- indicator buffers
double         BufferAATR[];
double         BufferColors[];
//--- global variables
double         level_h;
double         level_m;
double         level_l;
double         last_top;
double         last_mid;
double         last_bottom;
int            period_atr;
int            max_bars;
int            handle_atr;
//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
  {
//--- set global variables
   period_atr=int(InpPeriod<1 ? 1 : InpPeriod);
   level_h=InpLevelH;
   level_m=InpLevelM;
   level_l=InpLevelL;
   last_top=0;
   last_mid=0;
   last_bottom=0;
//--- indicator buffers mapping
   SetIndexBuffer(0,BufferAATR,INDICATOR_DATA);
   SetIndexBuffer(1,BufferColors,INDICATOR_COLOR_INDEX);
//--- setting indicator parameters
   string pf=(InpMode==MODE_PERCENT ? "%" : "");
   IndicatorSetString(INDICATOR_SHORTNAME,"ATR Volatility ("+(string)period_atr+","+DoubleToString(level_h,1)+pf+","+DoubleToString(level_m,1)+pf+","+DoubleToString(level_l,1)+pf+")");
   IndicatorSetInteger(INDICATOR_DIGITS,Digits());
   IndicatorSetInteger(INDICATOR_LEVELS,3);
   IndicatorSetInteger(INDICATOR_LEVELCOLOR,0,clrDodgerBlue);
   IndicatorSetInteger(INDICATOR_LEVELCOLOR,1,clrGray);
   IndicatorSetInteger(INDICATOR_LEVELCOLOR,2,clrOrangeRed);
//--- setting buffer arrays as timeseries
   ArraySetAsSeries(BufferAATR,true);
   ArraySetAsSeries(BufferColors,true);
//--- create MA's handles
   ResetLastError();
   handle_atr=iATR(NULL,PERIOD_CURRENT,period_atr);
   if(handle_atr==INVALID_HANDLE)
     {
      Print("The iATR(",(string)period_atr,") object was not created: Error ",GetLastError());
      return INIT_FAILED;
     }
//---
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
//--- Установка массивов буферов как таймсерий
   ArraySetAsSeries(high,true);
   ArraySetAsSeries(low,true);
   ArraySetAsSeries(close,true);
//--- Проверка и расчёт количества просчитываемых баров
   if(rates_total<4 || Point()==0) return 0;
//--- Проверка и расчёт количества просчитываемых баров
   int limit=rates_total-prev_calculated;
   if(limit>1)
     {
      limit=rates_total-1;
      ArrayInitialize(BufferAATR,EMPTY_VALUE);
     }
//--- Подготовка данных
   int count=(limit>1 ? rates_total : 1),copied=0;
   copied=CopyBuffer(handle_atr,0,0,count,BufferAATR);
   if(copied!=count) return 0;
   
//--- Расчёт индикатора
   int bars=rates_total-period_atr-1;
   int count_bars=int(InpMaxBars==0 ? bars : (int)InpMaxBars>bars ? bars : InpMaxBars);
   
   int bl=ArrayMinimum(BufferAATR,0,count_bars);
   int bh=ArrayMaximum(BufferAATR,0,count_bars);
   if(bl==WRONG_VALUE || bh==WRONG_VALUE)
      return 0;
   double min=BufferAATR[bl];
   double max=BufferAATR[bh];

   double top=0,mid=0,bottom=0,percentage=0;

   if(InpMode==MODE_POINTS)
     {
      top=level_h*Point();
      mid=level_m*Point();
      bottom=level_l*Point();
     }
   else
     {
      percentage=(max-min)/100.0;
      top=min+level_h*percentage;
      mid=min+level_m*percentage;
      bottom=min+level_l*percentage; 
     }
   if(last_top!=top)
     {
      IndicatorSetDouble(INDICATOR_LEVELVALUE,0,top);
      last_top=top;
     }
   if(last_mid!=mid)
     {
      IndicatorSetDouble(INDICATOR_LEVELVALUE,1,mid);
      last_mid=mid;
     }
   if(last_bottom!=bottom)
     {
      IndicatorSetDouble(INDICATOR_LEVELVALUE,2,bottom);
      last_bottom=bottom;
     }

   for(int i=limit; i>=0 && !IsStopped(); i--)
      BufferColors[i]=(BufferAATR[i]>top) ? 0 : (BufferAATR[i]>mid) ? 1 : (BufferAATR[i]>bottom) ? 2 : 3;

//--- return value of prev_calculated for next call
   return(rates_total);
  }
//+------------------------------------------------------------------+
