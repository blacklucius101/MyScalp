//+------------------------------------------------------------------+
//|                                                    Long-MACD.mq5 |
//|                             Copyright 2000-2025, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright   "Copyright 2000-2025, MetaQuotes Ltd."
#property link        "https://www.mql5.com"
#property description "MACD with color change on slope and signal line status label, toggle between line/histogram"
#include <MovingAverages.mqh>

//--- indicator settings
#property indicator_separate_window
#property indicator_buffers 5
#property indicator_plots   2
#property indicator_color1  clrDarkGray,clrDeepSkyBlue,clrDarkOrange,clrGreen,clrLime,clrOrange,clrCrimson
#property indicator_width1  2
#property indicator_color2  clrRed
#property indicator_width2  1
#property indicator_label2  "Signal"

//--- input parameters
input int                InpFastEMA=12;               // Fast EMA period
input int                InpSlowEMA=26;               // Slow EMA period
input int                InpSignalSMA=9;              // Signal SMA period
input ENUM_APPLIED_PRICE InpAppliedPrice=PRICE_CLOSE; // Applied price
input bool               ShowAsHistogram=false;       // Show as histogram
input int                LabelShiftX = 150;           // Label X position
input int                LabelShiftY = 15;            // Label Y position
input string             LabelFont = "Arial";         // Label font
input int                LabelFontSize = 10;          // Label font size
input bool               LabelBackground = true;      // Show label background
input color              LabelBgColor = clrGray;      // Label background color

//--- indicator buffers
double MACDLineBuffer[];
double ColorBuffer[];
double ExtSignalBuffer[];
double ExtFastMaBuffer[];
double ExtSlowMaBuffer[];

int    ExtFastMaHandle;
int    ExtSlowMaHandle;

//--- For label
int    indicatorWindow = -1;      // Will store our subwindow index
datetime lastUpdateTime = 0;

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
void OnInit()
  {
//--- Set plot properties based on ShowAsHistogram input
   if(ShowAsHistogram)
     {
      PlotIndexSetInteger(0,PLOT_DRAW_TYPE,DRAW_COLOR_HISTOGRAM);
      PlotIndexSetString(0,PLOT_LABEL,"MACD Histogram");
     }
   else
     {
      PlotIndexSetInteger(0,PLOT_DRAW_TYPE,DRAW_COLOR_LINE);
      PlotIndexSetString(0,PLOT_LABEL,"MACD Line");
     }

//--- indicator buffers mapping
   SetIndexBuffer(0,MACDLineBuffer,INDICATOR_DATA);
   SetIndexBuffer(1,ColorBuffer,INDICATOR_COLOR_INDEX);
   SetIndexBuffer(2,ExtSignalBuffer,INDICATOR_DATA);
   SetIndexBuffer(3,ExtFastMaBuffer,INDICATOR_CALCULATIONS);
   SetIndexBuffer(4,ExtSlowMaBuffer,INDICATOR_CALCULATIONS);
   
//--- sets first bar from what index will be drawn
   PlotIndexSetInteger(0,PLOT_DRAW_BEGIN,InpSlowEMA-1); // For MACD Line/Histogram
   PlotIndexSetInteger(1,PLOT_DRAW_BEGIN, (InpSlowEMA-1)+(InpSignalSMA-1)); // For Signal Line
   PlotIndexSetInteger(1,PLOT_DRAW_TYPE,DRAW_LINE);
   
//--- name for indicator subwindow label
   string short_name=StringFormat("MACD(%d,%d,%d) %s",InpFastEMA,InpSlowEMA,InpSignalSMA,ShowAsHistogram?"Histogram":"Line");
   IndicatorSetString(INDICATOR_SHORTNAME,short_name);
   
//--- get MA handles
   ExtFastMaHandle=iMA(NULL,0,InpFastEMA,0,MODE_EMA,InpAppliedPrice);
   ExtSlowMaHandle=iMA(NULL,0,InpSlowEMA,0,MODE_EMA,InpAppliedPrice);
   
//--- get our indicator subwindow index
   indicatorWindow = ChartWindowFind(0, short_name);
   if(indicatorWindow < 0)
     {
      Print("Failed to find indicator subwindow!");
      return;
     }

//--- Create label in the indicator subwindow
   CreateOrUpdateLabel();
  }

//+------------------------------------------------------------------+
//| Creates or updates the status label                              |
//+------------------------------------------------------------------+
void CreateOrUpdateLabel()
  {
//--- delete the label if it already exists
   if(ObjectFind(0, "MACD_Signal_Label") >= 0)
      ObjectDelete(0, "MACD_Signal_Label");

//--- create the label in our indicator subwindow
   if(!ObjectCreate(0, "MACD_Signal_Label", OBJ_LABEL, indicatorWindow, 0, 0))
     {
      Print("Failed to create status label! Error code: ", GetLastError());
      return;
     }

//--- set label properties
   ObjectSetInteger(0, "MACD_Signal_Label", OBJPROP_CORNER, CORNER_RIGHT_UPPER);
   ObjectSetInteger(0, "MACD_Signal_Label", OBJPROP_XDISTANCE, LabelShiftX);
   ObjectSetInteger(0, "MACD_Signal_Label", OBJPROP_YDISTANCE, LabelShiftY);
   ObjectSetInteger(0, "MACD_Signal_Label", OBJPROP_FONTSIZE, LabelFontSize);
   ObjectSetString(0, "MACD_Signal_Label", OBJPROP_FONT, LabelFont);
   ObjectSetString(0, "MACD_Signal_Label", OBJPROP_TEXT, "MACD: --");
   ObjectSetInteger(0, "MACD_Signal_Label", OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, "MACD_Signal_Label", OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, "MACD_Signal_Label", OBJPROP_HIDDEN, true);

//--- set background properties if enabled
   if(LabelBackground)
     {
      ObjectSetInteger(0, "MACD_Signal_Label", OBJPROP_BACK, true);
      ObjectSetInteger(0, "MACD_Signal_Label", OBJPROP_BGCOLOR, LabelBgColor);
      ObjectSetInteger(0, "MACD_Signal_Label", OBJPROP_BORDER_TYPE, BORDER_FLAT);
      ObjectSetInteger(0, "MACD_Signal_Label", OBJPROP_WIDTH, 1);
     }
  }

//+------------------------------------------------------------------+
//| Moving Averages Convergence/Divergence                           |
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
   if(rates_total < InpSlowEMA)
      return(0);

   const int macdDrawBeginIndex = InpSlowEMA-1; 
   const int signalLineStartIndex = macdDrawBeginIndex + InpSignalSMA-1; 

//--- not all data may be calculated
   int calculated=BarsCalculated(ExtFastMaHandle);
   if(calculated<rates_total)
     {
      Print("Not all data of ExtFastMaHandle is calculated (",calculated," bars). Error ",GetLastError());
      return(0);
     }
   calculated=BarsCalculated(ExtSlowMaHandle);
   if(calculated<rates_total)
     {
      Print("Not all data of ExtSlowMaHandle is calculated (",calculated," bars). Error ",GetLastError());
      return(0);
     }
//--- we can copy not all data
   int to_copy;
   if(prev_calculated>rates_total || prev_calculated<0)
      to_copy=rates_total;
   else
     {
      to_copy=rates_total-prev_calculated;
      if(prev_calculated>0)
         to_copy++;
     }
//--- get Fast EMA buffer
   if(IsStopped()) // checking for stop flag
      return(0);
   if(CopyBuffer(ExtFastMaHandle,0,0,to_copy,ExtFastMaBuffer)<=0)
     {
      Print("Getting fast EMA is failed! Error ",GetLastError());
      return(0);
     }
//--- get SlowSMA buffer
   if(IsStopped()) // checking for stop flag
      return(0);
   if(CopyBuffer(ExtSlowMaHandle,0,0,to_copy,ExtSlowMaBuffer)<=0)
     {
      Print("Getting slow SMA is failed! Error ",GetLastError());
      return(0);
     }
//---
   int start;
   if(prev_calculated==0)
      start=0;
   else
      start=prev_calculated-1;

//--- calculate MACD, Signal, and Color
   for(int i=start; i<rates_total && !IsStopped(); i++)
     {
      MACDLineBuffer[i]=ExtFastMaBuffer[i]-ExtSlowMaBuffer[i];

      // Calculate ExtSignalBuffer[i] using SMA on MACDLineBuffer
      if (i >= macdDrawBeginIndex + InpSignalSMA - 1)
        {
         double sum = 0;
         for (int k = 0; k < InpSignalSMA; k++)
           {
            sum += MACDLineBuffer[i-k];
           }
         ExtSignalBuffer[i] = sum / InpSignalSMA;
        }
      else
        {
         ExtSignalBuffer[i] = EMPTY_VALUE;
        }

      // Color calculation logic
      if (i < macdDrawBeginIndex) 
        {
         // Points before PLOT_DRAW_BEGIN for MACD line
        }
      else if (i == macdDrawBeginIndex)
        {
         ColorBuffer[i] = 0; // Neutral color (clrDarkGray)
        }
      else
        {
         if (i < signalLineStartIndex)
           {
            if (MACDLineBuffer[i] > MACDLineBuffer[i-1])
               ColorBuffer[i] = 1; // Basic Up (clrDeepSkyBlue)
            else if (MACDLineBuffer[i] < MACDLineBuffer[i-1])
               ColorBuffer[i] = 2; // Basic Down (clrDarkOrange)
            else
               ColorBuffer[i] = ColorBuffer[i-1];
           }
         else
           {
            if (MACDLineBuffer[i] > MACDLineBuffer[i-1])
              {
               if (MACDLineBuffer[i] > ExtSignalBuffer[i])
                  ColorBuffer[i] = 3; // MACD Up & Above Signal (clrGreen)
               else
                  ColorBuffer[i] = 4; // MACD Up & Below Signal (clrLime)
              }
            else if (MACDLineBuffer[i] < MACDLineBuffer[i-1])
              {
               if (MACDLineBuffer[i] > ExtSignalBuffer[i])
                  ColorBuffer[i] = 5; // MACD Down & Above Signal (clrOrange)
               else
                  ColorBuffer[i] = 6; // MACD Down & Below Signal (clrCrimson)
              }
            else
              {
               ColorBuffer[i] = ColorBuffer[i-1]; 
              }
           }
        } 
     }
     
//--- Update label
   if(TimeCurrent() > lastUpdateTime || prev_calculated == 0)
   {
      int lastBar = rates_total-1;
      if(lastBar >= 0 && lastBar < ArraySize(MACDLineBuffer) && lastBar < ArraySize(ExtSignalBuffer))
      {
         string text;
         color textColor;
         
         if(MACDLineBuffer[lastBar] > ExtSignalBuffer[lastBar])
         {
            text = "MACD: ABOVE SIGNAL";
            textColor = clrLime;
         }
         else if(MACDLineBuffer[lastBar] < ExtSignalBuffer[lastBar])
         {
            text = "MACD: BELOW SIGNAL";
            textColor = clrRed;
         }
         else
         {
            text = "MACD: AT SIGNAL";
            textColor = clrYellow;
         }
         
         if(ObjectFind(0, "MACD_Signal_Label") >= 0)
           {
            ObjectSetString(0, "MACD_Signal_Label", OBJPROP_TEXT, text);
            ObjectSetInteger(0, "MACD_Signal_Label", OBJPROP_COLOR, textColor);
            lastUpdateTime = TimeCurrent();
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
//--- Delete label
   ObjectDelete(0, "MACD_Signal_Label");
  }
//+------------------------------------------------------------------+
