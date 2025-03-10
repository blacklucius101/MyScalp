//+------------------------------------------------------------------+
//|                   EA with Integrated UI Panel                    |
//| This EA trades based on TSI, Stochastic and ATR with dynamic     |
//| trailing stops. A UI panel is provided to update key settings on   |
//| the fly.                                                         |
//+------------------------------------------------------------------+
#include <Trade\Trade.mqh>
CTrade trade;

//--------------------- Indicator & Static Parameters --------------------
// TSI & Stochastic parameters (unchanged as inputs)
input int    InpTSIPeriod1      = 25;   // TSI smoothing period ("s" period)
input int    InpTSIPeriod2      = 13;   // TSI momentum smoothing period ("r" period)
input int    InpTSISignalPeriod = 5;    // Used for signal smoothing

enum enTSIColorMode { tsiHigh, tsiMid, tsiLow };
input enTSIColorMode inpTSIColorMode = tsiMid; // User selectable: High, Mid, or Low sensitivity

input int    InpStochKPeriod    = 5;    // Stochastic %K period
input int    InpStochDPeriod    = 3;    // Stochastic %D period
input int    InpStochSlowing    = 3;    // Stochastic slowing

input int    InpATRPeriod       = 14;   // ATR period

//--------------------- Modifiable Trading Parameters --------------------
// These variables are modifiable via the UI panel (do not use the "input" keyword)
double ATR_Multiplier     = 2.0;    // ATR multiplier for SL/TP
double LotSize            = 0.03;   // Trade volume
double CustomTakeProfit   = 0.0;    // Custom TP in price units (0 = not specified)
bool   GoldRush           = false;  // GoldRush mode toggle
double TrailingStop       = 0.0;   // Trailing stop distance (in price units)
double TrailingStep       = 0.0;    // Minimum step size to modify the SL (in price units)
bool   TradeActionEnabled = true;   // When false, EA does not open trades
int    MaxTrades          = 0;      // Maximum number of trades (0 = no limit)

//-------------------------- Additional EA Parameter ---------------------
input int WarmUpBars         = 5;      // EA will not trade until this many bars have formed

//-------------------------- Global Variables ---------------------------
int stochHandle = INVALID_HANDLE;
int atrHandle   = INVALID_HANDLE;

// TSI state tracking globals
int lastTSIColor = 0;
double lastSignal = 0.0;
int    prevTSIColorMid = 0;

// Trade management
int tradesExecuted = 0;
datetime lastClosedTimeGlobal = 0;

// Structure for virtual SL/TP lines
struct TradeLevels
{
   ulong ticket;
   string slLineName;
   string tpLineName;
};
TradeLevels tradeLevelsArray[];

//-------------------------- UI Panel Code ------------------------------
// The panel uses a background rectangle and, for each parameter row, a label
// on the right (aligned with other labels) and an input control on the left.
// For the booleans, we now use a label and a toggle button.

bool panelCreated = false;

void CreateUIPanel()
{
   if(panelCreated)
      return;
      
   // Create background panel using a rectangle label.
   if(!ObjectCreate(0, "EA_UIPanel", OBJ_RECTANGLE_LABEL, 0, 0, 0))
   {
      Print("Failed to create UI panel background.");
      return;
   }
   ObjectSetInteger(0, "EA_UIPanel", OBJPROP_CORNER, CORNER_RIGHT_UPPER);
   ObjectSetInteger(0, "EA_UIPanel", OBJPROP_XDISTANCE, 330);
   ObjectSetInteger(0, "EA_UIPanel", OBJPROP_YDISTANCE, 50);
   ObjectSetInteger(0, "EA_UIPanel", OBJPROP_XSIZE, (long)260);
   ObjectSetInteger(0, "EA_UIPanel", OBJPROP_YSIZE, (long)180);
   ObjectSetInteger(0, "EA_UIPanel", OBJPROP_COLOR, clrDarkGray);
   ObjectSetInteger(0, "EA_UIPanel", OBJPROP_STYLE, STYLE_SOLID);
   
   // ATR Multiplier
   ObjectCreate(0, "Label_ATR_Multiplier", OBJ_LABEL, 0, 0, 0);
   ObjectSetString(0, "Label_ATR_Multiplier", OBJPROP_TEXT, "ATR Multiplier:");
   ObjectSetInteger(0, "Label_ATR_Multiplier", OBJPROP_CORNER, CORNER_RIGHT_UPPER);
   ObjectSetInteger(0, "Label_ATR_Multiplier", OBJPROP_XDISTANCE, 250);
   ObjectSetInteger(0, "Label_ATR_Multiplier", OBJPROP_YDISTANCE, 60);
   ObjectSetInteger(0, "Label_ATR_Multiplier", OBJPROP_COLOR, clrBlack);
   
   ObjectCreate(0, "Edit_ATR_Multiplier", OBJ_EDIT, 0, 0, 0);
   ObjectSetString(0, "Edit_ATR_Multiplier", OBJPROP_TEXT, DoubleToString(ATR_Multiplier,2));
   ObjectSetInteger(0, "Edit_ATR_Multiplier", OBJPROP_CORNER, CORNER_RIGHT_UPPER);
   ObjectSetInteger(0, "Edit_ATR_Multiplier", OBJPROP_XDISTANCE, 320);
   ObjectSetInteger(0, "Edit_ATR_Multiplier", OBJPROP_YDISTANCE, 60);
   
   // Lot Size
   ObjectCreate(0, "Label_LotSize", OBJ_LABEL, 0, 0, 0);
   ObjectSetString(0, "Label_LotSize", OBJPROP_TEXT, "Lot Size:");
   ObjectSetInteger(0, "Label_LotSize", OBJPROP_CORNER, CORNER_RIGHT_UPPER);
   ObjectSetInteger(0, "Label_LotSize", OBJPROP_XDISTANCE, 250);
   ObjectSetInteger(0, "Label_LotSize", OBJPROP_YDISTANCE, 80);
   ObjectSetInteger(0, "Label_LotSize", OBJPROP_COLOR, clrBlack);
   
   ObjectCreate(0, "Edit_LotSize", OBJ_EDIT, 0, 0, 0);
   ObjectSetString(0, "Edit_LotSize", OBJPROP_TEXT, DoubleToString(LotSize,2));
   ObjectSetInteger(0, "Edit_LotSize", OBJPROP_CORNER, CORNER_RIGHT_UPPER);
   ObjectSetInteger(0, "Edit_LotSize", OBJPROP_XDISTANCE, 320);
   ObjectSetInteger(0, "Edit_LotSize", OBJPROP_YDISTANCE, 80);
   
   // Custom Take Profit
   ObjectCreate(0, "Label_CustomTakeProfit", OBJ_LABEL, 0, 0, 0);
   ObjectSetString(0, "Label_CustomTakeProfit", OBJPROP_TEXT, "Custom TP:");
   ObjectSetInteger(0, "Label_CustomTakeProfit", OBJPROP_CORNER, CORNER_RIGHT_UPPER);
   ObjectSetInteger(0, "Label_CustomTakeProfit", OBJPROP_XDISTANCE, 250);
   ObjectSetInteger(0, "Label_CustomTakeProfit", OBJPROP_YDISTANCE, 100);
   ObjectSetInteger(0, "Label_CustomTakeProfit", OBJPROP_COLOR, clrBlack);
   
   ObjectCreate(0, "Edit_CustomTakeProfit", OBJ_EDIT, 0, 0, 0);
   ObjectSetString(0, "Edit_CustomTakeProfit", OBJPROP_TEXT, DoubleToString(CustomTakeProfit,2));
   ObjectSetInteger(0, "Edit_CustomTakeProfit", OBJPROP_CORNER, CORNER_RIGHT_UPPER);
   ObjectSetInteger(0, "Edit_CustomTakeProfit", OBJPROP_XDISTANCE, 320);
   ObjectSetInteger(0, "Edit_CustomTakeProfit", OBJPROP_YDISTANCE, 100);
   
   // GoldRush mode row:
   // Label aligned with other labels (right column)
   ObjectCreate(0, "Label_GoldRush", OBJ_LABEL, 0, 0, 0);
   ObjectSetString(0, "Label_GoldRush", OBJPROP_TEXT, "GoldRush mode:");
   ObjectSetInteger(0, "Label_GoldRush", OBJPROP_CORNER, CORNER_RIGHT_UPPER);
   ObjectSetInteger(0, "Label_GoldRush", OBJPROP_XDISTANCE, 250);
   ObjectSetInteger(0, "Label_GoldRush", OBJPROP_YDISTANCE, 120);
   ObjectSetInteger(0, "Label_GoldRush", OBJPROP_COLOR, clrBlack);
   // Toggle button aligned with other controls (left column)
   ObjectCreate(0, "Button_GoldRush", OBJ_BUTTON, 0, 0, 0);
   ObjectSetString(0, "Button_GoldRush", OBJPROP_TEXT, GoldRush ? "ON" : "OFF");
   ObjectSetInteger(0, "Button_GoldRush", OBJPROP_CORNER, CORNER_RIGHT_UPPER);
   ObjectSetInteger(0, "Button_GoldRush", OBJPROP_XDISTANCE, 320);
   ObjectSetInteger(0, "Button_GoldRush", OBJPROP_YDISTANCE, 120);
   ObjectSetInteger(0, "Button_GoldRush", OBJPROP_XSIZE, 50);
   ObjectSetInteger(0, "Button_GoldRush", OBJPROP_YSIZE, 18);
   ObjectSetInteger(0, "Button_GoldRush", OBJPROP_COLOR, clrBlack);
   ObjectSetInteger(0, "Button_GoldRush", OBJPROP_FONTSIZE, 8);
   ObjectSetInteger(0, "Button_GoldRush", OBJPROP_BORDER_TYPE, BORDER_RAISED);
   ObjectSetInteger(0, "Button_GoldRush", OBJPROP_BORDER_COLOR, clrBlack);
   
   // Trade Action row:
   // Label aligned with other labels (right column)
   ObjectCreate(0, "Label_TradeActionEnabled", OBJ_LABEL, 0, 0, 0);
   ObjectSetString(0, "Label_TradeActionEnabled", OBJPROP_TEXT, "Trade Action:");
   ObjectSetInteger(0, "Label_TradeActionEnabled", OBJPROP_CORNER, CORNER_RIGHT_UPPER);
   ObjectSetInteger(0, "Label_TradeActionEnabled", OBJPROP_XDISTANCE, 250);
   ObjectSetInteger(0, "Label_TradeActionEnabled", OBJPROP_YDISTANCE, 180);
   ObjectSetInteger(0, "Label_TradeActionEnabled", OBJPROP_COLOR, clrBlack);
   // Toggle button aligned with other controls (left column)
   ObjectCreate(0, "Button_TradeActionEnabled", OBJ_BUTTON, 0, 0, 0);
   ObjectSetString(0, "Button_TradeActionEnabled", OBJPROP_TEXT, TradeActionEnabled ? "ON" : "OFF");
   ObjectSetInteger(0, "Button_TradeActionEnabled", OBJPROP_CORNER, CORNER_RIGHT_UPPER);
   ObjectSetInteger(0, "Button_TradeActionEnabled", OBJPROP_XDISTANCE, 320);
   ObjectSetInteger(0, "Button_TradeActionEnabled", OBJPROP_YDISTANCE, 180);
   ObjectSetInteger(0, "Button_TradeActionEnabled", OBJPROP_XSIZE, 50);
   ObjectSetInteger(0, "Button_TradeActionEnabled", OBJPROP_YSIZE, 18);
   ObjectSetInteger(0, "Button_TradeActionEnabled", OBJPROP_COLOR, clrBlack);
   ObjectSetInteger(0, "Button_TradeActionEnabled", OBJPROP_FONTSIZE, 8);
   ObjectSetInteger(0, "Button_TradeActionEnabled", OBJPROP_BORDER_TYPE, BORDER_RAISED);
   ObjectSetInteger(0, "Button_TradeActionEnabled", OBJPROP_BORDER_COLOR, clrBlack);
   
   // Trailing Stop
   ObjectCreate(0, "Label_TrailingStop", OBJ_LABEL, 0, 0, 0);
   ObjectSetString(0, "Label_TrailingStop", OBJPROP_TEXT, "Trailing Stop:");
   ObjectSetInteger(0, "Label_TrailingStop", OBJPROP_CORNER, CORNER_RIGHT_UPPER);
   ObjectSetInteger(0, "Label_TrailingStop", OBJPROP_XDISTANCE, 250);
   ObjectSetInteger(0, "Label_TrailingStop", OBJPROP_YDISTANCE, 140);
   ObjectSetInteger(0, "Label_TrailingStop", OBJPROP_COLOR, clrBlack);
   
   ObjectCreate(0, "Edit_TrailingStop", OBJ_EDIT, 0, 0, 0);
   ObjectSetString(0, "Edit_TrailingStop", OBJPROP_TEXT, DoubleToString(TrailingStop,2));
   ObjectSetInteger(0, "Edit_TrailingStop", OBJPROP_CORNER, CORNER_RIGHT_UPPER);
   ObjectSetInteger(0, "Edit_TrailingStop", OBJPROP_XDISTANCE, 320);
   ObjectSetInteger(0, "Edit_TrailingStop", OBJPROP_YDISTANCE, 140);
   
   // Trailing Step
   ObjectCreate(0, "Label_TrailingStep", OBJ_LABEL, 0, 0, 0);
   ObjectSetString(0, "Label_TrailingStep", OBJPROP_TEXT, "Trailing Step:");
   ObjectSetInteger(0, "Label_TrailingStep", OBJPROP_CORNER, CORNER_RIGHT_UPPER);
   ObjectSetInteger(0, "Label_TrailingStep", OBJPROP_XDISTANCE, 250);
   ObjectSetInteger(0, "Label_TrailingStep", OBJPROP_YDISTANCE, 160);
   ObjectSetInteger(0, "Label_TrailingStep", OBJPROP_COLOR, clrBlack);
   
   ObjectCreate(0, "Edit_TrailingStep", OBJ_EDIT, 0, 0, 0);
   ObjectSetString(0, "Edit_TrailingStep", OBJPROP_TEXT, DoubleToString(TrailingStep,2));
   ObjectSetInteger(0, "Edit_TrailingStep", OBJPROP_CORNER, CORNER_RIGHT_UPPER);
   ObjectSetInteger(0, "Edit_TrailingStep", OBJPROP_XDISTANCE, 320);
   ObjectSetInteger(0, "Edit_TrailingStep", OBJPROP_YDISTANCE, 160);
   
   // Max Trades
   ObjectCreate(0, "Label_MaxTrades", OBJ_LABEL, 0, 0, 0);
   ObjectSetString(0, "Label_MaxTrades", OBJPROP_TEXT, "Max Trades:");
   ObjectSetInteger(0, "Label_MaxTrades", OBJPROP_CORNER, CORNER_RIGHT_UPPER);
   ObjectSetInteger(0, "Label_MaxTrades", OBJPROP_XDISTANCE, 250);
   ObjectSetInteger(0, "Label_MaxTrades", OBJPROP_YDISTANCE, 200);
   ObjectSetInteger(0, "Label_MaxTrades", OBJPROP_COLOR, clrBlack);
   
   ObjectCreate(0, "Edit_MaxTrades", OBJ_EDIT, 0, 0, 0);
   ObjectSetString(0, "Edit_MaxTrades", OBJPROP_TEXT, IntegerToString(MaxTrades));
   ObjectSetInteger(0, "Edit_MaxTrades", OBJPROP_CORNER, CORNER_RIGHT_UPPER);
   ObjectSetInteger(0, "Edit_MaxTrades", OBJPROP_XDISTANCE, 320);
   ObjectSetInteger(0, "Edit_MaxTrades", OBJPROP_YDISTANCE, 200);
   
   // Apply Settings button inside the panel
   ObjectCreate(0, "Button_ApplySettings", OBJ_BUTTON, 0, 0, 0);
   ObjectSetString(0, "Button_ApplySettings", OBJPROP_TEXT, "Apply Settings");
   ObjectSetInteger(0, "Button_ApplySettings", OBJPROP_CORNER, CORNER_RIGHT_UPPER);
   ObjectSetInteger(0, "Button_ApplySettings", OBJPROP_XDISTANCE, 150);
   ObjectSetInteger(0, "Button_ApplySettings", OBJPROP_YDISTANCE, 230);
   ObjectSetInteger(0, "Button_ApplySettings", OBJPROP_XSIZE, 80); // width in pixels
   ObjectSetInteger(0, "Button_ApplySettings", OBJPROP_YSIZE, 20); // height in pixels
   ObjectSetInteger(0, "Button_ApplySettings", OBJPROP_COLOR, clrBlack);
   ObjectSetInteger(0, "Button_ApplySettings", OBJPROP_FONTSIZE, 8);
   ObjectSetInteger(0, "Button_ApplySettings", OBJPROP_BORDER_TYPE, BORDER_RAISED);
   ObjectSetInteger(0, "Button_ApplySettings", OBJPROP_BORDER_COLOR, clrBlack);
   
   panelCreated = true;
}

// This function reads values from the UI panel (for the editable parameters) and updates the EA variables.
void UpdateParametersFromPanel()
{
    string s;
    
    s = ObjectGetString(0, "Edit_ATR_Multiplier", OBJPROP_TEXT);
    ATR_Multiplier = StringToDouble(s);
    
    s = ObjectGetString(0, "Edit_LotSize", OBJPROP_TEXT);
    LotSize = StringToDouble(s);
    
    s = ObjectGetString(0, "Edit_CustomTakeProfit", OBJPROP_TEXT);
    CustomTakeProfit = StringToDouble(s);
    
    s = ObjectGetString(0, "Edit_TrailingStop", OBJPROP_TEXT);
    TrailingStop = StringToDouble(s);
    
    s = ObjectGetString(0, "Edit_TrailingStep", OBJPROP_TEXT);
    TrailingStep = StringToDouble(s);
    
    s = ObjectGetString(0, "Edit_MaxTrades", OBJPROP_TEXT);
    MaxTrades = (int)StringToInteger(s);
    
    Print("EA settings updated via UI Panel");
}
//---------------------- End of UI Panel Code ---------------------------

//+------------------------------------------------------------------+
//| CheckClosedTrades: Remove virtual trade level lines for closed   |
//| trades from the chart                                            |
//+------------------------------------------------------------------+
void CheckClosedTrades()
{
   for(int i = (int)ArraySize(tradeLevelsArray) - 1; i >= 0; i--)
   {
      if(!PositionSelectByTicket(tradeLevelsArray[i].ticket))
      {
         ObjectDelete(0, tradeLevelsArray[i].slLineName);
         ObjectDelete(0, tradeLevelsArray[i].tpLineName);
         tradeLevelsArray[i] = tradeLevelsArray[(int)ArraySize(tradeLevelsArray) - 1];
         ArrayResize(tradeLevelsArray, (int)ArraySize(tradeLevelsArray) - 1);
      }
   }
}

//+------------------------------------------------------------------+
//| CalculateTSI: Compute TSI using recursive double-EMA method      |
//+------------------------------------------------------------------+
bool CalculateTSI(double &tsi_current, double &tsi_previous, int &color_current, int &color_previous)
{
   int barsToCopy = 100;
   double closes[];
   if(CopyClose(_Symbol, _Period, 1, barsToCopy, closes) <= 0)
   {
      Print("Failed to copy close prices for TSI");
      return(false);
   }
   ArraySetAsSeries(closes, false);
   
   double alpha1 = 2.0 / (InpTSIPeriod1 + 1);
   double alpha2 = 2.0 / (InpTSIPeriod2 + 1);
   
   int n = ArraySize(closes);
   if(n < 3) return(false);
   
   double diff[];
   ArrayResize(diff, n);
   diff[0] = 0;
   for(int i = 1; i < n; i++)
      diff[i] = closes[i] - closes[i-1];
      
   double ema1[], emaAbs1[], ema2[], emaAbs2[], tsi[];
   ArrayResize(ema1, n);
   ArrayResize(emaAbs1, n);
   ArrayResize(ema2, n);
   ArrayResize(emaAbs2, n);
   ArrayResize(tsi, n);
   
   ema1[1]    = diff[1];
   emaAbs1[1] = MathAbs(diff[1]);
   ema2[1]    = ema1[1];
   emaAbs2[1] = emaAbs1[1];
   tsi[1]     = (emaAbs2[1] != 0 ? 100 * (ema2[1] / emaAbs2[1]) : 0);
   
   for(int i = 2; i < n; i++)
   {
      ema1[i]    = ema1[i-1] + alpha1 * (diff[i] - ema1[i-1]);
      emaAbs1[i] = emaAbs1[i-1] + alpha1 * (MathAbs(diff[i]) - emaAbs1[i-1]);
      ema2[i]    = ema2[i-1] + alpha2 * (ema1[i] - ema2[i-1]);
      emaAbs2[i] = emaAbs2[i-1] + alpha2 * (emaAbs1[i] - emaAbs2[i-1]);
      tsi[i]     = (emaAbs2[i] != 0 ? 100 * (ema2[i] / emaAbs2[i]) : 0);
   }
   
   tsi_current  = tsi[n-1];
   tsi_previous = tsi[n-2];
   
   switch(inpTSIColorMode)
   {
      case tsiHigh:
      {
         if(tsi_current > tsi_previous)
            color_current = 1;
         else if(tsi_current < tsi_previous)
            color_current = 2;
         else
            color_current = lastTSIColor;
         if(n >= 3)
         {
            if(tsi[n-2] > tsi[n-3])
               color_previous = 1;
            else if(tsi[n-2] < tsi[n-3])
               color_previous = 2;
            else
               color_previous = lastTSIColor;
         }
         else
            color_previous = color_current;
      } break;
      
      case tsiMid:
      {
         double currentSignal;
         static bool firstSignal = true;
         if(firstSignal)
         {
            currentSignal = tsi_current;
            firstSignal = false;
         }
         else
         {
            double smoothing = (2.0 / (InpTSISignalPeriod > 1 ? InpTSISignalPeriod : 1));
            currentSignal = lastSignal + smoothing * (tsi_current - lastSignal);
         }
         if(tsi_current > currentSignal)
            color_current = 1;
         else if(tsi_current < currentSignal)
            color_current = 2;
         else
            color_current = lastTSIColor;
         color_previous = prevTSIColorMid;
         lastSignal = currentSignal;
         prevTSIColorMid = color_current;
      } break;
      
      case tsiLow:
      {
         if(tsi_current > 0)
            color_current = 1;
         else if(tsi_current < 0)
            color_current = 2;
         else
            color_current = lastTSIColor;
         if(n >= 3)
         {
            if(tsi[n-2] > 0)
               color_previous = 1;
            else if(tsi[n-2] < 0)
               color_previous = 2;
            else
               color_previous = lastTSIColor;
         }
         else
            color_previous = color_current;
      } break;
   }
   return(true);
}

//+------------------------------------------------------------------+
//| TrailPositions: Dynamically update stop loss for open positions    |
//+------------------------------------------------------------------+
void TrailPositions()
{
   double atrBuffer[3];
   if(CopyBuffer(atrHandle, 0, 1, 3, atrBuffer) <= 0) return;
   double currentATR = atrBuffer[0];
   
   double dynamicTS = (TrailingStop > 0.0) ? TrailingStop : ATR_Multiplier * currentATR;
   double dynamicTStep = (TrailingStep > 0.0) ? TrailingStep : (ATR_Multiplier * currentATR) / 2.0;
   
   int totalPositions = (int)PositionsTotal();
   for(int i = totalPositions - 1; i >= 0; i--)
   {
       ulong ticket = PositionGetTicket(i);
       if(PositionSelectByTicket(ticket))
       {
           string sym = PositionGetString(POSITION_SYMBOL);
           if(sym != _Symbol)
              continue;
           int type = (int)PositionGetInteger(POSITION_TYPE);
           double entryPrice = PositionGetDouble(POSITION_PRICE_OPEN);
           double currentSL = PositionGetDouble(POSITION_SL);
           double currentTP = PositionGetDouble(POSITION_TP);
           double newSL;
           double price;
           
           if(type == POSITION_TYPE_BUY)
           {
              price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
              if(price > entryPrice + dynamicTS)
              {
                 newSL = price - dynamicTS;
                 if(newSL > currentSL + dynamicTStep)
                 {
                    if(!trade.PositionModify(ticket, newSL, currentTP))
                       Print("Failed to modify position ", ticket, " for trailing stop update. Error:", GetLastError());
                 }
              }
           }
           else if(type == POSITION_TYPE_SELL)
           {
              price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
              if(price < entryPrice - dynamicTS)
              {
                 newSL = price + dynamicTS;
                 if((currentSL == 0.0) || (newSL < currentSL - dynamicTStep))
                 {
                    if(!trade.PositionModify(ticket, newSL, currentTP))
                       Print("Failed to modify position ", ticket, " for trailing stop update. Error:", GetLastError());
                 }
              }
           }
       }
   }
}

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   stochHandle = iStochastic(_Symbol, _Period, InpStochKPeriod, InpStochDPeriod, InpStochSlowing, MODE_SMA, (int)PRICE_CLOSE);
   if(stochHandle == INVALID_HANDLE)
   {
      Print("Failed to create Stochastic handle");
      return(INIT_FAILED);
   }
   
   atrHandle = iATR(_Symbol, _Period, InpATRPeriod);
   if(atrHandle == INVALID_HANDLE)
   {
      Print("Failed to create ATR handle");
      return(INIT_FAILED);
   }
   
   lastTSIColor = 0;
   
   // Initialize UI Panel (replacing the old external TradeToggleButton)
   CreateUIPanel();
   
   // Prevent a startup trade until the warm-up period is met
   if(iBars(_Symbol, _Period) >= WarmUpBars)
   {
       lastClosedTimeGlobal = iTime(_Symbol, _Period, 1);
       double tsi_current, tsi_previous;
       int tsi_color_current, tsi_color_previous;
       if(CalculateTSI(tsi_current, tsi_previous, tsi_color_current, tsi_color_previous))
           lastTSIColor = tsi_color_current;
   }
   
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   if(stochHandle != INVALID_HANDLE)
      IndicatorRelease(stochHandle);
   if(atrHandle != INVALID_HANDLE)
      IndicatorRelease(atrHandle);
      
   // Remove UI Panel objects
   ObjectDelete(0, "EA_UIPanel");
   ObjectDelete(0, "Label_ATR_Multiplier");
   ObjectDelete(0, "Edit_ATR_Multiplier");
   ObjectDelete(0, "Label_LotSize");
   ObjectDelete(0, "Edit_LotSize");
   ObjectDelete(0, "Label_CustomTakeProfit");
   ObjectDelete(0, "Edit_CustomTakeProfit");
   ObjectDelete(0, "Label_GoldRush");
   ObjectDelete(0, "Button_GoldRush");
   ObjectDelete(0, "Label_TradeActionEnabled");
   ObjectDelete(0, "Button_TradeActionEnabled");
   ObjectDelete(0, "Label_TrailingStop");
   ObjectDelete(0, "Edit_TrailingStop");
   ObjectDelete(0, "Label_TrailingStep");
   ObjectDelete(0, "Edit_TrailingStep");
   ObjectDelete(0, "Label_MaxTrades");
   ObjectDelete(0, "Edit_MaxTrades");
   ObjectDelete(0, "Button_ApplySettings");
   
   // Remove any remaining virtual trade level lines.
   for(int i = (int)ArraySize(tradeLevelsArray) - 1; i >= 0; i--)
   {
      ObjectDelete(0, tradeLevelsArray[i].slLineName);
      ObjectDelete(0, tradeLevelsArray[i].tpLineName);
   }
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   // Update the UI panel (if not created, CreateUIPanel() will do nothing on subsequent calls)
   CreateUIPanel();
   
   // Check if warm-up period is met.
   if(iBars(_Symbol, _Period) < WarmUpBars)
   {
      TrailPositions(); // Update trailing stops during warm-up.
      return;
   }
   
   // Process only on a new closed candle.
   datetime closedBarTime = iTime(_Symbol, _Period, 1);
   if(closedBarTime == lastClosedTimeGlobal)
      return;
   lastClosedTimeGlobal = closedBarTime;
   
   double tsi_current, tsi_previous;
   int    tsi_color_current, tsi_color_previous;
   if(!CalculateTSI(tsi_current, tsi_previous, tsi_color_current, tsi_color_previous))
      return;
      
   double stochK[3], stochD[3];
   if(CopyBuffer(stochHandle, 0, 1, 3, stochK) <= 0) return;
   if(CopyBuffer(stochHandle, 1, 1, 3, stochD) <= 0) return;
   
   bool stochCrossUp   = (stochK[1] < stochD[1] && stochK[0] >= stochD[0]);
   bool stochCrossDown = (stochK[1] > stochD[1] && stochK[0] <= stochD[0]);
   
   bool tradeSignal    = false;
   bool isBullishTrade = false;
   bool isBearishTrade = false;
   
   if(!GoldRush)
   {
      bool tsiJustChanged = (tsi_color_current != lastTSIColor);
      bool stochConfirmBull = stochCrossUp || (stochK[0] > stochD[0]);
      bool stochConfirmBear = stochCrossDown || (stochK[0] < stochD[0]);
      
      if(tsiJustChanged)
      {
         if(tsi_color_current == 1 && stochConfirmBull)
         {
            tradeSignal = true;
            isBullishTrade = true;
         }
         else if(tsi_color_current == 2 && stochConfirmBear)
         {
            tradeSignal = true;
            isBearishTrade = true;
         }
      }
      lastTSIColor = tsi_color_current;
   }
   else
   {
      bool tsiJustChanged = (tsi_color_current != lastTSIColor);
      bool standardBull = tsiJustChanged && (tsi_color_current == 1) && (stochCrossUp || (stochK[0] > stochD[0]));
      bool standardBear = tsiJustChanged && (tsi_color_current == 2) && (stochCrossDown || (stochK[0] < stochD[0]));
      
      bool goldrushBull = ((stochK[2] < stochD[2]) && (stochK[1] >= stochD[1])) && (tsi_color_current == 1 && tsi_color_current == tsi_color_previous);
      bool goldrushBear = ((stochK[2] > stochD[2]) && (stochK[1] <= stochD[1])) && (tsi_color_current == 2 && tsi_color_current == tsi_color_previous);
      
      if(standardBull || goldrushBull)
      {
         tradeSignal = true;
         isBullishTrade = true;
      }
      else if(standardBear || goldrushBear)
      {
         tradeSignal = true;
         isBearishTrade = true;
      }
      if(tsiJustChanged)
         lastTSIColor = tsi_color_current;
   }
   
   // Only open a trade if trading is enabled and max trade limit is not reached.
   if(tradeSignal && TradeActionEnabled && (MaxTrades == 0 || tradesExecuted < MaxTrades))
   {
      double atrBuffer[3];
      if(CopyBuffer(atrHandle, 0, 1, 3, atrBuffer) <= 0) return;
      double currentATR = atrBuffer[0];
      
      if(isBullishTrade)
      {
         double entryPrice = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         double sl = entryPrice - ATR_Multiplier * currentATR;
         double tp = (CustomTakeProfit > 0.0) ? (entryPrice + CustomTakeProfit) : (entryPrice + ATR_Multiplier * currentATR);
         if(trade.Buy(LotSize, NULL, entryPrice, sl, tp, "Bullish Signal"))
         {
            ulong ticket = trade.ResultOrder();
            string dotName = "SignalDot_" + TimeToString(closedBarTime, TIME_DATE|TIME_SECONDS) + "_" + IntegerToString(ticket);
            ObjectCreate(0, dotName, OBJ_ARROW, 0, closedBarTime, entryPrice);
            ObjectSetInteger(0, dotName, OBJPROP_ARROWCODE, 233);
            ObjectSetInteger(0, dotName, OBJPROP_COLOR, clrGreen);
            string vslName = "Virtual_SL_" + IntegerToString(ticket);
            string vtpName = "Virtual_TP_" + IntegerToString(ticket);
            if(!ObjectCreate(0, vslName, OBJ_HLINE, 0, 0, sl)) 
               Print("Failed to create virtual SL line for ticket ", ticket);
            else
               ObjectSetInteger(0, vslName, OBJPROP_COLOR, clrOrange);
            if(!ObjectCreate(0, vtpName, OBJ_HLINE, 0, 0, tp))
               Print("Failed to create virtual TP line for ticket ", ticket);
            else
               ObjectSetInteger(0, vtpName, OBJPROP_COLOR, clrAqua);
            TradeLevels newLevels;
            newLevels.ticket = ticket;
            newLevels.slLineName = vslName;
            newLevels.tpLineName = vtpName;
            int newSize = (int)ArraySize(tradeLevelsArray) + 1;
            ArrayResize(tradeLevelsArray, newSize);
            tradeLevelsArray[newSize - 1] = newLevels;
            tradesExecuted++;
         }
      }
      else if(isBearishTrade)
      {
         double entryPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         double sl = entryPrice + ATR_Multiplier * currentATR;
         double tp = (CustomTakeProfit > 0.0) ? (entryPrice - CustomTakeProfit) : (entryPrice - ATR_Multiplier * currentATR);
         if(trade.Sell(LotSize, NULL, entryPrice, sl, tp, "Bearish Signal"))
         {
            ulong ticket = trade.ResultOrder();
            string dotName = "SignalDot_" + TimeToString(closedBarTime, TIME_DATE|TIME_SECONDS) + "_" + IntegerToString(ticket);
            ObjectCreate(0, dotName, OBJ_ARROW, 0, closedBarTime, entryPrice);
            ObjectSetInteger(0, dotName, OBJPROP_ARROWCODE, 234);
            ObjectSetInteger(0, dotName, OBJPROP_COLOR, clrRed);
            string vslName = "Virtual_SL_" + IntegerToString(ticket);
            string vtpName = "Virtual_TP_" + IntegerToString(ticket);
            if(!ObjectCreate(0, vslName, OBJ_HLINE, 0, 0, sl)) 
               Print("Failed to create virtual SL line for ticket ", ticket);
            else
               ObjectSetInteger(0, vslName, OBJPROP_COLOR, clrOrange);
            if(!ObjectCreate(0, vtpName, OBJ_HLINE, 0, 0, tp))
               Print("Failed to create virtual TP line for ticket ", ticket);
            else
               ObjectSetInteger(0, vtpName, OBJPROP_COLOR, clrAqua);
            TradeLevels newLevels;
            newLevels.ticket = ticket;
            newLevels.slLineName = vslName;
            newLevels.tpLineName = vtpName;
            int newSize = (int)ArraySize(tradeLevelsArray) + 1;
            ArrayResize(tradeLevelsArray, newSize);
            tradeLevelsArray[newSize - 1] = newLevels;
            tradesExecuted++;
         }
      }
   }
   
   // Remove virtual trade level lines for closed trades.
   CheckClosedTrades();
   
   // Update dynamic trailing stops.
   TrailPositions();
}

//+------------------------------------------------------------------+
//| OnChartEvent: Handle UI events                                   |
//+------------------------------------------------------------------+
void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
{
   // Handle button clicks in the UI panel.
   if(id == CHARTEVENT_OBJECT_CLICK)
   {
      if(sparam == "Button_ApplySettings")
      {
         UpdateParametersFromPanel();
      }
      else if(sparam == "Button_GoldRush")
      {
         GoldRush = !GoldRush;
         ObjectSetString(0, "Button_GoldRush", OBJPROP_TEXT, GoldRush ? "ON" : "OFF");
         Print("GoldRush mode set to ", GoldRush ? "ON" : "OFF");
      }
      else if(sparam == "Button_TradeActionEnabled")
      {
         TradeActionEnabled = !TradeActionEnabled;
         ObjectSetString(0, "Button_TradeActionEnabled", OBJPROP_TEXT, TradeActionEnabled ? "ON" : "OFF");
         Print("Trade Action set to ", TradeActionEnabled ? "ON" : "OFF");
      }
   }
}
