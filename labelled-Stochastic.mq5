//+------------------------------------------------------------------+
//|                                          labelled-Stochastic.mq5 |
//|                             Copyright 2000-2025, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2000-2025, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
//--- indicator settings
#property indicator_separate_window
#property indicator_buffers 4
#property indicator_plots   2
#property indicator_type1   DRAW_LINE
#property indicator_type2   DRAW_LINE
#property indicator_color1  clrLightSeaGreen
#property indicator_color2  clrRed
#property indicator_style2  STYLE_DOT
//--- input parameters
input int InpKPeriod=5;               // K period
input int InpDPeriod=3;               // D period
input int InpSlowing=1;               // Slowing
input color NeutralColor = clrLightGray;  // Neutral label color
input color OverboughtColor = clrRed;     // Overbought label color
input color OversoldColor = clrBlue;      // Oversold label color
input int LabelShiftX = 200;              // Horizontal shift for label
input int LabelShiftY = 15;               // Vertical shift for label
input ENUM_BASE_CORNER LabelCorner = CORNER_RIGHT_UPPER; // Label corner
input string LabelFont = "Arial";         // Label font
input int LabelFontSize = 10;             // Label font size
input bool LabelBackground = true;        // Show label background
input color LabelBgColor = clrWhiteSmoke; // Label background color

//--- indicator buffers
double    ExtMainBuffer[];
double    ExtSignalBuffer[];
double    ExtHighesBuffer[];
double    ExtLowesBuffer[];

//--- for label object
string statusLabel = "Stoch_Status_Label";
int indicatorWindow = -1; // Will store our subwindow index

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
void OnInit()
  {
//--- indicator buffers mapping
   SetIndexBuffer(0,ExtMainBuffer,INDICATOR_DATA);
   SetIndexBuffer(1,ExtSignalBuffer,INDICATOR_DATA);
   SetIndexBuffer(2,ExtHighesBuffer,INDICATOR_CALCULATIONS);
   SetIndexBuffer(3,ExtLowesBuffer,INDICATOR_CALCULATIONS);

//--- set accuracy
   IndicatorSetInteger(INDICATOR_DIGITS,2);

//--- set levels
   IndicatorSetInteger(INDICATOR_LEVELS,2);
   IndicatorSetDouble(INDICATOR_LEVELVALUE,0,20);
   IndicatorSetDouble(INDICATOR_LEVELVALUE,1,80);

//--- set maximum and minimum for subwindow
   IndicatorSetDouble(INDICATOR_MINIMUM,0);
   IndicatorSetDouble(INDICATOR_MAXIMUM,100);

//--- name for DataWindow and indicator subwindow label
   string short_name=StringFormat("Stoch(%d,%d,%d)",InpKPeriod,InpDPeriod,InpSlowing);
   IndicatorSetString(INDICATOR_SHORTNAME,short_name);
   PlotIndexSetString(0,PLOT_LABEL,"Main");
   PlotIndexSetString(1,PLOT_LABEL,"Signal");

//--- sets first bar from what index will be drawn
   PlotIndexSetInteger(0,PLOT_DRAW_BEGIN,InpKPeriod+InpSlowing-2);
   PlotIndexSetInteger(1,PLOT_DRAW_BEGIN,InpKPeriod+InpDPeriod);

//--- get our indicator subwindow index
   indicatorWindow = ChartWindowFind(0, short_name);
   if(indicatorWindow < 0)
     {
      Print("Failed to find indicator subwindow!");
      return;
     }

//--- create or update status label object
   CreateOrUpdateLabel();
  }

//+------------------------------------------------------------------+
//| Creates or updates the status label                              |
//+------------------------------------------------------------------+
void CreateOrUpdateLabel()
  {
//--- delete the label if it already exists
   if(ObjectFind(0, statusLabel) >= 0)
      ObjectDelete(0, statusLabel);

//--- create the label in our indicator subwindow
   if(!ObjectCreate(0, statusLabel, OBJ_LABEL, indicatorWindow, 0, 0))
     {
      Print("Failed to create status label! Error code: ", GetLastError());
      return;
     }

//--- set label properties
   ObjectSetInteger(0, statusLabel, OBJPROP_CORNER, LabelCorner);
   ObjectSetInteger(0, statusLabel, OBJPROP_XDISTANCE, LabelShiftX);
   ObjectSetInteger(0, statusLabel, OBJPROP_YDISTANCE, LabelShiftY);
   ObjectSetInteger(0, statusLabel, OBJPROP_FONTSIZE, LabelFontSize);
   ObjectSetString(0, statusLabel, OBJPROP_FONT, LabelFont);
   ObjectSetString(0, statusLabel, OBJPROP_TEXT, "Initializing...");
   ObjectSetInteger(0, statusLabel, OBJPROP_COLOR, NeutralColor);
   ObjectSetInteger(0, statusLabel, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, statusLabel, OBJPROP_HIDDEN, true);

//--- set background properties if enabled
   if(LabelBackground)
     {
      ObjectSetInteger(0, statusLabel, OBJPROP_BACK, true);
      ObjectSetInteger(0, statusLabel, OBJPROP_BGCOLOR, LabelBgColor);
      ObjectSetInteger(0, statusLabel, OBJPROP_BORDER_TYPE, BORDER_FLAT);
      ObjectSetInteger(0, statusLabel, OBJPROP_WIDTH, 1);
     }
  }

//+------------------------------------------------------------------+
//| Stochastic Oscillator                                            |
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
   int i,k,start;

//--- check for bars count
   if(rates_total<=InpKPeriod+InpDPeriod+InpSlowing)
      return(0);

//---
   start=InpKPeriod-1;
   if(start+1<prev_calculated)
      start=prev_calculated-2;
   else
     {
      for(i=0; i<start; i++)
        {
         ExtLowesBuffer[i]=0.0;
         ExtHighesBuffer[i]=0.0;
        }
     }

//--- calculate HighesBuffer[] and ExtHighesBuffer[]
   for(i=start; i<rates_total && !IsStopped(); i++)
     {
      double dmin=1000000.0;
      double dmax=-1000000.0;
      for(k=i-InpKPeriod+1; k<=i; k++)
        {
         if(dmin>low[k])
            dmin=low[k];
         if(dmax<high[k])
            dmax=high[k];
        }
      ExtLowesBuffer[i]=dmin;
      ExtHighesBuffer[i]=dmax;
     }

//--- %K
   start=InpKPeriod-1+InpSlowing-1;
   if(start+1<prev_calculated)
      start=prev_calculated-2;
   else
     {
      for(i=0; i<start; i++)
         ExtMainBuffer[i]=0.0;
     }

//--- main cycle
   for(i=start; i<rates_total && !IsStopped(); i++)
     {
      double sum_low=0.0;
      double sum_high=0.0;
      for(k=(i-InpSlowing+1); k<=i; k++)
        {
         sum_low +=(close[k]-ExtLowesBuffer[k]);
         sum_high+=(ExtHighesBuffer[k]-ExtLowesBuffer[k]);
        }
      if(sum_high==0.0)
         ExtMainBuffer[i]=100.0;
      else
         ExtMainBuffer[i]=sum_low/sum_high*100;
     }

//--- signal
   start=InpDPeriod-1;
   if(start+1<prev_calculated)
      start=prev_calculated-2;
   else
     {
      for(i=0; i<start; i++)
         ExtSignalBuffer[i]=0.0;
     }
   for(i=start; i<rates_total && !IsStopped(); i++)
     {
      double sum=0.0;
      for(k=0; k<InpDPeriod; k++)
         sum+=ExtMainBuffer[i-k];
      ExtSignalBuffer[i]=sum/InpDPeriod;
     }

//--- Update status label if we have enough data
   if(rates_total > 1 && indicatorWindow >= 0)
     {
      double currentSignal = ExtSignalBuffer[rates_total-1];
      string statusText;
      color statusColor;

      if(currentSignal > 80)
        {
         statusText = "OVERBOUGHT";
         statusColor = OverboughtColor;
        }
      else if(currentSignal < 20)
        {
         statusText = "OVERSOLD";
         statusColor = OversoldColor;
        }
      else
        {
         statusText = "NEUTRAL";
         statusColor = NeutralColor;
        }

      // Format the text with the current value
      string newText = StringFormat("%s (%.2f)", statusText, currentSignal);

      // Only update if something changed
      if(ObjectGetString(0, statusLabel, OBJPROP_TEXT) != newText)
        {
         ObjectSetString(0, statusLabel, OBJPROP_TEXT, newText);
         ObjectSetInteger(0, statusLabel, OBJPROP_COLOR, statusColor);
         ChartRedraw();
        }
     }

//--- OnCalculate done. Return new prev_calculated.
   return(rates_total);
  }

//+------------------------------------------------------------------+
//| Deinitialization function                                        |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//--- delete our graphical object
   ObjectDelete(0, statusLabel);
  }
//+------------------------------------------------------------------+
