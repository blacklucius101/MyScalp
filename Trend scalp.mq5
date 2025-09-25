//------------------------------------------------------------------
#property copyright   "© mladen, 2018"
#property link        "mladenfx@gmail.com"
#property version     "1.00"
#property description "Trend scalp"
//------------------------------------------------------------------
#property indicator_separate_window
#property indicator_buffers 5
#property indicator_plots   3
#property indicator_label1  "Filling"
#property indicator_type1   DRAW_FILLING
#property indicator_color1  clrDeepSkyBlue,clrSandyBrown
#property indicator_label2  "Trend scalp levels"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrDarkGray
#property indicator_width2  0
#property indicator_type3   DRAW_COLOR_LINE
#property indicator_color3  clrDarkGray,clrDodgerBlue,clrOrangeRed
#property indicator_width3  2
//
//---
//
enum enT3Type
  {
   t3_tillson, // Tim Tillson way of calculation
   t3_fulksmat // Fulks/Matulich way of calculation
  };
//
//--
//
input int      inpPeriod        = 15;            // Period
input int      inpT3Period      = 5;             // T3 period
input double   inpT3Hot         = 0.7;           // T3 hot 
input enT3Type inpT3Type        = t3_fulksmat;   // T3 type
input double   inpLevels        = 100;           // Levels at +- (nnn)

double val[],valc[],lev[],fup[],fdn[];
//+------------------------------------------------------------------+ 
//| Custom indicator initialization function                         | 
//+------------------------------------------------------------------+ 
int OnInit()
  {
   SetIndexBuffer(0,fup,INDICATOR_DATA);     
   SetIndexBuffer(1,fdn,INDICATOR_DATA);
   SetIndexBuffer(2,lev,INDICATOR_DATA); 
   SetIndexBuffer(3,val,INDICATOR_DATA); 
   SetIndexBuffer(4,valc,INDICATOR_COLOR_INDEX);
   IndicatorSetString(INDICATOR_SHORTNAME,"Trend scalp ("+(string)inpPeriod+","+(string)inpT3Period+")");
   return(INIT_SUCCEEDED);
  }
void OnDeinit(const int reason) { return; }
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
   if(Bars(_Symbol,_Period)<rates_total) return(prev_calculated);
   //
   //---
   //
   int i=(int)MathMax(prev_calculated-1,0); for(; i<rates_total && !_StopFlag; i++)
     {
         int _start  = MathMax(i-inpPeriod,0);
         double HighestHighRecent = high[i];
         double HighestHighOlder  = high[ArrayMaximum(high,_start,inpPeriod)];
         double LowestLowRecent   = low [i];
         double LowestLowOlder    = low [ArrayMinimum(low ,_start,inpPeriod)];
      
         double BuyPower  = HighestHighRecent - LowestLowOlder;
         double SellPower = HighestHighOlder  - LowestLowRecent;
         double ttf = (BuyPower+SellPower!=0) ? 100*(BuyPower-SellPower)/(0.5*(BuyPower+SellPower)) : 0;
         val[i] = iT3(ttf,inpT3Period,inpT3Hot,inpT3Type==t3_tillson,i,rates_total);     
         valc[i] = (val[i]>inpLevels) ? 1 : (val[i]<-inpLevels) ? 2 : 0;
         lev[i]  = (val[i]>0) ? inpLevels : (val[i]<0) ? -inpLevels : 0;
         fup[i]  =  val[i];
         fdn[i]  = (val[i]>0) ? MathMin(val[i],inpLevels) : MathMax(val[i],-inpLevels);
     }
   return(i);
  }

//+------------------------------------------------------------------+
//| Custom functions                                                 |
//+------------------------------------------------------------------+
#define _t3Instances     1
#define _t3InstancesSize 6
double workT3[][_t3Instances*_t3InstancesSize];
double workT3Coeffs[][6];
#define _period 0
#define _c1     1
#define _c2     2
#define _c3     3
#define _c4     4
#define _alpha  5
//
//
//
//
//

double iT3(double price,double period,double hot,bool original,int r,int bars,int instanceNo=0)
  {
   if(ArrayRange(workT3,0)!=bars) ArrayResize(workT3,bars);
   if(ArrayRange(workT3Coeffs,0)<(instanceNo+1)) ArrayResize(workT3Coeffs,instanceNo+1);
   if(workT3Coeffs[instanceNo][_period]!=period)
     {
      workT3Coeffs[instanceNo][_period]=period;
      workT3Coeffs[instanceNo][_c1] = -hot*hot*hot;
      workT3Coeffs[instanceNo][_c2] = 3*hot*hot+3*hot*hot*hot;
      workT3Coeffs[instanceNo][_c3] = -6*hot*hot-3*hot-3*hot*hot*hot;
      workT3Coeffs[instanceNo][_c4] = 1+3*hot+hot*hot*hot+3*hot*hot;
      if(original)
         workT3Coeffs[instanceNo][_alpha] = 2.0/(1.0 + period);
      else workT3Coeffs[instanceNo][_alpha] = 2.0/(2.0 + (period-1.0)/2.0);
     }

//
//
//
//
//

   int buffer=instanceNo*_t3InstancesSize; for(int k=0; k<6; k++) workT3[r][k+buffer]=(r>0) ? workT3[r-1][k+buffer]: price;
   if(r>0 && period>1)
     {
      workT3[r][0+buffer] = workT3[r-1][0+buffer]+workT3Coeffs[instanceNo][_alpha]*(price              -workT3[r-1][0+buffer]);
      workT3[r][1+buffer] = workT3[r-1][1+buffer]+workT3Coeffs[instanceNo][_alpha]*(workT3[r][0+buffer]-workT3[r-1][1+buffer]);
      workT3[r][2+buffer] = workT3[r-1][2+buffer]+workT3Coeffs[instanceNo][_alpha]*(workT3[r][1+buffer]-workT3[r-1][2+buffer]);
      workT3[r][3+buffer] = workT3[r-1][3+buffer]+workT3Coeffs[instanceNo][_alpha]*(workT3[r][2+buffer]-workT3[r-1][3+buffer]);
      workT3[r][4+buffer] = workT3[r-1][4+buffer]+workT3Coeffs[instanceNo][_alpha]*(workT3[r][3+buffer]-workT3[r-1][4+buffer]);
      workT3[r][5+buffer] = workT3[r-1][5+buffer]+workT3Coeffs[instanceNo][_alpha]*(workT3[r][4+buffer]-workT3[r-1][5+buffer]);
     }
   return(workT3Coeffs[instanceNo][_c1]*workT3[r][5+buffer] +
          workT3Coeffs[instanceNo][_c2]*workT3[r][4+buffer]+
          workT3Coeffs[instanceNo][_c3]*workT3[r][3+buffer]+
          workT3Coeffs[instanceNo][_c4]*workT3[r][2+buffer]);
  }
//+------------------------------------------------------------------+
