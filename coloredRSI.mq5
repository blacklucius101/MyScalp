//+------------------------------------------------------------------+
//|                                                          coloredRSI.mq5 |
//|                             Copyright 2000-2025, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright   "Copyright 2000-2025, MetaQuotes Ltd."
#property link        "https://www.mql5.com"
#property description "Relative Strength Index with Slope Color Change"
//--- indicator settings
#property indicator_separate_window
#property indicator_minimum 0
#property indicator_maximum 100
#property indicator_level1 30
#property indicator_level2 70
#property indicator_buffers 5
#property indicator_plots   2
// #property indicator_color1  clrDodgerBlue
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrGreen // Color for upward slope
#property indicator_label1  "RSI Up"

#property indicator_type2   DRAW_LINE
#property indicator_color2  clrRed   // Color for downward slope
#property indicator_label2  "RSI Down"
//--- input parameters
input int InpPeriodRSI=14; // Period
//--- indicator buffers
double    ExtRSIUpBuffer[];   // Buffer for upward slope RSI line
double    ExtRSIDownBuffer[]; // Buffer for downward slope RSI line
double    ExtRSIBuffer[];
double    ExtPosBuffer[];
double    ExtNegBuffer[];

int       ExtPeriodRSI;
//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
void OnInit()
  {
//--- check for input
   if(InpPeriodRSI<1)
     {
      ExtPeriodRSI=14;
      PrintFormat("Incorrect value for input variable InpPeriodRSI = %d. Indicator will use value %d for calculations.",
                  InpPeriodRSI,ExtPeriodRSI);
     }
   else
      ExtPeriodRSI=InpPeriodRSI;

//--- indicator buffers mapping
   SetIndexBuffer(0, ExtRSIUpBuffer, INDICATOR_DATA);       // Up slope RSI line
   PlotIndexSetString(0, PLOT_LABEL, "RSI Up");
   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, ExtPeriodRSI);
   PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   // PlotIndexSetInteger(0, PLOT_LINE_STYLE, STYLE_SOLID); // Optional: ensure style
   // PlotIndexSetInteger(0, PLOT_LINE_WIDTH, 1);         // Optional: ensure width

   SetIndexBuffer(1, ExtRSIDownBuffer, INDICATOR_DATA);     // Down slope RSI line
   PlotIndexSetString(1, PLOT_LABEL, "RSI Down");
   PlotIndexSetInteger(1, PLOT_DRAW_BEGIN, ExtPeriodRSI);
   PlotIndexSetDouble(1, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   // PlotIndexSetInteger(1, PLOT_LINE_STYLE, STYLE_SOLID); // Optional: ensure style
   // PlotIndexSetInteger(1, PLOT_LINE_WIDTH, 1);         // Optional: ensure width

   SetIndexBuffer(2, ExtRSIBuffer, INDICATOR_CALCULATIONS); // Original RSI calculation for logic
   SetIndexBuffer(3, ExtPosBuffer, INDICATOR_CALCULATIONS);
   SetIndexBuffer(4, ExtNegBuffer, INDICATOR_CALCULATIONS);

//--- set accuracy
   IndicatorSetInteger(INDICATOR_DIGITS,2);
//--- name for DataWindow and indicator subwindow label
   IndicatorSetString(INDICATOR_SHORTNAME,"RSI Slope Color("+string(ExtPeriodRSI)+")");
  }
//+------------------------------------------------------------------+
//| Relative Strength Index                                          |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const int begin,
                const double &price[])
  {
   if(rates_total<=ExtPeriodRSI)
      return(0);
//--- preliminary calculations
   int pos=prev_calculated-1;
   if(pos<=ExtPeriodRSI)
     {
      double sum_pos=0.0;
      double sum_neg=0.0;
      //--- first RSIPeriod values of the indicator are not calculated
      // Initialize all buffers for the pre-calculation period including ExtPeriodRSI
      for(int k=0; k<=ExtPeriodRSI; k++) // Use k to avoid conflict with loop variable i later
        {
         ExtRSIBuffer[k]=0.0; // Or some other appropriate initial value
         ExtPosBuffer[k]=0.0;
         ExtNegBuffer[k]=0.0;
         ExtRSIUpBuffer[k] = EMPTY_VALUE;
         ExtRSIDownBuffer[k] = EMPTY_VALUE;
        }
      // Continue with sum calculation from bar 1 up to ExtPeriodRSI
      for(int k=1; k<=ExtPeriodRSI; k++) // Use k
        {
         double diff_price=price[k]-price[k-1]; // Renamed to avoid conflict
         sum_pos+=(diff_price>0?diff_price:0);
         sum_neg+=(diff_price<0?-diff_price:0);
        }
      //--- calculate first visible value
      ExtPosBuffer[ExtPeriodRSI]=sum_pos/ExtPeriodRSI;
      ExtNegBuffer[ExtPeriodRSI]=sum_neg/ExtPeriodRSI;
      if(ExtNegBuffer[ExtPeriodRSI]!=0.0)
         ExtRSIBuffer[ExtPeriodRSI]=100.0-(100.0/(1.0+ExtPosBuffer[ExtPeriodRSI]/ExtNegBuffer[ExtPeriodRSI]));
      else
        {
         if(ExtPosBuffer[ExtPeriodRSI]!=0.0)
            ExtRSIBuffer[ExtPeriodRSI]=100.0;
         else
            ExtRSIBuffer[ExtPeriodRSI]=50.0;
        }
      
      // Default the very first calculated RSI point to Green
      ExtRSIUpBuffer[ExtPeriodRSI] = ExtRSIBuffer[ExtPeriodRSI];
      ExtRSIDownBuffer[ExtPeriodRSI] = EMPTY_VALUE;

      //--- prepare the position value for main calculation
      pos=ExtPeriodRSI+1;
     }
//--- the main loop of calculations
   // rates_total can change dynamically, so we check it in the loop condition
   for(int i=pos; i<rates_total && !IsStopped(); i++)
     {
      // Calculate base RSI value for current bar i
      double diff_price=price[i]-price[i-1]; // Renamed to avoid conflict
      ExtPosBuffer[i]=(ExtPosBuffer[i-1]*(ExtPeriodRSI-1)+(diff_price>0.0?diff_price:0.0))/ExtPeriodRSI;
      ExtNegBuffer[i]=(ExtNegBuffer[i-1]*(ExtPeriodRSI-1)+(diff_price<0.0?-diff_price:0.0))/ExtPeriodRSI;
      if(ExtNegBuffer[i]!=0.0)
         ExtRSIBuffer[i]=100.0-100.0/(1+ExtPosBuffer[i]/ExtNegBuffer[i]);
      else
        {
         if(ExtPosBuffer[i]!=0.0)
            ExtRSIBuffer[i]=100.0;
         else
            ExtRSIBuffer[i]=50.0;
        }

      // Initialize color buffers for the current bar i
      ExtRSIUpBuffer[i] = EMPTY_VALUE;
      ExtRSIDownBuffer[i] = EMPTY_VALUE;

      double rsi_current = ExtRSIBuffer[i];
      double rsi_previous = ExtRSIBuffer[i-1]; // This is safe because loop starts at ExtPeriodRSI+1

      // Determine current slope direction
      int current_slope_direction = 0; // 0 for FLAT, 1 for UP, -1 for DOWN
      if(rsi_current > rsi_previous) current_slope_direction = 1;
      else if(rsi_current < rsi_previous) current_slope_direction = -1;

      // Determine previous slope direction
      int previous_slope_direction = 0; // 0 for FLAT/UNDEFINED, 1 for UP, -1 for DOWN
      if (i-1 > 0) // Need at least two previous points (i-1 and i-2)
      {
        // Check if i-1 is not the first calculated point (ExtPeriodRSI)
        // If i-1 is ExtPeriodRSI, there's no ExtPeriodRSI-1 for comparison in ExtRSIBuffer in the same way.
        // The point ExtRSIBuffer[ExtPeriodRSI-1] would be 0.0 or uninitialized for slope purposes.
        // So, if i-1 == ExtPeriodRSI, previous_slope_direction remains 0 (FLAT/UNDEFINED)
        if ( (i-1) > ExtPeriodRSI ) // Ensure ExtRSIBuffer[i-2] is a calculated RSI value
        {
            double rsi_previous_2 = ExtRSIBuffer[i-2];
            if(rsi_previous > rsi_previous_2) previous_slope_direction = 1;
            else if(rsi_previous < rsi_previous_2) previous_slope_direction = -1;
        }
        // else: i-1 is ExtPeriodRSI. previous_slope_direction is already 0.
      }
      // else: i-1 is 0 (not possible as loop starts at ExtPeriodRSI+1) or i-1 is ExtPeriodRSI.
      // If i-1 is ExtPeriodRSI, previous_slope_direction is 0.

      // --- Apply coloring logic ---

      if (current_slope_direction == 1) // Current slope is UP
      {
          ExtRSIUpBuffer[i] = rsi_current;
          if (previous_slope_direction == -1) // Valley: Was DOWN, now UP
          {
              ExtRSIDownBuffer[i-1] = rsi_previous; // End previous RED segment
              ExtRSIUpBuffer[i-1] = rsi_previous;   // Start new GREEN segment from same point
          }
          else if (previous_slope_direction == 0) // Was FLAT, now UP
          {
              if (ExtRSIDownBuffer[i-1] != EMPTY_VALUE) // Flat segment was RED
              {
                  ExtRSIDownBuffer[i-1] = rsi_previous; // End RED flat segment
                  ExtRSIUpBuffer[i-1] = rsi_previous;   // Start GREEN segment
              }
              else // Flat segment was GREEN or UNCOLORED (first point after ExtPeriodRSI)
              {
                  ExtRSIUpBuffer[i-1] = rsi_previous; // Continue/start GREEN
              }
          }
          else // Was UP, continues UP
          {
               ExtRSIUpBuffer[i-1] = rsi_previous; // Ensure previous point is on green line
          }
      }
      else if (current_slope_direction == -1) // Current slope is DOWN
      {
          ExtRSIDownBuffer[i] = rsi_current;
          if (previous_slope_direction == 1) // Peak: Was UP, now DOWN
          {
              ExtRSIUpBuffer[i-1] = rsi_previous;   // End previous GREEN segment
              ExtRSIDownBuffer[i-1] = rsi_previous; // Start new RED segment from same point
          }
          else if (previous_slope_direction == 0) // Was FLAT, now DOWN
          {
              if (ExtRSIUpBuffer[i-1] != EMPTY_VALUE) // Flat segment was GREEN
              {
                  ExtRSIUpBuffer[i-1] = rsi_previous; // End GREEN flat segment
                  ExtRSIDownBuffer[i-1] = rsi_previous; // Start RED segment
              }
              else // Flat segment was RED or UNCOLORED
              {
                  ExtRSIDownBuffer[i-1] = rsi_previous; // Continue/start RED
              }
          }
          else // Was DOWN, continues DOWN
          {
              ExtRSIDownBuffer[i-1] = rsi_previous; // Ensure previous point is on red line
          }
      }
      else // Current slope is FLAT (current_slope_direction == 0)
      {
          // Continue the color of the segment at i-1
          // Check ExtRSIUpBuffer[i-1] and ExtRSIDownBuffer[i-1] which would have been set by previous iteration's logic
          if (ExtRSIUpBuffer[i-1] != EMPTY_VALUE) // If previous segment was UP or FLAT-UP
          {
              ExtRSIUpBuffer[i] = rsi_current;
              // ExtRSIUpBuffer[i-1] = rsi_previous; // Already set by previous iteration logic
          }
          else if (ExtRSIDownBuffer[i-1] != EMPTY_VALUE) // If previous segment was DOWN or FLAT-DOWN
          {
              ExtRSIDownBuffer[i] = rsi_current;
              // ExtRSIDownBuffer[i-1] = rsi_previous; // Already set by previous iteration logic
          }
          else // Previous segment was uncolored or also flat and uncolored.
          {
              // This case happens if i-1 is ExtPeriodRSI.
              // ExtRSIUpBuffer[ExtPeriodRSI] was set to ExtRSIBuffer[ExtPeriodRSI].
              // ExtRSIDownBuffer[ExtPeriodRSI] was EMPTY_VALUE.
              // So, we continue with UP.
              ExtRSIUpBuffer[i] = rsi_current;
              // Ensure previous point is also colored if it's the start of this flat segment
              if(ExtRSIUpBuffer[i-1] == EMPTY_VALUE && ExtRSIDownBuffer[i-1] == EMPTY_VALUE) {
                ExtRSIUpBuffer[i-1] = rsi_previous;
              }
          }
      }
     }
//--- OnCalculate done. Return new prev_calculated.
   return(rates_total);
  }
//+------------------------------------------------------------------+
