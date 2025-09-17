//+------------------------------------------------------------------+
//|                                         M15_Interval_Lines.mq5 |
//|                        Copyright 2025, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, MetaQuotes Software Corp."
#property link      "https://www.mql5.com"
#property version   "1.00"
#property indicator_chart_window

//--- input parameters
input datetime      input_date   = 0;          // Select a date (0 = current day)
input color         line_color   = clrDodgerBlue; // Line color
input ENUM_LINE_STYLE line_style = STYLE_DASH;   // Line style

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
  {
//--- Timeframe validation
   if(Period() >= PERIOD_M15)
     {
      Alert("This indicator only works on timeframes lower than M15. Please change the timeframe.");
      return(INIT_FAILED);
     }

//--- Get the target date
   MqlDateTime date_struct;
   datetime target_date;

   if(input_date == 0) // User wants the current day
     {
      TimeCurrent(date_struct);
     }
   else // User has specified a date
     {
      TimeToStruct(input_date, date_struct);
     }

//--- Calculate the beginning of the day (00:00)
   date_struct.hour=0;
   date_struct.min=0;
   date_struct.sec=0;
   target_date = StructToTime(date_struct);

//--- Draw the vertical lines for each M15 interval
   for(int i = 0; i < 96; i++) // 24 hours * 4 intervals/hour = 96 intervals
     {
      datetime line_time = target_date + i * 15 * 60; // 15 minutes * 60 seconds
      string   obj_name  = "M15_Line_" + (string)line_time;

      //--- Create vertical line
      ObjectCreate(0, obj_name, OBJ_VLINE, 0, line_time, 0);
      ObjectSetInteger(0, obj_name, OBJPROP_COLOR, line_color);
      ObjectSetInteger(0, obj_name, OBJPROP_STYLE, line_style);
      ObjectSetInteger(0, obj_name, OBJPROP_WIDTH, 1);
      ObjectSetInteger(0, obj_name, OBJPROP_BACK, true);
     }
   ChartRedraw();
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
//--- The indicator should not react to new ticks
   return(rates_total);
  }
//+------------------------------------------------------------------+
//| Indicator deinitialization function                              |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//--- Delete all objects created by this indicator
   ObjectsDeleteAll(0, "M15_Line_");
  }
//+------------------------------------------------------------------+
