//+------------------------------------------------------------------+
//|                                    MACD-2-Cloud-Cross-Arrows.mq5 |
//|                                                      @mobilebass |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property description "Plots arrows on main chart when MACD cloud changes color (MACD crosses Signal)"
#property indicator_chart_window
#property indicator_buffers 2
#property indicator_plots   2

//+-----------------------------------+
//|  Indicator input parameters       |
//+-----------------------------------+
input uint FastMACD     = 12;   // Fast EMA Period
input uint SlowMACD     = 26;   // Slow EMA Period
input uint SignalMACD   = 9;    // Signal SMA Period
input ENUM_APPLIED_PRICE PriceMACD = PRICE_CLOSE;  // Applied Price
input color UpArrowColor = clrGreen;  // Up Arrow Color
input color DnArrowColor = clrRed;    // Down Arrow Color
input int ArrowSize = 1;              // Arrow Size
/*
STYLE_SOLID: Solid line.
STYLE_DOT: Dotted line.
STYLE_DASH: Dashed line.
STYLE_DASHDOT: Dash-dot line.
STYLE_DASHDOTDOT: Dash-dot-dot line.
*/
input ENUM_LINE_STYLE LineStyle = STYLE_DOT;

//--- buffers for arrow plotting
double UpArrowBuffer[];
double DnArrowBuffer[];

//--- handles and variables
int MACD_Handle;
double MACDLine[], SignalLine[];
int min_rates_total;
int    ArrowShiftPixels = 10;  // Arrow shift in pixels
datetime LastCrossTime = 0;

//--- state machine variables
enum MACD_STATE {MACD_ABOVE_SIGNAL, MACD_BELOW_SIGNAL, MACD_UNKNOWN};
MACD_STATE currentState = MACD_UNKNOWN;
MACD_STATE previousState = MACD_UNKNOWN;

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
{
   //--- set minimum bars needed
   min_rates_total = int(SignalMACD + MathMax(FastMACD, SlowMACD));
   
   //--- get MACD handle
   MACD_Handle = iMACD(NULL, 0, FastMACD, SlowMACD, SignalMACD, PriceMACD);
   if(MACD_Handle == INVALID_HANDLE)
   {
      Print("Failed to get the handle of iMACD");
      return(INIT_FAILED);
   }
   
   //--- set arrow buffers
   SetIndexBuffer(0, UpArrowBuffer, INDICATOR_DATA);
   SetIndexBuffer(1, DnArrowBuffer, INDICATOR_DATA);
   
   //--- set as series
   ArraySetAsSeries(UpArrowBuffer, true);
   ArraySetAsSeries(DnArrowBuffer, true);

   // Set arrow shifts
   PlotIndexSetInteger(1, PLOT_ARROW_SHIFT, -ArrowShiftPixels); // Low arrows shift DOWN (below price)
   PlotIndexSetInteger(0, PLOT_ARROW_SHIFT, ArrowShiftPixels);  // High arrows shift UP (above price)
   
   //--- set plot properties for up arrows
   PlotIndexSetInteger(0, PLOT_DRAW_TYPE, DRAW_ARROW);
   PlotIndexSetInteger(0, PLOT_ARROW, 233); // Up arrow code
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, UpArrowColor);
   PlotIndexSetInteger(0, PLOT_LINE_WIDTH, ArrowSize);
   PlotIndexSetString(0, PLOT_LABEL, "Bullish Cross");
   
   //--- set plot properties for down arrows
   PlotIndexSetInteger(1, PLOT_DRAW_TYPE, DRAW_ARROW);
   PlotIndexSetInteger(1, PLOT_ARROW, 234); // Down arrow code
   PlotIndexSetInteger(1, PLOT_LINE_COLOR, DnArrowColor);
   PlotIndexSetInteger(1, PLOT_LINE_WIDTH, ArrowSize);
   PlotIndexSetString(1, PLOT_LABEL, "Bearish Cross");
   
   //--- set empty value for arrows
   PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetDouble(1, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   
   //--- set indicator short name
   IndicatorSetString(INDICATOR_SHORTNAME, "MACD Cloud Cross Arrows (State Machine)");
   
   //--- initialize state machine
   currentState = MACD_UNKNOWN;
   previousState = MACD_UNKNOWN;
   
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
   //--- check if we have enough data
   if(BarsCalculated(MACD_Handle) < rates_total || rates_total < min_rates_total)
      return(0);
   
   //--- get MACD and Signal line data
   if(CopyBuffer(MACD_Handle, MAIN_LINE, 0, rates_total, MACDLine) <= 0) return(0);
   if(CopyBuffer(MACD_Handle, SIGNAL_LINE, 0, rates_total, SignalLine) <= 0) return(0);
   
   //--- set as series
   ArraySetAsSeries(MACDLine, true);
   ArraySetAsSeries(SignalLine, true);
   ArraySetAsSeries(time, true);
   ArraySetAsSeries(high, true);
   ArraySetAsSeries(low, true);
   
   //--- calculate start position
   int limit = (prev_calculated <= 0) ? rates_total - 1 : prev_calculated - 1;
   
   //--- main loop using state machine approach
   for(int i = limit; i >= 0 && !IsStopped(); i--)
   {
      UpArrowBuffer[i] = EMPTY_VALUE;
      DnArrowBuffer[i] = EMPTY_VALUE;
      
      //--- determine current state
      if(MACDLine[i] > SignalLine[i])
         currentState = MACD_ABOVE_SIGNAL;
      else
         currentState = MACD_BELOW_SIGNAL;
      
      //--- detect state change (crossover)
      if(i < rates_total - 1 && currentState != previousState)
      {
         if(currentState == MACD_ABOVE_SIGNAL && previousState == MACD_BELOW_SIGNAL)
         {
            // Bullish crossover
            if(time[i] != LastCrossTime)
            {
               UpArrowBuffer[i] = low[i];
               LastCrossTime = time[i];
               string lineName = "BullishCross_" + IntegerToString(i);
               ObjectCreate(0, lineName, OBJ_VLINE, 0, time[i], 0);
               ObjectSetInteger(0, lineName, OBJPROP_COLOR, UpArrowColor);
               ObjectSetInteger(0, lineName, OBJPROP_RAY_RIGHT, true);
               ObjectSetInteger(0, lineName, OBJPROP_WIDTH, 1);
               ObjectSetInteger(0, lineName, OBJPROP_STYLE, LineStyle);
            }
         }
         else if(currentState == MACD_BELOW_SIGNAL && previousState == MACD_ABOVE_SIGNAL)
         {
            // Bearish crossover
            if(time[i] != LastCrossTime)
            {
               DnArrowBuffer[i] = high[i];
               LastCrossTime = time[i];
               string lineName = "BearishCross_" + IntegerToString(i);
               ObjectCreate(0, lineName, OBJ_VLINE, 0, time[i], 0);
               ObjectSetInteger(0, lineName, OBJPROP_COLOR, DnArrowColor);
               ObjectSetInteger(0, lineName, OBJPROP_RAY_RIGHT, true);
               ObjectSetInteger(0, lineName, OBJPROP_WIDTH, 1);
               ObjectSetInteger(0, lineName, OBJPROP_STYLE, LineStyle);
            }
         }
      }
      
      //--- update previous state for next iteration
      previousState = currentState;
   }
   
   return(rates_total);
}

//+------------------------------------------------------------------+
//| Deinitialization function                                        |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    // Get the total number of objects on the current chart
    int totalObjects = ObjectsTotal(0);
    
    // Loop through all objects on the chart and delete those created by the indicator
    for(int i = totalObjects - 1; i >= 0; i--)
    {
        // Get the name of the object at index i
        string objectName = ObjectName(0, i, 0, 0);
        
        // Check if the object name starts with "BullishCross_" or "BearishCross_"
        if(StringFind(objectName, "BullishCross_") == 0 || StringFind(objectName, "BearishCross_") == 0)
        {
            // Delete the object
            ObjectDelete(0, objectName);
        }
    }
    
    // Optionally, clear the comment field
    Comment("");
}
