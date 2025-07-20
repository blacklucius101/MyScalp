//+------------------------------------------------------------------+
//|                                               TradeAssistant.mq5 |
//|                                                      @mobilebass |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"
#property description "TradeAssistant"

//--- Input parameters for trade levels
input group "Trade Levels (in Points)"
input int InpTakeProfit = 5000;       // Take Profit in points
input int InpStopLoss = 70000;         // Stop Loss in points
input int InpTrailingStop = 0;       // Trailing Stop in points (0 = disabled)
input int InpTrailingStep = 1;        // Trailing Step in points
input int InpStartTrailingPoint = 5001; // Start Trailing Point in points

//--- Input parameter for lot size
input group "Lot Size Management"
input double InpLotSize = 0.0;        // Lot size (0.0 = dynamic calculation)

input group "Signal Line Settings"; // New group for these settings
input double InpSignalThreshold = 61.8; // Threshold percentage (0-100)

//--- Input parameter for trade execution type
input group "Trade Execution"
enum EnumExecutionType
  {
   EXECUTE_IMMEDIATE,     // Execute immediately on button press
   EXECUTE_ON_NEXT_CANDLE // Execute on the open of the next candle
  };
input EnumExecutionType InpExecutionType = EXECUTE_ON_NEXT_CANDLE; // Trade execution type

//--- Input parameters for visual elements (e.g., button labels, colors) - to be added later if needed

// Include Trade library
#include <Trade\Trade.mqh>

//--- Data structure for signal tracking
struct SignalData
  {
   datetime candleTime;     // Time of the signal candle
   double   triggerPrice;   // Price where arrow appeared (high for bearish, low for bullish)
   double   thresholdPrice; // Calculated threshold price
   bool     signalUsed;     // Flag if signal has been used
   double   candleRange;    // Range of the signal candle (high-low)
  };

// Global instance of CTrade
CTrade trade;
long जी_EXPERT_MAGIC_NUMBER = 198705; // Example Magic Number

//--- Global variables for UI element names
string g_buyButtonName = "BuyButton";
string g_sellButtonName = "SellButton";
string g_execTypeButtonName = "ExecTypeButton"; // Name for the new execution type toggle button
string g_pendingIndicatorName = "PendingTradeIndicator"; // Name for the pending trade visual indicator
string g_highRetracementLabelName = "HighRetLabelTA"; // Name for High Retracement Label
string g_lowRetracementLabelName = "LowRetLabelTA";   // Name for Low Retracement Label

//--- Line properties for retracement levels
const string g_bullishEntryLinePrefix = "BullishEntryTA_";
const string g_bearishEntryLinePrefix = "BearishEntryTA_";
const string g_bullishFormingLineName = g_bullishEntryLinePrefix + "CurrentForming"; // Name for the dynamic bullish line on the forming candle
const string g_bearishFormingLineName = g_bearishEntryLinePrefix + "CurrentForming";   // Name for the dynamic bearish line on the forming candle
const color  g_bullishLineColor = clrAqua;
const color  g_bearishLineColor = clrMagenta;
const int    g_lineWidth = 1; 
const ENUM_LINE_STYLE g_lineStyle = STYLE_DOT;
const int    g_lineDurationBars = 1; 

//--- Global variables for pending "next candle" trades
ENUM_ORDER_TYPE g_pendingOrderType = WRONG_VALUE; 
bool g_tradeOnNextCandlePending = false;     

//--- Global variable to hold the current execution type state
EnumExecutionType g_currentExecutionType;

//--- Global variables for immediate pending trades
bool g_immediateTradePending = false;      
ENUM_ORDER_TYPE g_immediatePendingOrderType = WRONG_VALUE; 
datetime g_pendingTradeCandleTime = 0;     

//--- Colors for pending indicator states
const color clrPendingImmediateBuy = clrAqua;
const color clrPendingImmediateSell = clrMagenta; 

SignalData g_arrowBearish;    
SignalData g_arrowBullish;    
int g_zzSemaforHandle = INVALID_HANDLE; 
//+------------------------------------------------------------------+
//| Execute Trade Operation                                          |
//+------------------------------------------------------------------+
void ExecuteTrade(ENUM_ORDER_TYPE orderType)
  {
   if(orderType != ORDER_TYPE_BUY && orderType != ORDER_TYPE_SELL)
     {
      Print("ExecuteTrade: Invalid order type specified.");
      g_tradeOnNextCandlePending = false; 
      g_pendingOrderType = WRONG_VALUE;
      g_immediateTradePending = false;
      g_immediatePendingOrderType = WRONG_VALUE;
      g_pendingTradeCandleTime = 0;
      ObjectSetInteger(0, g_pendingIndicatorName, OBJPROP_BGCOLOR, clrLightGray);
      ChartRedraw();
      return;
     }

   double lot = CalculateLotSize();
   if(lot <= 0)
     {
      Print("ExecuteTrade: Invalid lot size calculated: ", lot);
      if(g_immediateTradePending && g_immediatePendingOrderType == orderType)
        {
         g_immediateTradePending = false;
         g_immediatePendingOrderType = WRONG_VALUE;
         g_pendingTradeCandleTime = 0;
        }
      if(g_tradeOnNextCandlePending && g_pendingOrderType == orderType)
        {
         g_tradeOnNextCandlePending = false; 
         g_pendingOrderType = WRONG_VALUE;
        }
      ObjectSetInteger(0, g_pendingIndicatorName, OBJPROP_BGCOLOR, clrLightGray);
      ChartRedraw();
      return;
     }

   if(!CheckTradeConditions(orderType))
     {
      if(g_tradeOnNextCandlePending && g_pendingOrderType == orderType && !g_immediateTradePending) 
        {
         Print("ExecuteTrade: Conditions not met for pending next candle ", (orderType == ORDER_TYPE_BUY ? "BUY" : "SELL"), ". Resetting next candle pending state.");
         g_tradeOnNextCandlePending = false;
         g_pendingOrderType = WRONG_VALUE;
         ObjectSetInteger(0, g_pendingIndicatorName, OBJPROP_BGCOLOR, clrLightGray);
         ChartRedraw();
        }
      return; 
     }
   
   double currentPrice = (orderType == ORDER_TYPE_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(currentPrice == 0)
     {
       Print("ExecuteTrade: Could not retrieve current price for trade execution. Aborting trade attempt.");
        g_immediateTradePending = false;
        g_immediatePendingOrderType = WRONG_VALUE;
        g_pendingTradeCandleTime = 0;
        g_tradeOnNextCandlePending = false;
        g_pendingOrderType = WRONG_VALUE;
        ObjectSetInteger(0, g_pendingIndicatorName, OBJPROP_BGCOLOR, clrLightGray);
        ChartRedraw();
       return;
     }

   double slPrice = 0.0;
   double tpPrice = 0.0;
   string comment = "";
   bool tradeAttemptMade = false; 

   if(orderType == ORDER_TYPE_BUY)
     {
      slPrice = (InpStopLoss > 0) ? currentPrice - InpStopLoss * _Point : 0.0;
      tpPrice = (InpTakeProfit > 0) ? currentPrice + InpTakeProfit * _Point : 0.0;
      comment = "Buy executed by EA";
      Print("Attempting BUY: Lot=", lot, ", Price=", DoubleToString(currentPrice, _Digits), ", SL=", DoubleToString(slPrice, _Digits), ", TP=", DoubleToString(tpPrice, _Digits));
      tradeAttemptMade = true;
      if(!trade.Buy(lot, _Symbol, currentPrice, slPrice, tpPrice, comment))
        {
         Print("Buy order failed: ", trade.ResultRetcode(), " - ", trade.ResultRetcodeDescription());
        }
      else
        {
         Print("Buy order successful. Position #", trade.ResultOrder());
         if(trade.ResultOrder() > 0) CloseOppositeTrades(ORDER_TYPE_SELL);
        }
     }
   else if(orderType == ORDER_TYPE_SELL)
     {
      slPrice = (InpStopLoss > 0) ? currentPrice + InpStopLoss * _Point : 0.0;
      tpPrice = (InpTakeProfit > 0) ? currentPrice - InpTakeProfit * _Point : 0.0;
      comment = "Sell executed by EA";
      Print("Attempting SELL: Lot=", lot, ", Price=", DoubleToString(currentPrice, _Digits), ", SL=", DoubleToString(slPrice, _Digits), ", TP=", DoubleToString(tpPrice, _Digits));
      tradeAttemptMade = true;
      if(!trade.Sell(lot, _Symbol, currentPrice, slPrice, tpPrice, comment))
        {
         Print("Sell order failed: ", trade.ResultRetcode(), " - ", trade.ResultRetcodeDescription());
        }
      else
        {
         Print("Sell order successful. Position #", trade.ResultOrder());
         if(trade.ResultOrder() > 0) CloseOppositeTrades(ORDER_TYPE_BUY);
        }
     }

   if(tradeAttemptMade)
     {
      Print("ExecuteTrade: Trade attempt made for ", (orderType == ORDER_TYPE_BUY ? "BUY" : "SELL"), ". Resetting all pending states.");
      g_immediateTradePending = false;
      g_immediatePendingOrderType = WRONG_VALUE;
      g_pendingTradeCandleTime = 0;
      
      g_tradeOnNextCandlePending = false;
      g_pendingOrderType = WRONG_VALUE;
      
      ObjectSetInteger(0, g_pendingIndicatorName, OBJPROP_BGCOLOR, clrLightGray);
      ChartRedraw(); 
     }
  }

//+------------------------------------------------------------------+
//| Check Trade Conditions                                           |
//+------------------------------------------------------------------+
bool CheckTradeConditions(ENUM_ORDER_TYPE orderType)
  {
   if(orderType != ORDER_TYPE_BUY && orderType != ORDER_TYPE_SELL)
     {
      Print("CheckTradeConditions: Invalid order type specified.");
      return false;
     }

   double prevHigh = iHigh(_Symbol, _Period, 1);
   double prevLow = iLow(_Symbol, _Period, 1);
   double prevRange = prevHigh - prevLow;

   if(prevRange <= 0) 
     {
      if (_Point > 0) Print("CheckTradeConditions: Previous candle range is zero or negative (H:", prevHigh, ", L:", prevLow,"). Cannot determine retracement. Conditions not met.");
      else Print("CheckTradeConditions: Invalid _Point size or previous candle range is zero/negative. Conditions not met.");
      return false;
     }

   double currentPrice = 0;
   string tradeTypeStr = (orderType == ORDER_TYPE_BUY) ? "BUY" : "SELL";

   if(orderType == ORDER_TYPE_BUY)
     {
      currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(currentPrice == 0)
        {
         Print("CheckTradeConditions: Could not get ASK price for ", tradeTypeStr, ". Conditions not met.");
         return false;
        }
      
      double requiredRetracementPrice = prevLow + (InpSignalThreshold / 100.0) * prevRange;
      if(currentPrice < requiredRetracementPrice) 
        {
         Print("CheckTradeConditions: ", tradeTypeStr, " condition not met. Current Ask: ", DoubleToString(currentPrice, _Digits), ", Required Price >= ", DoubleToString(requiredRetracementPrice, _Digits));
         return false;
        }
     }
   else // ORDER_TYPE_SELL
     {
      currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(currentPrice == 0)
        {
         Print("CheckTradeConditions: Could not get BID price for ", tradeTypeStr, ". Conditions not met.");
         return false;
        }
      
      double requiredRetracementPrice = prevHigh - (InpSignalThreshold / 100.0) * prevRange;
      if(currentPrice > requiredRetracementPrice) 
        {
         Print("CheckTradeConditions: ", tradeTypeStr, " condition not met. Current Bid: ", DoubleToString(currentPrice, _Digits), ", Required Price <= ", DoubleToString(requiredRetracementPrice, _Digits));
         return false;
        }
     }
   
   Print("CheckTradeConditions: ", tradeTypeStr, " retracement conditions MET. Current Price: ", DoubleToString(currentPrice, _Digits));

   // MACD Chaikin Confirmation has been removed. 
   // If EXECUTE_IMMEDIATE, the retracement condition is now the only condition from this function.

   Print("CheckTradeConditions: ALL ", tradeTypeStr, " conditions (retracement only) MET.");
   return true; 
  }

//+------------------------------------------------------------------+
//| Close Opposite Trades                                            |
//+------------------------------------------------------------------+
void CloseOppositeTrades(ENUM_ORDER_TYPE oppositeOrderTypeToClose)
  {
   if(oppositeOrderTypeToClose != ORDER_TYPE_BUY && oppositeOrderTypeToClose != ORDER_TYPE_SELL)
     {
      Print("CloseOppositeTrades: Invalid order type specified to close.");
      return;
     }

   string directionToCloseStr = (oppositeOrderTypeToClose == ORDER_TYPE_BUY) ? "BUY" : "SELL";
   Print("CloseOppositeTrades: Checking for open '", directionToCloseStr, "' positions to close.");

   for(int i = PositionsTotal() - 1; i >= 0; i--) 
     {
      ulong positionTicket = PositionGetTicket(i);
      if(positionTicket == 0) continue; 

      if(PositionSelectByTicket(positionTicket))
        {
         if(PositionGetString(POSITION_SYMBOL) == _Symbol) 
           {
            ENUM_POSITION_TYPE positionType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
            
            bool shouldClose = false;
            if(oppositeOrderTypeToClose == ORDER_TYPE_BUY && positionType == POSITION_TYPE_BUY)
              {
               shouldClose = true;
              }
            else if(oppositeOrderTypeToClose == ORDER_TYPE_SELL && positionType == POSITION_TYPE_SELL)
              {
               shouldClose = true;
              }

            if(shouldClose)
              {
               Print("CloseOppositeTrades: Attempting to close ", directionToCloseStr, " position #", positionTicket);
               if(!trade.PositionClose(positionTicket))
                 {
                  Print("CloseOppositeTrades: Failed to close position #", positionTicket, ". Error: ", trade.ResultRetcode(), " - ", trade.ResultRetcodeDescription());
                 }
               else
                 {
                  Print("CloseOppositeTrades: Successfully closed position #", positionTicket, ". Result: ", trade.ResultRetcodeDescription());
                 }
              }
           }
        }
      else
        {
         Print("CloseOppositeTrades: Error selecting position with ticket ", positionTicket, ". Error: ", GetLastError());
        }
     }
  }

//+------------------------------------------------------------------+
//| Create Button Object                                             |
//+------------------------------------------------------------------+
void CreateButton(string name, string text, int x, int y, int width, int height, color bgColor, color textColor, int corner = 0, int fontSize = 8) 
  {
   if(ObjectFind(0, name) != 0) 
     {
      if(!ObjectCreate(0, name, OBJ_BUTTON, 0, 0, 0))
        {
         Print("Error creating button ", name, ": ", GetLastError());
         return;
        }
     }

   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_XSIZE, width);
   ObjectSetInteger(0, name, OBJPROP_YSIZE, height);
   ObjectSetInteger(0, name, OBJPROP_CORNER, corner);
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR, bgColor);
   ObjectSetInteger(0, name, OBJPROP_COLOR, textColor);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, fontSize);
   ObjectSetInteger(0, name, OBJPROP_STATE, 0); 
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, 0); 
   ObjectSetInteger(0, name, OBJPROP_BACK, 0); 
   ObjectSetInteger(0, name, OBJPROP_ZORDER, 0); 
  }

//+------------------------------------------------------------------+
//| Create Retracement Label Object                                  |
//+------------------------------------------------------------------+
void CreateRetracementLabelTA(string name, string initial_text, color label_color, int corner, int x_offset, int y_offset, int fontSize = 8)
{
   if(ObjectFind(0, name) != 0) // If object already exists, no need to recreate, just ensure properties.
   {
      // Optionally, one could update properties here if they might change,
      // but for initial creation, this check is mainly to prevent creation errors.
      // For this use case, we'll assume if it exists, it's correctly set up by OnInit.
      // If not, it will be created.
   }

   if(!ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0))
   {
      Print("Error creating label '", name, "': ", GetLastError());
      return;
   }

   ObjectSetString(0, name, OBJPROP_TEXT, initial_text);
   ObjectSetInteger(0, name, OBJPROP_CORNER, corner);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x_offset);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y_offset);
   ObjectSetInteger(0, name, OBJPROP_COLOR, label_color);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, fontSize);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, 0); // Not selectable
   ObjectSetInteger(0, name, OBJPROP_BACK, true);    // Draw behind price chart
   ObjectSetInteger(0, name, OBJPROP_ZORDER, 0);     // Standard Z-order
}

//+------------------------------------------------------------------+
//| Calculate Lot Size                                               |
//+------------------------------------------------------------------+
double CalculateLotSize()
  {
   if(InpLotSize > 0.0)
     {
      double userLotSize = InpLotSize;
      double volumeMin = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
      double volumeMax = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
      double volumeStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);

      if(userLotSize < volumeMin) userLotSize = volumeMin;
      if(userLotSize > volumeMax) userLotSize = volumeMax;
      
      userLotSize = MathFloor(userLotSize / volumeStep) * volumeStep;
      if (userLotSize < volumeMin) userLotSize = volumeMin; 

      return(NormalizeDouble(userLotSize, 2)); 
     }

   double calculatedLotSize = AccountInfoDouble(ACCOUNT_BALANCE) / 1000.0;

   double volumeMin = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double volumeMax = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double volumeStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);

   if(calculatedLotSize < volumeMin)
     {
      calculatedLotSize = volumeMin;
     }
   else if(calculatedLotSize > volumeMax)
     {
      calculatedLotSize = volumeMax;
     }
   else
     {
      calculatedLotSize = MathRound(calculatedLotSize / volumeStep) * volumeStep;
      if(calculatedLotSize < volumeMin) calculatedLotSize = volumeMin;
      if(calculatedLotSize > volumeMax) calculatedLotSize = volumeMax;
     }
   
   return(NormalizeDouble(calculatedLotSize, 2));
  }

//+------------------------------------------------------------------+
//| Reset signal data structure                                      |
//+------------------------------------------------------------------+
void ResetSignalDataTA(SignalData &data)
  {
   data.candleTime = 0;
   data.triggerPrice = 0;
   data.thresholdPrice = 0;
   data.signalUsed = false;
   data.candleRange = 0;
  }

//+------------------------------------------------------------------+
//| Draw entry level line                                            |
//+------------------------------------------------------------------+
void DrawEntryLineTA(string prefix, datetime signalTime, double price, color lineColor)
  {
   string lineName = prefix + TimeToString(signalTime, TIME_MINUTES); 

   datetime endTime = signalTime + PeriodSeconds() * g_lineDurationBars;

   if(ObjectFind(0, lineName) != -1)
     {
      ObjectDelete(0, lineName);
     }

   if(!ObjectCreate(0, lineName, OBJ_TREND, 0, signalTime, price, endTime, price))
     {
      Print("Failed to create entry line '", lineName, "'! Error: ", GetLastError());
      return;
     }

   ObjectSetInteger(0, lineName, OBJPROP_COLOR, lineColor);
   ObjectSetInteger(0, lineName, OBJPROP_WIDTH, g_lineWidth);
   ObjectSetInteger(0, lineName, OBJPROP_STYLE, g_lineStyle);
   ObjectSetInteger(0, lineName, OBJPROP_RAY_RIGHT, false); 
   ObjectSetInteger(0, lineName, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, lineName, OBJPROP_BACK, true); 
   ObjectSetString(0, lineName, OBJPROP_TOOLTIP, prefix + " Level"); 
  }

//+------------------------------------------------------------------+
//| Clean up old entry lines                                         |
//+------------------------------------------------------------------+
void CleanUpOldLinesTA()
  {
   datetime currentTime = TimeCurrent();
   datetime expirationTimeThreshold = currentTime - (PeriodSeconds() * (g_lineDurationBars + 10)); 

   int totalObjects = ObjectsTotal(0, 0, OBJ_TREND); 
   bool chartNeedsRedraw = false; 

   for(int i = totalObjects - 1; i >= 0; i--) 
     {
      string name = ObjectName(0, i, 0, OBJ_TREND);
      bool isBullishLine = (StringFind(name, g_bullishEntryLinePrefix) == 0);
      bool isBearishLine = (StringFind(name, g_bearishEntryLinePrefix) == 0);

      if(isBullishLine || isBearishLine)
        {
         datetime lineCreationTime = (datetime)ObjectGetInteger(0, name, OBJPROP_TIME, 0);
         bool deleteLine = false;

         if(lineCreationTime < expirationTimeThreshold)
           {
            deleteLine = true;
            Print("CleanUpOldLinesTA: Deleting line '", name, "' due to time expiration.");
           }

         if(!deleteLine && g_zzSemaforHandle != INVALID_HANDLE)
           {
            int barShift = iBarShift(_Symbol, _Period, lineCreationTime);
            if(barShift < 0) 
              {
               continue; 
              }

            double arrowValue = 0;
            int bufferIndex = -1;

            if(isBullishLine)
              {
               bufferIndex = 0; 
              }
            else 
              {
               bufferIndex = 1; 
              }

            double tempBuffer[];
            if(CopyBuffer(g_zzSemaforHandle, bufferIndex, barShift, 1, tempBuffer) == 1)
              {
               arrowValue = tempBuffer[0];
              }
            else
              {
               Print("CleanUpOldLinesTA: Error copying ZZ Semafor buffer for line '", name, "', barShift ", barShift, ". Error: ", GetLastError());
               continue; 
              }
            
            if(arrowValue == 0 || arrowValue == EMPTY_VALUE)
              {
               deleteLine = true;
               Print("CleanUpOldLinesTA: Deleting line '", name, "' due to semafor repaint (arrow no longer at ", TimeToString(lineCreationTime), ").");
              }
           }
         else if (!deleteLine && g_zzSemaforHandle == INVALID_HANDLE)
           {
           }

         if(deleteLine)
           {
            ObjectDelete(0, name);
            chartNeedsRedraw = true;
           }
        }
     }

   if(chartNeedsRedraw)
     {
     }
  }

//+------------------------------------------------------------------+
//| Find Latest Semafor                                              |
//| Iterates backwards to find the most recent semafor signal.       |
//+------------------------------------------------------------------+
bool FindLatestSemaforTA(int semaforBufferIndex, int &semaforBarShift, double &semaforPrice, double &semaforAnchorCandleRange, int lookbackLimit = 500)
{
   if(g_zzSemaforHandle == INVALID_HANDLE)
   {
      Print("FindLatestSemaforTA: Invalid ZZ Semafor Handle.");
      return false;
   }

   // Start searching from the current forming bar (shift=0) to include most recent signals.
   // User request: "Semafor's on the currently forming candle should also be considered"
   for(int shift = 0; shift < lookbackLimit; shift++)
   {
      if(IsStopped()) break; // Check if EA is stopping

      double semaforValueBuffer[];
      if(CopyBuffer(g_zzSemaforHandle, semaforBufferIndex, shift, 1, semaforValueBuffer) != 1)
      {
         Print("FindLatestSemaforTA: Error copying ZZ Semafor buffer for index ", semaforBufferIndex, ", shift ", shift, ". Error: ", GetLastError());
         return false; // Error copying buffer
      }

      if(semaforValueBuffer[0] > 0 && semaforValueBuffer[0] != EMPTY_VALUE)
      {
         semaforBarShift = shift;
         semaforPrice = semaforValueBuffer[0]; // This is the high or low of the semafor bar

         double semaforCandleHigh = iHigh(_Symbol, _Period, shift);
         double semaforCandleLow = iLow(_Symbol, _Period, shift);

         if(semaforCandleHigh == 0 || semaforCandleLow == 0) // Check for valid price data
         {
            Print("FindLatestSemaforTA: Could not get high/low for semafor bar at shift ", shift);
            return false; 
         }
         
         semaforAnchorCandleRange = semaforCandleHigh - semaforCandleLow;

         if(semaforAnchorCandleRange <= 0)
         {
            Print("FindLatestSemaforTA: Invalid candle range (<=0) for semafor bar at shift ", shift);
            // Potentially continue searching or return false. For now, let's consider it a failure for this semafor.
            return false; 
         }
         
         // Sanity check: if it's a high semafor, price should be the high. If low, price should be the low.
         if (semaforBufferIndex == 1 && MathAbs(semaforPrice - semaforCandleHigh) > _Point) {
             Print("FindLatestSemaforTA: High semafor price ", semaforPrice, " does not match candle high ", semaforCandleHigh, " at shift ", shift);
             // This might indicate a logic issue or data inconsistency, treat as not found or handle as error
             return false;
         }
         if (semaforBufferIndex == 0 && MathAbs(semaforPrice - semaforCandleLow) > _Point) {
             Print("FindLatestSemaforTA: Low semafor price ", semaforPrice, " does not match candle low ", semaforCandleLow, " at shift ", shift);
             return false;
         }

         Print("FindLatestSemaforTA: Found semafor. Index: ", semaforBufferIndex, ", Shift: ", shift, ", Price: ", semaforPrice, ", Range: ", semaforAnchorCandleRange);
         return true; // Found the latest semafor
      }
   }

   //Print("FindLatestSemaforTA: No semafor found within lookback limit for buffer index ", semaforBufferIndex);
   return false; // No semafor found within the lookback limit
}

//+------------------------------------------------------------------+
//| Update or Create Forming Line for current candle                 |
//+------------------------------------------------------------------+
void UpdateFormingLineTA(string lineName, datetime barTime, double price, color lineColor)
  {
   bool lineExists = (ObjectFind(0, lineName) != -1);
   double existingPrice = 0;

   if(lineExists)
     {
      existingPrice = ObjectGetDouble(0, lineName, OBJPROP_PRICE, 0);
      if(MathAbs(price - existingPrice) < (_Point / 2.0)) 
        {
         return;
        }
      ObjectDelete(0, lineName); 
     }

   datetime endTime = barTime + PeriodSeconds(); 

   if(!ObjectCreate(0, lineName, OBJ_TREND, 0, barTime, price, endTime, price))
     {
      Print("Failed to create/update forming line '", lineName, "'! Error: ", GetLastError());
      return;
     }

   ObjectSetInteger(0, lineName, OBJPROP_COLOR, lineColor);
   ObjectSetInteger(0, lineName, OBJPROP_WIDTH, g_lineWidth);
   ObjectSetInteger(0, lineName, OBJPROP_STYLE, g_lineStyle);
   ObjectSetInteger(0, lineName, OBJPROP_RAY_RIGHT, false);
   ObjectSetInteger(0, lineName, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, lineName, OBJPROP_BACK, true);
   ObjectSetString(0, lineName, OBJPROP_TOOLTIP, StringSubstr(lineName, StringLen(g_bullishEntryLinePrefix)) + " Level (Forming)"); 
  }

//+------------------------------------------------------------------+
//| Process New Bar for Signal Line Drawing                          |
//+------------------------------------------------------------------+
void ProcessNewBarTA()
  {
   if(g_zzSemaforHandle == INVALID_HANDLE)
     {
      return;
     }

   int c1 = 1; 

   double c1High = iHigh(_Symbol, _Period, c1);
   double c1Low = iLow(_Symbol, _Period, c1);
   datetime c1Time = iTime(_Symbol, _Period, c1);
   double c1Range = c1High - c1Low;

   if(c1Range <= 0)
     {
      return;
     }

   double highArrowBuffer[];
   double lowArrowBuffer[];
   bool newBearishSignal = false;
   bool newBullishSignal = false;

   if(CopyBuffer(g_zzSemaforHandle, 1, c1, 1, highArrowBuffer) == 1)
     {
      if(highArrowBuffer[0] > 0) 
        {
         newBearishSignal = true;
        }
     }
   else
     {
      Print("ProcessNewBarTA: Error copying high arrow buffer from ZZ Semafor. Error: ", GetLastError());
     }

   if(CopyBuffer(g_zzSemaforHandle, 0, c1, 1, lowArrowBuffer) == 1)
     {
      if(lowArrowBuffer[0] > 0) 
        {
         newBullishSignal = true;
        }
     }
   else
     {
      Print("ProcessNewBarTA: Error copying low arrow buffer from ZZ Semafor. Error: ", GetLastError());
     }

   bool lineDrawn = false; 

   if(newBearishSignal)
     {
      g_arrowBearish.signalUsed = false; 

      g_arrowBearish.candleTime = c1Time;
      g_arrowBearish.triggerPrice = c1High; 
      g_arrowBearish.candleRange = c1Range;
      g_arrowBearish.thresholdPrice = NormalizeDouble(c1High - ((InpSignalThreshold / 100.0) * c1Range), _Digits);

      DrawEntryLineTA(g_bearishEntryLinePrefix, c1Time, g_arrowBearish.thresholdPrice, g_bearishLineColor);
      Print("ProcessNewBarTA: New Bearish Signal (ZZ Semafor) at ", TimeToString(c1Time), ". Threshold: ", DoubleToString(g_arrowBearish.thresholdPrice, _Digits));
      lineDrawn = true;
     }

   if(newBullishSignal)
     {
      g_arrowBullish.signalUsed = false; 

      g_arrowBullish.candleTime = c1Time;
      g_arrowBullish.triggerPrice = c1Low; 
      g_arrowBullish.candleRange = c1Range;
      g_arrowBullish.thresholdPrice = NormalizeDouble(c1Low + ((InpSignalThreshold / 100.0) * c1Range), _Digits);
      
      DrawEntryLineTA(g_bullishEntryLinePrefix, c1Time, g_arrowBullish.thresholdPrice, g_bullishLineColor);
      Print("ProcessNewBarTA: New Bullish Signal (ZZ Semafor) at ", TimeToString(c1Time), ". Threshold: ", DoubleToString(g_arrowBullish.thresholdPrice, _Digits));
      lineDrawn = true;
     }
   
   if(lineDrawn)
     {
      ChartRedraw(); 
     }
  }

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
   if(_Point == 0)
     {
      Print("Error: Invalid point size for symbol ", _Symbol, ". EA cannot continue.");
      return(INIT_FAILED);
     }

   if(!AccountInfoInteger(ACCOUNT_TRADE_ALLOWED))
     {
      Print("Trading is not allowed for this account.");
      return(INIT_FAILED);
     }

   if(!MQLInfoInteger(MQL_TRADE_ALLOWED))
     {
      Print("Expert Advisor is not allowed to trade. Please check settings in Tools > Options > Expert Advisors.");
      return(INIT_FAILED);
     }

   trade.SetExpertMagicNumber(जी_EXPERT_MAGIC_NUMBER);
   
   g_currentExecutionType = InpExecutionType;

   CreateButton(g_buyButtonName, "BUY", 90, 50, 70, 25, clrGreen, clrWhite, 1); 
   CreateButton(g_sellButtonName, "SELL", 10, 50, 70, 25, clrRed, clrWhite, 1);

   string initialExecButtonText;
   if (g_currentExecutionType == EXECUTE_IMMEDIATE)
     initialExecButtonText = "Exec: Imm"; 
   else
     initialExecButtonText = "Exec: Next";  

   CreateButton(g_execTypeButtonName, initialExecButtonText, 190, 50, 85, 25, clrBlue, clrWhite, 1, 8); 

   if(ObjectCreate(0, g_pendingIndicatorName, OBJ_RECTANGLE_LABEL, 0, 0, 0))
     {
      ObjectSetInteger(0, g_pendingIndicatorName, OBJPROP_CORNER, 1); 
      ObjectSetInteger(0, g_pendingIndicatorName, OBJPROP_XDISTANCE, 285); 
      ObjectSetInteger(0, g_pendingIndicatorName, OBJPROP_YDISTANCE, 50);
      ObjectSetInteger(0, g_pendingIndicatorName, OBJPROP_XSIZE, 25);
      ObjectSetInteger(0, g_pendingIndicatorName, OBJPROP_YSIZE, 25);
      ObjectSetInteger(0, g_pendingIndicatorName, OBJPROP_BGCOLOR, clrLightGray); 
      ObjectSetInteger(0, g_pendingIndicatorName, OBJPROP_BORDER_TYPE, BORDER_FLAT); 
      ObjectSetInteger(0, g_pendingIndicatorName, OBJPROP_SELECTABLE, 0); 
      ObjectSetInteger(0, g_pendingIndicatorName, OBJPROP_BACK, 0); 
      ObjectSetString(0, g_pendingIndicatorName, OBJPROP_TOOLTIP, "Pending Trade Status");
     }
   else
     {
      Print("Error creating pending trade indicator object '", g_pendingIndicatorName, "': ", GetLastError());
     }

   // Create Retracement Labels
   // CORNER_RIGHT_UPPER = 1
   // X_Offset for right corner means distance from right edge. Y_Offset is distance from top edge.
   // Let's position them below the existing buttons/indicators.
   // Buttons are at Y=50, Height=25. So bottom of buttons is around Y=75.
   // Indicator is at Y=50, Height=25.
   // Let's start labels at Y=80 or so.
   // User request: High Ret (Magenta) above Low Ret (Aqua). CORNER_RIGHT_UPPER.
   CreateRetracementLabelTA(g_highRetracementLabelName, "High Ret: ---%", clrMagenta, 1, 325, 50); // Magenta, 80 from top
   CreateRetracementLabelTA(g_lowRetracementLabelName, "Low Ret: ---%", clrAqua,    1, 325, 35); // Aqua, 95 from top


   Print("ZZ_Semafor_Visual_EA initialized successfully. Magic Number: ", जी_EXPERT_MAGIC_NUMBER);

   g_zzSemaforHandle = iCustom(NULL, 0, "Custom\\Single_Level_ZZ_Semafor");
   if(g_zzSemaforHandle == INVALID_HANDLE)
     {
      Print("Error: Failed to load Single_Level_ZZ_Semafor indicator. EA cannot continue.");
      return(INIT_FAILED);
     }
   else
     {
      Print("Single_Level_ZZ_Semafor indicator loaded successfully. Handle: ", g_zzSemaforHandle);
     }
   ResetSignalDataTA(g_arrowBearish);
   ResetSignalDataTA(g_arrowBullish);

   Print("TradeAssistant EA initialized. Immediate Pending: ", g_immediateTradePending, ", NextCandle Pending: ", g_tradeOnNextCandlePending);
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   if(g_zzSemaforHandle != INVALID_HANDLE)
     {
      IndicatorRelease(g_zzSemaforHandle);
      Print("Single_Level_ZZ_Semafor indicator released. Handle: ", g_zzSemaforHandle);
      g_zzSemaforHandle = INVALID_HANDLE; 
     }

   ObjectDelete(0, g_buyButtonName);
   ObjectDelete(0, g_sellButtonName);
   ObjectDelete(0, g_execTypeButtonName); 
   ObjectDelete(0, g_pendingIndicatorName); 
   ObjectDelete(0, g_highRetracementLabelName);
   ObjectDelete(0, g_lowRetracementLabelName);
  }
//+------------------------------------------------------------------+
//| Trailing Stop Logic                                              |
//+------------------------------------------------------------------+
void TrailingStopModifyOrders()
  {
   if(InpTrailingStop <= 0) 
      return;

   for(int i = PositionsTotal() - 1; i >= 0; i--) 
     {
      if(PositionGetSymbol(i) == _Symbol) 
        {
         long positionTicket = PositionGetInteger(POSITION_TICKET);
         ENUM_POSITION_TYPE positionType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
         double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
         double currentSl = PositionGetDouble(POSITION_SL);
         double currentTp = PositionGetDouble(POSITION_TP); 
         double currentPrice = 0;

         if(positionType == POSITION_TYPE_BUY)
           {
            currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
            if(currentPrice == 0) 
              {
               continue; 
              }

            if(currentPrice >= openPrice + InpStartTrailingPoint * _Point)
              {
               double proposed_sl = currentPrice - InpTrailingStop * _Point;

               if(proposed_sl > openPrice &&
                  (currentSl == 0 || proposed_sl > currentSl) &&
                  (currentSl == 0 || (proposed_sl - currentSl) >= InpTrailingStep * _Point || InpTrailingStep == 0) ) 
                 {
                  if(trade.PositionModify(positionTicket, proposed_sl, currentTp))
                    {
                     Print("Trailing stop updated for BUY #", positionTicket, " to ", DoubleToString(proposed_sl, _Digits));
                    }
                  else
                    {
                     Print("Error modifying trailing stop for BUY position #", positionTicket, ": ", trade.ResultRetcode(), " (", trade.ResultRetcodeDescription(), ")");
                    }
                 }
              }
           }
         else if(positionType == POSITION_TYPE_SELL)
           {
            currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_ASK); 
            if(currentPrice == 0) 
              { 
               Print("TrailingStopModifyOrders: Could not get ASK price for SELL position #", positionTicket); 
               continue; 
              }

            if(currentPrice <= openPrice - InpStartTrailingPoint * _Point)
              {
               double proposed_sl = currentPrice + InpTrailingStop * _Point;

               if(proposed_sl < openPrice && 
                  (currentSl == 0 || proposed_sl < currentSl) && 
                  (currentSl == 0 || (currentSl - proposed_sl) >= InpTrailingStep * _Point || InpTrailingStep == 0) ) 
                 {
                  if(trade.PositionModify(positionTicket, proposed_sl, currentTp))
                    {
                     Print("Trailing stop updated for SELL position #", positionTicket, " to ", DoubleToString(proposed_sl, _Digits));
                    }
                  else
                    {
                     Print("Error modifying trailing stop for SELL position #", positionTicket, ": ", trade.ResultRetcode(), " (", trade.ResultRetcodeDescription(), ")");
                    }
                 }
              }
           }
        }
     }
  }

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
datetime g_lastBarTime = 0; 

void OnTick()
  {
   // --- Retracement Label Logic ---
   bool labelsUpdated = false;
   int    latestHighSemaforBarShift = -1;
   double latestHighSemaforPrice = 0;
   double latestHighSemaforAnchorCandleRange = 0;
   string highLabelText = "High Ret: N/A";

   if(FindLatestSemaforTA(1, latestHighSemaforBarShift, latestHighSemaforPrice, latestHighSemaforAnchorCandleRange))
     {
      double currentBidPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(currentBidPrice > 0 && latestHighSemaforAnchorCandleRange > 0)
        {
         double retracementPct = (latestHighSemaforPrice - currentBidPrice) / latestHighSemaforAnchorCandleRange * 100.0;
         highLabelText = "High Ret: " + DoubleToString(retracementPct, 1) + "%";
        }
      else if (latestHighSemaforAnchorCandleRange <= 0)
        {
         highLabelText = "High Ret: Range Err";
        }
      else
        {
         highLabelText = "High Ret: Price Err";
        }
     }

   if(ObjectGetString(0, g_highRetracementLabelName, OBJPROP_TEXT) != highLabelText)
     {
      ObjectSetString(0, g_highRetracementLabelName, OBJPROP_TEXT, highLabelText);
      labelsUpdated = true;
     }

   int    latestLowSemaforBarShift = -1;
   double latestLowSemaforPrice = 0;
   double latestLowSemaforAnchorCandleRange = 0;
   string lowLabelText = "Low Ret: N/A";

   if(FindLatestSemaforTA(0, latestLowSemaforBarShift, latestLowSemaforPrice, latestLowSemaforAnchorCandleRange))
     {
      double currentAskPrice = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(currentAskPrice > 0 && latestLowSemaforAnchorCandleRange > 0)
        {
         double retracementPct = (currentAskPrice - latestLowSemaforPrice) / latestLowSemaforAnchorCandleRange * 100.0;
         lowLabelText = "Low Ret: " + DoubleToString(retracementPct, 1) + "%";
        }
      else if (latestLowSemaforAnchorCandleRange <= 0)
        {
         lowLabelText = "Low Ret: Range Err";
        }
      else
        {
         lowLabelText = "Low Ret: Price Err";
        }
     }
   
   if(ObjectGetString(0, g_lowRetracementLabelName, OBJPROP_TEXT) != lowLabelText)
     {
      ObjectSetString(0, g_lowRetracementLabelName, OBJPROP_TEXT, lowLabelText);
      labelsUpdated = true;
     }
   // --- End of Retracement Label Logic ---

   bool formingLinePotentiallyDeleted = false;
   if(ObjectFind(0, g_bullishFormingLineName) != -1)
     {
      ObjectDelete(0, g_bullishFormingLineName);
      formingLinePotentiallyDeleted = true;
     }
   if(ObjectFind(0, g_bearishFormingLineName) != -1)
     {
      ObjectDelete(0, g_bearishFormingLineName);
      formingLinePotentiallyDeleted = true;
     }

   CleanUpOldLinesTA();

   if(ObjectFind(0,g_pendingIndicatorName) == 0) 
     {
      if (!g_tradeOnNextCandlePending && !g_immediateTradePending && ObjectGetInteger(0, g_pendingIndicatorName, OBJPROP_BGCOLOR, 0) != clrLightGray)
        {
         ObjectSetInteger(0, g_pendingIndicatorName, OBJPROP_BGCOLOR, clrLightGray);
        }
     }

   datetime newBarDTime = (datetime)SeriesInfoInteger(_Symbol, _Period, SERIES_LASTBAR_DATE);
   bool isNewBar = false;
   if(newBarDTime != g_lastBarTime)
     {
      isNewBar = true;
      g_lastBarTime = newBarDTime;
     }

   if(isNewBar)
     {
      Print("New bar detected at ", TimeToString(newBarDTime));
      ProcessNewBarTA(); 

      if(g_tradeOnNextCandlePending && g_pendingOrderType != WRONG_VALUE && !g_immediateTradePending)
        {
         Print("OnTick/NewBar: Executing 'Next Candle' pending order: ", EnumToString(g_pendingOrderType));
         ExecuteTrade(g_pendingOrderType); 
        }
     }

   if(g_immediateTradePending)
     {
      datetime currentCandleOpenTime = iTime(_Symbol, _Period, 0);
      string pendingTypeStr = (g_immediatePendingOrderType == ORDER_TYPE_BUY) ? "BUY" : "SELL";

      if(currentCandleOpenTime > g_pendingTradeCandleTime)
        {
         Print("OnTick: Immediate pending ", pendingTypeStr, " trade EXPIRED due to new candle formation.");
         g_immediateTradePending = false;
         g_immediatePendingOrderType = WRONG_VALUE;
         g_pendingTradeCandleTime = 0;
         ObjectSetInteger(0, g_pendingIndicatorName, OBJPROP_BGCOLOR, clrLightGray);
         ChartRedraw(); 
        }
      else
        {
         Print("OnTick: Re-evaluating conditions for IMMEDIATE PENDING ", pendingTypeStr, " trade.");
         ExecuteTrade(g_immediatePendingOrderType); 
        }
     }
   
   bool formingLineProcessed = false; 
   if(g_zzSemaforHandle != INVALID_HANDLE)
     {
      double currentHigh = iHigh(_Symbol, _Period, 0);
      double currentLow = iLow(_Symbol, _Period, 0);
      datetime currentTime = iTime(_Symbol, _Period, 0);

      if(currentHigh != 0 && currentLow != 0) 
        {
         double currentRange = currentHigh - currentLow;
         if(currentRange > 0)
           {
            double highArrowBuffer[];
            double lowArrowBuffer[];
            bool isBearishSemafor = false;
            bool isBullishSemafor = false;

            if(CopyBuffer(g_zzSemaforHandle, 1, 0, 1, highArrowBuffer) == 1 && highArrowBuffer[0] > 0)
              {
               isBearishSemafor = true;
              }

            if(CopyBuffer(g_zzSemaforHandle, 0, 0, 1, lowArrowBuffer) == 1 && lowArrowBuffer[0] > 0)
              {
               isBullishSemafor = true;
              }

            if(isBearishSemafor)
              {
               double retracementPrice = NormalizeDouble(currentHigh - ((InpSignalThreshold / 100.0) * currentRange), _Digits);
               UpdateFormingLineTA(g_bearishFormingLineName, currentTime, retracementPrice, g_bearishLineColor);
               formingLineProcessed = true;
               if(ObjectFind(0, g_bullishFormingLineName) != -1) ObjectDelete(0, g_bullishFormingLineName);
              }
            else 
              {
               if(ObjectFind(0, g_bearishFormingLineName) != -1)
                 {
                  ObjectDelete(0, g_bearishFormingLineName);
                  formingLineProcessed = true;
                 }
              }

            if(isBullishSemafor)
              {
               double retracementPrice = NormalizeDouble(currentLow + ((InpSignalThreshold / 100.0) * currentRange), _Digits);
               UpdateFormingLineTA(g_bullishFormingLineName, currentTime, retracementPrice, g_bullishLineColor);
               formingLineProcessed = true;
               if(ObjectFind(0, g_bearishFormingLineName) != -1) ObjectDelete(0, g_bearishFormingLineName);
              }
            else 
              {
               if(ObjectFind(0, g_bullishFormingLineName) != -1)
                 {
                  ObjectDelete(0, g_bullishFormingLineName);
                  formingLineProcessed = true;
                 }
              }
           }
        }
     }
   else 
     {
      if(ObjectFind(0, g_bullishFormingLineName) != -1)
        {
         ObjectDelete(0, g_bullishFormingLineName);
         formingLineProcessed = true;
        }
      if(ObjectFind(0, g_bearishFormingLineName) != -1)
        {
         ObjectDelete(0, g_bearishFormingLineName);
         formingLineProcessed = true;
        }
     }

   TrailingStopModifyOrders();
   
   if(formingLineProcessed || formingLinePotentiallyDeleted || labelsUpdated) // Added labelsUpdated
     {
      ChartRedraw();
     }
  }
//+------------------------------------------------------------------+
//| Attempt Immediate Trade Execution or Set Pending                 |
//+------------------------------------------------------------------+
void AttemptImmediateTradeExecution(ENUM_ORDER_TYPE orderType)
  {
   bool conditionsMet = CheckTradeConditions(orderType); 
   string tradeTypeStr = (orderType == ORDER_TYPE_BUY) ? "BUY" : "SELL";

   if(conditionsMet)
     {
      Print("AttemptImmediateTradeExecution: Conditions met for ", tradeTypeStr, ". Executing trade.");
      ExecuteTrade(orderType); 
     }
   else
     {
      g_immediateTradePending = true;
      g_immediatePendingOrderType = orderType;
      g_pendingTradeCandleTime = iTime(_Symbol, _Period, 0);

      color pendingColor = (orderType == ORDER_TYPE_BUY) ? clrPendingImmediateBuy : clrPendingImmediateSell;
      ObjectSetInteger(0, g_pendingIndicatorName, OBJPROP_BGCOLOR, pendingColor);
      
      Print("AttemptImmediateTradeExecution: Conditions NOT met for ", tradeTypeStr, ". Trade set to PENDING for current candle. Indicator: ", ColorToString(pendingColor));
      ChartRedraw(); 
     }
  }

//+------------------------------------------------------------------+
//| ChartEvent function                                              |
//+------------------------------------------------------------------+
void OnChartEvent(const int id,
                  const long &lparam,
                  const double &dparam,
                  const string &sparam)
  {
   if(id == CHARTEVENT_OBJECT_CLICK)
     {
      ObjectSetInteger(0, sparam, OBJPROP_STATE, 0); 
      ChartRedraw();

      if(sparam == g_buyButtonName)
        {
         Print("Buy button clicked. Execution Type: ", EnumToString(g_currentExecutionType));
         if(g_currentExecutionType == EXECUTE_IMMEDIATE)
           {
            if(g_tradeOnNextCandlePending)
              {
               Print("Cancelling previously armed 'Next Candle' trade due to new 'Immediate' Buy request.");
               g_tradeOnNextCandlePending = false;
               g_pendingOrderType = WRONG_VALUE;
              }
            if(g_immediateTradePending && g_immediatePendingOrderType == ORDER_TYPE_SELL)
              {
                Print("Cancelling previous immediate SELL pending trade due to new BUY request.");
                g_immediateTradePending = false;
                g_immediatePendingOrderType = WRONG_VALUE;
                g_pendingTradeCandleTime = 0;
              }
            AttemptImmediateTradeExecution(ORDER_TYPE_BUY);
           }
         else 
           {
            if(g_immediateTradePending)
              {
               Print("Cancelling previously armed 'Immediate' pending trade due to new 'Next Candle' Buy request.");
               g_immediateTradePending = false;
               g_immediatePendingOrderType = WRONG_VALUE;
               g_pendingTradeCandleTime = 0;
              }

            if(g_tradeOnNextCandlePending && g_pendingOrderType == ORDER_TYPE_SELL)
              {
               Print("A Sell order is already pending for the next candle. Cannot set a Buy order simultaneously. Sell pending remains.");
              }
            else
              {
               g_tradeOnNextCandlePending = true;
               g_pendingOrderType = ORDER_TYPE_BUY;
               ObjectSetInteger(0, g_pendingIndicatorName, OBJPROP_BGCOLOR, clrGreen); 
               Print("Buy order armed for Next Candle. Indicator: Green.");
              }
           }
        }
      else if(sparam == g_sellButtonName)
        {
         Print("Sell button clicked. Execution Type: ", EnumToString(g_currentExecutionType));
         if(g_currentExecutionType == EXECUTE_IMMEDIATE)
           {
            if(g_tradeOnNextCandlePending)
              {
               Print("Cancelling previously armed 'Next Candle' trade due to new 'Immediate' Sell request.");
               g_tradeOnNextCandlePending = false;
               g_pendingOrderType = WRONG_VALUE;
              }
            if(g_immediateTradePending && g_immediatePendingOrderType == ORDER_TYPE_BUY)
              {
                Print("Cancelling previous immediate BUY pending trade due to new SELL request.");
                g_immediateTradePending = false;
                g_immediatePendingOrderType = WRONG_VALUE;
                g_pendingTradeCandleTime = 0;
              }
            AttemptImmediateTradeExecution(ORDER_TYPE_SELL);
           }
         else 
           {
            if(g_immediateTradePending)
              {
               Print("Cancelling previously armed 'Immediate' pending trade due to new 'Next Candle' Sell request.");
               g_immediateTradePending = false;
               g_immediatePendingOrderType = WRONG_VALUE;
               g_pendingTradeCandleTime = 0;
              }

            if(g_tradeOnNextCandlePending && g_pendingOrderType == ORDER_TYPE_BUY)
              {
               Print("A Buy order is already pending for the next candle. Cannot set a Sell order simultaneously. Buy pending remains.");
              }
            else
              {
               g_tradeOnNextCandlePending = true;
               g_pendingOrderType = ORDER_TYPE_SELL;
               ObjectSetInteger(0, g_pendingIndicatorName, OBJPROP_BGCOLOR, clrRed); 
               Print("Sell order armed for Next Candle. Indicator: Red.");
              }
           }
        }
      else if(sparam == g_execTypeButtonName)
        {
         Print("Execution type button clicked.");
         if(g_currentExecutionType == EXECUTE_IMMEDIATE) 
           {
            g_currentExecutionType = EXECUTE_ON_NEXT_CANDLE;
            ObjectSetString(0, g_execTypeButtonName, OBJPROP_TEXT, "Exec: Next");
            Print("Execution type changed to: Next Candle.");
            if(g_immediateTradePending)
              {
               Print("Cancelling active 'Immediate' pending trade due to switch to 'Next Candle' mode.");
               g_immediateTradePending = false;
               g_immediatePendingOrderType = WRONG_VALUE;
               g_pendingTradeCandleTime = 0;
               ObjectSetInteger(0, g_pendingIndicatorName, OBJPROP_BGCOLOR, clrLightGray); 
               Print("Immediate pending trade cancelled. Indicator: Gray.");
              }
            if (!g_tradeOnNextCandlePending && !g_immediateTradePending) 
              {
                 ObjectSetInteger(0, g_pendingIndicatorName, OBJPROP_BGCOLOR, clrLightGray);
                 Print("No trades pending. Indicator: Gray.");
              }
            else if (g_tradeOnNextCandlePending) 
              {
                Print("Existing 'Next Candle' pending trade remains active.");
              }
           }
         else 
           {
            g_currentExecutionType = EXECUTE_IMMEDIATE;
            ObjectSetString(0, g_execTypeButtonName, OBJPROP_TEXT, "Exec: Imm");
            Print("Execution type changed to: Immediate.");
            if (g_tradeOnNextCandlePending)
              {
               Print("Cancelling active 'Next Candle' pending trade due to switch to 'Immediate' mode.");
               g_tradeOnNextCandlePending = false;
               g_pendingOrderType = WRONG_VALUE;
               ObjectSetInteger(0, g_pendingIndicatorName, OBJPROP_BGCOLOR, clrLightGray); 
               Print("Next candle pending trade cancelled. Indicator: Gray.");
              }
            if(g_immediateTradePending)
              {
                 Print("Existing 'Immediate' pending trade remains active.");
              }
            if (!g_tradeOnNextCandlePending && !g_immediateTradePending)
              {
                 ObjectSetInteger(0, g_pendingIndicatorName, OBJPROP_BGCOLOR, clrLightGray);
                 Print("No trades pending. Indicator: Gray.");
              }
           }
        }
     }
  }
//+------------------------------------------------------------------+
