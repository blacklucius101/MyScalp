//+------------------------------------------------------------------+
//|                                 Candle_Retracement.mq5 |
//|                        Copyright 2023, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023, MetaQuotes Software Corp."
#property link      "https://www.mql5.com"
#property version   "1.00"
#property indicator_chart_window

input int InpRetracementPercentage = 50; // Retracement percentage

//--- indicator buffers
double HighRetBuffer[];
double LowRetBuffer[];

//+------------------------------------------------------------------+
//| Delete Objects                                                   |
//+------------------------------------------------------------------+
void DeleteIndicatorObjects()
  {
   ObjectDelete(0, "HighRetLabel");
   ObjectDelete(0, "LowRetLabel");
   ObjectDelete(0, "HighRetLine");
   ObjectDelete(0, "LowRetLine");
  }

//+------------------------------------------------------------------+
//| Delete Retracement Objects                                       |
//+------------------------------------------------------------------+
void DeleteRetracementObjects()
  {
   ObjectDelete(0, "HighRetLabel");
   ObjectDelete(0, "LowRetLabel");
   ObjectDelete(0, "HighRetLine");
   ObjectDelete(0, "LowRetLine");
  }

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
void OnInit()
  {
//--- indicator buffers mapping
   SetIndexBuffer(0, HighRetBuffer, INDICATOR_DATA);
   SetIndexBuffer(1, LowRetBuffer, INDICATOR_DATA);

//--- clean up existing objects
   DeleteIndicatorObjects();

//--- labels
   ObjectCreate(0, "HighRetLabel", OBJ_LABEL, 0, 0, 0);
   ObjectSetString(0, "HighRetLabel", OBJPROP_TEXT, "High ret:");
   ObjectSetInteger(0,"HighRetLabel",OBJPROP_CORNER,CORNER_LEFT_LOWER);
   ObjectSetInteger(0, "HighRetLabel", OBJPROP_COLOR, clrMagenta);
   ObjectSetInteger(0, "HighRetLabel", OBJPROP_XDISTANCE, 320);
   ObjectSetInteger(0, "HighRetLabel", OBJPROP_YDISTANCE, 55);

   ObjectCreate(0, "LowRetLabel", OBJ_LABEL, 0, 0, 0);
   ObjectSetString(0, "LowRetLabel", OBJPROP_TEXT, "Low ret:");
   ObjectSetInteger(0,"LowRetLabel",OBJPROP_CORNER,CORNER_LEFT_LOWER);
   ObjectSetInteger(0, "LowRetLabel", OBJPROP_COLOR, clrAqua);
   ObjectSetInteger(0, "LowRetLabel", OBJPROP_XDISTANCE, 320);
   ObjectSetInteger(0, "LowRetLabel", OBJPROP_YDISTANCE, 40);

//--- create movable vertical line at the last closed candle (shift 1)
   string line_name = "IdentifiedCandleLine";
   if(ObjectFind(0, line_name) < 0)
     {
      // Get time of the last closed candle (shift 1)
      datetime last_closed_time = iTime(_Symbol, _Period, 1);
      ObjectCreate(0, line_name, OBJ_VLINE, 0, last_closed_time, 0);
      ObjectSetInteger(0, line_name, OBJPROP_COLOR, clrYellow);
      ObjectSetInteger(0, line_name, OBJPROP_STYLE, STYLE_DOT);
      ObjectSetInteger(0, line_name, OBJPROP_SELECTABLE, true);
      ObjectSetInteger(0, line_name, OBJPROP_SELECTED, true);
      ObjectSetInteger(0, line_name, OBJPROP_BACK, true);
     }
  }

//+------------------------------------------------------------------+
//| Custom indicator deinitialization function                       |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//--- clean up all objects created by the indicator
   DeleteIndicatorObjects();
   ObjectDelete(0, "IdentifiedCandleLine");
  }

//+------------------------------------------------------------------+
//| Update Retracement                                               |
//+------------------------------------------------------------------+
void UpdateRetracement()
  {
   datetime time[];
   double open[], high[], low[], close[];
   long tick_volume[], volume[];
   int spread[];

   CopyTime(_Symbol, _Period, 0, Bars(_Symbol, _Period), time);
   CopyHigh(_Symbol, _Period, 0, Bars(_Symbol, _Period), high);
   CopyLow(_Symbol, _Period, 0, Bars(_Symbol, _Period), low);
   CopyClose(_Symbol, _Period, 0, Bars(_Symbol, _Period), close);

   string line_name = "IdentifiedCandleLine";
   datetime line_time = (datetime)ObjectGetInteger(0, line_name, OBJPROP_TIME);

   int identified_candle_index = -1;
   for(int i = Bars(_Symbol, _Period) - 1; i >= 0; i--)
     {
      if(time[i] == line_time)
        {
         identified_candle_index = i;
         break;
        }
     }

   if(identified_candle_index < 0)
     {
      ObjectSetString(0, "HighRetLabel", OBJPROP_TEXT, "High ret: 0.00%");
      ObjectSetString(0, "LowRetLabel", OBJPROP_TEXT, "Low ret: 0.00%");
      ObjectSetInteger(0, "HighRetLine", OBJPROP_COLOR, clrNONE);
      ObjectSetInteger(0, "LowRetLine", OBJPROP_COLOR, clrNONE);
      return;
     }

   int i = Bars(_Symbol, _Period) - 1;

   double identified_high = high[identified_candle_index];
   double identified_low = low[identified_candle_index];
   double identified_range = identified_high - identified_low;

   double current_price = close[i];

   double high_ret = 0;
   double low_ret = 0;

   if(identified_range > 0)
     {
      high_ret = ((identified_high - current_price) / identified_range) * 100;
      low_ret = ((current_price - identified_low) / identified_range) * 100;
     }

   ObjectSetString(0, "HighRetLabel", OBJPROP_TEXT, "High ret: " + DoubleToString(high_ret, 2) + "%");
   ObjectSetString(0, "LowRetLabel", OBJPROP_TEXT, "Low ret: " + DoubleToString(low_ret, 2) + "%");

   DrawRetracementLines(identified_candle_index, identified_high, identified_low);
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
   UpdateRetracement();
   return(rates_total);
  }

//+------------------------------------------------------------------+
//| ChartEvent function                                              |
//+------------------------------------------------------------------+
void OnChartEvent(const int id,
                  const long &lparam,
                  const double &dparam,
                  const string &sparam)
  {
//--- check if the event is a move of a graphical object
   if(id == CHARTEVENT_OBJECT_DRAG)
     {
      //--- check if the moved object is our vertical line
      if(sparam == "IdentifiedCandleLine")
        {
         //--- update the retracement lines
         UpdateRetracement();
        }
     }
  }
//+------------------------------------------------------------------+
//| Draw Retracement Lines                                           |
//+------------------------------------------------------------------+
void DrawRetracementLines(int identified_candle_index, double identified_high, double identified_low)
  {
   string high_line_name = "HighRetLine";
   string low_line_name = "LowRetLine";

   double high_level = identified_high - (identified_high - identified_low) * (InpRetracementPercentage / 100.0);
   double low_level = identified_low + (identified_high - identified_low) * (InpRetracementPercentage / 100.0);

   datetime start_time = iTime(_Symbol, _Period, identified_candle_index);
   datetime end_time = iTime(_Symbol, _Period, 0);

   // High line
   if(ObjectFind(0, high_line_name) < 0)
     {
      ObjectCreate(0, high_line_name, OBJ_TREND, 0, start_time, high_level, end_time, high_level);
      ObjectSetInteger(0, high_line_name, OBJPROP_WIDTH, 1);
      ObjectSetInteger(0, high_line_name, OBJPROP_STYLE, STYLE_DOT);
      ObjectSetInteger(0, high_line_name, OBJPROP_RAY_RIGHT, false);
      ObjectSetInteger(0, high_line_name, OBJPROP_SELECTABLE, false);
     }
   ObjectSetInteger(0, high_line_name, OBJPROP_COLOR, clrMagenta);
   ObjectSetInteger(0, high_line_name, OBJPROP_TIME, 0, start_time);
   ObjectSetDouble(0, high_line_name, OBJPROP_PRICE, 0, high_level);
   ObjectSetInteger(0, high_line_name, OBJPROP_TIME, 1, end_time);
   ObjectSetDouble(0, high_line_name, OBJPROP_PRICE, 1, high_level);

   // Low line
   if(ObjectFind(0, low_line_name) < 0)
     {
      ObjectCreate(0, low_line_name, OBJ_TREND, 0, start_time, low_level, end_time, low_level);
      ObjectSetInteger(0, low_line_name, OBJPROP_WIDTH, 1);
      ObjectSetInteger(0, low_line_name, OBJPROP_STYLE, STYLE_DOT);
      ObjectSetInteger(0, low_line_name, OBJPROP_RAY_RIGHT, false);
      ObjectSetInteger(0, low_line_name, OBJPROP_SELECTABLE, false);
     }
   ObjectSetInteger(0, low_line_name, OBJPROP_COLOR, clrAqua);
   ObjectSetInteger(0, low_line_name, OBJPROP_TIME, 0, start_time);
   ObjectSetDouble(0, low_line_name, OBJPROP_PRICE, 0, low_level);
   ObjectSetInteger(0, low_line_name, OBJPROP_TIME, 1, end_time);
   ObjectSetDouble(0, low_line_name, OBJPROP_PRICE, 1, low_level);
  }
//+------------------------------------------------------------------+
