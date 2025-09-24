//+------------------------------------------------------------------
#property copyright   "mladen"
#property link        "mladenfx@gmail.com"
#property description "RSI bands"
//+------------------------------------------------------------------
#property indicator_buffers 5
#property indicator_plots   5

#property indicator_label1  "Level 1"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrDarkGreen
#property indicator_style1  STYLE_SOLID  // Solid

#property indicator_label2  "Level 2"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrDarkGreen
#property indicator_style2  STYLE_DOT    // Dotted

#property indicator_label3  "Level 3"
#property indicator_type3   DRAW_LINE
#property indicator_color3  clrAqua
#property indicator_style3  STYLE_DOT    // Dotted

#property indicator_label4  "Level 4"
#property indicator_type4   DRAW_LINE
#property indicator_color4  clrMaroon
#property indicator_style4  STYLE_DOT    // Dotted

#property indicator_label5  "Level 5"
#property indicator_type5   DRAW_LINE
#property indicator_color5  clrMaroon
#property indicator_style5  STYLE_SOLID  // Solid
//--- input parameters
input int                inpRsiPeriod   = 14;          // RSI period
input ENUM_APPLIED_PRICE inpPrice       = PRICE_CLOSE; // Price
input double inpLevel1 = 70;   // Topmost (solid)
input double inpLevel2 = 60;   // Dotted
input double inpLevel3 = 50;   // Mid (dotted)
input double inpLevel4 = 40;   // Dotted
input double inpLevel5 = 30;   // Bottom (solid)
//--- buffers declarations
double val1[], val2[], val3[], val4[], val5[];
//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
  {
//--- indicator buffers mapping
   SetIndexBuffer(0, val1, INDICATOR_DATA); // Level 1
   SetIndexBuffer(1, val2, INDICATOR_DATA); // Level 2
   SetIndexBuffer(2, val3, INDICATOR_DATA); // Level 3
   SetIndexBuffer(3, val4, INDICATOR_DATA); // Level 4
   SetIndexBuffer(4, val5, INDICATOR_DATA); // Level 5
//---
   IndicatorSetString(INDICATOR_SHORTNAME,"RSI bands("+(string)inpRsiPeriod+")");
//---
   return (INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Custom indicator de-initialization function                      |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
  }
//+------------------------------------------------------------------+
//| Custom indicator iteration function                              |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,const int prev_calculated,const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
  {
   if(Bars(_Symbol,_Period)<rates_total) return(prev_calculated);
   int i = (int)MathMax(prev_calculated - 1, 1);
   for (; i < rates_total && !_StopFlag; i++)
   {
      double price = getPrice(inpPrice, open, close, high, low, i, rates_total);
      val1[i] = rsiBand(price, inpRsiPeriod, inpLevel1, i, rates_total, 0); // Solid
      val2[i] = rsiBand(price, inpRsiPeriod, inpLevel2, i, rates_total, 1); // Dot
      val3[i] = rsiBand(price, inpRsiPeriod, inpLevel3, i, rates_total, 2); // Dot
      val4[i] = rsiBand(price, inpRsiPeriod, inpLevel4, i, rates_total, 3); // Dot
      val5[i] = rsiBand(price, inpRsiPeriod, inpLevel5, i, rates_total, 4); // Solid
   }
   return (i);
  }
//+------------------------------------------------------------------+
//| custom functions                                                 |
//+------------------------------------------------------------------+
#define _rsiBandInstances 5
#define _rsiBandInstanceSize 4
double rsiBandWork[][_rsiBandInstances*_rsiBandInstanceSize];
#define _rsibPrice 0
#define _rsibPa    1
#define _rsibNa    2
#define _rsibValue 3
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double rsiBand(double price,int rsiPeriod,double targetLevel,int i,int bars,int instance=0)
  {
   if(ArrayRange(rsiBandWork,0)!=bars) ArrayResize(rsiBandWork,bars); instance*=_rsiBandInstanceSize;

   rsiBandWork[i][instance+_rsibPrice]=price;
   double pprice = (i>0) ? rsiBandWork[i-1][instance+_rsibPrice] : price;
   double cprice =         rsiBandWork[i]  [instance+_rsibPrice];
   double diff   = cprice-pprice;
   double w      = (diff > 0) ?  diff : 0;
   double s      = (diff < 0) ? -diff : 0;
   double p      = (i>0) ? rsiBandWork[i-1][instance+_rsibPa]    : 0;
   double n      = (i>0) ? rsiBandWork[i-1][instance+_rsibNa]    : 0;
   double prev   = (i>0) ? rsiBandWork[i-1][instance+_rsibValue] : 0;
   double match  = 0.00;

   if(prev>pprice)
      match=pprice+p-p*rsiPeriod -((n*rsiPeriod)-n)*targetLevel/(targetLevel-100.00);
   else  match=pprice-n-p+n*rsiPeriod+p*rsiPeriod+(100.00*p)/targetLevel -(100.00*p*rsiPeriod)/targetLevel;

   rsiBandWork[i][instance+_rsibPa]    = ((rsiPeriod-1)*p+w)/rsiPeriod;
   rsiBandWork[i][instance+_rsibNa]    = ((rsiPeriod-1)*n+s)/rsiPeriod;
   rsiBandWork[i][instance+_rsibValue] = match;
   return(match);
  }
//
//---
//
double getPrice(ENUM_APPLIED_PRICE tprice,const double &open[],const double &close[],const double &high[],const double &low[],int i,int _bars)
  {
   switch(tprice)
     {
      case PRICE_CLOSE:     return(close[i]);
      case PRICE_OPEN:      return(open[i]);
      case PRICE_HIGH:      return(high[i]);
      case PRICE_LOW:       return(low[i]);
      case PRICE_MEDIAN:    return((high[i]+low[i])/2.0);
      case PRICE_TYPICAL:   return((high[i]+low[i]+close[i])/3.0);
      case PRICE_WEIGHTED:  return((high[i]+low[i]+close[i]+close[i])/4.0);
     }
   return(0);
  }
//+------------------------------------------------------------------+
