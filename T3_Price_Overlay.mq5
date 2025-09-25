//+------------------------------------------------------------------+
//|                                             T3_Price_Overlay.mq5 |
//|                        Copyright 2018, MetaQuotes Software Corp. |
//|                                                 https://mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2018, MetaQuotes Software Corp."
#property link      "https://mql5.com"
#property version   "1.00"
#property description "Tim Tillson's T3 MA Price Overlay indicator"
#property indicator_chart_window
#property indicator_buffers 19
#property indicator_plots   3
//--- plot T3High
#property indicator_label1  "T3 High"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrSilver
#property indicator_style1  STYLE_SOLID
#property indicator_width1  1
//--- plot T3Low
#property indicator_label2  "T3 Low"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrSilver
#property indicator_style2  STYLE_SOLID
#property indicator_width2  1
//--- plot Candle
#property indicator_label3  "Candle"
#property indicator_type3   DRAW_COLOR_BARS
//#property indicator_type3   DRAW_COLOR_CANDLES
#property indicator_color3  clrForestGreen,clrMediumAquamarine,clrRed,clrBurlyWood,clrDarkGray
#property indicator_style3  STYLE_SOLID
#property indicator_width3  1
//--- input parameters
input uint     InpPeriod         =  20;   // T3 period
input double   InpVolumeFactor   =  0.7;  // T3 volume factor
//--- indicator buffers
double         BufferT3High[];
double         BufferT3Low[];
double         BufferCandleO[];
double         BufferCandleH[];
double         BufferCandleL[];
double         BufferCandleC[];
double         BufferColors[];
//---
double         BufferHE1[];
double         BufferHE2[];
double         BufferHE3[];
double         BufferHE4[];
double         BufferHE5[];
double         BufferHE6[];
//---
double         BufferLE1[];
double         BufferLE2[];
double         BufferLE3[];
double         BufferLE4[];
double         BufferLE5[];
double         BufferLE6[];
//--- global variables
double         factor;
int            period;
int            handle_mah;
int            handle_mal;
double         c1,c2,c3,c4,w1,w2;
//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
  {
//--- set global variables
   period=int(InpPeriod<1 ? 1 : InpPeriod);
   factor=InpVolumeFactor;
   double b2=0,b3=0;
   b2=factor*factor;
   b3=b2*factor;
   c1=-b3;
   c2=(3.0*(b2+b3));
   c3=-3.0*(2*b2+factor+b3);
   c4=(1.0+3.0*factor+b3+3*b2);
   double n=1.0+0.5*(period-1);
   w1=2.0/(n+1.0);
   w2=1.0-w1;
//--- indicator buffers mapping
   SetIndexBuffer(0,BufferT3High,INDICATOR_DATA);
   SetIndexBuffer(1,BufferT3Low,INDICATOR_DATA);
   SetIndexBuffer(2,BufferCandleO,INDICATOR_DATA);
   SetIndexBuffer(3,BufferCandleH,INDICATOR_DATA);
   SetIndexBuffer(4,BufferCandleL,INDICATOR_DATA);
   SetIndexBuffer(5,BufferCandleC,INDICATOR_DATA);
   SetIndexBuffer(6,BufferColors,INDICATOR_COLOR_INDEX);
   SetIndexBuffer(7,BufferHE1,INDICATOR_CALCULATIONS);
   SetIndexBuffer(8,BufferHE2,INDICATOR_CALCULATIONS);
   SetIndexBuffer(9,BufferHE3,INDICATOR_CALCULATIONS);
   SetIndexBuffer(10,BufferHE4,INDICATOR_CALCULATIONS);
   SetIndexBuffer(11,BufferHE5,INDICATOR_CALCULATIONS);
   SetIndexBuffer(12,BufferHE6,INDICATOR_CALCULATIONS);
   SetIndexBuffer(13,BufferLE1,INDICATOR_CALCULATIONS);
   SetIndexBuffer(14,BufferLE2,INDICATOR_CALCULATIONS);
   SetIndexBuffer(15,BufferLE3,INDICATOR_CALCULATIONS);
   SetIndexBuffer(16,BufferLE4,INDICATOR_CALCULATIONS);
   SetIndexBuffer(17,BufferLE5,INDICATOR_CALCULATIONS);
   SetIndexBuffer(18,BufferLE6,INDICATOR_CALCULATIONS);
//--- setting indicator parameters
   IndicatorSetString(INDICATOR_SHORTNAME,"T3 Price Overlay ("+(string)period+","+(string)factor+")");
   IndicatorSetInteger(INDICATOR_DIGITS,Digits());
//--- setting plot buffer parameters
   PlotIndexSetInteger(2,PLOT_SHOW_DATA,false);
//--- setting buffer arrays as timeseries
   ArraySetAsSeries(BufferT3High,true);
   ArraySetAsSeries(BufferT3Low,true);
   ArraySetAsSeries(BufferCandleO,true);
   ArraySetAsSeries(BufferCandleH,true);
   ArraySetAsSeries(BufferCandleL,true);
   ArraySetAsSeries(BufferCandleC,true);
   ArraySetAsSeries(BufferColors,true);
   ArraySetAsSeries(BufferHE1,true);
   ArraySetAsSeries(BufferHE2,true);
   ArraySetAsSeries(BufferHE3,true);
   ArraySetAsSeries(BufferHE4,true);
   ArraySetAsSeries(BufferHE5,true);
   ArraySetAsSeries(BufferHE6,true);
   ArraySetAsSeries(BufferLE1,true);
   ArraySetAsSeries(BufferLE2,true);
   ArraySetAsSeries(BufferLE3,true);
   ArraySetAsSeries(BufferLE4,true);
   ArraySetAsSeries(BufferLE5,true);
   ArraySetAsSeries(BufferLE6,true);
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
   ArraySetAsSeries(open,true);
   ArraySetAsSeries(high,true);
   ArraySetAsSeries(low,true);
   ArraySetAsSeries(close,true);
//--- Проверка количества доступных баров
   if(rates_total<fmax(period,4)) return 0;
//--- Проверка и расчёт количества просчитываемых баров
   int limit=rates_total-prev_calculated;
   if(limit>1)
     {
      limit=rates_total-2;
      ArrayInitialize(BufferT3High,EMPTY_VALUE);
      ArrayInitialize(BufferT3Low,EMPTY_VALUE);
      ArrayInitialize(BufferCandleO,EMPTY_VALUE);
      ArrayInitialize(BufferCandleH,EMPTY_VALUE);
      ArrayInitialize(BufferCandleL,EMPTY_VALUE);
      ArrayInitialize(BufferCandleC,EMPTY_VALUE);
      ArrayInitialize(BufferColors,4);
      ArrayInitialize(BufferHE1,0);
      ArrayInitialize(BufferHE2,0);
      ArrayInitialize(BufferHE3,0);
      ArrayInitialize(BufferHE4,0);
      ArrayInitialize(BufferHE5,0);
      ArrayInitialize(BufferHE6,0);
      ArrayInitialize(BufferLE1,0);
      ArrayInitialize(BufferLE2,0);
      ArrayInitialize(BufferLE3,0);
      ArrayInitialize(BufferLE4,0);
      ArrayInitialize(BufferLE5,0);
      ArrayInitialize(BufferLE6,0);
     }
     
//--- Расчёт T3
   for(int i=limit; i>=0 && !IsStopped(); i--)
     {
      BufferHE1[i]=w1*high[i]+w2*BufferHE1[i+1];
      BufferHE2[i]=w1*BufferHE1[i]+w2*BufferHE2[i+1];
      BufferHE3[i]=w1*BufferHE2[i]+w2*BufferHE3[i+1];
      BufferHE4[i]=w1*BufferHE3[i]+w2*BufferHE4[i+1];
      BufferHE5[i]=w1*BufferHE4[i]+w2*BufferHE5[i+1];
      BufferHE6[i]=w1*BufferHE5[i]+w2*BufferHE6[i+1];
      BufferT3High[i]=c1*BufferHE6[i]+c2*BufferHE5[i]+c3*BufferHE4[i]+c4*BufferHE3[i];
//---
      BufferLE1[i]=w1*low[i]+w2*BufferLE1[i+1];
      BufferLE2[i]=w1*BufferLE1[i]+w2*BufferLE2[i+1];
      BufferLE3[i]=w1*BufferLE2[i]+w2*BufferLE3[i+1];
      BufferLE4[i]=w1*BufferLE3[i]+w2*BufferLE4[i+1];
      BufferLE5[i]=w1*BufferLE4[i]+w2*BufferLE5[i+1];
      BufferLE6[i]=w1*BufferLE5[i]+w2*BufferLE6[i+1];
      BufferT3Low[i]=c1*BufferLE6[i]+c2*BufferLE5[i]+c3*BufferLE4[i]+c4*BufferLE3[i];
     }

//--- Расчёт свечей
   for(int i=limit; i>=0 && !IsStopped(); i--)
     {
      if(close[i]>BufferT3High[i])
        {
         BufferCandleO[i]=open[i];
         BufferCandleH[i]=high[i];
         BufferCandleL[i]=low[i];
         BufferCandleC[i]=close[i];
         BufferColors[i]=(open[i]<close[i] ? 0 : open[i]>close[i] ? 1 : 4);
        }
      else if(close[i]<BufferT3Low[i])
        {
         BufferCandleO[i]=open[i];
         BufferCandleH[i]=high[i];
         BufferCandleL[i]=low[i];
         BufferCandleC[i]=close[i];
         BufferColors[i]=(open[i]>close[i] ? 2 : open[i]<close[i] ? 3 : 4);
        }
      else
        {
         BufferCandleO[i]=BufferCandleH[i]=BufferCandleL[i]=BufferCandleC[i]=EMPTY_VALUE;
         BufferColors[i]=4;
        }
     }

//--- return value of prev_calculated for next call
   return(rates_total);
  }
//+------------------------------------------------------------------+
