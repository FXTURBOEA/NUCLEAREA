//+------------------------------------------------------------------+
//|                                                  RiskManager.mqh |
//|                                         FTMO Algorithmic Trading |
//|                                Risk Management with News Control |
//+------------------------------------------------------------------+
#property copyright "FTMO Algorithmic Trading"
#property version   "3.00"
#property strict

#include <Trade\PositionInfo.mqh>
#include <Trade\DealInfo.mqh>
#include "NewsManager.mqh"  // News Manager include

//+------------------------------------------------------------------+
//| Magic Risk Configuration Structure - Updated                     |
//+------------------------------------------------------------------+
struct SMagicRiskConfig
{
   // Risk Parameters
   double            riskPercentPerTrade;    // İşlem başına risk yüzdesi
   double            maxTotalRiskPercent;    // Bu magic için maksimum toplam risk %
   double            riskRewardRatio;        // Risk:Reward oranı (TP hesaplamak için)
   
   // ATR Stop Loss Parameters
   bool              useATRStopLoss;         // ATR tabanlı SL kullan
   int               atrPeriod;              // ATR periyodu
   ENUM_TIMEFRAMES   atrTimeframe;           // ATR zaman dilimi
   double            atrMultiplier;          // ATR çarpanı
   
   // News Filter Parameters (YENİ)
   bool              useNewsFilter;          // Haber filtresi aktif mi
   bool              blockTradesOnNews;      // Haber zamanı trade engelle
   bool              closePositionsOnNews;   // Haber zamanı pozisyon kapat
   int               newsMinutesBefore;      // Haberden kaç dk önce
   int               newsMinutesAfter;       // Haberden kaç dk sonra
   
   // Validation
   bool              isActive;               // Konfigürasyon aktif mi
};

//+------------------------------------------------------------------+
//| Position Risk Information Structure                              |
//+------------------------------------------------------------------+
struct SPositionRiskInfo
{
   ulong             ticket;                 // Pozisyon ticket
   ulong             magic;                  // Magic number
   string            symbol;                 // Sembol
   double            lotSize;                // Lot büyüklüğü
   double            entryPrice;             // Giriş fiyatı
   double            stopLoss;               // Stop loss
   double            takeProfit;             // Take profit
   double            riskAmount;             // Risk miktarı (para)
   double            riskPercent;            // Risk yüzdesi
   double            potentialProfit;        // Potansiyel kar
   ENUM_POSITION_TYPE positionType;          // BUY/SELL
   datetime          openTime;               // Açılış zamanı
};

//+------------------------------------------------------------------+
//| Risk Analysis Result Structure - Updated                         |
//+------------------------------------------------------------------+
struct SRiskAnalysisResult
{
   // Position Parameters
   double            recommendedLotSize;     // Önerilen lot büyüklüğü
   double            entryPrice;             // Giriş fiyatı
   double            stopLoss;               // Hesaplanan/önerilen stop loss
   double            takeProfit;             // Hesaplanan take profit
   
   // Risk Information
   double            calculatedRisk;         // Hesaplanan risk miktarı
   double            calculatedRiskPercent;  // Hesaplanan risk yüzdesi
   double            remainingCapacity;      // Kalan risk kapasitesi
   double            potentialProfit;        // Potansiyel kar miktarı
   double            riskRewardRatio;        // Risk:Reward oranı
   
   // News Information (YENİ)
   bool              newsRestricted;         // Haber kısıtlaması var mı
   string            newsRestrictionReason;  // Haber kısıtlama nedeni
   
   // Validation
   bool              isValid;                // Pozisyon geçerli mi
   string            riskMessage;            // Risk durumu mesajı
};

//+------------------------------------------------------------------+
//| FTMO Risk Manager Class - Full Version                          |
//+------------------------------------------------------------------+
class CFTMORiskManager
{
private:
   // Core Objects
   CPositionInfo     m_position;
   CDealInfo         m_deal;
   CFTMONewsManager* m_newsManager;          // News Manager instance (YENİ)
   
   // Magic Configurations
   SMagicRiskConfig  m_magicConfigs[];
   ulong             m_magicNumbers[];
   int               m_configCount;
   
   // Account Information
   double            m_accountBalance;
   double            m_accountEquity;
   double            m_accountFreeMargin;
   
   // Global Risk Limits
   double            m_maxDailyRiskPercent;
   double            m_maxGlobalRiskPercent;
   
   // Daily Profit/Loss Targets
   double            m_dailyProfitTargetPercent;    // Günlük kar hedefi % (DURDUR)
   double            m_profitRealizePercent;        // Floating kar realize % (DEVAM)
   bool              m_tradingStopped;              // Trading durduruldu mu?
   
   // Position Count Limits
   int               m_maxGlobalPositions;
   int               m_maxMagicPositions;
   
   // Daily Drawdown Control
   double            m_maxDailyDrawdownPercent;
   double            m_dailyStartBalance;
   datetime          m_currentDay;
   bool              m_dailyDrawdownExceeded;
   
   // News Integration (YENİ)
   bool              m_globalNewsFilterEnabled;  // Global haber filtresi
   
   // Internal Methods
   void              UpdateAccountInfo();
   void              CheckNewDay();
   void              InitializeDailyTracking();
   double            GetPositionCommission(ulong positionTicket);
   double            GetPointValue(string symbol);
   double            GetMinLotSize(string symbol);
   double            GetMaxLotSize(string symbol);
   double            GetLotStep(string symbol);
   double            NormalizeLotSize(string symbol, double lotSize);
   int               FindMagicIndex(ulong magic);
   
   // News Methods (YENİ)
   bool              CheckNewsRestrictions(ulong magic, string symbol, string &reason);
   void              UpdateNewsConfiguration(ulong magic);

public:
   // Constructor & Destructor
                     CFTMORiskManager(CFTMONewsManager* newsManager = NULL);
                    ~CFTMORiskManager();
   
   // News Manager Integration (YENİ)
   void              SetNewsManager(CFTMONewsManager* newsManager) { m_newsManager = newsManager; }
   CFTMONewsManager* GetNewsManager() { return m_newsManager; }
   void              SetGlobalNewsFilter(bool enabled) { m_globalNewsFilterEnabled = enabled; }
   bool              IsGlobalNewsFilterEnabled() const { return m_globalNewsFilterEnabled; }
   
   // Configuration Management
   bool              AddMagicConfig(ulong magic, const SMagicRiskConfig &config);
   bool              UpdateMagicConfig(ulong magic, const SMagicRiskConfig &config);
   bool              RemoveMagicConfig(ulong magic);
   bool              GetMagicConfig(ulong magic, SMagicRiskConfig &config);
   bool              IsMagicConfigured(ulong magic);
   
   // Global Risk Settings
   void              SetMaxDailyRisk(double percent) { m_maxDailyRiskPercent = percent; }
   void              SetMaxGlobalRisk(double percent) { m_maxGlobalRiskPercent = percent; }
   void              SetMaxDailyDrawdown(double percent) { m_maxDailyDrawdownPercent = percent; }
   void              SetMaxGlobalPositions(int count) { m_maxGlobalPositions = count; }
   void              SetMaxMagicPositions(int count) { m_maxMagicPositions = count; }
   
   // Daily Profit/Loss Targets
   void              SetDailyProfitTarget(double percent) { m_dailyProfitTargetPercent = percent; }
   void              SetProfitRealizeTarget(double percent) { m_profitRealizePercent = percent; }
   
   // Getters
   double            GetMaxDailyRisk() const { return m_maxDailyRiskPercent; }
   double            GetMaxGlobalRisk() const { return m_maxGlobalRiskPercent; }
   double            GetMaxDailyDrawdown() const { return m_maxDailyDrawdownPercent; }
   int               GetMaxGlobalPositions() const { return m_maxGlobalPositions; }
   int               GetMaxMagicPositions() const { return m_maxMagicPositions; }
   double            GetDailyProfitTarget() const { return m_dailyProfitTargetPercent; }
   double            GetProfitRealizeTarget() const { return m_profitRealizePercent; }
   
   // Account Information
   double            GetAccountBalance() const { return m_accountBalance; }
   double            GetAccountEquity() const { return m_accountEquity; }
   double            GetAccountFreeMargin() const { return m_accountFreeMargin; }
   void              RefreshAccountInfo() { UpdateAccountInfo(); }
   
   // ATR Calculations
   double            CalculateATR(string symbol, ENUM_TIMEFRAMES timeframe, int period, int shift = 0);
   double            CalculateATRStopLoss(string symbol, ENUM_POSITION_TYPE type, double entryPrice,
                                        ENUM_TIMEFRAMES timeframe, int period, double multiplier);
   
   // Risk Calculations
   double            CalculateLotSizeByRisk(string symbol, double riskPercent, 
                                          double entryPrice, double stopLoss);
   double            CalculateAdjustedLotSize(ulong magic, string symbol, 
                                            double entryPrice, double stopLoss);
   double            CalculatePositionRisk(ulong ticket);
   double            CalculatePositionRiskAmount(string symbol, double lotSize, 
                                               double entryPrice, double stopLoss);
   double            CalculatePositionRiskPercent(string symbol, double lotSize, 
                                                double entryPrice, double stopLoss);
   double            CalculateTakeProfit(double entryPrice, double stopLoss, 
                                       ENUM_POSITION_TYPE type, double riskRewardRatio);
   
   // Risk Analysis
   double            GetMagicRiskAmount(ulong magic);
   double            GetMagicRiskPercent(ulong magic);
   double            GetTotalRiskAmount();
   double            GetTotalRiskPercent();
   int               GetMagicPositionCount(ulong magic);
   double            GetRemainingRiskCapacity(ulong magic);
   
   // Position Information
   SPositionRiskInfo GetPositionRiskInfo(ulong ticket);
   int               GetAllPositions(SPositionRiskInfo &positions[]);
   
   // Risk Validation & Analysis
   bool              ValidatePositionRisk(ulong magic, string symbol, double lotSize, 
                                        double stopLoss, double entryPrice);
   SRiskAnalysisResult AnalyzePositionRisk(ulong magic, string symbol, double entryPrice, 
                                         ENUM_POSITION_TYPE type, double stopLoss = 0);
   bool              CheckGlobalRiskLimits();
   bool              CheckDailyRiskLimits();
   bool              CheckDailyDrawdownLimit();
   bool              CheckPositionCountLimits(ulong magic);
   
   // News Control Methods (YENİ)
   bool              ShouldClosePositionsForNews(ulong magic);
   int               GetMagicPositionsToCloseForNews(ulong magic, ulong &tickets[]);
   
   // Daily P&L Management
   double            GetDailyDrawdownPercent();
   double            GetDailyDrawdownAmount();
   double            GetDailyStartBalance() const { return m_dailyStartBalance; }
   double            GetDailyPnL();              // Sadece açık pozisyonlar
   double            GetDailyClosedPnL();        // Kapanan pozisyonlar
   double            GetDailyFloatingPnL();      // Floating P&L
   double            GetDailyTotalPnL();         // Closed + Floating
   double            GetDailyTotalPnLPercent();  // Daily Total P&L %
   double            GetFloatingProfitPercent(); // Floating Profit %
   bool              IsDailyDrawdownExceeded() const { return m_dailyDrawdownExceeded; }
   void              ResetDailyTracking();
   
   // Trading Control
   bool              ShouldStopTradingProfit();     // Daily total kar hedefi
   bool              ShouldStopTradingDrawdown();   // Daily drawdown limiti
   bool              ShouldRealizeProfits();        // Floating kar realize
   bool              IsTradingAllowed();            // Genel trading kontrolü
   void              ResetDailyTradingStatus();     // Yeni güne sıfırla
   
   // Reporting
   void              PrintRiskReport();
   void              PrintMagicReport(ulong magic);
   void              PrintPositionReport(ulong ticket);
   void              PrintNewsStatus();      // YENİ
   string            GetRiskSummary();
   string            GetMagicRiskSummary(ulong magic);
};

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CFTMORiskManager::CFTMORiskManager(CFTMONewsManager* newsManager = NULL)
{
   m_newsManager = newsManager;
   m_configCount = 0;
   m_maxDailyRiskPercent = 5.0;    // Default 5%
   m_maxGlobalRiskPercent = 10.0;  // Default 10%
   m_maxDailyDrawdownPercent = 5.0; // FTMO Default 5%
   m_maxGlobalPositions = 10;      // Default max 10 positions
   m_maxMagicPositions = 5;        // Default max 5 per magic
   
   // Daily Profit/Loss Targets
   m_dailyProfitTargetPercent = 0.0;  // Default disabled
   m_profitRealizePercent = 0.0;      // Default disabled  
   m_tradingStopped = false;
   m_globalNewsFilterEnabled = true;  // Default aktif
   
   ArrayResize(m_magicConfigs, 0);
   ArrayResize(m_magicNumbers, 0);
   
   UpdateAccountInfo();
   InitializeDailyTracking();
   
   Print("=== FTMO Risk Manager Initialized ===");
   Print("Max Daily Risk: ", m_maxDailyRiskPercent, "%");
   Print("Max Global Risk: ", m_maxGlobalRiskPercent, "%");
   Print("Max Daily Drawdown: ", m_maxDailyDrawdownPercent, "%");
   Print("Max Global Positions: ", m_maxGlobalPositions);
   Print("Max Magic Positions: ", m_maxMagicPositions);
   Print("News Manager: ", (m_newsManager != NULL ? "Connected" : "Not Connected"));
   Print("Global News Filter: ", (m_globalNewsFilterEnabled ? "Enabled" : "Disabled"));
}

//+------------------------------------------------------------------+
//| Destructor                                                      |
//+------------------------------------------------------------------+
CFTMORiskManager::~CFTMORiskManager()
{
   ArrayFree(m_magicConfigs);
   ArrayFree(m_magicNumbers);
   Print("=== FTMO Risk Manager Destroyed ===");
}

//+------------------------------------------------------------------+
//| Update Account Information                                       |
//+------------------------------------------------------------------+
void CFTMORiskManager::UpdateAccountInfo()
{
   m_accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   m_accountEquity = AccountInfoDouble(ACCOUNT_EQUITY);
   m_accountFreeMargin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
   
   CheckNewDay();
}

//+------------------------------------------------------------------+
//| Check New Day and Reset Daily Tracking                          |
//+------------------------------------------------------------------+
void CFTMORiskManager::CheckNewDay()
{
   datetime d1OpenTime[];
   if(CopyTime(Symbol(), PERIOD_D1, 0, 1, d1OpenTime) <= 0)
   {
      Print("ERROR: Cannot get D1 timeframe data for new day calculation");
      return;
   }
   
   datetime currentD1Open = d1OpenTime[0];
   
   if(m_currentDay != currentD1Open)
   {
      m_currentDay = currentD1Open;
      m_dailyStartBalance = m_accountBalance;
      m_dailyDrawdownExceeded = false;
      
      // Yeni gün başladığında trading status'u resetle
      ResetDailyTradingStatus();
      
      Print("=== NEW DAY STARTED (D1-0) ===");
      Print("D1 Open Time: ", TimeToString(currentD1Open, TIME_DATE|TIME_MINUTES));
      Print("Daily Start Balance: $", DoubleToString(m_dailyStartBalance, 2));
      Print("Daily Profit Target: ", DoubleToString(m_dailyProfitTargetPercent, 2), "%");
      Print("Profit Realize Target: ", DoubleToString(m_profitRealizePercent, 2), "%");
   }
}

//+------------------------------------------------------------------+
//| Initialize Daily Tracking                                       |
//+------------------------------------------------------------------+
void CFTMORiskManager::InitializeDailyTracking()
{
   // D1 timeframe'den günün başlangıcını al
   datetime d1OpenTime[];
   
   if(CopyTime(Symbol(), PERIOD_D1, 0, 1, d1OpenTime) <= 0)
   {
      Print("WARNING: Cannot get D1 timeframe data, using system date");
      datetime currentTime = TimeCurrent();
      MqlDateTime timeStruct;
      TimeToStruct(currentTime, timeStruct);
      timeStruct.hour = 0;
      timeStruct.min = 0;
      timeStruct.sec = 0;
      m_currentDay = StructToTime(timeStruct);
   }
   else
   {
      m_currentDay = d1OpenTime[0];
   }
   
   m_dailyStartBalance = m_accountBalance;
   m_dailyDrawdownExceeded = false;
   
   Print("Daily tracking initialized:");
   Print("Day start: ", TimeToString(m_currentDay, TIME_DATE|TIME_MINUTES));
   Print("Start balance: $", DoubleToString(m_dailyStartBalance, 2));
}

//+------------------------------------------------------------------+
//| Get Position Opening Commission from Deal History               |
//+------------------------------------------------------------------+
double CFTMORiskManager::GetPositionCommission(ulong positionTicket)
{
   if(!HistorySelectByPosition(positionTicket))
      return 0;
   
   int totalDeals = HistoryDealsTotal();
   double totalCommission = 0;
   
   for(int i = 0; i < totalDeals; i++)
   {
      if(!m_deal.SelectByIndex(i))
         continue;
      
      if(m_deal.Entry() == DEAL_ENTRY_IN && m_deal.PositionId() == positionTicket)
      {
         double commission = m_deal.Commission();
         // Commission negatif olabilir, mutlak değerini al
         totalCommission += (commission < 0) ? MathAbs(commission) : commission;
      }
   }
   
   return totalCommission;
}

//+------------------------------------------------------------------+
//| Get Point Value                                                 |
//+------------------------------------------------------------------+
double CFTMORiskManager::GetPointValue(string symbol)
{
   double tickValue = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   
   if(tickSize > 0)
      return (tickValue * point) / tickSize;
   
   return 0;
}

//+------------------------------------------------------------------+
//| Get Symbol Trading Information                                   |
//+------------------------------------------------------------------+
double CFTMORiskManager::GetMinLotSize(string symbol)
{
   return SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
}

double CFTMORiskManager::GetMaxLotSize(string symbol)
{
   return SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
}

double CFTMORiskManager::GetLotStep(string symbol)
{
   return SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
}

//+------------------------------------------------------------------+
//| Normalize Lot Size                                              |
//+------------------------------------------------------------------+
double CFTMORiskManager::NormalizeLotSize(string symbol, double lotSize)
{
   double minLot = GetMinLotSize(symbol);
   double maxLot = GetMaxLotSize(symbol);
   double lotStep = GetLotStep(symbol);
   
   lotSize = MathMax(minLot, MathMin(maxLot, lotSize));
   
   if(lotStep > 0)
   {
      lotSize = NormalizeDouble(MathRound(lotSize / lotStep) * lotStep, 2);
   }
   
   return lotSize;
}

//+------------------------------------------------------------------+
//| Find Magic Index in Arrays                                      |
//+------------------------------------------------------------------+
int CFTMORiskManager::FindMagicIndex(ulong magic)
{
   for(int i = 0; i < m_configCount; i++)
   {
      if(m_magicNumbers[i] == magic)
         return i;
   }
   return -1;
}

//+------------------------------------------------------------------+
//| Add Magic Configuration                                          |
//+------------------------------------------------------------------+
bool CFTMORiskManager::AddMagicConfig(ulong magic, const SMagicRiskConfig &config)
{
   if(FindMagicIndex(magic) >= 0)
   {
      Print("ERROR: Magic ", magic, " already configured. Use UpdateMagicConfig instead.");
      return false;
   }
   
   if(config.riskPercentPerTrade <= 0 || config.riskPercentPerTrade > 10)
   {
      Print("ERROR: Invalid risk per trade (", config.riskPercentPerTrade, "%). Must be 0.1-10%");
      return false;
   }
   
   if(config.maxTotalRiskPercent <= 0 || config.maxTotalRiskPercent > 50)
   {
      Print("ERROR: Invalid max total risk (", config.maxTotalRiskPercent, "%). Must be 0.1-50%");
      return false;
   }
   
   if(config.riskPercentPerTrade > config.maxTotalRiskPercent)
   {
      Print("ERROR: Risk per trade cannot exceed max total risk");
      return false;
   }
   
   ArrayResize(m_magicConfigs, m_configCount + 1);
   ArrayResize(m_magicNumbers, m_configCount + 1);
   
   m_magicConfigs[m_configCount] = config;
   m_magicConfigs[m_configCount].isActive = true;
   m_magicNumbers[m_configCount] = magic;
   m_configCount++;
   
   // News Manager'a sembol ekle
   UpdateNewsConfiguration(magic);
   
   Print("SUCCESS: Magic ", magic, " configured - Risk/Trade: ", config.riskPercentPerTrade, 
         "%, Max Total: ", config.maxTotalRiskPercent, "%");
   
   if(config.useNewsFilter)
   {
      Print("  News Filter: Enabled");
      Print("  Block Trades: ", config.blockTradesOnNews);
      Print("  Close Positions: ", config.closePositionsOnNews);
      Print("  Minutes Before: ", config.newsMinutesBefore);
      Print("  Minutes After: ", config.newsMinutesAfter);
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Update Magic Configuration                                       |
//+------------------------------------------------------------------+
bool CFTMORiskManager::UpdateMagicConfig(ulong magic, const SMagicRiskConfig &config)
{
   int index = FindMagicIndex(magic);
   if(index < 0)
   {
      Print("ERROR: Magic ", magic, " not found. Use AddMagicConfig first.");
      return false;
   }
   
   m_magicConfigs[index] = config;
   m_magicConfigs[index].isActive = true;
   
   // News konfigürasyonunu güncelle
   UpdateNewsConfiguration(magic);
   
   Print("SUCCESS: Magic ", magic, " configuration updated");
   return true;
}

//+------------------------------------------------------------------+
//| Remove Magic Configuration                                       |
//+------------------------------------------------------------------+
bool CFTMORiskManager::RemoveMagicConfig(ulong magic)
{
   int index = FindMagicIndex(magic);
   if(index < 0)
   {
      Print("ERROR: Magic ", magic, " not found");
      return false;
   }
   
   for(int i = index; i < m_configCount - 1; i++)
   {
      m_magicConfigs[i] = m_magicConfigs[i + 1];
      m_magicNumbers[i] = m_magicNumbers[i + 1];
   }
   
   m_configCount--;
   ArrayResize(m_magicConfigs, m_configCount);
   ArrayResize(m_magicNumbers, m_configCount);
   
   Print("SUCCESS: Magic ", magic, " configuration removed");
   return true;
}

//+------------------------------------------------------------------+
//| Get Magic Configuration                                          |
//+------------------------------------------------------------------+
bool CFTMORiskManager::GetMagicConfig(ulong magic, SMagicRiskConfig &config)
{
   int index = FindMagicIndex(magic);
   if(index >= 0)
   {
      config = m_magicConfigs[index];
      return true;
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Check if Magic is Configured                                    |
//+------------------------------------------------------------------+
bool CFTMORiskManager::IsMagicConfigured(ulong magic)
{
   return FindMagicIndex(magic) >= 0;
}

//+------------------------------------------------------------------+
//| Update News Configuration                                        |
//+------------------------------------------------------------------+
void CFTMORiskManager::UpdateNewsConfiguration(ulong magic)
{
   if(m_newsManager == NULL)
      return;
   
   int index = FindMagicIndex(magic);
   if(index < 0)
      return;
   
   SMagicRiskConfig config = m_magicConfigs[index];
   
   // News Manager konfigürasyonunu güncelle
   if(config.useNewsFilter)
   {
      SNewsFilterConfig newsConfig;
      newsConfig.filterHighImpact = true;
      newsConfig.filterByCurrency = true;
      newsConfig.minutesBefore = config.newsMinutesBefore;
      newsConfig.minutesAfter = config.newsMinutesAfter;
      newsConfig.closePositions = config.closePositionsOnNews;
      newsConfig.blockNewTrades = config.blockTradesOnNews;
      
      m_newsManager.SetFilterConfig(newsConfig);
   }
}

//+------------------------------------------------------------------+
//| Check News Restrictions                                          |
//+------------------------------------------------------------------+
bool CFTMORiskManager::CheckNewsRestrictions(ulong magic, string symbol, string &reason)
{
   reason = "";
   
   // Global haber filtresi kapalıysa kontrol etme
   if(!m_globalNewsFilterEnabled)
      return false;
   
   // News Manager yoksa kısıtlama yok
   if(m_newsManager == NULL)
      return false;
   
   // Magic konfigürasyonunu al
   SMagicRiskConfig config;
   if(!GetMagicConfig(magic, config) || !config.isActive)
      return false;
   
   // Bu magic için haber filtresi kapalıysa
   if(!config.useNewsFilter)
      return false;
   
   // News Manager'ı güncelle
   m_newsManager.UpdateNewsData();
   
   // Symbol'ü monitor et
   if(!m_newsManager.IsSymbolMonitored(symbol))
      m_newsManager.AddSymbolToMonitor(symbol);
   
   // Haber zamanı mı kontrol et
   if(m_newsManager.IsNewsTime(symbol))
   {
      reason = m_newsManager.GetNewsRestrictionReason(symbol);
      return true;
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Calculate ATR                                                    |
//+------------------------------------------------------------------+
double CFTMORiskManager::CalculateATR(string symbol, ENUM_TIMEFRAMES timeframe, int period, int shift = 0)
{
   double atr[];
   int handle = iATR(symbol, timeframe, period);
   
   if(handle == INVALID_HANDLE)
   {
      Print("ERROR: Failed to create ATR indicator for ", symbol);
      return 0;
   }
   
   if(CopyBuffer(handle, 0, shift, 1, atr) <= 0)
   {
      Print("ERROR: Failed to copy ATR data for ", symbol);
      IndicatorRelease(handle);
      return 0;
   }
   
   IndicatorRelease(handle);
   return atr[0];
}

//+------------------------------------------------------------------+
//| Calculate ATR-based Stop Loss                                   |
//+------------------------------------------------------------------+
double CFTMORiskManager::CalculateATRStopLoss(string symbol, ENUM_POSITION_TYPE type, double entryPrice,
                                            ENUM_TIMEFRAMES timeframe, int period, double multiplier)
{
   double atr = CalculateATR(symbol, timeframe, period, 0);
   if(atr <= 0 || entryPrice <= 0)
      return 0;
   
   if(type == POSITION_TYPE_BUY)
      return entryPrice - (atr * multiplier);
   else
      return entryPrice + (atr * multiplier);
}

//+------------------------------------------------------------------+
//| Calculate Lot Size by Risk                                      |
//+------------------------------------------------------------------+
double CFTMORiskManager::CalculateLotSizeByRisk(string symbol, double riskPercent, 
                                              double entryPrice, double stopLoss)
{
   if(stopLoss == 0 || entryPrice == 0)
      return 0;
   
   UpdateAccountInfo();
   
   double riskAmount = m_accountBalance * (riskPercent / 100.0);
   double pointValue = GetPointValue(symbol);
   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   double riskPoints = MathAbs(entryPrice - stopLoss);
   
   if(pointValue <= 0 || point <= 0 || riskPoints <= 0)
      return 0;
   
   double lotSize = riskAmount / ((riskPoints / point) * pointValue);
   
   return NormalizeLotSize(symbol, lotSize);
}

//+------------------------------------------------------------------+
//| Calculate Adjusted Lot Size Based on Remaining Capacity         |
//+------------------------------------------------------------------+
double CFTMORiskManager::CalculateAdjustedLotSize(ulong magic, string symbol, 
                                                 double entryPrice, double stopLoss)
{
   SMagicRiskConfig config;
   if(!GetMagicConfig(magic, config) || !config.isActive)
   {
      Print("ERROR: Magic ", magic, " not configured for adjusted lot calculation");
      return 0;
   }
   
   if(stopLoss == 0 || entryPrice == 0)
   {
      Print("ERROR: Invalid entry price or stop loss for adjusted lot calculation");
      return 0;
   }
   
   double remainingCapacity = GetRemainingRiskCapacity(magic);
   
   if(remainingCapacity <= 0)
   {
      Print("WARNING: No remaining risk capacity for Magic ", magic);
      return 0;
   }
   
   double normalLotSize = CalculateLotSizeByRisk(symbol, config.riskPercentPerTrade, entryPrice, stopLoss);
   double adjustedLotSize = CalculateLotSizeByRisk(symbol, remainingCapacity, entryPrice, stopLoss);
   double finalLotSize = MathMin(normalLotSize, adjustedLotSize);
   
   if(adjustedLotSize < normalLotSize)
   {
      Print("INFO: Lot size adjusted due to capacity limit");
      Print("  Normal lot: ", DoubleToString(normalLotSize, 2));
      Print("  Adjusted lot: ", DoubleToString(adjustedLotSize, 2));
      Print("  Remaining capacity: ", DoubleToString(remainingCapacity, 2), "%");
   }
   
   return finalLotSize;
}

//+------------------------------------------------------------------+
//| Calculate Position Risk Amount (by symbol and parameters)       |
//+------------------------------------------------------------------+
double CFTMORiskManager::CalculatePositionRiskAmount(string symbol, double lotSize, 
                                                   double entryPrice, double stopLoss)
{
   if(stopLoss == 0 || entryPrice == 0 || lotSize <= 0)
      return 0;
   
   double pointValue = GetPointValue(symbol);
   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   double riskPoints = MathAbs(entryPrice - stopLoss);
   
   return (riskPoints / point) * pointValue * lotSize;
}

//+------------------------------------------------------------------+
//| Calculate Position Risk Percentage (by symbol and parameters)   |
//+------------------------------------------------------------------+
double CFTMORiskManager::CalculatePositionRiskPercent(string symbol, double lotSize, 
                                                    double entryPrice, double stopLoss)
{
   double riskAmount = CalculatePositionRiskAmount(symbol, lotSize, entryPrice, stopLoss);
   if(riskAmount <= 0)
      return 0;
   
   UpdateAccountInfo();
   return (riskAmount / m_accountBalance) * 100.0;
}

//+------------------------------------------------------------------+
//| Calculate Take Profit                                           |
//+------------------------------------------------------------------+
double CFTMORiskManager::CalculateTakeProfit(double entryPrice, double stopLoss, 
                                           ENUM_POSITION_TYPE type, double riskRewardRatio)
{
   if(stopLoss == 0 || entryPrice == 0 || riskRewardRatio <= 0)
      return 0;
   
   double riskDistance = MathAbs(entryPrice - stopLoss);
   double rewardDistance = riskDistance * riskRewardRatio;
   
   if(type == POSITION_TYPE_BUY)
      return entryPrice + rewardDistance;
   else
      return entryPrice - rewardDistance;
}

//+------------------------------------------------------------------+
//| Calculate Position Risk Amount (by ticket)                      |
//+------------------------------------------------------------------+
double CFTMORiskManager::CalculatePositionRisk(ulong ticket)
{
   if(!m_position.SelectByTicket(ticket))
      return 0;
   
   string symbol = m_position.Symbol();
   double lotSize = m_position.Volume();
   double entryPrice = m_position.PriceOpen();
   double stopLoss = m_position.StopLoss();
   
   return CalculatePositionRiskAmount(symbol, lotSize, entryPrice, stopLoss);
}

//+------------------------------------------------------------------+
//| Get Magic Risk Amount                                           |
//+------------------------------------------------------------------+
double CFTMORiskManager::GetMagicRiskAmount(ulong magic)
{
   double totalRisk = 0;
   
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(m_position.SelectByIndex(i) && m_position.Magic() == magic)
      {
         totalRisk += CalculatePositionRisk(m_position.Ticket());
      }
   }
   
   return totalRisk;
}

//+------------------------------------------------------------------+
//| Get Magic Risk Percentage                                       |
//+------------------------------------------------------------------+
double CFTMORiskManager::GetMagicRiskPercent(ulong magic)
{
   double riskAmount = GetMagicRiskAmount(magic);
   UpdateAccountInfo();
   return (riskAmount / m_accountBalance) * 100.0;
}

//+------------------------------------------------------------------+
//| Get Total Risk Amount                                           |
//+------------------------------------------------------------------+
double CFTMORiskManager::GetTotalRiskAmount()
{
   double totalRisk = 0;
   
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(m_position.SelectByIndex(i))
      {
         totalRisk += CalculatePositionRisk(m_position.Ticket());
      }
   }
   
   return totalRisk;
}

//+------------------------------------------------------------------+
//| Get Total Risk Percentage                                       |
//+------------------------------------------------------------------+
double CFTMORiskManager::GetTotalRiskPercent()
{
   double riskAmount = GetTotalRiskAmount();
   UpdateAccountInfo();
   return (riskAmount / m_accountBalance) * 100.0;
}

//+------------------------------------------------------------------+
//| Get Magic Position Count                                        |
//+------------------------------------------------------------------+
int CFTMORiskManager::GetMagicPositionCount(ulong magic)
{
   int count = 0;
   
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(m_position.SelectByIndex(i) && m_position.Magic() == magic)
         count++;
   }
   
   return count;
}

//+------------------------------------------------------------------+
//| Get Remaining Risk Capacity for Magic                           |
//+------------------------------------------------------------------+
double CFTMORiskManager::GetRemainingRiskCapacity(ulong magic)
{
   SMagicRiskConfig config;
   if(!GetMagicConfig(magic, config))
      return 0;
   
   double currentRisk = GetMagicRiskPercent(magic);
   return MathMax(0, config.maxTotalRiskPercent - currentRisk);
}

//+------------------------------------------------------------------+
//| Get Position Risk Information                                    |
//+------------------------------------------------------------------+
SPositionRiskInfo CFTMORiskManager::GetPositionRiskInfo(ulong ticket)
{
   SPositionRiskInfo info;
   ZeroMemory(info);
   
   if(!m_position.SelectByTicket(ticket))
      return info;
   
   info.ticket = ticket;
   info.magic = m_position.Magic();
   info.symbol = m_position.Symbol();
   info.lotSize = m_position.Volume();
   info.entryPrice = m_position.PriceOpen();
   info.stopLoss = m_position.StopLoss();
   info.takeProfit = m_position.TakeProfit();
   info.positionType = (ENUM_POSITION_TYPE)m_position.PositionType();
   info.openTime = (datetime)m_position.Time();
   info.riskAmount = CalculatePositionRisk(ticket);
   
   // Doğru parametrelerle çağır
   info.riskPercent = CalculatePositionRiskPercent(info.symbol, info.lotSize, 
                                                   info.entryPrice, info.stopLoss);
   
   if(info.takeProfit > 0)
   {
      double pointValue = GetPointValue(info.symbol);
      double point = SymbolInfoDouble(info.symbol, SYMBOL_POINT);
      double profitPoints = MathAbs(info.entryPrice - info.takeProfit);
      info.potentialProfit = (profitPoints / point) * pointValue * info.lotSize;
   }
   
   return info;
}

//+------------------------------------------------------------------+
//| Get All Positions                                               |
//+------------------------------------------------------------------+
int CFTMORiskManager::GetAllPositions(SPositionRiskInfo &positions[])
{
   int count = PositionsTotal();
   
   if(count == 0)
      return 0;
   
   ArrayResize(positions, count);
   
   for(int i = 0; i < count; i++)
   {
      if(m_position.SelectByIndex(i))
      {
         positions[i] = GetPositionRiskInfo(m_position.Ticket());
      }
   }
   
   return count;
}

//+------------------------------------------------------------------+
//| Validate Position Risk (Complete Validation)                    |
//+------------------------------------------------------------------+
bool CFTMORiskManager::ValidatePositionRisk(ulong magic, string symbol, double lotSize, 
                                           double stopLoss, double entryPrice)
{
   SMagicRiskConfig config;
   if(!GetMagicConfig(magic, config) || !config.isActive)
   {
      Print("ERROR: Magic ", magic, " not configured or inactive");
      return false;
   }
   
   if(!CheckDailyDrawdownLimit())
   {
      Print("ERROR: Daily drawdown limit exceeded - trading disabled");
      return false;
   }
   
   if(!CheckPositionCountLimits(magic))
   {
      Print("ERROR: Position count limits exceeded");
      return false;
   }
   
   if(!CheckDailyRiskLimits())
   {
      Print("ERROR: Daily risk limits exceeded");
      return false;
   }
   
   if(!CheckGlobalRiskLimits())
   {
      Print("ERROR: Global risk limits exceeded");
      return false;
   }
   
   double riskAmount = CalculatePositionRiskAmount(symbol, lotSize, entryPrice, stopLoss);
   double riskPercent = CalculatePositionRiskPercent(symbol, lotSize, entryPrice, stopLoss);
   
   if(riskPercent <= 0)
   {
      Print("ERROR: Cannot calculate position risk - invalid parameters");
      return false;
   }
   
   if(riskPercent > config.riskPercentPerTrade)
   {
      Print("ERROR: Position risk (", DoubleToString(riskPercent, 2), "%) exceeds per-trade limit (", 
            config.riskPercentPerTrade, "%) for Magic ", magic);
      return false;
   }
   
   double currentMagicRisk = GetMagicRiskPercent(magic);
   double totalMagicRisk = currentMagicRisk + riskPercent;
   if(totalMagicRisk > config.maxTotalRiskPercent)
   {
      Print("ERROR: Total magic risk would be (", DoubleToString(totalMagicRisk, 2), 
            "%) exceeding limit (", config.maxTotalRiskPercent, "%) for Magic ", magic);
      return false;
   }
   
   double remainingCapacity = GetRemainingRiskCapacity(magic);
   if(riskPercent > remainingCapacity)
   {
      Print("ERROR: Position risk (", DoubleToString(riskPercent, 2), "%) exceeds remaining capacity (", 
            DoubleToString(remainingCapacity, 2), "%) for Magic ", magic);
      return false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Analyze Position Risk - Updated with News Control               |
//+------------------------------------------------------------------+
SRiskAnalysisResult CFTMORiskManager::AnalyzePositionRisk(ulong magic, string symbol, 
                                                        double entryPrice, ENUM_POSITION_TYPE type, 
                                                        double stopLoss = 0)
{
   SRiskAnalysisResult result;
   ZeroMemory(result);
   
   // 1. Trading genel olarak izinli mi kontrol et
   if(!IsTradingAllowed())
   {
      result.riskMessage = "Trading not allowed - daily limits reached";
      return result;
   }
   
   // 2. Magic konfigürasyonu kontrolü
   SMagicRiskConfig config;
   if(!GetMagicConfig(magic, config) || !config.isActive)
   {
      result.riskMessage = "Magic " + IntegerToString(magic) + " not configured or inactive";
      return result;
   }
   
   // 3. HABER KONTROLÜ (YENİ)
   string newsReason;
   if(CheckNewsRestrictions(magic, symbol, newsReason))
   {
      result.newsRestricted = true;
      result.newsRestrictionReason = newsReason;
      
      if(config.blockTradesOnNews)
      {
         result.riskMessage = "News restriction: " + newsReason;
         result.isValid = false;
         return result;
      }
   }
   
   result.entryPrice = entryPrice;
   result.riskRewardRatio = config.riskRewardRatio;
   
   // 4. Stop Loss hesaplama/kontrolü
   if(config.useATRStopLoss && stopLoss == 0)
   {
      result.stopLoss = CalculateATRStopLoss(symbol, type, entryPrice, 
                                           config.atrTimeframe, config.atrPeriod, config.atrMultiplier);
   }
   else
   {
      result.stopLoss = stopLoss;
   }
   
   if(result.stopLoss <= 0)
   {
      result.riskMessage = "Invalid stop loss - cannot calculate";
      return result;
   }
   
   // 5. Take Profit hesaplama
   result.takeProfit = CalculateTakeProfit(entryPrice, result.stopLoss, type, config.riskRewardRatio);
   
   // 6. Lot size hesaplama
   result.recommendedLotSize = CalculateAdjustedLotSize(magic, symbol, entryPrice, result.stopLoss);
   
   if(result.recommendedLotSize <= 0)
   {
      result.riskMessage = "Cannot calculate lot size - invalid parameters or no risk capacity";
      return result;
   }
   
   // 7. Risk hesaplamaları
   result.calculatedRisk = CalculatePositionRiskAmount(symbol, result.recommendedLotSize, 
                                                     entryPrice, result.stopLoss);
   result.calculatedRiskPercent = CalculatePositionRiskPercent(symbol, result.recommendedLotSize, 
                                                             entryPrice, result.stopLoss);
   
   // 8. Potansiyel kar hesaplama
   if(result.takeProfit > 0)
   {
      double pointValue = GetPointValue(symbol);
      double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
      double profitPoints = MathAbs(entryPrice - result.takeProfit);
      result.potentialProfit = (profitPoints / point) * pointValue * result.recommendedLotSize;
   }
   
   result.remainingCapacity = GetRemainingRiskCapacity(magic);
   
   // 9. Detaylı validasyon (tüm kontroller)
   result.isValid = ValidatePositionRisk(magic, symbol, result.recommendedLotSize, result.stopLoss, entryPrice);
   
   // 10. Detaylı mesaj oluşturma
   if(result.isValid)
   {
      string newsInfo = result.newsRestricted ? " [NEWS WARNING]" : "";
      result.riskMessage = StringFormat("Position ready: Lot=%.2f, Risk=%.2f%%, Reward=%.2f%%, Positions=%d/%d%s", 
                                      result.recommendedLotSize, result.calculatedRiskPercent, 
                                      (result.potentialProfit / m_accountBalance * 100.0),
                                      GetMagicPositionCount(magic), m_maxMagicPositions, newsInfo);
   }
   else
   {
      // Haber kısıtlaması varsa öncelikli mesaj
      if(result.newsRestricted && config.blockTradesOnNews)
         result.riskMessage = "News restriction: " + newsReason;
      else if(ShouldStopTradingProfit())
         result.riskMessage = "Daily profit target reached - trading stopped";
      else if(ShouldStopTradingDrawdown())
         result.riskMessage = "Daily drawdown limit exceeded - trading stopped";
      else if(!CheckDailyDrawdownLimit())
         result.riskMessage = "Daily drawdown limit exceeded";
      else if(!CheckPositionCountLimits(magic))
         result.riskMessage = "Position count limits exceeded";
      else if(!CheckDailyRiskLimits())
         result.riskMessage = "Daily risk limits exceeded";
      else if(result.calculatedRiskPercent > config.riskPercentPerTrade)
         result.riskMessage = "Risk per trade limit exceeded";
      else if(result.calculatedRiskPercent > result.remainingCapacity)
         result.riskMessage = "Magic total risk limit would be exceeded";
      else if(!CheckGlobalRiskLimits())
         result.riskMessage = "Global risk limits exceeded";
      else
         result.riskMessage = "Position cannot be opened - risk limits";
   }
   
   return result;
}

//+------------------------------------------------------------------+
//| Check Global Risk Limits                                        |
//+------------------------------------------------------------------+
bool CFTMORiskManager::CheckGlobalRiskLimits()
{
   double totalRisk = GetTotalRiskPercent();
   
   if(totalRisk >= m_maxGlobalRiskPercent)
   {
      Print("ERROR: Global risk (", DoubleToString(totalRisk, 2), "%) exceeds limit (", m_maxGlobalRiskPercent, "%)");
      return false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Check Daily Risk Limits (Risk + Drawdown)                       |
//+------------------------------------------------------------------+
bool CFTMORiskManager::CheckDailyRiskLimits()
{
   if(!CheckDailyDrawdownLimit())
      return false;
   
   double totalRisk = GetTotalRiskPercent();
   if(totalRisk >= m_maxDailyRiskPercent)
   {
      Print("ERROR: Daily total risk (", DoubleToString(totalRisk, 2), 
            "%) exceeds limit (", m_maxDailyRiskPercent, "%)");
      return false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Check Position Count Limits                                     |
//+------------------------------------------------------------------+
bool CFTMORiskManager::CheckPositionCountLimits(ulong magic)
{
   int totalPositions = PositionsTotal();
   if(totalPositions >= m_maxGlobalPositions)
   {
      Print("ERROR: Global position limit reached (", totalPositions, "/", m_maxGlobalPositions, ")");
      return false;
   }
   
   int magicPositions = GetMagicPositionCount(magic);
   if(magicPositions >= m_maxMagicPositions)
   {
      Print("ERROR: Magic ", magic, " position limit reached (", magicPositions, "/", m_maxMagicPositions, ")");
      return false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Get Daily Drawdown Percentage                                   |
//+------------------------------------------------------------------+
double CFTMORiskManager::GetDailyDrawdownPercent()
{
   if(m_dailyStartBalance <= 0)
      return 0;
   
   double dailyTotalPnL = GetDailyTotalPnL();
   
   if(dailyTotalPnL >= 0)
      return 0;
   
   return MathAbs(dailyTotalPnL) / m_dailyStartBalance * 100.0;
}

//+------------------------------------------------------------------+
//| Get Daily Drawdown Amount                                       |
//+------------------------------------------------------------------+
double CFTMORiskManager::GetDailyDrawdownAmount()
{
   double dailyTotalPnL = GetDailyTotalPnL();
   
   if(dailyTotalPnL >= 0)
      return 0;
   
   return MathAbs(dailyTotalPnL);
}

//+------------------------------------------------------------------+
//| Get Daily P&L (Sadece Açık Pozisyonlar)                         |
//+------------------------------------------------------------------+
double CFTMORiskManager::GetDailyPnL()
{
   return GetDailyFloatingPnL();
}

//+------------------------------------------------------------------+
//| Get Daily Closed P&L (History)                                  |
//+------------------------------------------------------------------+
double CFTMORiskManager::GetDailyClosedPnL()
{
   double totalClosedPnL = 0;
   
   if(!HistorySelect(m_currentDay, TimeCurrent()))
   {
      Print("ERROR: Cannot select history for daily P&L calculation");
      return 0;
   }
   
   int totalDeals = HistoryDealsTotal();
   
   for(int i = 0; i < totalDeals; i++)
   {
      if(!m_deal.SelectByIndex(i))
         continue;
      
      if(m_deal.Entry() == DEAL_ENTRY_OUT)
      {
         datetime dealTime = m_deal.Time();
         
         if(dealTime >= m_currentDay)
         {
            totalClosedPnL += m_deal.Profit();
            totalClosedPnL += m_deal.Commission();
            totalClosedPnL += m_deal.Swap();
         }
      }
   }
   
   return totalClosedPnL;
}

//+------------------------------------------------------------------+
//| Get Daily Floating P&L                                          |
//+------------------------------------------------------------------+
double CFTMORiskManager::GetDailyFloatingPnL()
{
   double totalFloatingPnL = 0;
   
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(m_position.SelectByIndex(i))
      {
         double profit = m_position.Profit();
         double swap = m_position.Swap();
         double commission = GetPositionCommission(m_position.Ticket());
         
         // Commission negatif olabilir, doğru işaretle ekle
         totalFloatingPnL += profit + swap - commission;
      }
   }
   
   return totalFloatingPnL;
}

//+------------------------------------------------------------------+
//| Get Daily Total P&L (Closed + Floating)                         |
//+------------------------------------------------------------------+
double CFTMORiskManager::GetDailyTotalPnL()
{
   return GetDailyClosedPnL() + GetDailyFloatingPnL();
}

//+------------------------------------------------------------------+
//| Get Daily Total P&L Percentage                                  |
//+------------------------------------------------------------------+
double CFTMORiskManager::GetDailyTotalPnLPercent()
{
   if(m_dailyStartBalance <= 0)
      return 0;
   
   double dailyTotalPnL = GetDailyTotalPnL();
   return (dailyTotalPnL / m_dailyStartBalance) * 100.0;
}

//+------------------------------------------------------------------+
//| Get Floating Profit Percentage                                  |
//+------------------------------------------------------------------+
double CFTMORiskManager::GetFloatingProfitPercent()
{
   if(m_dailyStartBalance <= 0)
      return 0;
   
   double floatingPnL = GetDailyFloatingPnL();
   
   if(floatingPnL <= 0)
      return 0;
   
   return (floatingPnL / m_dailyStartBalance) * 100.0;
}

//+------------------------------------------------------------------+
//| Should Stop Trading - Daily Profit Target                       |
//+------------------------------------------------------------------+
bool CFTMORiskManager::ShouldStopTradingProfit()
{
   if(m_dailyProfitTargetPercent <= 0)
      return false;
   
   double dailyTotalPnLPercent = GetDailyTotalPnLPercent();
   
   if(dailyTotalPnLPercent >= m_dailyProfitTargetPercent)
   {
      if(!m_tradingStopped)
      {
         m_tradingStopped = true;
         Print("TRADING STOPPED: Daily profit target reached!");
         Print("Daily Total P&L: ", DoubleToString(dailyTotalPnLPercent, 2), "%");
         Print("Target: ", DoubleToString(m_dailyProfitTargetPercent, 2), "%");
         Print("=== ALL POSITIONS SHOULD BE CLOSED ===");
      }
      return true;
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Should Stop Trading - Daily Drawdown                            |
//+------------------------------------------------------------------+
bool CFTMORiskManager::ShouldStopTradingDrawdown()
{
   double currentDrawdown = GetDailyDrawdownPercent();
   
   if(currentDrawdown >= m_maxDailyDrawdownPercent)
   {
      if(!m_tradingStopped)
      {
         m_tradingStopped = true;
         Print("TRADING STOPPED: Daily drawdown limit exceeded!");
         Print("Current Drawdown: ", DoubleToString(currentDrawdown, 2), "%");
         Print("Maximum Allowed: ", DoubleToString(m_maxDailyDrawdownPercent, 2), "%");
         Print("=== EMERGENCY CLOSE ALL POSITIONS ===");
      }
      return true;
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Should Realize Profits - Floating P&L                           |
//+------------------------------------------------------------------+
bool CFTMORiskManager::ShouldRealizeProfits()
{
   if(m_profitRealizePercent <= 0)
      return false;
   
   double floatingProfitPercent = GetFloatingProfitPercent();
   
   if(floatingProfitPercent >= m_profitRealizePercent)
   {
      Print("PROFIT REALIZATION: Floating profit target reached!");
      Print("Floating Profit: ", DoubleToString(floatingProfitPercent, 2), "%");
      Print("Target: ", DoubleToString(m_profitRealizePercent, 2), "%");
      Print("=== CLOSING ALL POSITIONS FOR PROFIT REALIZATION ===");
      return true;
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Is Trading Allowed                                              |
//+------------------------------------------------------------------+
bool CFTMORiskManager::IsTradingAllowed()
{
   // Account info güncelle
   UpdateAccountInfo();
   
   // Trading durdurulmuşsa izin verme
   if(m_tradingStopped)
   {
      Print("TRADING BLOCKED: Manual stop active");
      return false;
   }
   
   // Daily profit target kontrolü
   if(ShouldStopTradingProfit())
   {
      Print("TRADING BLOCKED: Daily profit target reached");
      return false;
   }
   
   // Daily drawdown kontrolü  
   if(ShouldStopTradingDrawdown())
   {
      Print("TRADING BLOCKED: Daily drawdown limit exceeded");
      return false;
   }
   
   // Market hours kontrolü
   if(!SymbolInfoInteger(Symbol(), SYMBOL_TRADE_MODE))
   {
      Print("TRADING BLOCKED: Market closed");
      return false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Reset Daily Trading Status                                      |
//+------------------------------------------------------------------+
void CFTMORiskManager::ResetDailyTradingStatus()
{
   m_tradingStopped = false;
   Print("Daily trading status reset - Trading allowed");
}

//+------------------------------------------------------------------+
//| Check Daily Drawdown Limit                                      |
//+------------------------------------------------------------------+
bool CFTMORiskManager::CheckDailyDrawdownLimit()
{
   double currentDrawdown = GetDailyDrawdownPercent();
   
   if(currentDrawdown >= m_maxDailyDrawdownPercent)
   {
      if(!m_dailyDrawdownExceeded)
      {
         m_dailyDrawdownExceeded = true;
         Print("CRITICAL: Daily drawdown limit exceeded!");
         Print("Current Drawdown: ", DoubleToString(currentDrawdown, 2), "%");
         Print("Maximum Allowed: ", m_maxDailyDrawdownPercent, "%");
         Print("=== TRADING SHOULD BE STOPPED ===");
      }
      return false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Reset Daily Tracking (Manual)                                   |
//+------------------------------------------------------------------+
void CFTMORiskManager::ResetDailyTracking()
{
   UpdateAccountInfo();
   InitializeDailyTracking();
   Print("Daily tracking manually reset");
}

//+------------------------------------------------------------------+
//| Should Close Positions for News                                 |
//+------------------------------------------------------------------+
bool CFTMORiskManager::ShouldClosePositionsForNews(ulong magic)
{
   if(!m_globalNewsFilterEnabled || m_newsManager == NULL)
      return false;
   
   SMagicRiskConfig config;
   if(!GetMagicConfig(magic, config) || !config.isActive)
      return false;
   
   if(!config.useNewsFilter || !config.closePositionsOnNews)
      return false;
   
   // Magic'e ait pozisyonları kontrol et
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(m_position.SelectByIndex(i) && m_position.Magic() == magic)
      {
         string symbol = m_position.Symbol();
         if(m_newsManager.ShouldClosePosition(symbol))
            return true;
      }
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Get Magic Positions to Close for News                           |
//+------------------------------------------------------------------+
int CFTMORiskManager::GetMagicPositionsToCloseForNews(ulong magic, ulong &tickets[])
{
   ArrayResize(tickets, 0);
   
   if(!m_globalNewsFilterEnabled || m_newsManager == NULL)
      return 0;
   
   SMagicRiskConfig config;
   if(!GetMagicConfig(magic, config) || !config.isActive)
      return 0;
   
   if(!config.useNewsFilter || !config.closePositionsOnNews)
      return 0;
   
   int count = 0;
   
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(m_position.SelectByIndex(i) && m_position.Magic() == magic)
      {
         string symbol = m_position.Symbol();
         if(m_newsManager.ShouldClosePosition(symbol))
         {
            ArrayResize(tickets, count + 1);
            tickets[count] = m_position.Ticket();
            count++;
         }
      }
   }
   
   return count;
}

//+------------------------------------------------------------------+
//| Get Risk Summary                                                |
//+------------------------------------------------------------------+
string CFTMORiskManager::GetRiskSummary()
{
   UpdateAccountInfo();
   
   string summary = StringFormat(
      "Risk Summary: Total=%.2f%% (%.2f$), Global Limit=%.2f%%, Positions=%d",
      GetTotalRiskPercent(),
      GetTotalRiskAmount(),
      m_maxGlobalRiskPercent,
      PositionsTotal()
   );
   
   return summary;
}

//+------------------------------------------------------------------+
//| Get Magic Risk Summary                                          |
//+------------------------------------------------------------------+
string CFTMORiskManager::GetMagicRiskSummary(ulong magic)
{
   SMagicRiskConfig config;
   if(!GetMagicConfig(magic, config))
      return "Magic not configured";
   
   string summary = StringFormat(
      "Magic %d: Risk=%.2f%% (%.2f$), Limit=%.2f%%, Remaining=%.2f%%, Positions=%d",
      magic,
      GetMagicRiskPercent(magic),
      GetMagicRiskAmount(magic),
      config.maxTotalRiskPercent,
      GetRemainingRiskCapacity(magic),
      GetMagicPositionCount(magic)
   );
   
   return summary;
}

//+------------------------------------------------------------------+
//| Print News Status                                               |
//+------------------------------------------------------------------+
void CFTMORiskManager::PrintNewsStatus()
{
   Print("\n========== NEWS FILTER STATUS ==========");
   Print("Global News Filter: ", m_globalNewsFilterEnabled ? "Enabled" : "Disabled");
   Print("News Manager: ", m_newsManager != NULL ? "Connected" : "Not Connected");
   
   if(m_newsManager != NULL && m_globalNewsFilterEnabled)
   {
      // Her magic için haber durumunu yazdır
      for(int i = 0; i < m_configCount; i++)
      {
         ulong magic = m_magicNumbers[i];
         SMagicRiskConfig config = m_magicConfigs[i];
         
         if(config.useNewsFilter)
         {
            Print("\nMagic ", magic, " News Settings:");
            Print("  Block Trades on News: ", config.blockTradesOnNews);
            Print("  Close Positions on News: ", config.closePositionsOnNews);
            Print("  Minutes Before: ", config.newsMinutesBefore);
            Print("  Minutes After: ", config.newsMinutesAfter);
            
            // Magic'e ait pozisyonların haber durumu
            int newsAffectedPositions = 0;
            for(int j = PositionsTotal() - 1; j >= 0; j--)
            {
               if(m_position.SelectByIndex(j) && m_position.Magic() == magic)
               {
                  string symbol = m_position.Symbol();
                  if(m_newsManager.IsNewsTime(symbol))
                  {
                     newsAffectedPositions++;
                     Print("  WARNING: Position ", m_position.Ticket(), " (", symbol, ") in news time!");
                  }
               }
            }
            
            if(newsAffectedPositions > 0)
            {
               Print("  Total positions affected by news: ", newsAffectedPositions);
            }
         }
      }
      
      // News Manager raporu
      m_newsManager.PrintNewsReport();
   }
   
   Print("========================================\n");
}

//+------------------------------------------------------------------+
//| Print Risk Report                                               |
//+------------------------------------------------------------------+
void CFTMORiskManager::PrintRiskReport()
{
   UpdateAccountInfo();
   
   Print("\n========== FTMO RISK MANAGER REPORT ==========");
   Print("Account Balance: $", DoubleToString(m_accountBalance, 2));
   Print("Account Equity: $", DoubleToString(m_accountEquity, 2));
   Print("Free Margin: $", DoubleToString(m_accountFreeMargin, 2));
   Print("Max Daily Risk: ", m_maxDailyRiskPercent, "%");
   Print("Max Global Risk: ", m_maxGlobalRiskPercent, "%");
   Print("Max Daily Drawdown: ", m_maxDailyDrawdownPercent, "%");
   Print("Daily Profit Target: ", m_dailyProfitTargetPercent, "%");
   Print("Profit Realize Target: ", m_profitRealizePercent, "%");
   Print("Max Global Positions: ", m_maxGlobalPositions);
   Print("Max Magic Positions: ", m_maxMagicPositions);
   Print("Total Risk: $", DoubleToString(GetTotalRiskAmount(), 2), " (", 
         DoubleToString(GetTotalRiskPercent(), 2), "%)");
   Print("Current Positions: ", PositionsTotal(), "/", m_maxGlobalPositions);
   Print("Current Daily Total P&L: $", DoubleToString(GetDailyTotalPnL(), 2), " (", 
         DoubleToString(GetDailyTotalPnLPercent(), 2), "%)");
   Print("Current Daily Floating P&L: $", DoubleToString(GetDailyFloatingPnL(), 2), " (", 
         DoubleToString(GetFloatingProfitPercent(), 2), "%)");
   Print("Current Daily Drawdown: ", DoubleToString(GetDailyDrawdownPercent(), 2), "% ($", 
         DoubleToString(GetDailyDrawdownAmount(), 2), ")");
   Print("Daily Closed P&L: $", DoubleToString(GetDailyClosedPnL(), 2));
   Print("Trading Status: ", (IsTradingAllowed() ? "ALLOWED" : "STOPPED"));
   Print("News Manager: ", m_newsManager != NULL ? "Connected" : "Not Connected");
   Print("Global News Filter: ", m_globalNewsFilterEnabled ? "Enabled" : "Disabled");
   
   Print("\n--- MAGIC CONFIGURATIONS ---");
   for(int i = 0; i < m_configCount; i++)
   {
      ulong magic = m_magicNumbers[i];
      SMagicRiskConfig config = m_magicConfigs[i];
      
      Print("Magic ", magic, ":");
      Print("  Risk/Trade: ", config.riskPercentPerTrade, "%");
      Print("  Max Total: ", config.maxTotalRiskPercent, "%");
      Print("  Risk:Reward: 1:", config.riskRewardRatio);
      Print("  News Filter: ", config.useNewsFilter ? "Enabled" : "Disabled");
      
      if(config.useNewsFilter)
      {
         Print("    Block Trades: ", config.blockTradesOnNews);
         Print("    Close Positions: ", config.closePositionsOnNews);
         Print("    Minutes Before/After: ", config.newsMinutesBefore, "/", config.newsMinutesAfter);
      }
      
      Print("  Current Risk: $", DoubleToString(GetMagicRiskAmount(magic), 2), 
            " (", DoubleToString(GetMagicRiskPercent(magic), 2), "%)");
      Print("  Positions: ", GetMagicPositionCount(magic));
      Print("  Remaining Capacity: ", DoubleToString(GetRemainingRiskCapacity(magic), 2), "%");
      
      // Haber kısıtlaması kontrolü
      if(config.useNewsFilter && m_newsManager != NULL)
      {
         int newsRestricted = 0;
         for(int j = PositionsTotal() - 1; j >= 0; j--)
         {
            if(m_position.SelectByIndex(j) && m_position.Magic() == magic)
            {
               if(m_newsManager.IsNewsTime(m_position.Symbol()))
                  newsRestricted++;
            }
         }
         if(newsRestricted > 0)
            Print("  NEWS WARNING: ", newsRestricted, " positions in news time!");
      }
      
      Print("  Status: ", (config.isActive ? "ACTIVE" : "INACTIVE"));
   }
   
   Print("==============================================\n");
}

//+------------------------------------------------------------------+
//| Print Magic Report                                              |
//+------------------------------------------------------------------+
void CFTMORiskManager::PrintMagicReport(ulong magic)
{
   Print("\n========== MAGIC ", magic, " RISK REPORT ==========");
   
   SMagicRiskConfig config;
   if(!GetMagicConfig(magic, config))
   {
      Print("Magic ", magic, " not configured");
      Print("==============================================\n");
      return;
   }
   
   Print(GetMagicRiskSummary(magic));
   
   // Configuration details
   Print("\n--- CONFIGURATION ---");
   Print("Risk per Trade: ", config.riskPercentPerTrade, "%");
   Print("Max Total Risk: ", config.maxTotalRiskPercent, "%");
   Print("Risk:Reward Ratio: 1:", config.riskRewardRatio);
   Print("Active: ", config.isActive ? "Yes" : "No");
   
   // ATR Settings
   if(config.useATRStopLoss)
   {
      Print("\n--- ATR STOP LOSS ---");
      Print("ATR Period: ", config.atrPeriod);
      Print("ATR Timeframe: ", EnumToString(config.atrTimeframe));
      Print("ATR Multiplier: ", config.atrMultiplier);
   }
   
   // News Settings
   if(config.useNewsFilter)
   {
      Print("\n--- NEWS FILTER ---");
      Print("Block Trades on News: ", config.blockTradesOnNews);
      Print("Close Positions on News: ", config.closePositionsOnNews);
      Print("Minutes Before: ", config.newsMinutesBefore);
      Print("Minutes After: ", config.newsMinutesAfter);
   }
   
   // Current positions
   Print("\n--- POSITIONS ---");
   int posCount = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(m_position.SelectByIndex(i) && m_position.Magic() == magic)
      {
         posCount++;
         Print("Position ", m_position.Ticket(), ":");
         Print("  Symbol: ", m_position.Symbol());
         Print("  Type: ", m_position.TypeDescription());
         Print("  Volume: ", m_position.Volume());
         Print("  Risk: $", DoubleToString(CalculatePositionRisk(m_position.Ticket()), 2));
         
         if(config.useNewsFilter && m_newsManager != NULL)
         {
            if(m_newsManager.IsNewsTime(m_position.Symbol()))
               Print("  NEWS: IN NEWS TIME!");
         }
      }
   }
   
   if(posCount == 0)
      Print("No open positions");
   
   Print("==============================================\n");
}

//+------------------------------------------------------------------+
//| Print Position Report                                           |
//+------------------------------------------------------------------+
void CFTMORiskManager::PrintPositionReport(ulong ticket)
{
   SPositionRiskInfo info = GetPositionRiskInfo(ticket);
   
   if(info.ticket == 0)
   {
      Print("Position ", ticket, " not found");
      return;
   }
   
   Print("\n========== POSITION ", ticket, " RISK REPORT ==========");
   Print("Magic: ", info.magic);
   Print("Symbol: ", info.symbol);
   Print("Type: ", (info.positionType == POSITION_TYPE_BUY ? "BUY" : "SELL"));
   Print("Lot Size: ", info.lotSize);
   Print("Entry Price: ", info.entryPrice);
   Print("Stop Loss: ", info.stopLoss);
   Print("Take Profit: ", info.takeProfit);
   Print("Risk Amount: $", DoubleToString(info.riskAmount, 2));
   Print("Risk Percent: ", DoubleToString(info.riskPercent, 2), "%");
   Print("Potential Profit: $", DoubleToString(info.potentialProfit, 2));
   Print("Open Time: ", TimeToString(info.openTime));
   
   // News status check
   if(m_newsManager != NULL && m_globalNewsFilterEnabled)
   {
      SMagicRiskConfig config;
      if(GetMagicConfig(info.magic, config) && config.useNewsFilter)
      {
         if(m_newsManager.IsNewsTime(info.symbol))
         {
            Print("\n--- NEWS STATUS ---");
            Print("WARNING: Position is in news time!");
            Print("News: ", m_newsManager.GetNewsRestrictionReason(info.symbol));
         }
      }
   }
   
   Print("==============================================\n");
}
