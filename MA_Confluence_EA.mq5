//+------------------------------------------------------------------+
//|                                        MA_Confluence_EA.mq5     |
//|                                          FTMO Algorithmic Trade |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "FTMO Algorithmic Trade"
#property link      ""
#property version   "1.00"

#include <Trade\Trade.mqh>

//--- Input parametreleri
input group "=== Moving Average Settings ==="
input int EMA_Fast = 11;                              // Hızlı EMA periyodu
input int SMA_Medium = 33;                            // Orta SMA periyodu  
input int SMA_Slow = 140;                             // Yavaş SMA periyodu

input group "=== MACD Settings ==="
input int MACD_Fast = 7;                             // MACD hızlı EMA
input int MACD_Slow = 25;                             // MACD yavaş EMA
input int MACD_Signal = 5;                            // MACD sinyal periyodu

input group "=== Trade Settings ==="
input double RiskPercent = 0.5;                       // Risk yüzdesi (% bakiye)
input int MaxSpread = 30;                             // Maximum spread (points)

input group "=== Daily Trade Limit ==="
input bool EnableDailyLimit = true;                   // Günlük işlem sınırı etkinleştir
input int MaxDailyTrades = 3;                         // Günlük maksimum işlem adeti

input group "=== Trading Sessions ==="
input bool EnableTradingSessions = true;              // İşlem saatleri kontrolü etkinleştir
input int Session1_StartHour = 5;                     // 1. Seans başlangıç saati
input int Session1_EndHour = 13;                      // 1. Seans bitiş saati
input int Session2_StartHour = 14;                    // 2. Seans başlangıç saati
input int Session2_EndHour = 19;                      // 2. Seans bitiş saati

input group "=== ATR Settings ==="
input int ATR_Period = 21;                            // ATR periyodu
input double ATR_StopLoss = 1.6;                      // Stop Loss (ATR çarpanı)
input double ATR_TakeProfit = 3.5;                    // Take Profit (ATR çarpanı)

input group "=== Pullback Settings ==="
input int PullbackBars = 3;                           // Pullback kontrol bar sayısı
input double ATR_PullbackTolerance = 1.4;             // EMA'ya yakınlık toleransı (ATR çarpanı)

input group "=== Risk Management ==="
input bool EnableBreakeven = true;                    // Breakeven etkinleştir
input double BreakevenTriggerATR = 1.5;               // Breakeven tetikleme (ATR çarpanı)
input double BreakevenOffsetATR = 0.15;                // Breakeven offset (ATR çarpanı)

input bool EnableTrailing = true;                     // Trailing stop etkinleştir
input double TrailingTriggerATR = 2.6;                // Trailing başlama (ATR çarpanı)
input double TrailingStepATR = 1.1;                   // Trailing adımı (ATR çarpanı)

input group "=== Other Settings ==="
input bool EnableBuySignals = true;                   // Buy sinyallerini etkinleştir
input bool EnableSellSignals = true;                  // Sell sinyallerini etkinleştir
input bool ShowDebug = true;                          // Debug mesajları
input int MagicNumber = 234567;                       // Magic number
input ENUM_TIMEFRAMES signal_tf = PERIOD_M30;           // Signal Timeframe

//--- Global değişkenler
CTrade trade;
int emaFastHandle, smaMediumHandle, smaSlowHandle;
int macdHandle, atrHandle;

// Trade tracking
struct TradeInfo {
    bool breakevenMoved;
    bool trailingActive;
    double entryPrice;
    double stopLoss;
    double takeProfit;
    double riskAmount;
    double highestPrice;    // Buy için
    double lowestPrice;     // Sell için
};

TradeInfo currentTrade;
datetime lastTradeTime = 0;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
    // Trade ayarları
    trade.SetExpertMagicNumber(MagicNumber);
    trade.SetDeviationInPoints(10);
    trade.SetTypeFilling(ORDER_FILLING_FOK);
    
    // İndikatör handle'larını oluştur
    emaFastHandle = iMA(_Symbol, signal_tf, EMA_Fast, 0, MODE_EMA, PRICE_CLOSE);
    smaMediumHandle = iMA(_Symbol, signal_tf, SMA_Medium, 0, MODE_SMA, PRICE_CLOSE);
    smaSlowHandle = iMA(_Symbol, signal_tf, SMA_Slow, 0, MODE_SMA, PRICE_CLOSE);
    macdHandle = iMACD(_Symbol, signal_tf, MACD_Fast, MACD_Slow, MACD_Signal, PRICE_CLOSE);
    atrHandle = iATR(_Symbol, signal_tf, ATR_Period);
    
    // Handle kontrolü
    if(emaFastHandle == INVALID_HANDLE || smaMediumHandle == INVALID_HANDLE || 
       smaSlowHandle == INVALID_HANDLE || macdHandle == INVALID_HANDLE || atrHandle == INVALID_HANDLE)
    {
        Print("İndikatör handle'ları başlatılamadı!");
        return(INIT_FAILED);
    }
    
    // Trade info başlat
    ResetTradeInfo();
    
    Print("MA Confluence EA başlatıldı");
    Print("- Fast EMA: ", EMA_Fast);
    Print("- Medium SMA: ", SMA_Medium); 
    Print("- Slow SMA: ", SMA_Slow);
    Print("- ATR Period: ", ATR_Period);
    Print("- ATR Stop Loss: ", ATR_StopLoss, "x");
    Print("- ATR Take Profit: ", ATR_TakeProfit, "x");
    Print("- Max Daily Trades: ", MaxDailyTrades);
    Print("- Session 1: ", Session1_StartHour, ":00 - ", Session1_EndHour, ":00");
    Print("- Session 2: ", Session2_StartHour, ":00 - ", Session2_EndHour, ":00");
    
    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    if(emaFastHandle != INVALID_HANDLE) IndicatorRelease(emaFastHandle);
    if(smaMediumHandle != INVALID_HANDLE) IndicatorRelease(smaMediumHandle);
    if(smaSlowHandle != INVALID_HANDLE) IndicatorRelease(smaSlowHandle);
    if(macdHandle != INVALID_HANDLE) IndicatorRelease(macdHandle);
    if(atrHandle != INVALID_HANDLE) IndicatorRelease(atrHandle);
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
    // Spread kontrolü
    if(SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) > MaxSpread)
        return;
    
    // Yeni bar kontrolü
    static datetime lastBarTime = 0;
    datetime currentBarTime = iTime(_Symbol, signal_tf, 0);
    
    if(currentBarTime != lastBarTime)
    {
        lastBarTime = currentBarTime;
        
        // Sinyal kontrolü
        CheckSignals();
    }
    
    // Risk yönetimi
    if(PositionsTotal() > 0)
    {
        ManageOpenPositions();
    }
}

//+------------------------------------------------------------------+
//| Günlük işlem adeti kontrolü                                      |
//+------------------------------------------------------------------+

int GetDailyTradeCount()
{
   if(!EnableDailyLimit)
       return 0;
   
   // Bugünün D1 bar'ının başlangıç zamanını al
   datetime startOfDay = iTime(_Symbol, PERIOD_D1, 0);
   datetime currentTime = TimeCurrent();
   
   int tradeCount = 0;
   
   // History seçimi
   if(!HistorySelect(startOfDay, currentTime))
       return 0;
   
   // Günlük tamamlanan işlemleri say
   for(int i = 0; i < HistoryDealsTotal(); i++)
   {
       ulong dealTicket = HistoryDealGetTicket(i);
       if(dealTicket == 0) continue;
       
       // Sadece kendi magic number'ımızı kontrol et
       if(HistoryDealGetInteger(dealTicket, DEAL_MAGIC) != MagicNumber)
           continue;
       
       // Sadece IN (entry) işlemlerini say
       if(HistoryDealGetInteger(dealTicket, DEAL_ENTRY) == DEAL_ENTRY_IN)
       {
           // Sadece bizim sembolümüz
           if(HistoryDealGetString(dealTicket, DEAL_SYMBOL) == _Symbol)
           {
               tradeCount++;
           }
       }
   }
   
   return tradeCount;
}

//+------------------------------------------------------------------+
//| İşlem saatleri kontrolü                                          |
//+------------------------------------------------------------------+
bool IsWithinTradingHours()
{
    if(!EnableTradingSessions)
        return true;
    
    MqlDateTime timeStruct;
    TimeCurrent(timeStruct);
    int currentHour = timeStruct.hour;
    
    // 1. Seans kontrolü
    bool inSession1 = (currentHour >= Session1_StartHour && currentHour < Session1_EndHour);
    
    // 2. Seans kontrolü
    bool inSession2 = (currentHour >= Session2_StartHour && currentHour < Session2_EndHour);
    
    return (inSession1 || inSession2);
}

//+------------------------------------------------------------------+
//| Sinyalleri kontrol et                                            |
//+------------------------------------------------------------------+
void CheckSignals()
{
    // Pozisyon varsa yeni sinyal arama
    if(PositionsTotal() > 0)
        return;
    
    // Günlük işlem sınırı kontrolü
    if(EnableDailyLimit)
    {
        int dailyTrades = GetDailyTradeCount();
        if(dailyTrades >= MaxDailyTrades)
        {
            if(ShowDebug)
                Print("Günlük işlem sınırına ulaşıldı: ", dailyTrades, "/", MaxDailyTrades);
            return;
        }
        
        if(ShowDebug)
            Print("Günlük işlem sayısı: ", dailyTrades, "/", MaxDailyTrades);
    }
    
    // İşlem saatleri kontrolü
    if(!IsWithinTradingHours())
    {
        if(ShowDebug)
        {
            MqlDateTime timeStruct;
            TimeCurrent(timeStruct);
            Print("İşlem saatleri dışında: ", timeStruct.hour, ":00");
        }
        return;
    }
    
    // Çok yakın zamanda işlem yapıldıysa bekle
    if(TimeCurrent() - lastTradeTime < 300) // 5 dakika
        return;
    
    // İndikatör değerlerini al
    double emaFast[], smaMedium[], smaSlow[];
    double macdMain[], macdSignal[];
    double atrValues[];
    
    if(!GetIndicatorValues(emaFast, smaMedium, smaSlow, macdMain, macdSignal, atrValues))
        return;
    
    // Ana trend kontrolü (200 SMA)
    bool bullishTrend = IsAboveSMA200(smaSlow);
    bool bearishTrend = IsBelowSMA200(smaSlow);
    
    if(ShowDebug)
    {
        Print("Trend Analysis:");
        Print("- Bullish Trend: ", bullishTrend);
        Print("- Bearish Trend: ", bearishTrend);
        Print("- EMA 20: ", emaFast[1]);
        Print("- SMA 50: ", smaMedium[1]);
        Print("- SMA 200: ", smaSlow[1]);
        Print("- MACD: ", macdMain[1]);
        Print("- ATR: ", atrValues[1]);
    }
    
    // BUY sinyali kontrol
    if(EnableBuySignals && bullishTrend)
    {
        if(CheckBuyConditions(emaFast, smaMedium, smaSlow, macdMain, macdSignal, atrValues))
        {
            ExecuteBuyTrade(atrValues[1]);
        }
    }
    
    // SELL sinyali kontrol  
    if(EnableSellSignals && bearishTrend)
    {
        if(CheckSellConditions(emaFast, smaMedium, smaSlow, macdMain, macdSignal, atrValues))
        {
            ExecuteSellTrade(atrValues[1]);
        }
    }
}

//+------------------------------------------------------------------+
//| İndikatör değerlerini al                                         |
//+------------------------------------------------------------------+
bool GetIndicatorValues(double &emaFast[], double &smaMedium[], double &smaSlow[], 
                       double &macdMain[], double &macdSignal[], double &atrValues[])
{
    ArraySetAsSeries(emaFast, true);
    ArraySetAsSeries(smaMedium, true);
    ArraySetAsSeries(smaSlow, true);
    ArraySetAsSeries(macdMain, true);
    ArraySetAsSeries(macdSignal, true);
    ArraySetAsSeries(atrValues, true);
    
    if(CopyBuffer(emaFastHandle, 0, 0, 3, emaFast) <= 0) return false;
    if(CopyBuffer(smaMediumHandle, 0, 0, 3, smaMedium) <= 0) return false;
    if(CopyBuffer(smaSlowHandle, 0, 0, 3, smaSlow) <= 0) return false;
    if(CopyBuffer(macdHandle, 0, 0, 3, macdMain) <= 0) return false;
    if(CopyBuffer(macdHandle, 1, 0, 3, macdSignal) <= 0) return false;
    if(CopyBuffer(atrHandle, 0, 0, 3, atrValues) <= 0) return false;
    
    return true;
}

//+------------------------------------------------------------------+
//| ATR değerini al                                                  |
//+------------------------------------------------------------------+
double GetATRValue()
{
    double atrValues[];
    ArraySetAsSeries(atrValues, true);
    
    if(CopyBuffer(atrHandle, 0, 1, 1, atrValues) <= 0)
        return 0;
    
    return atrValues[0];
}

//+------------------------------------------------------------------+
//| 200 SMA üzerinde mi kontrol et                                   |
//+------------------------------------------------------------------+
bool IsAboveSMA200(const double &smaSlow[])
{
    double currentPrice = iClose(_Symbol, signal_tf, 1);
    return currentPrice > smaSlow[1];
}

//+------------------------------------------------------------------+
//| 200 SMA altında mı kontrol et                                    |
//+------------------------------------------------------------------+
bool IsBelowSMA200(const double &smaSlow[])
{
    double currentPrice = iClose(_Symbol, signal_tf, 1);
    return currentPrice < smaSlow[1];
}

//+------------------------------------------------------------------+
//| Buy koşullarını kontrol et                                       |
//+------------------------------------------------------------------+
bool CheckBuyConditions(const double &emaFast[], const double &smaMedium[], const double &smaSlow[],
                       const double &macdMain[], const double &macdSignal[], const double &atrValues[])
{
    double currentPrice = iClose(_Symbol, signal_tf, 1);
    
    // 1. EMA 20 > SMA 50 (Kısa vadeli momentum yukarı)
    bool emaAboveSMA = emaFast[1] > smaMedium[1];
    
    // 2. MACD > 0 ve yükseliyor
    bool macdBullish = macdMain[1] > 0 && macdMain[1] > macdMain[2];
    
    // 3. Pullback kontrolü - Fiyat EMA 20'ye yakın mı?
    double pullbackDistance = MathAbs(currentPrice - emaFast[1]);
    double atrTolerance = atrValues[1] * ATR_PullbackTolerance;
    bool isPullback = pullbackDistance <= atrTolerance;
    
    // 4. Fiyat EMA 20'nin üzerinde bounce yapıyor mu?
    bool bounceFromEMA = false;
    for(int i = 1; i <= PullbackBars; i++)
    {
        double lowPrice = iLow(_Symbol, signal_tf, i);
        if(lowPrice <= emaFast[1] + atrTolerance && currentPrice > emaFast[1])
        {
            bounceFromEMA = true;
            break;
        }
    }
    
    if(ShowDebug)
    {
        Print("BUY Conditions:");
        Print("- EMA > SMA: ", emaAboveSMA);
        Print("- MACD Bullish: ", macdBullish);
        Print("- Is Pullback: ", isPullback);
        Print("- Bounce from EMA: ", bounceFromEMA);
        Print("- Pullback Distance: ", pullbackDistance);
        Print("- ATR Tolerance: ", atrTolerance);
    }
    
    return emaAboveSMA && macdBullish && (isPullback || bounceFromEMA);
}

//+------------------------------------------------------------------+
//| Sell koşullarını kontrol et                                      |
//+------------------------------------------------------------------+
bool CheckSellConditions(const double &emaFast[], const double &smaMedium[], const double &smaSlow[],
                        const double &macdMain[], const double &macdSignal[], const double &atrValues[])
{
    double currentPrice = iClose(_Symbol, signal_tf, 1);
    
    // 1. EMA 20 < SMA 50 (Kısa vadeli momentum aşağı)
    bool emaBelowSMA = emaFast[1] < smaMedium[1];
    
    // 2. MACD < 0 ve düşüyor
    bool macdBearish = macdMain[1] < 0 && macdMain[1] < macdMain[2];
    
    // 3. Pullback kontrolü - Fiyat EMA 20'ye yakın mı?
    double pullbackDistance = MathAbs(currentPrice - emaFast[1]);
    double atrTolerance = atrValues[1] * ATR_PullbackTolerance;
    bool isPullback = pullbackDistance <= atrTolerance;
    
    // 4. Fiyat EMA 20'den rejection yapıyor mu?
    bool rejectionFromEMA = false;
    for(int i = 1; i <= PullbackBars; i++)
    {
        double highPrice = iHigh(_Symbol, signal_tf, i);
        if(highPrice >= emaFast[1] - atrTolerance && currentPrice < emaFast[1])
        {
            rejectionFromEMA = true;
            break;
        }
    }
    
    if(ShowDebug)
    {
        Print("SELL Conditions:");
        Print("- EMA < SMA: ", emaBelowSMA);
        Print("- MACD Bearish: ", macdBearish);
        Print("- Is Pullback: ", isPullback);
        Print("- Rejection from EMA: ", rejectionFromEMA);
        Print("- Pullback Distance: ", pullbackDistance);
        Print("- ATR Tolerance: ", atrTolerance);
    }
    
    return emaBelowSMA && macdBearish && (isPullback || rejectionFromEMA);
}

//+------------------------------------------------------------------+
//| Buy trade gerçekleştir                                           |
//+------------------------------------------------------------------+
void ExecuteBuyTrade(double atrValue)
{
    double entryPrice = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    double stopLoss = entryPrice - (atrValue * ATR_StopLoss);
    double takeProfit = entryPrice + (atrValue * ATR_TakeProfit);
    
    // Normalize et
    stopLoss = NormalizeDouble(stopLoss, _Digits);
    takeProfit = NormalizeDouble(takeProfit, _Digits);
    
    // Lot size hesapla
    double lotSize = CalculateLotSize(entryPrice - stopLoss);
    
    if(trade.Buy(lotSize, _Symbol, entryPrice, stopLoss, takeProfit, 
                StringFormat("MA Confluence BUY - ATR: %.5f", atrValue)))
    {
        lastTradeTime = TimeCurrent();
        
        // Trade info güncelle
        currentTrade.entryPrice = entryPrice;
        currentTrade.stopLoss = stopLoss;
        currentTrade.takeProfit = takeProfit;
        currentTrade.riskAmount = entryPrice - stopLoss;
        currentTrade.highestPrice = entryPrice;
        currentTrade.breakevenMoved = false;
        currentTrade.trailingActive = false;
        
        if(ShowDebug)
        {
            Print("BUY TRADE EXECUTED:");
            Print("- Entry: ", entryPrice);
            Print("- Stop Loss: ", stopLoss);
            Print("- Take Profit: ", takeProfit);
            Print("- ATR: ", atrValue);
            Print("- Lot Size: ", lotSize);
            Print("- Risk Distance: ", entryPrice - stopLoss);
            Print("- Daily Trades: ", GetDailyTradeCount() + 1, "/", MaxDailyTrades);
        }
    }
    else
    {
        Print("Buy trade failed! Error: ", GetLastError());
    }
}

//+------------------------------------------------------------------+
//| Sell trade gerçekleştir                                          |
//+------------------------------------------------------------------+
void ExecuteSellTrade(double atrValue)
{
    double entryPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double stopLoss = entryPrice + (atrValue * ATR_StopLoss);
    double takeProfit = entryPrice - (atrValue * ATR_TakeProfit);
    
    // Normalize et
    stopLoss = NormalizeDouble(stopLoss, _Digits);
    takeProfit = NormalizeDouble(takeProfit, _Digits);
    
    // Lot size hesapla
    double lotSize = CalculateLotSize(stopLoss - entryPrice);
    
    if(trade.Sell(lotSize, _Symbol, entryPrice, stopLoss, takeProfit,
                 StringFormat("MA Confluence SELL - ATR: %.5f", atrValue)))
    {
        lastTradeTime = TimeCurrent();
        
        // Trade info güncelle
        currentTrade.entryPrice = entryPrice;
        currentTrade.stopLoss = stopLoss;
        currentTrade.takeProfit = takeProfit;
        currentTrade.riskAmount = stopLoss - entryPrice;
        currentTrade.lowestPrice = entryPrice;
        currentTrade.breakevenMoved = false;
        currentTrade.trailingActive = false;
        
        if(ShowDebug)
        {
            Print("SELL TRADE EXECUTED:");
            Print("- Entry: ", entryPrice);
            Print("- Stop Loss: ", stopLoss);
            Print("- Take Profit: ", takeProfit);
            Print("- ATR: ", atrValue);
            Print("- Lot Size: ", lotSize);
            Print("- Risk Distance: ", stopLoss - entryPrice);
            Print("- Daily Trades: ", GetDailyTradeCount() + 1, "/", MaxDailyTrades);
        }
    }
    else
    {
        Print("Sell trade failed! Error: ", GetLastError());
    }
}

//+------------------------------------------------------------------+
//| Lot size hesapla                                                 |
//+------------------------------------------------------------------+
double CalculateLotSize(double riskDistance)
{
    
    double accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
    double riskAmount = accountBalance * RiskPercent / 100.0;
    
    double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
    double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
    
    double lotSize = riskAmount / (riskDistance / tickSize * tickValue);
    
    // Minimum ve maksimum lot kontrolü
    double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
    double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
    double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
    
    lotSize = MathMax(minLot, MathMin(maxLot, lotSize));
    lotSize = MathFloor(lotSize / lotStep) * lotStep;
    
    return NormalizeDouble(lotSize, 2);
}

//+------------------------------------------------------------------+
//| Trade info sıfırla                                               |
//+------------------------------------------------------------------+
void ResetTradeInfo()
{
    currentTrade.breakevenMoved = false;
    currentTrade.trailingActive = false;
    currentTrade.entryPrice = 0;
    currentTrade.stopLoss = 0;
    currentTrade.takeProfit = 0;
    currentTrade.riskAmount = 0;
    currentTrade.highestPrice = 0;
    currentTrade.lowestPrice = DBL_MAX;
}

//+------------------------------------------------------------------+
//| Açık pozisyonları yönet                                          |
//+------------------------------------------------------------------+
void ManageOpenPositions()
{
    if(PositionsTotal() == 0)
    {
        ResetTradeInfo();
        return;
    }
    
    if(!PositionSelect(_Symbol))
        return;
    
    ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
    double currentPrice = (posType == POSITION_TYPE_BUY) ? 
                         SymbolInfoDouble(_Symbol, SYMBOL_BID) : 
                         SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    
    double atrValue = GetATRValue();
    if(atrValue <= 0)
        return;
    
    if(posType == POSITION_TYPE_BUY)
    {
        // En yüksek fiyatı güncelle
        if(currentPrice > currentTrade.highestPrice)
            currentTrade.highestPrice = currentPrice;
        
        // Breakeven kontrolü
        if(EnableBreakeven && !currentTrade.breakevenMoved)
        {
            CheckBreakevenBuy(currentPrice, atrValue);
        }
        
        // Trailing stop kontrolü
        if(EnableTrailing)
        {
            CheckTrailingStopBuy(currentPrice, atrValue);
        }
    }
    else if(posType == POSITION_TYPE_SELL)
    {
        // En düşük fiyatı güncelle
        if(currentPrice < currentTrade.lowestPrice)
            currentTrade.lowestPrice = currentPrice;
        
        // Breakeven kontrolü
        if(EnableBreakeven && !currentTrade.breakevenMoved)
        {
            CheckBreakevenSell(currentPrice, atrValue);
        }
        
        // Trailing stop kontrolü
        if(EnableTrailing)
        {
            CheckTrailingStopSell(currentPrice, atrValue);
        }
    }
}

//+------------------------------------------------------------------+
//| Buy için breakeven kontrolü                                      |
//+------------------------------------------------------------------+
void CheckBreakevenBuy(double currentPrice, double atrValue)
{
    double breakevenTrigger = currentTrade.entryPrice + (atrValue * BreakevenTriggerATR);
    
    if(currentPrice >= breakevenTrigger)
    {
        double newSL = currentTrade.entryPrice + (atrValue * BreakevenOffsetATR);
        newSL = NormalizeDouble(newSL, _Digits);
        
        double currentSL = PositionGetDouble(POSITION_SL);
        
        if(newSL > currentSL)
        {
            if(trade.PositionModify(_Symbol, newSL, PositionGetDouble(POSITION_TP)))
            {
                currentTrade.breakevenMoved = true;
                
                if(ShowDebug)
                    Print("BREAKEVEN MOVED - New SL: ", newSL);
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Sell için breakeven kontrolü                                     |
//+------------------------------------------------------------------+
void CheckBreakevenSell(double currentPrice, double atrValue)
{
    double breakevenTrigger = currentTrade.entryPrice - (atrValue * BreakevenTriggerATR);
    
    if(currentPrice <= breakevenTrigger)
    {
        double newSL = currentTrade.entryPrice - (atrValue * BreakevenOffsetATR);
        newSL = NormalizeDouble(newSL, _Digits);
        
        double currentSL = PositionGetDouble(POSITION_SL);
        
        if(newSL < currentSL)
        {
            if(trade.PositionModify(_Symbol, newSL, PositionGetDouble(POSITION_TP)))
            {
                currentTrade.breakevenMoved = true;
                
                if(ShowDebug)
                    Print("BREAKEVEN MOVED - New SL: ", newSL);
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Buy için trailing stop kontrolü                                  |
//+------------------------------------------------------------------+
void CheckTrailingStopBuy(double currentPrice, double atrValue)
{
    double trailingTrigger = currentTrade.entryPrice + (atrValue * TrailingTriggerATR);
    
    // Trailing henüz aktif değilse
    if(!currentTrade.trailingActive)
    {
        if(currentPrice >= trailingTrigger)
        {
            currentTrade.trailingActive = true;
            if(ShowDebug)
                Print("TRAILING STOP ACTIVATED");
        }
        return;
    }
    
    // Trailing aktifse
    double currentSL = PositionGetDouble(POSITION_SL);
    double newSL = currentTrade.highestPrice - (atrValue * TrailingStepATR);
    newSL = NormalizeDouble(newSL, _Digits);
    
    if(newSL > currentSL)
    {
        if(trade.PositionModify(_Symbol, newSL, PositionGetDouble(POSITION_TP)))
        {
            if(ShowDebug)
                Print("TRAILING STOP MOVED - New SL: ", newSL);
        }
    }
}

//+------------------------------------------------------------------+
//| Sell için trailing stop kontrolü                                 |
//+------------------------------------------------------------------+
void CheckTrailingStopSell(double currentPrice, double atrValue)
{
    double trailingTrigger = currentTrade.entryPrice - (atrValue * TrailingTriggerATR);
    
    // Trailing henüz aktif değilse
    if(!currentTrade.trailingActive)
    {
        if(currentPrice <= trailingTrigger)
        {
            currentTrade.trailingActive = true;
            if(ShowDebug)
                Print("TRAILING STOP ACTIVATED");
        }
        return;
    }
    
    // Trailing aktifse
    double currentSL = PositionGetDouble(POSITION_SL);
    double newSL = currentTrade.lowestPrice + (atrValue * TrailingStepATR);
    newSL = NormalizeDouble(newSL, _Digits);
    
    if(newSL < currentSL)
    {
        if(trade.PositionModify(_Symbol, newSL, PositionGetDouble(POSITION_TP)))
        {
            if(ShowDebug)
                Print("TRAILING STOP MOVED - New SL: ", newSL);
        }
    }
}
