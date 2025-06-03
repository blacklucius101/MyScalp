//+------------------------------------------------------------------+
//|                                                 ZZ_Semafor_EA.mq5|
//|                                                      @mobilebass |
//|                                            https://www.mql5.com  |
//+------------------------------------------------------------------+
#property copyright "@mobilebass"
#property link      "https://www.mql5.com"
#property version   "1.03" // Version updated for ComboTSI_Stoch integration

//+------------------------------------------------------------------+
//| Include files                                                    |
//+------------------------------------------------------------------+
#include <Trade/Trade.mqh>
#include <Trade/PositionInfo.mqh>

// Input parameters
input double   Threshold = 50.0;       // Threshold percentage (0-100)
input int      TakeProfit = 3000;      // Take profit in points
input int      StopLoss = 70000;       // Stop loss in points
input double   LotSize = 0.01;         // Fixed lot size (0 for auto)
input int      MagicNumber = 123456;   // EA identifier
input bool     EnableAlerts = false;   // Enable popup alerts
input bool     UseWeakSignals = false; // false=only strong signals, true=both strong and weak

// Button properties
const string   BuyButtonName = "BuyToggleButton";
const string   SellButtonName = "SellToggleButton";
const int      ButtonWidth = 100;
const int      ButtonHeight = 30;
const int      ButtonXOffset = 10;
const int      ButtonYOffset = 20;
const int      ButtonSpacing = 5;      // Space between buttons
const color    ButtonOnColor = clrForestGreen;
const color    ButtonOffColor = clrFireBrick;
const color    ButtonTextColor = clrWhite;

// Line properties
const string   BullishLinePrefix = "BullishEntry_";
const string   BearishLinePrefix = "BearishEntry_";
const color    BullishLineColor = clrForestGreen;
const color    BearishLineColor = clrFireBrick;
const int      LineWidth = 5;
const ENUM_LINE_STYLE LineStyle = STYLE_DOT;
const int      LineDurationBars = 5; // How many bars the line should span

// Data structures for signal tracking
struct SignalData {
   datetime candleTime;     // Time of the signal candle
   double triggerPrice;     // Price where arrow appeared (high for bearish, low for bullish)
   double thresholdPrice;   // Calculated threshold price
   bool signalUsed;         // Flag if signal has been used
   double candleRange;      // Range of the signal candle (high-low)
};

SignalData arrowBearish;    // Stores bearish signal data
SignalData arrowBullish;    // Stores bullish signal data

// Global variables
int zzHandle;              // Handle for custom indicator
int tsiStochHandle;        // Handle for ComboTSI_Stoch indicator
datetime lastBarTime;      // Time of last processed bar
CTrade trade;              // Trade object
CPositionInfo positionInfo;
bool isBuyEnabled = false; // Global flag for buy trading permission
bool isSellEnabled = false; // Global flag for sell trading permission

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   // Validate inputs
   if(Threshold <= 0 || Threshold >= 100) {
      Alert("Threshold must be between 0 and 100");
      return(INIT_PARAMETERS_INCORRECT);
   }
   
   if(TakeProfit < 1000 || StopLoss < 1000) {
      Alert("TP/SL must be at least 1000 points for BTCUSD");
      return(INIT_PARAMETERS_INCORRECT);
   }
   
   // Load custom indicator
   zzHandle = iCustom(NULL, 0, "Custom\\Single_Level_ZZ_Semafor");
   if(zzHandle == INVALID_HANDLE) {
      Alert("Failed to load Single_Level_ZZ_Semafor indicator");
      return(INIT_FAILED);
   }

   // Load ComboTSI_Stoch indicator
   tsiStochHandle = iCustom(NULL, 0, "Custom\\ComboTSI_Stoch");
   if(tsiStochHandle == INVALID_HANDLE) {
      Alert("Failed to load ComboTSI_Stoch indicator");
      return(INIT_FAILED);
   }
   
   // Initialize trade object
   trade.SetExpertMagicNumber(MagicNumber);
   trade.SetMarginMode();
   trade.SetTypeFillingBySymbol(_Symbol);
   
   // Initialize signal structures
   ResetSignalData(arrowBearish);
   ResetSignalData(arrowBullish);
   
   // Get current bar time
   lastBarTime = iTime(NULL, PERIOD_CURRENT, 0);
   
   // Create the toggle buttons
   CreateTradeToggleButtons();
   
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Create the trading toggle buttons                                |
//+------------------------------------------------------------------+
void CreateTradeToggleButtons()
{
   // Delete any existing buttons first
   ObjectDelete(0, BuyButtonName);
   ObjectDelete(0, SellButtonName);
   
   // Create the Buy button
   if(!ObjectCreate(0, BuyButtonName, OBJ_BUTTON, 0, 0, 0))
   {
      Print("Failed to create Buy button! Error code: ", GetLastError());
      return;
   }
   
   // Set Buy button properties
   ObjectSetInteger(0, BuyButtonName, OBJPROP_XDISTANCE, ButtonXOffset);
   ObjectSetInteger(0, BuyButtonName, OBJPROP_YDISTANCE, ButtonYOffset);
   ObjectSetInteger(0, BuyButtonName, OBJPROP_XSIZE, ButtonWidth);
   ObjectSetInteger(0, BuyButtonName, OBJPROP_YSIZE, ButtonHeight);
   ObjectSetInteger(0, BuyButtonName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, BuyButtonName, OBJPROP_FONTSIZE, 10);
   ObjectSetInteger(0, BuyButtonName, OBJPROP_COLOR, ButtonTextColor);
   ObjectSetInteger(0, BuyButtonName, OBJPROP_BGCOLOR, isBuyEnabled ? ButtonOnColor : ButtonOffColor);
   ObjectSetString(0, BuyButtonName, OBJPROP_TEXT, isBuyEnabled ? "Buy: ON" : "Buy: OFF");
   ObjectSetInteger(0, BuyButtonName, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, BuyButtonName, OBJPROP_SELECTED, false);
   
   // Create the Sell button
   if(!ObjectCreate(0, SellButtonName, OBJ_BUTTON, 0, 0, 0))
   {
      Print("Failed to create Sell button! Error code: ", GetLastError());
      return;
   }
   
   // Set Sell button properties
   ObjectSetInteger(0, SellButtonName, OBJPROP_XDISTANCE, ButtonXOffset + ButtonWidth + ButtonSpacing);
   ObjectSetInteger(0, SellButtonName, OBJPROP_YDISTANCE, ButtonYOffset);
   ObjectSetInteger(0, SellButtonName, OBJPROP_XSIZE, ButtonWidth);
   ObjectSetInteger(0, SellButtonName, OBJPROP_YSIZE, ButtonHeight);
   ObjectSetInteger(0, SellButtonName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, SellButtonName, OBJPROP_FONTSIZE, 10);
   ObjectSetInteger(0, SellButtonName, OBJPROP_COLOR, ButtonTextColor);
   ObjectSetInteger(0, SellButtonName, OBJPROP_BGCOLOR, isSellEnabled ? ButtonOnColor : ButtonOffColor);
   ObjectSetString(0, SellButtonName, OBJPROP_TEXT, isSellEnabled ? "Sell: ON" : "Sell: OFF");
   ObjectSetInteger(0, SellButtonName, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, SellButtonName, OBJPROP_SELECTED, false);
   
   // Make sure buttons are visible and in the foreground
   ObjectSetInteger(0, BuyButtonName, OBJPROP_HIDDEN, false);
   ObjectSetInteger(0, SellButtonName, OBJPROP_HIDDEN, false);
   ChartRedraw();
}

//+------------------------------------------------------------------+
//| Draw entry level line                                            |
//+------------------------------------------------------------------+
void DrawEntryLine(string prefix, datetime signalTime, double price, color lineColor)
{
   string lineName = prefix + TimeToString(signalTime);
   
   // Calculate end time (signal time + duration in bars)
   datetime endTime = iTime(NULL, 0, LineDurationBars) + (PeriodSeconds() * LineDurationBars);
   
   // Delete old line if exists
   ObjectDelete(0, lineName);
   
   // Create the line
   if(!ObjectCreate(0, lineName, OBJ_TREND, 0, signalTime, price, endTime, price))
   {
      Print("Failed to create entry line! Error: ", GetLastError());
      return;
   }
   
   // Set line properties
   ObjectSetInteger(0, lineName, OBJPROP_COLOR, lineColor);
   ObjectSetInteger(0, lineName, OBJPROP_WIDTH, LineWidth);
   ObjectSetInteger(0, lineName, OBJPROP_STYLE, LineStyle);
   ObjectSetInteger(0, lineName, OBJPROP_RAY, false);
   ObjectSetInteger(0, lineName, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, lineName, OBJPROP_BACK, true);
   
   ChartRedraw();
}

//+------------------------------------------------------------------+
//| Clean up old entry lines                                         |
//+------------------------------------------------------------------+
void CleanUpOldLines()
{
   datetime currentTime = TimeCurrent();
   datetime expirationTime = currentTime - (PeriodSeconds() * LineDurationBars * 2);
   
   // Clean up bullish lines
   int totalObjects = ObjectsTotal(0, 0, -1);
   for(int i = totalObjects-1; i >= 0; i--)
   {
      string name = ObjectName(0, i, 0, -1);
      if(StringFind(name, BullishLinePrefix) == 0 || StringFind(name, BearishLinePrefix) == 0)
      {
         datetime createTime = (datetime)ObjectGetInteger(0, name, OBJPROP_TIME);
         if(createTime < expirationTime)
         {
            ObjectDelete(0, name);
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Reset signal data structure                                      |
//+------------------------------------------------------------------+
void ResetSignalData(SignalData &data)
{
   data.candleTime = 0;
   data.triggerPrice = 0;
   data.thresholdPrice = 0;
   data.signalUsed = false;
   data.candleRange = 0;
}

//+------------------------------------------------------------------+
//| Check if new bar has formed                                      |
//+------------------------------------------------------------------+
bool IsNewBar()
{
   datetime currentBarTime = iTime(NULL, PERIOD_CURRENT, 0);
   if(currentBarTime != lastBarTime) {
      lastBarTime = currentBarTime;
      return true;
   }
   return false;
}

//+------------------------------------------------------------------+
//| Process new bar data                                             |
//+------------------------------------------------------------------+
void ProcessNewBar()
{
   // We're interested in the previous candle (c1) which just closed
   int c1 = 1; // Index of previous candle
   
   // Get indicator values for previous candle
   double highArrow = GetIndicatorValue(zzHandle, 1, c1); // High buffer
   double lowArrow = GetIndicatorValue(zzHandle, 0, c1);  // Low buffer
   
   // Get candle data for c1 (signal candle)
   double c1High = iHigh(NULL, 0, c1);
   double c1Low = iLow(NULL, 0, c1);
   datetime c1Time = iTime(NULL, 0, c1);
   double c1Range = c1High - c1Low;
   
   // Clean up old lines first
   CleanUpOldLines();
   
   // Check for bearish signal (high arrow)
   if(highArrow > 0) {
      // Reset signalUsed flag whenever a new arrow appears
      arrowBearish.signalUsed = false;
      
      arrowBearish.candleTime = c1Time;
      arrowBearish.triggerPrice = c1High;
      arrowBearish.candleRange = c1Range;
      // Corrected threshold calculation using c1 prices
      arrowBearish.thresholdPrice = NormalizeDouble(c1High - ((Threshold / 100) * c1Range), 2);

      // Draw bearish entry line
      DrawEntryLine(BearishLinePrefix, c1Time, arrowBearish.thresholdPrice, BearishLineColor);
      
      if(EnableAlerts) Alert("New Bearish Signal at ", c1Time, " Threshold: ", arrowBearish.thresholdPrice);
   }
   
   // Check for bullish signal (low arrow)
   if(lowArrow > 0) {
      // Reset signalUsed flag whenever a new arrow appears
      arrowBullish.signalUsed = false;
      
      arrowBullish.candleTime = c1Time;
      arrowBullish.triggerPrice = c1Low;
      arrowBullish.candleRange = c1Range;
      // Corrected threshold calculation using c1 prices
      arrowBullish.thresholdPrice = NormalizeDouble(c1Low + ((Threshold / 100) * c1Range), 2);

      // Draw bullish entry line
      DrawEntryLine(BullishLinePrefix, c1Time, arrowBullish.thresholdPrice, BullishLineColor);
      
      if(EnableAlerts) Alert("New Bullish Signal at ", c1Time, " Threshold: ", arrowBullish.thresholdPrice);
   }
}

//+------------------------------------------------------------------+
//| Get indicator value from buffer                                  |
//+------------------------------------------------------------------+
double GetIndicatorValue(int handle, int buffer, int shift)
{
   double value[1];
   if(CopyBuffer(handle, buffer, shift, 1, value) == 1) {
      return value[0];
   }
   return EMPTY_VALUE;
}

//+------------------------------------------------------------------+
//| Check entry conditions                                           |
//+------------------------------------------------------------------+
void CheckEntryConditions()
{
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   
   // Get ComboTSI_Stoch signal for current bar (buffer 5 is signalValueBuffer)
   double tsiStochSignal[1];
   if(CopyBuffer(tsiStochHandle, 5, 0, 1, tsiStochSignal) != 1) {
      Print("Failed to get ComboTSI_Stoch signal value");
      return;
   }
   int currentSignal = (int)tsiStochSignal[0];
   
   // Bearish signal: Enter sell when bid is <= bearish threshold and sell is enabled
   if(arrowBearish.candleTime > 0 && !arrowBearish.signalUsed && bid <= arrowBearish.thresholdPrice && isSellEnabled)
   {
      // Check if we have a valid bearish signal from ComboTSI_Stoch
      bool validSignal = (currentSignal == 1) || (UseWeakSignals && currentSignal == 3);
      
      if(validSignal) {
         ExecuteTrade(ORDER_TYPE_SELL, bid);
         arrowBearish.signalUsed = true;
      }
      else if(EnableAlerts) {
         Alert("Sell signal rejected - No matching ComboTSI_Stoch signal");
      }
   }
   
   // Bullish signal: Enter buy when ask is >= bullish threshold and buy is enabled
   if(arrowBullish.candleTime > 0 && !arrowBullish.signalUsed && ask >= arrowBullish.thresholdPrice && isBuyEnabled)
   {
      // Check if we have a valid bullish signal from ComboTSI_Stoch
      bool validSignal = (currentSignal == 0) || (UseWeakSignals && currentSignal == 2);
      
      if(validSignal) {
         ExecuteTrade(ORDER_TYPE_BUY, ask);
         arrowBullish.signalUsed = true;
      }
      else if(EnableAlerts) {
         Alert("Buy signal rejected - No matching ComboTSI_Stoch signal");
      }
   }
}

//+------------------------------------------------------------------+
//| Execute trade                                                    |
//+------------------------------------------------------------------+
void ExecuteTrade(ENUM_ORDER_TYPE orderType, double requestedPrice)
{
   double lot = (LotSize == 0) ? NormalizeDouble(AccountInfoDouble(ACCOUNT_BALANCE) / 1000.0, 2) : LotSize;

   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double spreadPoints = (ask - bid) / _Point;

   // Adjust TP and SL to account for spread
   double realTP = TakeProfit + spreadPoints;
   double realSL = StopLoss + spreadPoints;

   double sl = 0.0, tp = 0.0;

   if(orderType == ORDER_TYPE_BUY)
   {
      sl = NormalizeDouble(requestedPrice - realSL * _Point, _Digits);
      tp = NormalizeDouble(requestedPrice + realTP * _Point, _Digits);
   }
   else if(orderType == ORDER_TYPE_SELL)
   {
      sl = NormalizeDouble(requestedPrice + realSL * _Point, _Digits);
      tp = NormalizeDouble(requestedPrice - realTP * _Point, _Digits);
   }

   // Open position with calculated SL/TP
   if(trade.PositionOpen(_Symbol, orderType, lot, requestedPrice, sl, tp, "ZZ_Semafor_EA"))
   {
      if(trade.ResultRetcode() == TRADE_RETCODE_DONE)
      {
         if(EnableAlerts)
         {
            string dir = (orderType == ORDER_TYPE_BUY) ? "Buy" : "Sell";
            Alert(dir, " order executed at ", DoubleToString(trade.ResultPrice(), _Digits),
                  " (Requested: ", DoubleToString(requestedPrice, _Digits), ")",
                  " TP: ", DoubleToString(tp, _Digits),
                  " SL: ", DoubleToString(sl, _Digits),
                  " [Spread-adjusted by ", DoubleToString(spreadPoints, 0), " points]");
         }
      }
      else
      {
         Alert("Order placed but not successful. Error: ", trade.ResultRetcodeDescription());
      }
   }
   else
   {
      Alert("Order failed to send. Error: ", trade.ResultRetcodeDescription());
   }
}

//+------------------------------------------------------------------+
//| Handle chart events                                              |
//+------------------------------------------------------------------+
void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
{
   // Handle Buy button click event
   if(id == CHARTEVENT_OBJECT_CLICK && sparam == BuyButtonName)
   {
      // Toggle the buy trading flag
      isBuyEnabled = !isBuyEnabled;
      
      // Update the button appearance
      ObjectSetInteger(0, BuyButtonName, OBJPROP_BGCOLOR, isBuyEnabled ? ButtonOnColor : ButtonOffColor);
      ObjectSetString(0, BuyButtonName, OBJPROP_TEXT, isBuyEnabled ? "Buy: ON" : "Buy: OFF");
      
      // Redraw the chart to show changes
      ChartRedraw();
      
      if(EnableAlerts) Alert("Buy trading is now ", (isBuyEnabled ? "ENABLED" : "DISABLED"));
   }
   
   // Handle Sell button click event
   if(id == CHARTEVENT_OBJECT_CLICK && sparam == SellButtonName)
   {
      // Toggle the sell trading flag
      isSellEnabled = !isSellEnabled;
      
      // Update the button appearance
      ObjectSetInteger(0, SellButtonName, OBJPROP_BGCOLOR, isSellEnabled ? ButtonOnColor : ButtonOffColor);
      ObjectSetString(0, SellButtonName, OBJPROP_TEXT, isSellEnabled ? "Sell: ON" : "Sell: OFF");
      
      // Redraw the chart to show changes
      ChartRedraw();
      
      if(EnableAlerts) Alert("Sell trading is now ", (isSellEnabled ? "ENABLED" : "DISABLED"));
   }
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   // Clean up the indicator handles
   if(zzHandle != INVALID_HANDLE) {
      IndicatorRelease(zzHandle);
   }
   if(tsiStochHandle != INVALID_HANDLE) {
      IndicatorRelease(tsiStochHandle);
   }
   
   // Delete the button objects
   ObjectDelete(0, BuyButtonName);
   ObjectDelete(0, SellButtonName);
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   if(IsNewBar()) {
      ProcessNewBar();
   }
   CheckEntryConditions();
}