//+------------------------------------------------------------------+
//|                                         M15_Interval_Lines_AutoUpdate.mq5 |
//|                        Copyright 2025, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, MetaQuotes Software Corp."
#property link      "https://www.mql5.com"
#property version   "1.01"
#property indicator_chart_window

//--- input parameters
input datetime         input_date   = 0;             // Select a date (0 = current day)
input color            line_color   = clrDodgerBlue; // Line color
input ENUM_LINE_STYLE line_style   = STYLE_DOT;      // Line style

//--- internal tracking
datetime last_processed_date = 0; // Keeps track of last drawn date

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
  {
   //--- Timeframe check
   if(Period() >= PERIOD_M15)
     {
      Alert("This indicator only works on timeframes lower than M15. Please change the timeframe.");
      return(INIT_FAILED);
     }

   //--- Determine the base date
   datetime base_date = (input_date == 0) ? TimeCurrent() : input_date;

   //--- Draw the lines
   DrawM15Lines(base_date);

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Function to draw M15 interval lines                              |
//+------------------------------------------------------------------+
void DrawM15Lines(datetime base_date)
  {
   //--- Delete existing lines
   ObjectsDeleteAll(0, "M15_Line_");

   //--- Get 00:00 of the day
   MqlDateTime dt;
   TimeToStruct(base_date, dt);
   dt.hour = 0;
   dt.min = 0;
   dt.sec = 0;
   datetime start_of_day = StructToTime(dt);

   //--- Draw 96 lines (96 x 15min = 24h)
   for(int i = 0; i < 96; i++)
     {
      datetime line_time = start_of_day + i * 15 * 60;
      string obj_name = "M15_Line_" + (string)line_time;

      ObjectCreate(0, obj_name, OBJ_VLINE, 0, line_time, 0);
      ObjectSetInteger(0, obj_name, OBJPROP_COLOR, line_color);
      ObjectSetInteger(0, obj_name, OBJPROP_STYLE, line_style);
      ObjectSetInteger(0, obj_name, OBJPROP_WIDTH, 1);
      ObjectSetInteger(0, obj_name, OBJPROP_BACK, true);
     }

   last_processed_date = start_of_day;
   ChartRedraw();
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
   //--- Only auto-update if using current day
   if(input_date != 0)
      return(rates_total);

   //--- Check if the day has changed
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   dt.hour = 0;
   dt.min = 0;
   dt.sec = 0;
   datetime today_start = StructToTime(dt);

   if(today_start != last_processed_date)
     {
      DrawM15Lines(TimeCurrent());
     }

   return(rates_total);
  }

//+------------------------------------------------------------------+
//| Custom indicator deinitialization function                       |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   //--- Remove lines
   ObjectsDeleteAll(0, "M15_Line_");
  }
//+------------------------------------------------------------------+
