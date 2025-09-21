#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>

input group "=== TRADING ==="
input int      TakeProfit = 50;
input int      StopLoss = 50;
input int      TP_Step = 1;
input int      SL_Step = 1;
input int      Slippage = 3;

input group "=== DASHBOARD ==="
input double UIScale = 1.0;  // User adjustable scale factor
input int      DashX = 30;
input int      DashY = 30;
input int      ButtonSize = 90;

#define SX(v) (int)(v * UIScale)
#define SY(v) (int)(v * UIScale)

input group "=== KEYBOARD HOTKEYS ==="
input bool     EnableHotkeys = true;
input string   BuyKey = "1";
input string   SellKey = "3"; 
input string   CloseKey = "2";
input string   MinimizeKey = "m";
input string   ExitKey = "x";

input group "=== RISK ==="
input int      MaxPositions = 1;

// --- TP/SL UI ---
enum SLTP_MODE {
    MODE_POINTS,
    MODE_CURRENCY
};

SLTP_MODE tpMode = MODE_POINTS;
SLTP_MODE slMode = MODE_POINTS;

double currentTakeProfit;
double currentStopLoss;

string tpDownBtn, tpUpBtn, tpModeBtn, tpLabel;
string slDownBtn, slUpBtn, slModeBtn, slLabel;
// --- END TP/SL UI ---

CTrade trade;
CPositionInfo position;

string prefix = "FutureDash_";
double dailyPL = 0;
datetime resetTime;

string buyBtn = prefix + "BUY";
string sellBtn = prefix + "SELL";
string closeBtn = prefix + "CLOSE";
string posLbl = prefix + "POS";
string plLbl = prefix + "PL";
string spreadLbl = prefix + "SPREAD";
string statusLbl = prefix + "STATUS";
string mainPanel = prefix + "PANEL";
string glowPanel = prefix + "GLOW";
string lotLbl = prefix + "LOT";

// --- UI State & Elements ---
bool isMinimized = false;
string minimizeBtn = prefix + "MINIMIZE";
string maximizeBtn = prefix + "MAXIMIZE";
string closeIconBtn = prefix + "CLOSE_ICON";
string minimizedPanel = prefix + "MINIMIZED_PANEL";
// --- END UI State & Elements ---

double GetLotSize()
{
   double lot = AccountInfoDouble(ACCOUNT_BALANCE) / 1000.0;
   // Ensure lot respects broker min/max requirements
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);

   lot = MathFloor(lot / lotStep) * lotStep; // round to step
   lot = MathMax(minLot, MathMin(maxLot, lot)); // clamp to min/max

   return lot;
}

int OnInit()
{
    trade.SetExpertMagicNumber(888888);
    trade.SetDeviationInPoints(Slippage);
    resetTime = TimeCurrent();
    dailyPL = GetDailyPL();
    
    // --- TP/SL UI Init ---
    currentTakeProfit = TakeProfit;
    currentStopLoss = StopLoss;
    
    tpDownBtn = prefix + "TP_DOWN";
    tpUpBtn = prefix + "TP_UP";
    tpModeBtn = prefix + "TP_MODE";
    tpLabel = prefix + "TP_LABEL";
    slDownBtn = prefix + "SL_DOWN";
    slUpBtn = prefix + "SL_UP";
    slModeBtn = prefix + "SL_MODE";
    slLabel = prefix + "SL_LABEL";
    // --- END TP/SL UI Init ---
    
    Print("=== DASHBOARD INITIALIZATION ===");
    Print("Symbol: ", _Symbol);
    Print("Lot Size: ", GetLotSize());
    Print("Take Profit: ", TakeProfit);
    Print("Stop Loss: ", StopLoss);
    Print("Magic Number: ", 888888);
    Print("Trading allowed: ", CanTrade() ? "YES" : "NO");
    
    CreateFuturisticDashboard();
    Print("Click buttons or use NUMPAD: 1=BUY 3=SELL 2=CLOSE");
    return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
    DeleteAllObjects();
    Print("Dashboard - OFFLINE");
}

void OnTick()
{
    CheckDailyReset();
    if(!isMinimized)
    {
        UpdateDashboard();
    }
}

void MinimizeDashboard()
{
    DeleteAllObjects();
    isMinimized = true;

    int x = SX(DashX);
    int y = SY(DashY);
    int panelW = SX(60);
    int panelH = SY(25);

    CreateMainPanel(minimizedPanel, x - SX(10), y - SY(10), panelW, panelH);

    int iconBtnSize = SX(20);
    int iconBtnY = y - SY(8);
    int iconBtnX = x + panelW - iconBtnSize - SX(15);
    
    CreateIconButton(closeIconBtn, iconBtnX, iconBtnY, iconBtnSize, iconBtnSize, "x", C'25,25,45', C'255,0,0', C'255,255,255');
    CreateIconButton(maximizeBtn, iconBtnX - iconBtnSize - SX(2), iconBtnY, iconBtnSize, iconBtnSize, "y", C'25,25,45', C'100,149,237', C'255,255,255');
    
    ChartRedraw();
}

void MaximizeDashboard()
{
    DeleteAllObjects();
    isMinimized = false;
    CreateFuturisticDashboard();
}

void OnChartEvent(const int id, const long& lparam, const double& dparam, const string& sparam)
{
    if(id == CHARTEVENT_OBJECT_CLICK)
    {
        if(sparam == buyBtn)
        {
            ExecuteBuy();
            FlashButton(buyBtn, C'0,255,100');
            ObjectSetInteger(0, buyBtn, OBJPROP_STATE, false);
        }
        else if(sparam == sellBtn)
        {
            ExecuteSell();
            FlashButton(sellBtn, C'255,50,100');
            ObjectSetInteger(0, sellBtn, OBJPROP_STATE, false);
        }
        else if(sparam == closeBtn)
        {
            CloseLastPosition();
            FlashButton(closeBtn, C'255,150,0');
            ObjectSetInteger(0, closeBtn, OBJPROP_STATE, false);
        }
        // --- TP/SL UI Events ---
        else if(sparam == tpUpBtn) { currentTakeProfit += TP_Step; UpdateTPDisplay(); }
        else if(sparam == tpDownBtn) { currentTakeProfit = MathMax(0, currentTakeProfit - TP_Step); UpdateTPDisplay(); }
        else if(sparam == tpModeBtn) { tpMode = (tpMode == MODE_POINTS) ? MODE_CURRENCY : MODE_POINTS; UpdateTPDisplay(); }
        else if(sparam == slUpBtn) { currentStopLoss += SL_Step; UpdateSLDisplay(); }
        else if(sparam == slDownBtn) { currentStopLoss = MathMax(0, currentStopLoss - SL_Step); UpdateSLDisplay(); }
        else if(sparam == slModeBtn) { slMode = (slMode == MODE_POINTS) ? MODE_CURRENCY : MODE_POINTS; UpdateSLDisplay(); }
        // --- END TP/SL UI Events ---
        else if(sparam == minimizeBtn)
        {
            MinimizeDashboard();
        }
        else if(sparam == maximizeBtn)
        {
            MaximizeDashboard();
        }
        else if(sparam == closeIconBtn)
        {
            ExpertRemove();
        }
        ChartRedraw();
    }
    else if(id == CHARTEVENT_KEYDOWN && EnableHotkeys)
    {
        int keyCode = (int)lparam;
        string key = "";
        
        if(keyCode >= 48 && keyCode <= 57)      
            key = CharToString((uchar)keyCode);
        else if(keyCode >= 96 && keyCode <= 105) 
            key = CharToString((uchar)(keyCode - 48));
        else
            key = CharToString((uchar)keyCode);
        
        Print("Key pressed: ", key, " (code: ", keyCode, ")");
        
        bool isBuyKey = (key == BuyKey) || (keyCode == 49) || (keyCode == 97);   
        bool isSellKey = (key == SellKey) || (keyCode == 51) || (keyCode == 99);  
        bool isCloseKey = (key == CloseKey) || (keyCode == 50) || (keyCode == 98); 
        
        if(isBuyKey)
        {
            ExecuteBuy();
            FlashButton(buyBtn, C'0,255,100');
        }
        else if(isSellKey)
        {
            ExecuteSell();
            FlashButton(sellBtn, C'255,50,100');
        }
        else if(isCloseKey)
        {
            CloseLastPosition();
            FlashButton(closeBtn, C'255,150,0');
        }
        else if(StringCompare(key, MinimizeKey, false) == 0)
        {
            if(isMinimized)
                MaximizeDashboard();
            else
                MinimizeDashboard();
        }
        else if(StringCompare(key, ExitKey, false) == 0)
        {
            ExpertRemove();
        }
        
        ChartRedraw();
    }
}

void UpdateTPDisplay()
{
    string currencySymbol = AccountInfoString(ACCOUNT_CURRENCY);
    string mode = (tpMode == MODE_POINTS) ? "points" : currencySymbol;
    string value = (tpMode == MODE_POINTS) ? IntegerToString((int)currentTakeProfit) : DoubleToString(currentTakeProfit, 2);
    ObjectSetString(0, tpLabel, OBJPROP_TEXT, "TP: " + value + " " + mode);
    ObjectSetString(0, tpModeBtn, OBJPROP_TEXT, (tpMode == MODE_POINTS) ? "P" : currencySymbol);
}

void UpdateSLDisplay()
{
    string currencySymbol = AccountInfoString(ACCOUNT_CURRENCY);
    string mode = (slMode == MODE_POINTS) ? "points" : currencySymbol;
    string value = (slMode == MODE_POINTS) ? IntegerToString((int)currentStopLoss) : DoubleToString(currentStopLoss, 2);
    ObjectSetString(0, slLabel, OBJPROP_TEXT, "SL: " + value + " " + mode);
    ObjectSetString(0, slModeBtn, OBJPROP_TEXT, (slMode == MODE_POINTS) ? "P" : currencySymbol);
}

void CreateProButtonSmall(string name, int x, int y, int w, int h, string text, color bg, color hover, color textColor)
{
    ObjectCreate(0, name, OBJ_BUTTON, 0, 0, 0);
    ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
    ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
    ObjectSetInteger(0, name, OBJPROP_XSIZE, w);
    ObjectSetInteger(0, name, OBJPROP_YSIZE, h);
    ObjectSetString(0, name, OBJPROP_TEXT, text);
    ObjectSetInteger(0, name, OBJPROP_COLOR, textColor);
    ObjectSetInteger(0, name, OBJPROP_BGCOLOR, bg);
    ObjectSetInteger(0, name, OBJPROP_BORDER_COLOR, hover);
    ObjectSetInteger(0, name, OBJPROP_FONTSIZE, (int)(10 * UIScale));
    ObjectSetString(0, name, OBJPROP_FONT, "Arial Bold");
    ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
}

void CreateIconButton(string name, int x, int y, int w, int h, string text, color bg, color hover, color textColor)
{
    ObjectCreate(0, name, OBJ_BUTTON, 0, 0, 0);
    ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
    ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
    ObjectSetInteger(0, name, OBJPROP_XSIZE, w);
    ObjectSetInteger(0, name, OBJPROP_YSIZE, h);
    ObjectSetString(0, name, OBJPROP_TEXT, text);
    ObjectSetInteger(0, name, OBJPROP_COLOR, textColor);
    ObjectSetInteger(0, name, OBJPROP_BGCOLOR, bg);
    ObjectSetInteger(0, name, OBJPROP_BORDER_COLOR, hover);
    ObjectSetInteger(0, name, OBJPROP_FONTSIZE, (int)(10 * UIScale));
    ObjectSetString(0, name, OBJPROP_FONT, "Wingdings");
    ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
}


void CreateFuturisticDashboard()
{
    int x = SX(DashX);
    int y = SY(DashY);
    int btnW = SX(ButtonSize);
    int btnH = SY(40);
    int gap = SX(5);
    int panelW = (btnW * 3) + (gap * 2) + SX(20);
    int panelH = SY(280);
    
    CreateProPanel(glowPanel, x - SX(20), y - SY(20), panelW + SX(40), panelH + SY(40));
    CreateMainPanel(mainPanel, x - SX(10), y - SY(10), panelW + SX(20), panelH + SY(20));
    
    int btnY = y + SY(10);
    int btnX = x + SX(10);
    CreateProButton(buyBtn, btnX, btnY, btnW, btnH, "▲ BUY", C'34,139,34', C'0,255,0', C'255,255,255');
    btnX += btnW + gap;
    CreateProButton(sellBtn, btnX, btnY, btnW, btnH, "▼ SELL", C'220,20,60', C'255,0,100', C'255,255,255');
    btnX += btnW + gap;
    CreateProButton(closeBtn, btnX, btnY, btnW, btnH, "✕ CLOSE", C'255,140,0', C'255,165,0', C'0,0,0');
    
    // --- TP/SL UI Elements ---
    int controlsY = btnY + btnH + SY(15);
    CreateStatsPanel(prefix + "TP_PANEL", x + SX(5), controlsY, panelW - SX(10), SY(80));
    
    int smallBtnW = SX(30);
    int smallBtnH = SY(20);
    
    // Take Profit controls
    int tpY = controlsY + SY(15);
    CreateHeaderLabel(tpLabel, x + SX(15), tpY, "TP:", C'0,255,255');
    CreateProButtonSmall(tpDownBtn, x + SX(170), tpY - SY(5), smallBtnW, smallBtnH, "-", C'220,20,60', C'255,0,100', C'255,255,255');
    CreateProButtonSmall(tpUpBtn, x + SX(210), tpY - SY(5), smallBtnW, smallBtnH, "+", C'34,139,34', C'0,255,0', C'255,255,255');
    CreateProButtonSmall(tpModeBtn, x + SX(250), tpY - SY(5), SX(40), smallBtnH, "P", C'70,130,180', C'100,149,237', C'255,255,255');

    // Stop Loss controls
    int slY = controlsY + SY(45);
    CreateHeaderLabel(slLabel, x + SX(15), slY, "SL:", C'0,255,255');
    CreateProButtonSmall(slDownBtn, x + SX(170), slY - SY(5), smallBtnW, smallBtnH, "-", C'220,20,60', C'255,0,100', C'255,255,255');
    CreateProButtonSmall(slUpBtn, x + SX(210), slY - SY(5), smallBtnW, smallBtnH, "+", C'34,139,34', C'0,255,0', C'255,255,255');
    CreateProButtonSmall(slModeBtn, x + SX(250), slY - SY(5), SX(40), smallBtnH, "P", C'70,130,180', C'100,149,237', C'255,255,255');

    UpdateTPDisplay();
    UpdateSLDisplay();
    // --- END TP/SL UI Elements ---

    CreateStatsPanel(prefix + "STATS", x + SX(5), slY + SY(25), panelW - SX(10), SY(115));
    
    int statsY = slY + SY(35);
    CreateStatsLabel(posLbl, x + SX(15), statsY, "POSITIONS", "0", C'0,255,255');
    CreateStatsLabel(spreadLbl, x + SX(15), statsY + SY(20), "SPREAD", "0.0", C'255,215,0');
    CreateStatsLabel(plLbl, x + SX(15), statsY + SY(40), "DAILY P&L", "$0.00", C'50,205,50');
    CreateStatsLabel(statusLbl, x + SX(15), statsY + SY(60), "STATUS", "READY", C'0,191,255');
    CreateStatsLabel(lotLbl, x + SX(15), statsY + SY(80), "LOT SIZE", DoubleToString(GetLotSize(), 2), C'176,196,222');
    
    if(EnableHotkeys)
    {
        CreateHotkeyPanel(prefix + "HOTKEY_PANEL", x + SX(5), statsY + SY(105), panelW - SX(10), SY(25));
        string hotkeys = "HOTKEYS: ["+BuyKey+"] BUY ["+SellKey+"] SELL ["+CloseKey+"] CLOSE ["+MinimizeKey+"] MINIMIZE ["+ExitKey+"] EXIT";
        CreateHotkeyLabel(prefix + "HOTKEYS", x + SX(15), statsY + SY(110), hotkeys, C'176,196,222');
    }
    
    // --- Window Control Buttons ---
    int iconBtnSize = SX(20);
    int iconBtnY = y - SY(15);
    int iconBtnX = x + panelW - iconBtnSize + SX(10);
    
    CreateIconButton(closeIconBtn, iconBtnX, iconBtnY, iconBtnSize, iconBtnSize, "x", C'25,25,45', C'255,0,0', C'255,255,255');
    CreateIconButton(minimizeBtn, iconBtnX - iconBtnSize - SX(2), iconBtnY, iconBtnSize, iconBtnSize, ";", C'25,25,45', C'100,149,237', C'255,255,255');
    // --- END Window Control Buttons ---

    ChartRedraw();
}

void CreateProPanel(string name, int x, int y, int w, int h)
{
    ObjectCreate(0, name, OBJ_RECTANGLE_LABEL, 0, 0, 0);
    ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
    ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
    ObjectSetInteger(0, name, OBJPROP_XSIZE, w);
    ObjectSetInteger(0, name, OBJPROP_YSIZE, h);
    ObjectSetInteger(0, name, OBJPROP_BGCOLOR, C'15,15,35');
    ObjectSetInteger(0, name, OBJPROP_BORDER_COLOR, C'70,130,180');
    ObjectSetInteger(0, name, OBJPROP_BORDER_TYPE, BORDER_RAISED);
    ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
}

void CreateMainPanel(string name, int x, int y, int w, int h)
{
    ObjectCreate(0, name, OBJ_RECTANGLE_LABEL, 0, 0, 0);
    ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
    ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
    ObjectSetInteger(0, name, OBJPROP_XSIZE, w);
    ObjectSetInteger(0, name, OBJPROP_YSIZE, h);
    ObjectSetInteger(0, name, OBJPROP_BGCOLOR, C'25,25,45');
    ObjectSetInteger(0, name, OBJPROP_BORDER_COLOR, C'100,149,237');
    ObjectSetInteger(0, name, OBJPROP_BORDER_TYPE, BORDER_RAISED);
    ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
}

void CreateHeaderPanel(string name, int x, int y, int w, int h)
{
    ObjectCreate(0, name, OBJ_RECTANGLE_LABEL, 0, 0, 0);
    ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
    ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
    ObjectSetInteger(0, name, OBJPROP_XSIZE, w);
    ObjectSetInteger(0, name, OBJPROP_YSIZE, h);
    ObjectSetInteger(0, name, OBJPROP_BGCOLOR, C'35,35,65');
    ObjectSetInteger(0, name, OBJPROP_BORDER_COLOR, C'0,191,255');
    ObjectSetInteger(0, name, OBJPROP_BORDER_TYPE, BORDER_FLAT);
    ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
}

void CreateStatsPanel(string name, int x, int y, int w, int h)
{
    ObjectCreate(0, name, OBJ_RECTANGLE_LABEL, 0, 0, 0);
    ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
    ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
    ObjectSetInteger(0, name, OBJPROP_XSIZE, w);
    ObjectSetInteger(0, name, OBJPROP_YSIZE, h);
    ObjectSetInteger(0, name, OBJPROP_BGCOLOR, C'20,20,40');
    ObjectSetInteger(0, name, OBJPROP_BORDER_COLOR, C'75,75,95');
    ObjectSetInteger(0, name, OBJPROP_BORDER_TYPE, BORDER_FLAT);
    ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
}

void CreateHotkeyPanel(string name, int x, int y, int w, int h)
{
    ObjectCreate(0, name, OBJ_RECTANGLE_LABEL, 0, 0, 0);
    ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
    ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
    ObjectSetInteger(0, name, OBJPROP_XSIZE, w);
    ObjectSetInteger(0, name, OBJPROP_YSIZE, h);
    ObjectSetInteger(0, name, OBJPROP_BGCOLOR, C'30,30,50');
    ObjectSetInteger(0, name, OBJPROP_BORDER_COLOR, C'65,105,225');
    ObjectSetInteger(0, name, OBJPROP_BORDER_TYPE, BORDER_FLAT);
    ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
}

void CreateProButton(string name, int x, int y, int w, int h, string text, color bg, color hover, color textColor)
{
    ObjectCreate(0, name, OBJ_BUTTON, 0, 0, 0);
    ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
    ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
    ObjectSetInteger(0, name, OBJPROP_XSIZE, w);
    ObjectSetInteger(0, name, OBJPROP_YSIZE, h);
    ObjectSetString(0, name, OBJPROP_TEXT, text);
    ObjectSetInteger(0, name, OBJPROP_COLOR, textColor);
    ObjectSetInteger(0, name, OBJPROP_BGCOLOR, bg);
    ObjectSetInteger(0, name, OBJPROP_BORDER_COLOR, hover);
    ObjectSetInteger(0, name, OBJPROP_FONTSIZE, (int)(14 * UIScale));
    ObjectSetString(0, name, OBJPROP_FONT, "Arial Bold");
    ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
}

void CreateHeaderLabel(string name, int x, int y, string text, color clr)
{
    ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
    ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
    ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
    ObjectSetString(0, name, OBJPROP_TEXT, text);
    ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
    ObjectSetInteger(0, name, OBJPROP_FONTSIZE, (int)(12 * UIScale));
    ObjectSetString(0, name, OBJPROP_FONT, "Arial Bold");
    ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
}

void CreateStatsLabel(string name, int x, int y, string label, string value, color clr)
{
    ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
    ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
    ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
    ObjectSetString(0, name, OBJPROP_TEXT, label + ": " + value);
    ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
    ObjectSetInteger(0, name, OBJPROP_FONTSIZE, (int)(10 * UIScale));
    ObjectSetString(0, name, OBJPROP_FONT, "Arial");
    ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
}

void CreateHotkeyLabel(string name, int x, int y, string text, color clr)
{
    ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
    ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
    ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
    ObjectSetString(0, name, OBJPROP_TEXT, text);
    ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
    ObjectSetInteger(0, name, OBJPROP_FONTSIZE, (int)(8 * UIScale));
    ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
}

void DeleteAllObjects()
{
    ObjectDelete(0, glowPanel);
    ObjectDelete(0, mainPanel);
    ObjectDelete(0, minimizedPanel);
    ObjectDelete(0, prefix + "STATS");
    ObjectDelete(0, buyBtn);
    ObjectDelete(0, sellBtn);
    ObjectDelete(0, closeBtn);
    ObjectDelete(0, posLbl);
    ObjectDelete(0, spreadLbl);
    ObjectDelete(0, plLbl);
    ObjectDelete(0, statusLbl);
    ObjectDelete(0, lotLbl);
    
    // --- TP/SL UI Cleanup ---
    ObjectDelete(0, tpDownBtn);
    ObjectDelete(0, tpUpBtn);
    ObjectDelete(0, tpModeBtn);
    ObjectDelete(0, tpLabel);
    ObjectDelete(0, slDownBtn);
    ObjectDelete(0, slUpBtn);
    ObjectDelete(0, slModeBtn);
    ObjectDelete(0, slLabel);
    ObjectDelete(0, prefix + "TP_PANEL");
    // --- END TP/SL UI Cleanup ---

    if(EnableHotkeys)
    {
        ObjectDelete(0, prefix + "HOTKEY_PANEL");
        ObjectDelete(0, prefix + "HOTKEYS");
    }
    
    ObjectDelete(0, minimizeBtn);
    ObjectDelete(0, maximizeBtn);
    ObjectDelete(0, closeIconBtn);
}

void ExecuteBuy()
{
    if(!CanTrade()) 
    {
        Print("Cannot trade - Max positions reached or other restriction");
        return;
    }
    
    double lot = GetLotSize();
    double price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    double sl = 0, tp = 0;
    
    double sl_points = 0;
    if(slMode == MODE_POINTS)
    {
        sl_points = currentStopLoss;
    }
    else // MODE_CURRENCY
    {
        double tick_value = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
        double tick_size = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
        if(tick_value > 0 && tick_size > 0 && lot > 0)
        {
            double one_point_value = (tick_value / tick_size) * _Point * lot;
            sl_points = currentStopLoss / one_point_value;
        }
    }

    double tp_points = 0;
    if(tpMode == MODE_POINTS)
    {
        tp_points = currentTakeProfit;
    }
    else // MODE_CURRENCY
    {
        double tick_value = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
        double tick_size = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
        if(tick_value > 0 && tick_size > 0 && lot > 0)
        {
            double one_point_value = (tick_value / tick_size) * _Point * lot;
            tp_points = currentTakeProfit / one_point_value;
        }
    }

    if(sl_points > 0)
        sl = price - sl_points * _Point;
    
    if(tp_points > 0)
        tp = price + tp_points * _Point;
    
    Print("Attempting BUY: Price=", price, " SL=", sl, " TP=", tp, " Lot=", lot);
    
    if(trade.Buy(lot, _Symbol, price, sl, tp, "Dashboard BUY"))
    {
        SetStatus("BUY EXECUTED", C'50,205,50');
        PlaySound("alert2.wav");
    }
    else
    {
        Print("Error code: ", trade.ResultRetcode());
        SetStatus("BUY FAILED", C'255,69,0');
    }
}

void ExecuteSell()
{
    if(!CanTrade()) 
    {
        Print("Cannot trade - Max positions reached or other restriction");
        return;
    }
    
    double lot = GetLotSize();
    double price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double sl = 0, tp = 0;
    
    double sl_points = 0;
    if(slMode == MODE_POINTS)
    {
        sl_points = currentStopLoss;
    }
    else // MODE_CURRENCY
    {
        double tick_value = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
        double tick_size = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
        if(tick_value > 0 && tick_size > 0 && lot > 0)
        {
            double one_point_value = (tick_value / tick_size) * _Point * lot;
            sl_points = currentStopLoss / one_point_value;
        }
    }

    double tp_points = 0;
    if(tpMode == MODE_POINTS)
    {
        tp_points = currentTakeProfit;
    }
    else // MODE_CURRENCY
    {
        double tick_value = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
        double tick_size = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
        if(tick_value > 0 && tick_size > 0 && lot > 0)
        {
            double one_point_value = (tick_value / tick_size) * _Point * lot;
            tp_points = currentTakeProfit / one_point_value;
        }
    }
    
    if(sl_points > 0)
        sl = price + sl_points * _Point;
    
    if(tp_points > 0)
        tp = price - tp_points * _Point;
    
    Print("Attempting SELL: Price=", price, " SL=", sl, " TP=", tp, " Lot=", lot);
    
    if(trade.Sell(lot, _Symbol, price, sl, tp, "Dashboard SELL"))
    {
        SetStatus("SELL EXECUTED", C'50,205,50');
        PlaySound("alert2.wav");
    }
    else
    {
        Print("Error code: ", trade.ResultRetcode());
        SetStatus("SELL FAILED", C'255,69,0');
    }
}

void CloseLastPosition()
{
    ulong ticket = 0;
    datetime lastTime = 0;
    int totalPos = 0;
    
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        if(position.SelectByIndex(i) && position.Symbol() == _Symbol)
        {
            totalPos++;
            if(position.Time() > lastTime)
            {
                lastTime = position.Time();
                ticket = position.Ticket();
            }
        }
    }
    
    if(ticket > 0)
    {
        Print("Attempting to close position: ", ticket);
        if(trade.PositionClose(ticket))
        {
            Print("POSITION CLOSED: ", ticket);
            SetStatus("POSITION CLOSED", C'255,215,0');
            PlaySound("alert2.wav");
        }
        else
        {
            Print("FAILED TO CLOSE: ", trade.ResultRetcodeDescription());
            SetStatus("CLOSE FAILED", C'255,69,0');
        }
    }
    else
    {
        Print("NO POSITIONS TO CLOSE");
        SetStatus("NO POSITIONS", C'255,215,0');
    }
}

bool CanTrade()
{
    int pos = 0;
    for(int i = 0; i < PositionsTotal(); i++)
    {
        if(position.SelectByIndex(i) && position.Symbol() == _Symbol)
            pos++;
    }
    
    if(pos >= MaxPositions)
    {
        SetStatus("MAX POSITIONS", C'255,215,0');
        return false;
    }
    
    if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED))
    {
        SetStatus("ENABLE AUTO TRADING", C'255,69,0');
        return false;
    }
    
    if(!MQLInfoInteger(MQL_TRADE_ALLOWED))
    {
        SetStatus("ALLOW DLL IMPORTS", C'255,69,0');
        return false;
    }
    
    return true;
}

void UpdateDashboard()
{
    int positions = 0;
    double totalPL = 0;
    
    for(int i = 0; i < PositionsTotal(); i++)
    {
        if(position.SelectByIndex(i) && position.Symbol() == _Symbol)
        {
            positions++;
            totalPL += position.Profit();
        }
    }
    
    double spread = (SymbolInfoDouble(_Symbol, SYMBOL_ASK) - SymbolInfoDouble(_Symbol, SYMBOL_BID)) / _Point;
    
    ObjectSetString(0, posLbl, OBJPROP_TEXT, StringFormat("POSITIONS: %d", positions));
    ObjectSetInteger(0, posLbl, OBJPROP_COLOR, positions > 0 ? C'255,215,0' : C'0,255,255');
    
    ObjectSetString(0, spreadLbl, OBJPROP_TEXT, StringFormat("SPREAD: %.1f", spread));
    color spreadColor = spread <= 2.0 ? C'50,205,50' : (spread <= 5.0 ? C'255,215,0' : C'255,69,0');
    ObjectSetInteger(0, spreadLbl, OBJPROP_COLOR, spreadColor);
    
    dailyPL = GetDailyPL();
    ObjectSetString(0, plLbl, OBJPROP_TEXT, StringFormat("DAILY P&L: $%.2f", dailyPL));
    ObjectSetInteger(0, plLbl, OBJPROP_COLOR, dailyPL >= 0 ? C'50,205,50' : C'255,69,0');
    
    string status = "READY";
    color statusColor = C'0,191,255';
    
    if(positions > 0)
    {
        if(totalPL > 0)
        {
            status = "IN PROFIT";
            statusColor = C'50,205,50';
        }
        else if(totalPL < 0)
        {
            status = "IN LOSS";
            statusColor = C'255,69,0';
        }
        else
        {
            status = "BREAKEVEN";
            statusColor = C'255,215,0';
        }
    }
    
    ObjectSetString(0, statusLbl, OBJPROP_TEXT, StringFormat("STATUS: %s", status));
    ObjectSetInteger(0, statusLbl, OBJPROP_COLOR, statusColor);
    ObjectSetString(0, lotLbl, OBJPROP_TEXT, StringFormat("LOT SIZE: %.2f", GetLotSize()));
}

void SetStatus(string text, color clr)
{
    ObjectSetString(0, statusLbl, OBJPROP_TEXT, text);
    ObjectSetInteger(0, statusLbl, OBJPROP_COLOR, clr);
}

void FlashButton(string btnName, color flashColor)
{
    ObjectSetInteger(0, btnName, OBJPROP_BGCOLOR, clrWhite);
    ObjectSetInteger(0, btnName, OBJPROP_BORDER_COLOR, flashColor);
    ChartRedraw();
    Sleep(150);
    
    if(btnName == buyBtn)
    {
        ObjectSetInteger(0, btnName, OBJPROP_BGCOLOR, C'34,139,34');
        ObjectSetInteger(0, btnName, OBJPROP_BORDER_COLOR, C'0,255,0');
    }
    else if(btnName == sellBtn)
    {
        ObjectSetInteger(0, btnName, OBJPROP_BGCOLOR, C'220,20,60');
        ObjectSetInteger(0, btnName, OBJPROP_BORDER_COLOR, C'255,0,100');
    }
    else if(btnName == closeBtn)
    {
        ObjectSetInteger(0, btnName, OBJPROP_BGCOLOR, C'255,140,0');
        ObjectSetInteger(0, btnName, OBJPROP_BORDER_COLOR, C'255,165,0');
    }
}

double GetDailyPL()
{
    double profit = 0;
    datetime today = StringToTime(TimeToString(TimeCurrent(), TIME_DATE));
    
    HistorySelect(today, TimeCurrent());
    for(int i = 0; i < HistoryDealsTotal(); i++)
    {
        ulong ticket = HistoryDealGetTicket(i);
        if(HistoryDealGetString(ticket, DEAL_SYMBOL) == _Symbol)
        {
            profit += HistoryDealGetDouble(ticket, DEAL_PROFIT);
            profit += HistoryDealGetDouble(ticket, DEAL_SWAP);
            profit += HistoryDealGetDouble(ticket, DEAL_COMMISSION);
        }
    }
    
    for(int i = 0; i < PositionsTotal(); i++)
    {
        if(position.SelectByIndex(i) && position.Symbol() == _Symbol)
        {
            profit += position.Profit() + position.Swap() + position.Commission();
        }
    }
    
    return profit;
}

void CheckDailyReset()
{
    datetime current = TimeCurrent();
    datetime currentDate = StringToTime(TimeToString(current, TIME_DATE));
    datetime lastDate = StringToTime(TimeToString(resetTime, TIME_DATE));
    
    if(currentDate > lastDate)
    {
        resetTime = current;
        Print("Daily reset");
    }
}
