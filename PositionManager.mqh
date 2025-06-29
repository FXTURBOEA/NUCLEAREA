//+------------------------------------------------------------------+
//|                                            PositionManager.mqh   |
//|                                         FTMO Algorithmic Trading |
//|                             Professional Position Management V3  |
//+------------------------------------------------------------------+
#property copyright "FTMO Algorithmic Trading"
#property version   "3.10"
#property strict

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\OrderInfo.mqh>
#include "RiskManager.mqh"

//+------------------------------------------------------------------+
//| Global Position Configuration Structure                          |
//+------------------------------------------------------------------+
struct SGlobalPositionConfig
{
   // Trailing & Breakeven
   bool              enableTrailing;          // Global trailing aktif
   bool              enableBreakeven;         // Global breakeven aktif
   double            atrMultiplierTrail;      // Trailing ATR çarpanı
   double            atrMultiplierBE;         // Breakeven ATR çarpanı
   int               atrPeriod;               // ATR periyodu
   ENUM_TIMEFRAMES   atrTimeframe;            // ATR timeframe
   double            minProfitATRTrail;       // Trailing için min kar (ATR cinsinden)
   double            minProfitATRBE;          // Breakeven için min kar (ATR cinsinden)
   
   // Partial Close (Reward bazlı)
   bool              enablePartialClose;      // Partial close aktif
   double            partialClosePercent;     // Kapatılacak lot yüzdesi
   double            partialCloseTriggerReward; // Reward'ın yüzde kaçında tetiklensin
   
   // Time Management
   bool              enableDayEndClose;       // Gün sonu kapatma
   bool              enableWeekendClose;      // Hafta sonu kapatma
   int               dayEndHour;              // Gün sonu saati
   int               dayEndMinute;            // Gün sonu dakikası
   
   // News Management
   bool              enableNewsClose;         // News kapatma
   int               newsMinutesBefore;       // News'den kaç dk önce
   int               newsMinutesAfter;        // News'den kaç dk sonra
   
   // Retry Settings
   int               maxRetries;              // Maksimum deneme sayısı
   int               retryDelay;              // Deneme arası gecikme (ms)
};

//+------------------------------------------------------------------+
//| Strategy Position Configuration Structure                        |
//+------------------------------------------------------------------+
struct SStrategyPositionConfig
{
   // Strategy Identification
   ulong             magic;                   // Magic number
   string            strategyName;            // Strategy name
   bool              isActive;                // Konfigürasyon aktif mi
   
   // Override Flags
   bool              useCustomTrailing;       // Custom trailing kullan
   bool              useCustomBreakeven;      // Custom breakeven kullan
   bool              useCustomPartial;        // Custom partial close kullan
   bool              useCustomTime;           // Custom time management kullan
   bool              useCustomNews;           // Custom news management kullan
   
   // Strategy-Specific Trailing Settings
   bool              enableTrailing;          // Trailing aktif
   double            atrMultiplierTrail;      // Trailing ATR çarpanı
   int               atrPeriodTrail;          // Trailing ATR periyodu
   ENUM_TIMEFRAMES   atrTimeframeTrail;       // Trailing ATR timeframe
   double            minProfitATRTrail;       // Min kar (ATR cinsinden)
   double            trailingStepATR;         // Trailing step (ATR cinsinden)
   
   // Strategy-Specific Breakeven Settings
   bool              enableBreakeven;         // Breakeven aktif
   double            atrMultiplierBE;         // Breakeven ATR çarpanı
   int               atrPeriodBE;             // Breakeven ATR periyodu
   ENUM_TIMEFRAMES   atrTimeframeBE;          // Breakeven ATR timeframe
   double            minProfitATRBE;          // Min kar (ATR cinsinden)
   double            breakevenOffsetATR;      // Breakeven offset (ATR cinsinden)
   
   // Strategy-Specific Partial Close Settings
   bool              enablePartialClose;      // Partial close aktif
   double            partialClosePercent;     // Kapatılacak lot yüzdesi
   double            partialCloseTriggerReward; // Reward'ın yüzde kaçında
   
   // Strategy-Specific Time Management
   bool              enableDayEndClose;       // Gün sonu kapatma
   bool              enableWeekendClose;      // Hafta sonu kapatma
   int               dayEndHour;              // Gün sonu saati
   int               dayEndMinute;            // Gün sonu dakikası
   
   // Strategy-Specific News Management
   bool              enableNewsClose;         // News kapatma
   int               newsMinutesBefore;       // News'den kaç dk önce
   int               newsMinutesAfter;        // News'den kaç dk sonra
   
   // Risk Integration
   double            maxRiskPerStrategy;      // Strategy başına max risk %
   bool              closeOnRiskLimit;        // Risk limitinde kapat
};

//+------------------------------------------------------------------+
//| Position Status Structure                                        |
//+------------------------------------------------------------------+
struct SPositionStatus
{
   ulong             ticket;                  // Position ticket
   ulong             magic;                   // Magic number
   string            symbol;                  // Symbol
   ENUM_POSITION_TYPE type;                   // BUY/SELL
   double            lotSize;                 // Current lot size
   double            originalLotSize;         // Original lot size
   double            entryPrice;              // Entry price
   double            currentSL;               // Current stop loss
   double            currentTP;               // Current take profit
   double            currentProfit;           // Current profit (currency)
   double            currentProfitATR;        // Current profit (ATR cinsinden)
   double            rewardRatio;             // Current reward ratio
   bool              breakEvenSet;            // Breakeven set edildi mi
   bool              partialClosed;           // Partial close yapıldı mı
   bool              newsAffected;            // Haber etkisinde mi
   string            newsReason;              // Haber nedeni
   datetime          lastUpdate;              // Son güncelleme zamanı
};

//+------------------------------------------------------------------+
//| Config Cache Entry Structure                                     |
//+------------------------------------------------------------------+
struct SConfigCache
{
   ulong             magic;                   // Magic number
   SGlobalPositionConfig config;              // Cached config
   datetime          lastUpdate;              // Son güncelleme zamanı
   bool              isValid;                 // Cache geçerli mi
};

//+------------------------------------------------------------------+
//| Timeframe ATR Cache Entry                                       |
//+------------------------------------------------------------------+
struct STimeframeATRCache
{
   ENUM_TIMEFRAMES   timeframe;               // Timeframe
   int               atrHandle;               // Persistent handle
   datetime          lastBarTime;             // Son bar zamanı
   double            cachedValue;             // Cache değeri
   bool              isInitialized;           // Handle başarılı mı
   datetime          lastAccess;              // Son erişim zamanı
};

//+------------------------------------------------------------------+
//| Symbol Cache Structure                                          |
//+------------------------------------------------------------------+
struct SSymbolCache
{
   string            symbol;
   STimeframeATRCache timeframes[9];          // M1'den MN1'e kadar
   int               activeCount;             // Aktif timeframe sayısı
   datetime          lastPositionClose;       // Son pozisyon kapanma zamanı
};

//+------------------------------------------------------------------+
//| Position Close Result Structure                                  |
//+------------------------------------------------------------------+
struct SPositionCloseResult
{
   bool              success;                 // İşlem başarılı mı
   ulong             ticket;                  // Position ticket
   double            closedVolume;            // Kapatılan hacim
   double            remainingVolume;         // Kalan hacim
   double            closePrice;              // Kapanış fiyatı
   double            profit;                  // Kar/Zarar
   string            comment;                 // Yorum
   string            errorMessage;            // Hata mesajı
   int               retcode;                 // Return code
};

//+------------------------------------------------------------------+
//| FTMO Position Manager V3 Class - Full ATR Based with News       |
//+------------------------------------------------------------------+
class CFTMOPositionManager
{
private:
   // Core Objects
   CTrade            m_trade;
   CPositionInfo     m_position;
   COrderInfo        m_order;
   CFTMORiskManager  *m_riskManager;
   CFTMONewsManager  *m_newsManager;          // News Manager instance (from RiskManager)
   
   // Configuration
   SGlobalPositionConfig m_globalConfig;
   SStrategyPositionConfig m_strategyConfigs[];
   int               m_strategyConfigCount;
   
   // Config Cache (OPTIMIZATION)
   SConfigCache      m_configCache[];         // Config cache array
   int               m_configCacheCount;      // Cache count
   int               m_configCacheLifetime;   // Cache lifetime (seconds)
   
   // Position Tracking
   SPositionStatus   m_positions[];
   int               m_positionCount;
   
   // Optimized ATR Cache
   SSymbolCache      m_symbolCaches[];
   int               m_symbolCacheCount;
   int               m_defaultATRPeriod;
   
   // Emergency Status
   bool              m_emergencyCloseExecuted;
   string            m_lastEmergencyReason;
   datetime          m_lastEmergencyTime;
   
   // News Status
   bool              m_globalNewsFilterEnabled;
   int               m_newsClosedPositions;
   int               m_newsCancelledOrders;
   datetime          m_lastNewsCheck;
   
   // Statistics
   int               m_totalClosedPositions;
   int               m_totalPartialCloses;
   int               m_totalBreakevenSets;
   int               m_totalTrailingUpdates;
   
   // Internal Methods - Configuration
   bool              GetEffectiveConfigCached(ulong magic, SGlobalPositionConfig &effectiveConfig);
   void              UpdateConfigCache(ulong magic, const SGlobalPositionConfig &config);
   void              InvalidateConfigCache(ulong magic = 0);
   bool              GetEffectiveConfigInternal(ulong magic, SGlobalPositionConfig &effectiveConfig);
   int               FindStrategyConfigIndex(ulong magic);
   bool              IsConfiguredStrategy(ulong magic);
   
   // Internal Methods - Position Management
   int               FindPositionIndex(ulong ticket);
   void              UpdatePositionStatus(ulong ticket);
   void              UpdateAllPositionsStatus();
   double            CalculateRewardRatio(ulong ticket);
   double            CalculateProfitInATR(ulong ticket);
   bool              ShouldCloseForTime(ulong magic);
   SPositionCloseResult ClosePositionWithRetry(ulong ticket, double volume, string reason);
   bool              ModifyPositionSL(ulong ticket, double newSL, string reason);
   
   // Internal Methods - News (OPTIMIZED)
   bool              CheckNewsStatus(ulong magic, string symbol, bool &shouldClose, string &reason);
   void              ProcessNewsActions();
   
   // Internal Methods - ATR Cache
   int               TimeframeToIndex(ENUM_TIMEFRAMES tf);
   int               GetSymbolCacheIndex(string symbol);
   bool              IsNewBar(string symbol, ENUM_TIMEFRAMES timeframe, datetime &lastBarTime);
   double            GetCachedATRInternal(string symbol, ENUM_TIMEFRAMES timeframe, 
                                         int period, bool forceUpdate = false);
   void              CleanupInactiveCache();

public:
   // Constructor & Destructor
                     CFTMOPositionManager(CFTMORiskManager *riskManager);
                    ~CFTMOPositionManager();
   
   // News Manager Integration
   void              SetGlobalNewsFilter(bool enabled) { m_globalNewsFilterEnabled = enabled; }
   bool              IsGlobalNewsFilterEnabled() const { return m_globalNewsFilterEnabled; }
   
   // Configuration Management
   void              SetGlobalConfig(const SGlobalPositionConfig &config);
   bool              AddStrategyConfig(const SStrategyPositionConfig &config);
   bool              UpdateStrategyConfig(const SStrategyPositionConfig &config);
   bool              RemoveStrategyConfig(ulong magic);
   bool              GetStrategyConfig(ulong magic, SStrategyPositionConfig &config);
   
   // Main Update Method (OnTick'te çağırılacak)
   void              Update();
   
   // Emergency Operations
   void              CheckEmergencyConditions();
   int               CloseAllPositions(string reason);
   int               CloseAllPositionsByMagic(ulong magic, string reason);
   int               CloseAllPendingOrders(string reason);
   
   // Position Management
   SPositionCloseResult ClosePosition(ulong ticket, string reason);
   SPositionCloseResult PartialClosePosition(ulong ticket, double percent, string reason);
   bool              ModifyStopLoss(ulong ticket, double newSL, string reason);
   
   // Trailing & Breakeven (OnTick optimized)
   void              ProcessTrailingStops();
   void              ProcessBreakevens();
   void              ProcessPartialCloses();
   
   // Time based Management
   void              CheckTimeBasedCloses();
   
   // Information Methods
   int               GetManagedPositionsCount();
   int               GetManagedPositionsByMagic(ulong magic);
   SPositionStatus   GetPositionStatus(ulong ticket);
   int               GetNewsAffectedPositions();
   int               GetNewsCancelledOrders() const { return m_newsCancelledOrders; }
   
   // Statistics
   int               GetTotalClosedPositions() const { return m_totalClosedPositions; }
   int               GetTotalPartialCloses() const { return m_totalPartialCloses; }
   int               GetTotalBreakevenSets() const { return m_totalBreakevenSets; }
   int               GetTotalTrailingUpdates() const { return m_totalTrailingUpdates; }
   int               GetNewsClosedPositions() const { return m_newsClosedPositions; }
   void              ResetStatistics();
   
   // ATR Cache Management
   double            GetCachedATR(string symbol, ENUM_TIMEFRAMES timeframe, int period);
   void              PreloadATRCache(string symbol, ENUM_TIMEFRAMES timeframe, int period);
   void              ClearATRCache();
   void              PrintCacheStatistics();
   
   // Reporting
   void              PrintPositionReport();
   void              PrintConfigurationReport();
   void              PrintStatisticsReport();
   void              PrintNewsStatus();
   string            GetStatusSummary();
};

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CFTMOPositionManager::CFTMOPositionManager(CFTMORiskManager *riskManager)
{
   m_riskManager = riskManager;
   
   // Get NewsManager from RiskManager (OPTIMIZATION)
   m_newsManager = (riskManager != NULL) ? riskManager.GetNewsManager() : NULL;
   
   m_strategyConfigCount = 0;
   m_positionCount = 0;
   m_symbolCacheCount = 0;
   m_defaultATRPeriod = 14;
   m_globalNewsFilterEnabled = true;
   m_newsClosedPositions = 0;
   m_newsCancelledOrders = 0;
   m_lastNewsCheck = 0;
   
   // Config cache settings
   m_configCacheCount = 0;
   m_configCacheLifetime = 60; // 60 seconds cache lifetime
   
   // Default Global Configuration
   m_globalConfig.enableTrailing = true;
   m_globalConfig.enableBreakeven = true;
   m_globalConfig.atrMultiplierTrail = 2.0;
   m_globalConfig.atrMultiplierBE = 0.5;
   m_globalConfig.atrPeriod = 14;
   m_globalConfig.atrTimeframe = PERIOD_H1;
   m_globalConfig.minProfitATRTrail = 1.0;
   m_globalConfig.minProfitATRBE = 0.5;
   
   // Partial Close
   m_globalConfig.enablePartialClose = false;
   m_globalConfig.partialClosePercent = 50.0;
   m_globalConfig.partialCloseTriggerReward = 50.0;
   
   // Time Management
   m_globalConfig.enableDayEndClose = false;
   m_globalConfig.enableWeekendClose = false;
   m_globalConfig.dayEndHour = 22;
   m_globalConfig.dayEndMinute = 0;
   
   // News Management
   m_globalConfig.enableNewsClose = false;
   m_globalConfig.newsMinutesBefore = 30;
   m_globalConfig.newsMinutesAfter = 30;
   
   // Retry Settings
   m_globalConfig.maxRetries = 3;
   m_globalConfig.retryDelay = 1000;
   
   // Emergency Status
   m_emergencyCloseExecuted = false;
   m_lastEmergencyReason = "";
   m_lastEmergencyTime = 0;
   
   // Statistics
   m_totalClosedPositions = 0;
   m_totalPartialCloses = 0;
   m_totalBreakevenSets = 0;
   m_totalTrailingUpdates = 0;
   
   // Arrays
   ArrayResize(m_strategyConfigs, 0);
   ArrayResize(m_positions, 0);
   ArrayResize(m_symbolCaches, 0);
   ArrayResize(m_configCache, 0);
   
   // Trade class setup
   m_trade.SetExpertMagicNumber(0);
   m_trade.SetMarginMode();
   
   Print("=== FTMO Position Manager V3 Initialized ===");
   Print("Risk Manager: ", (m_riskManager != NULL ? "Connected" : "Not Connected"));
   Print("News Manager: ", (m_newsManager != NULL ? "Connected (via RiskManager)" : "Not Connected"));
   Print("Global News Filter: ", (m_globalNewsFilterEnabled ? "Enabled" : "Disabled"));
   Print("Global Trailing: ", (m_globalConfig.enableTrailing ? "ON" : "OFF"));
   Print("Global Breakeven: ", (m_globalConfig.enableBreakeven ? "ON" : "OFF"));
   Print("Global Partial Close: ", (m_globalConfig.enablePartialClose ? "ON" : "OFF"));
   Print("Config Cache Lifetime: ", m_configCacheLifetime, " seconds");
   Print("ATR Based System: ACTIVE");
}

//+------------------------------------------------------------------+
//| Destructor                                                      |
//+------------------------------------------------------------------+
CFTMOPositionManager::~CFTMOPositionManager()
{
   // Release all ATR handles
   for(int i = 0; i < m_symbolCacheCount; i++)
   {
      for(int j = 0; j < 9; j++)
      {
         if(m_symbolCaches[i].timeframes[j].atrHandle != INVALID_HANDLE)
         {
            IndicatorRelease(m_symbolCaches[i].timeframes[j].atrHandle);
         }
      }
   }
   
   ArrayFree(m_strategyConfigs);
   ArrayFree(m_positions);
   ArrayFree(m_symbolCaches);
   ArrayFree(m_configCache);
   
   Print("=== FTMO Position Manager V3 Destroyed ===");
   Print("Total Positions Closed: ", m_totalClosedPositions);
   Print("Total Partial Closes: ", m_totalPartialCloses);
   Print("Total Breakeven Sets: ", m_totalBreakevenSets);
   Print("Total Trailing Updates: ", m_totalTrailingUpdates);
   Print("News Closed Positions: ", m_newsClosedPositions);
}

//+------------------------------------------------------------------+
//| Get Effective Configuration with Cache (OPTIMIZED)              |
//+------------------------------------------------------------------+
bool CFTMOPositionManager::GetEffectiveConfigCached(ulong magic, SGlobalPositionConfig &effectiveConfig)
{
   // 1. Check cache first
   datetime currentTime = TimeCurrent();
   
   for(int i = 0; i < m_configCacheCount; i++)
   {
      if(m_configCache[i].magic == magic && m_configCache[i].isValid)
      {
         // Check if cache is still valid
         if((currentTime - m_configCache[i].lastUpdate) < m_configCacheLifetime)
         {
            effectiveConfig = m_configCache[i].config;
            return true;
         }
         else
         {
            // Cache expired
            m_configCache[i].isValid = false;
         }
      }
   }
   
   // 2. Cache miss - calculate config
   if(!GetEffectiveConfigInternal(magic, effectiveConfig))
      return false;
   
   // 3. Update cache
   UpdateConfigCache(magic, effectiveConfig);
   
   return true;
}

//+------------------------------------------------------------------+
//| Update Config Cache                                              |
//+------------------------------------------------------------------+
void CFTMOPositionManager::UpdateConfigCache(ulong magic, const SGlobalPositionConfig &config)
{
   // Find existing cache entry
   int cacheIndex = -1;
   for(int i = 0; i < m_configCacheCount; i++)
   {
      if(m_configCache[i].magic == magic)
      {
         cacheIndex = i;
         break;
      }
   }
   
   // Add new entry if not found
   if(cacheIndex < 0)
   {
      ArrayResize(m_configCache, m_configCacheCount + 1);
      cacheIndex = m_configCacheCount;
      m_configCacheCount++;
   }
   
   // Update cache
   m_configCache[cacheIndex].magic = magic;
   m_configCache[cacheIndex].config = config;
   m_configCache[cacheIndex].lastUpdate = TimeCurrent();
   m_configCache[cacheIndex].isValid = true;
}

//+------------------------------------------------------------------+
//| Invalidate Config Cache                                         |
//+------------------------------------------------------------------+
void CFTMOPositionManager::InvalidateConfigCache(ulong magic = 0)
{
   if(magic == 0)
   {
      // Invalidate all cache entries
      for(int i = 0; i < m_configCacheCount; i++)
      {
         m_configCache[i].isValid = false;
      }
   }
   else
   {
      // Invalidate specific magic cache
      for(int i = 0; i < m_configCacheCount; i++)
      {
         if(m_configCache[i].magic == magic)
         {
            m_configCache[i].isValid = false;
            break;
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Get Effective Configuration Internal (Original Logic)           |
//+------------------------------------------------------------------+
bool CFTMOPositionManager::GetEffectiveConfigInternal(ulong magic, SGlobalPositionConfig &effectiveConfig)
{
   // Start with global config
   effectiveConfig = m_globalConfig;
   
   // Find strategy specific config
   int index = FindStrategyConfigIndex(magic);
   if(index < 0)
      return true; // Use global config
   
   SStrategyPositionConfig strategyConfig = m_strategyConfigs[index];
   
   // Override with strategy specific settings
   if(strategyConfig.useCustomTrailing)
   {
      effectiveConfig.enableTrailing = strategyConfig.enableTrailing;
      effectiveConfig.atrMultiplierTrail = strategyConfig.atrMultiplierTrail;
      effectiveConfig.atrPeriod = strategyConfig.atrPeriodTrail;
      effectiveConfig.atrTimeframe = strategyConfig.atrTimeframeTrail;
      effectiveConfig.minProfitATRTrail = strategyConfig.minProfitATRTrail;
   }
   
   if(strategyConfig.useCustomBreakeven)
   {
      effectiveConfig.enableBreakeven = strategyConfig.enableBreakeven;
      effectiveConfig.atrMultiplierBE = strategyConfig.atrMultiplierBE;
      effectiveConfig.minProfitATRBE = strategyConfig.minProfitATRBE;
   }
   
   if(strategyConfig.useCustomPartial)
   {
      effectiveConfig.enablePartialClose = strategyConfig.enablePartialClose;
      effectiveConfig.partialClosePercent = strategyConfig.partialClosePercent;
      effectiveConfig.partialCloseTriggerReward = strategyConfig.partialCloseTriggerReward;
   }
   
   if(strategyConfig.useCustomTime)
   {
      effectiveConfig.enableDayEndClose = strategyConfig.enableDayEndClose;
      effectiveConfig.enableWeekendClose = strategyConfig.enableWeekendClose;
      effectiveConfig.dayEndHour = strategyConfig.dayEndHour;
      effectiveConfig.dayEndMinute = strategyConfig.dayEndMinute;
   }
   
   if(strategyConfig.useCustomNews)
   {
      effectiveConfig.enableNewsClose = strategyConfig.enableNewsClose;
      effectiveConfig.newsMinutesBefore = strategyConfig.newsMinutesBefore;
      effectiveConfig.newsMinutesAfter = strategyConfig.newsMinutesAfter;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Check News Status (OPTIMIZED - Combined Function)               |
//+------------------------------------------------------------------+
bool CFTMOPositionManager::CheckNewsStatus(ulong magic, string symbol, bool &shouldClose, string &reason)
{
   shouldClose = false;
   reason = "";
   
   // RiskManager'a sor
   if(m_riskManager != NULL)
   {
      // RiskManager'dan news close kararını al
      shouldClose = m_riskManager.ShouldClosePositionsForNews(magic);
      
      if(shouldClose)
      {
         // NewsManager'dan sadece reason bilgisini al
         if(m_newsManager != NULL && m_newsManager.IsNewsTime(symbol))
         {
            reason = m_newsManager.GetNewsRestrictionReason(symbol);
         }
         else
         {
            reason = "News close required by Risk Manager";
         }
         return true;
      }
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Process News Actions (OPTIMIZED - Combined Method)              |
//+------------------------------------------------------------------+
void CFTMOPositionManager::ProcessNewsActions()
{
   if(!m_globalNewsFilterEnabled || m_newsManager == NULL)
      return;
   
   // 30 saniyede bir news kontrolü yap
   datetime currentTime = TimeCurrent();
   if(m_lastNewsCheck > 0 && (currentTime - m_lastNewsCheck) < 30)
      return;
   
   m_lastNewsCheck = currentTime;
   
   // News data'yı güncelle
   m_newsManager.UpdateNewsData();
   
   // 1. AÇIK POZİSYONLAR İÇİN KONTROL
   for(int i = 0; i < m_positionCount; i++)
   {
      SPositionStatus pos = m_positions[i];
      
      bool shouldClose = false;
      string newsReason = "";
      
      if(CheckNewsStatus(pos.magic, pos.symbol, shouldClose, newsReason))
      {
         // Update position news status
         m_positions[i].newsAffected = true;
         m_positions[i].newsReason = newsReason;
         
         // Close if needed
         if(shouldClose)
         {
            string closeReason = "News Close: " + newsReason;
            
            SPositionCloseResult result = ClosePosition(pos.ticket, closeReason);
            if(result.success)
            {
               m_newsClosedPositions++;
               Print("NEWS CLOSE: ", closeReason, " - Ticket: ", pos.ticket);
            }
         }
      }
      else
      {
         // Clear news status
         m_positions[i].newsAffected = false;
         m_positions[i].newsReason = "";
      }
   }
   
   // 2. BEKLEYEN EMİRLER İÇİN KONTROL
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(m_order.SelectByIndex(i))
      {
         ulong magic = m_order.Magic();
         string symbol = m_order.Symbol();
         ulong ticket = m_order.Ticket();
         
         // Sadece konfigüre edilmiş strategy'leri kontrol et
         if(m_strategyConfigCount > 0 && !IsConfiguredStrategy(magic))
            continue;
         
         bool shouldClose = false;
         string newsReason = "";
         
         // RiskManager'dan magic config'i al
         SMagicRiskConfig magicConfig;
         if(m_riskManager.GetMagicConfig(magic, magicConfig))
         {
            // News filter aktif ve trade block var mı?
            if(magicConfig.useNewsFilter && magicConfig.blockTradesOnNews)
            {
               // NewsManager'dan kontrol
               if(m_newsManager != NULL && m_newsManager.IsNewsTime(symbol))
               {
                  string newsReason = m_newsManager.GetNewsRestrictionReason(symbol);
                  string cancelReason = "News Cancel: " + newsReason;
                  
                  Print("Cancelling pending order ", ticket, " (", symbol, ") - ", cancelReason);
                  
                  if(m_trade.OrderDelete(ticket))
                  {
                     m_newsCancelledOrders++;
                     Print("Order ", ticket, " cancelled due to news");
                  }
               }
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Timeframe to Index Mapping                                      |
//+------------------------------------------------------------------+
int CFTMOPositionManager::TimeframeToIndex(ENUM_TIMEFRAMES tf)
{
   switch(tf)
   {
      case PERIOD_M1:  return 0;
      case PERIOD_M5:  return 1;
      case PERIOD_M15: return 2;
      case PERIOD_M30: return 3;
      case PERIOD_H1:  return 4;
      case PERIOD_H4:  return 5;
      case PERIOD_D1:  return 6;
      case PERIOD_W1:  return 7;
      case PERIOD_MN1: return 8;
      default: return -1;
   }
}

//+------------------------------------------------------------------+
//| Get Symbol Cache Index                                          |
//+------------------------------------------------------------------+
int CFTMOPositionManager::GetSymbolCacheIndex(string symbol)
{
   // Existing symbol search
   for(int i = 0; i < m_symbolCacheCount; i++)
   {
      if(m_symbolCaches[i].symbol == symbol)
         return i;
   }
   
   // Add new symbol
   ArrayResize(m_symbolCaches, m_symbolCacheCount + 1);
   m_symbolCaches[m_symbolCacheCount].symbol = symbol;
   m_symbolCaches[m_symbolCacheCount].activeCount = 0;
   m_symbolCaches[m_symbolCacheCount].lastPositionClose = 0;
   
   // Initialize timeframe caches
   for(int i = 0; i < 9; i++)
   {
      m_symbolCaches[m_symbolCacheCount].timeframes[i].isInitialized = false;
      m_symbolCaches[m_symbolCacheCount].timeframes[i].atrHandle = INVALID_HANDLE;
      m_symbolCaches[m_symbolCacheCount].timeframes[i].lastBarTime = 0;
      m_symbolCaches[m_symbolCacheCount].timeframes[i].cachedValue = 0;
      m_symbolCaches[m_symbolCacheCount].timeframes[i].lastAccess = 0;
   }
   
   return m_symbolCacheCount++;
}

//+------------------------------------------------------------------+
//| Check if New Bar                                                |
//+------------------------------------------------------------------+
bool CFTMOPositionManager::IsNewBar(string symbol, ENUM_TIMEFRAMES timeframe, datetime &lastBarTime)
{
   datetime currentBarTime[];
   if(CopyTime(symbol, timeframe, 0, 1, currentBarTime) <= 0)
      return false;
   
   if(currentBarTime[0] != lastBarTime)
   {
      lastBarTime = currentBarTime[0];
      return true;
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Get Cached ATR (Internal)                                       |
//+------------------------------------------------------------------+
double CFTMOPositionManager::GetCachedATRInternal(string symbol, ENUM_TIMEFRAMES timeframe, 
                                                   int period, bool forceUpdate = false)
{
   // Get indexes
   int symbolIndex = GetSymbolCacheIndex(symbol);
   if(symbolIndex < 0) return 0;
   
   int tfIndex = TimeframeToIndex(timeframe);
   if(tfIndex < 0) return 0;
   
   datetime currentTime = TimeCurrent();
   
   // Initialize handle if needed
   if(!m_symbolCaches[symbolIndex].timeframes[tfIndex].isInitialized || 
      m_symbolCaches[symbolIndex].timeframes[tfIndex].atrHandle == INVALID_HANDLE)
   {
      m_symbolCaches[symbolIndex].timeframes[tfIndex].atrHandle = iATR(symbol, timeframe, period);
      if(m_symbolCaches[symbolIndex].timeframes[tfIndex].atrHandle == INVALID_HANDLE)
      {
         Print("ERROR: Failed to create ATR handle for ", symbol, " ", EnumToString(timeframe));
         return 0;
      }
      
      m_symbolCaches[symbolIndex].timeframes[tfIndex].timeframe = timeframe;
      m_symbolCaches[symbolIndex].timeframes[tfIndex].isInitialized = true;
      m_symbolCaches[symbolIndex].timeframes[tfIndex].lastBarTime = 0;
      m_symbolCaches[symbolIndex].activeCount++;
      
      // Wait for initialization
      Sleep(50);
   }
   
   // Check for new bar or force update
   bool needUpdate = forceUpdate || 
                    IsNewBar(symbol, timeframe, m_symbolCaches[symbolIndex].timeframes[tfIndex].lastBarTime) || 
                    m_symbolCaches[symbolIndex].timeframes[tfIndex].cachedValue == 0;
   
   if(needUpdate)
   {
      double atrBuffer[];
      // Shift=1 kullanıyoruz (önceki tamamlanmış bar)
      if(CopyBuffer(m_symbolCaches[symbolIndex].timeframes[tfIndex].atrHandle, 0, 1, 1, atrBuffer) > 0)
      {
         m_symbolCaches[symbolIndex].timeframes[tfIndex].cachedValue = atrBuffer[0];
         m_symbolCaches[symbolIndex].timeframes[tfIndex].lastAccess = currentTime;
      }
      else
      {
         Print("ERROR: Failed to copy ATR buffer for ", symbol, " ", EnumToString(timeframe));
         return 0;
      }
   }
   
   m_symbolCaches[symbolIndex].timeframes[tfIndex].lastAccess = currentTime;
   return m_symbolCaches[symbolIndex].timeframes[tfIndex].cachedValue;
}

//+------------------------------------------------------------------+
//| Get Cached ATR (Public)                                         |
//+------------------------------------------------------------------+
double CFTMOPositionManager::GetCachedATR(string symbol, ENUM_TIMEFRAMES timeframe, int period)
{
   if(period <= 0) period = m_defaultATRPeriod;
   return GetCachedATRInternal(symbol, timeframe, period, false);
}

//+------------------------------------------------------------------+
//| Preload ATR Cache                                               |
//+------------------------------------------------------------------+
void CFTMOPositionManager::PreloadATRCache(string symbol, ENUM_TIMEFRAMES timeframe, int period)
{
   if(period <= 0) period = m_defaultATRPeriod;
   GetCachedATRInternal(symbol, timeframe, period, true);
   Print("ATR Cache preloaded: ", symbol, " ", EnumToString(timeframe), " Period:", period);
}

//+------------------------------------------------------------------+
//| Clear ATR Cache                                                 |
//+------------------------------------------------------------------+
void CFTMOPositionManager::ClearATRCache()
{
   for(int i = 0; i < m_symbolCacheCount; i++)
   {
      for(int j = 0; j < 9; j++)
      {
         if(m_symbolCaches[i].timeframes[j].atrHandle != INVALID_HANDLE)
         {
            IndicatorRelease(m_symbolCaches[i].timeframes[j].atrHandle);
            m_symbolCaches[i].timeframes[j].atrHandle = INVALID_HANDLE;
            m_symbolCaches[i].timeframes[j].isInitialized = false;
         }
      }
   }
   
   ArrayResize(m_symbolCaches, 0);
   m_symbolCacheCount = 0;
   Print("ATR Cache cleared");
}

//+------------------------------------------------------------------+
//| Cleanup Inactive Cache                                          |
//+------------------------------------------------------------------+
void CFTMOPositionManager::CleanupInactiveCache()
{
   datetime currentTime = TimeCurrent();
   int cleanupCount = 0;
   
   for(int i = 0; i < m_symbolCacheCount; i++)
   {
      // Check if symbol has no positions
      bool hasPosition = false;
      for(int p = 0; p < m_positionCount; p++)
      {
         if(m_positions[p].symbol == m_symbolCaches[i].symbol)
         {
            hasPosition = true;
            break;
         }
      }
      
      if(!hasPosition && m_symbolCaches[i].lastPositionClose > 0 && 
         (currentTime - m_symbolCaches[i].lastPositionClose) > 300) // 5 minutes
      {
         // Release handles for this symbol
         for(int j = 0; j < 9; j++)
         {
            if(m_symbolCaches[i].timeframes[j].atrHandle != INVALID_HANDLE)
            {
               IndicatorRelease(m_symbolCaches[i].timeframes[j].atrHandle);
               m_symbolCaches[i].timeframes[j].atrHandle = INVALID_HANDLE;
               m_symbolCaches[i].timeframes[j].isInitialized = false;
               cleanupCount++;
            }
         }
         m_symbolCaches[i].activeCount = 0;
      }
   }
   
   if(cleanupCount > 0)
   {
      Print("Cleaned up ", cleanupCount, " inactive ATR handles");
   }
}

//+------------------------------------------------------------------+
//| Print Cache Statistics                                          |
//+------------------------------------------------------------------+
void CFTMOPositionManager::PrintCacheStatistics()
{
   Print("=== ATR Cache Statistics ===");
   Print("Total Symbols: ", m_symbolCacheCount);
   
   int totalHandles = 0;
   int activeHandles = 0;
   
   for(int i = 0; i < m_symbolCacheCount; i++)
   {
      int symbolActiveHandles = 0;
      for(int j = 0; j < 9; j++)
      {
         if(m_symbolCaches[i].timeframes[j].atrHandle != INVALID_HANDLE)
         {
            totalHandles++;
            symbolActiveHandles++;
         }
      }
      
      if(symbolActiveHandles > 0)
      {
         activeHandles += symbolActiveHandles;
         Print("Symbol: ", m_symbolCaches[i].symbol, " - Active Handles: ", symbolActiveHandles);
      }
   }
   
   Print("Total Active Handles: ", activeHandles);
   Print("Memory Usage: ~", activeHandles * 8, " KB (estimated)");
   
   // Config cache statistics
   Print("\n=== Config Cache Statistics ===");
   Print("Total Config Entries: ", m_configCacheCount);
   int validCacheCount = 0;
   for(int i = 0; i < m_configCacheCount; i++)
   {
      if(m_configCache[i].isValid)
         validCacheCount++;
   }
   Print("Valid Cache Entries: ", validCacheCount);
   Print("Cache Lifetime: ", m_configCacheLifetime, " seconds");
}

//+------------------------------------------------------------------+
//| Set Global Configuration                                         |
//+------------------------------------------------------------------+
void CFTMOPositionManager::SetGlobalConfig(const SGlobalPositionConfig &config)
{
   m_globalConfig = config;
   
   // Invalidate all config cache
   InvalidateConfigCache(0);
   
   Print("Global Position Configuration Updated");
   Print("Trailing: ", (config.enableTrailing ? "ON" : "OFF"));
   Print("Breakeven: ", (config.enableBreakeven ? "ON" : "OFF"));
   Print("Partial Close: ", (config.enablePartialClose ? "ON" : "OFF"));
   Print("Day End Close: ", (config.enableDayEndClose ? "ON" : "OFF"));
   Print("Weekend Close: ", (config.enableWeekendClose ? "ON" : "OFF"));
   Print("News Close: ", (config.enableNewsClose ? "ON" : "OFF"));
   Print("Min Profit ATR Trail: ", config.minProfitATRTrail);
   Print("Min Profit ATR BE: ", config.minProfitATRBE);
}

//+------------------------------------------------------------------+
//| Add Strategy Configuration                                       |
//+------------------------------------------------------------------+
bool CFTMOPositionManager::AddStrategyConfig(const SStrategyPositionConfig &config)
{
   if(FindStrategyConfigIndex(config.magic) >= 0)
   {
      Print("ERROR: Strategy Magic ", config.magic, " already configured. Use UpdateStrategyConfig.");
      return false;
   }
   
   ArrayResize(m_strategyConfigs, m_strategyConfigCount + 1);
   m_strategyConfigs[m_strategyConfigCount] = config;
   m_strategyConfigs[m_strategyConfigCount].isActive = true;
   m_strategyConfigCount++;
   
   // Invalidate config cache for this magic
   InvalidateConfigCache(config.magic);
   
   Print("SUCCESS: Strategy ", config.strategyName, " (Magic: ", config.magic, ") configuration added");
   return true;
}

//+------------------------------------------------------------------+
//| Update Strategy Configuration                                    |
//+------------------------------------------------------------------+
bool CFTMOPositionManager::UpdateStrategyConfig(const SStrategyPositionConfig &config)
{
   int index = FindStrategyConfigIndex(config.magic);
   if(index < 0)
   {
      Print("ERROR: Strategy Magic ", config.magic, " not found. Use AddStrategyConfig.");
      return false;
   }
   
   m_strategyConfigs[index] = config;
   m_strategyConfigs[index].isActive = true;
   
   // Invalidate config cache for this magic
   InvalidateConfigCache(config.magic);
   
   Print("SUCCESS: Strategy ", config.strategyName, " (Magic: ", config.magic, ") configuration updated");
   return true;
}

//+------------------------------------------------------------------+
//| Remove Strategy Configuration                                    |
//+------------------------------------------------------------------+
bool CFTMOPositionManager::RemoveStrategyConfig(ulong magic)
{
   int index = FindStrategyConfigIndex(magic);
   if(index < 0)
   {
      Print("ERROR: Strategy Magic ", magic, " not found");
      return false;
   }
   
   string strategyName = m_strategyConfigs[index].strategyName;
   
   for(int i = index; i < m_strategyConfigCount - 1; i++)
   {
      m_strategyConfigs[i] = m_strategyConfigs[i + 1];
   }
   
   m_strategyConfigCount--;
   ArrayResize(m_strategyConfigs, m_strategyConfigCount);
   
   // Invalidate config cache for this magic
   InvalidateConfigCache(magic);
   
   Print("SUCCESS: Strategy ", strategyName, " (Magic: ", magic, ") configuration removed");
   return true;
}

//+------------------------------------------------------------------+
//| Get Strategy Configuration                                       |
//+------------------------------------------------------------------+
bool CFTMOPositionManager::GetStrategyConfig(ulong magic, SStrategyPositionConfig &config)
{
   int index = FindStrategyConfigIndex(magic);
   if(index >= 0)
   {
      config = m_strategyConfigs[index];
      return true;
   }
   return false;
}

//+------------------------------------------------------------------+
//| Find Strategy Configuration Index                                |
//+------------------------------------------------------------------+
int CFTMOPositionManager::FindStrategyConfigIndex(ulong magic)
{
   for(int i = 0; i < m_strategyConfigCount; i++)
   {
      if(m_strategyConfigs[i].magic == magic && m_strategyConfigs[i].isActive)
         return i;
   }
   return -1;
}

//+------------------------------------------------------------------+
//| Check if Strategy is Configured                                 |
//+------------------------------------------------------------------+
bool CFTMOPositionManager::IsConfiguredStrategy(ulong magic)
{
   return FindStrategyConfigIndex(magic) >= 0;
}

//+------------------------------------------------------------------+
//| Main Update Method                                               |
//+------------------------------------------------------------------+
void CFTMOPositionManager::Update()
{
   // 1. Emergency kontrolü (EN ÖNCELİKLİ)
   CheckEmergencyConditions();
   
   // Emergency durumunda diğer işlemleri yapma
   if(m_emergencyCloseExecuted)
      return;
   
   // 2. Position status güncelleme
   UpdateAllPositionsStatus();
   
   // 3. News-based actions (OPTIMIZED)
   ProcessNewsActions();
   
   // 4. Time-based closes
   CheckTimeBasedCloses();
   
   // 5. Partial closes (Reward bazlı)
   ProcessPartialCloses();
   
   // 6. Breakeven updates (ATR bazlı)
   ProcessBreakevens();
   
   // 7. Trailing stop updates (ATR bazlı)
   ProcessTrailingStops();
   
   // 8. Periodic cache cleanup (every 100 ticks)
   static int tickCounter = 0;
   if(++tickCounter >= 100)
   {
      CleanupInactiveCache();
      tickCounter = 0;
   }
}

//+------------------------------------------------------------------+
//| Check Emergency Conditions                                       |
//+------------------------------------------------------------------+
void CFTMOPositionManager::CheckEmergencyConditions()
{
   if(m_riskManager == NULL)
      return;
   
   string emergencyReason = "";
   bool shouldCloseAll = false;
   bool shouldClosePending = false;
   
   // 1. Daily Drawdown Limit (EN KRİTİK)
   if(m_riskManager.ShouldStopTradingDrawdown())
   {
      emergencyReason = "EMERGENCY: Daily drawdown limit exceeded";
      shouldCloseAll = true;
      shouldClosePending = true;
   }
   // 2. Daily Profit Target
   else if(m_riskManager.ShouldStopTradingProfit())
   {
      emergencyReason = "EMERGENCY: Daily profit target reached";
      shouldCloseAll = true;
      shouldClosePending = true;
   }
   // 3. Floating Profit Realize (Trading devam eder)
   else if(m_riskManager.ShouldRealizeProfits())
   {
      emergencyReason = "PROFIT REALIZATION: Floating target reached";
      shouldCloseAll = true;
      shouldClosePending = false; // Pending orders kapatılmaz
   }
   
   if(shouldCloseAll)
   {
      datetime currentTime = TimeCurrent();
      
      // Aynı dakika içinde tekrar tetiklenmesini önle
      if(m_lastEmergencyTime > 0 && (currentTime - m_lastEmergencyTime) < 60)
         return;
      
      Print("========== ", emergencyReason, " ==========");
      
      int closedPositions = CloseAllPositions(emergencyReason);
      Print("Closed Positions: ", closedPositions);
      
      if(shouldClosePending)
      {
         int closedOrders = CloseAllPendingOrders(emergencyReason);
         Print("Cancelled Pending Orders: ", closedOrders);
      }
      
      m_emergencyCloseExecuted = true;
      m_lastEmergencyReason = emergencyReason;
      m_lastEmergencyTime = currentTime;
      
      Print("=====================================");
   }
   else
   {
      // Emergency durum geçtiyse reset et
      if(m_emergencyCloseExecuted)
      {
         m_emergencyCloseExecuted = false;
         Print("Emergency status cleared - Normal operations resumed");
      }
   }
}

//+------------------------------------------------------------------+
//| Calculate Profit in ATR                                         |
//+------------------------------------------------------------------+
double CFTMOPositionManager::CalculateProfitInATR(ulong ticket)
{
   if(!m_position.SelectByTicket(ticket))
      return 0;
   
   string symbol = m_position.Symbol();
   double entryPrice = m_position.PriceOpen();
   ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)m_position.PositionType();
   
   double currentPrice = (type == POSITION_TYPE_BUY) ? 
                        SymbolInfoDouble(symbol, SYMBOL_BID) :
                        SymbolInfoDouble(symbol, SYMBOL_ASK);
   
   double profitDistance = 0;
   if(type == POSITION_TYPE_BUY)
      profitDistance = currentPrice - entryPrice;
   else
      profitDistance = entryPrice - currentPrice;
   
   // Get ATR from cache
   double atr = GetCachedATR(symbol, m_globalConfig.atrTimeframe, m_globalConfig.atrPeriod);
   if(atr <= 0)
      return 0;
   
   return profitDistance / atr;
}

//+------------------------------------------------------------------+
//| Update All Positions Status                                     |
//+------------------------------------------------------------------+
void CFTMOPositionManager::UpdateAllPositionsStatus()
{
   m_positionCount = 0;
   ArrayResize(m_positions, PositionsTotal());
   
   for(int i = 0; i < PositionsTotal(); i++)
   {
      if(m_position.SelectByIndex(i))
      {
         ulong magic = m_position.Magic();
         
         // Sadece konfigüre edilmiş strategy'leri takip et
         if(m_strategyConfigCount == 0 || IsConfiguredStrategy(magic))
         {
            UpdatePositionStatus(m_position.Ticket());
         }
      }
   }
   
   ArrayResize(m_positions, m_positionCount);
   
   // Mark closed positions in cache
   for(int i = 0; i < m_symbolCacheCount; i++)
   {
      bool hasPosition = false;
      for(int p = 0; p < m_positionCount; p++)
      {
         if(m_positions[p].symbol == m_symbolCaches[i].symbol)
         {
            hasPosition = true;
            break;
         }
      }
      
      if(!hasPosition && m_symbolCaches[i].activeCount > 0)
      {
         m_symbolCaches[i].lastPositionClose = TimeCurrent();
      }
   }
   
}

//+------------------------------------------------------------------+
//| Update Position Status                                          |
//+------------------------------------------------------------------+
void CFTMOPositionManager::UpdatePositionStatus(ulong ticket)
{
   if(!m_position.SelectByTicket(ticket))
      return;
   
   int index = FindPositionIndex(ticket);
   if(index < 0)
   {
      // Yeni pozisyon ekle
      index = m_positionCount;
      m_positionCount++;
      ArrayResize(m_positions, m_positionCount);
      
      // İlk kez eklenen pozisyon için original lot size'ı kaydet
      m_positions[index].originalLotSize = m_position.Volume();
      m_positions[index].breakEvenSet = false;
      m_positions[index].partialClosed = false;
      m_positions[index].newsAffected = false;
      m_positions[index].newsReason = "";
   }
   
   // Position bilgilerini güncelle
   m_positions[index].ticket = ticket;
   m_positions[index].magic = m_position.Magic();
   m_positions[index].symbol = m_position.Symbol();
   m_positions[index].type = (ENUM_POSITION_TYPE)m_position.PositionType();
   m_positions[index].lotSize = m_position.Volume();
   m_positions[index].entryPrice = m_position.PriceOpen();
   m_positions[index].currentSL = m_position.StopLoss();
   m_positions[index].currentTP = m_position.TakeProfit();
   m_positions[index].lastUpdate = TimeCurrent();
   
   // Kar hesapla
   m_positions[index].currentProfit = m_position.Profit();
   
   // ATR cinsinden kar hesapla
   m_positions[index].currentProfitATR = CalculateProfitInATR(ticket);
   
   // Reward ratio hesapla
   m_positions[index].rewardRatio = CalculateRewardRatio(ticket);
   
   // News durumu ProcessNewsActions'da güncelleniyor artık
}

//+------------------------------------------------------------------+
//| Find Position Index                                             |
//+------------------------------------------------------------------+
int CFTMOPositionManager::FindPositionIndex(ulong ticket)
{
   for(int i = 0; i < m_positionCount; i++)
   {
      if(m_positions[i].ticket == ticket)
         return i;
   }
   return -1;
}

//+------------------------------------------------------------------+
//| Calculate Reward Ratio                                          |
//+------------------------------------------------------------------+
double CFTMOPositionManager::CalculateRewardRatio(ulong ticket)
{
   if(!m_position.SelectByTicket(ticket))
      return 0;
   
   double entryPrice = m_position.PriceOpen();
   double stopLoss = m_position.StopLoss();
   double takeProfit = m_position.TakeProfit();
   
   if(stopLoss == 0 || takeProfit == 0)
      return 0;
   
   double riskDistance = MathAbs(entryPrice - stopLoss);
   double rewardDistance = MathAbs(takeProfit - entryPrice);
   
   if(riskDistance == 0)
      return 0;
   
   // Mevcut fiyata göre gerçekleşen reward ratio
   double currentPrice = (m_position.PositionType() == POSITION_TYPE_BUY) ? 
                        SymbolInfoDouble(m_position.Symbol(), SYMBOL_BID) :
                        SymbolInfoDouble(m_position.Symbol(), SYMBOL_ASK);
   
   double currentRewardDistance = 0;
   if(m_position.PositionType() == POSITION_TYPE_BUY)
      currentRewardDistance = currentPrice - entryPrice;
   else
      currentRewardDistance = entryPrice - currentPrice;
   
   double maxRewardRatio = (rewardDistance / riskDistance) * 100.0;
   double currentRewardRatio = (currentRewardDistance / riskDistance) * 100.0;
   
   // Maksimum reward'ın yüzde kaçına ulaştık
   if(maxRewardRatio > 0)
      return (currentRewardRatio / maxRewardRatio) * 100.0;
   
   return 0;
}

//+------------------------------------------------------------------+
//| Process Breakevens - ATR Based                                  |
//+------------------------------------------------------------------+
void CFTMOPositionManager::ProcessBreakevens()
{
   for(int i = 0; i < m_positionCount; i++)
   {
      SPositionStatus pos = m_positions[i];
      
      // Zaten breakeven set edilmişse atla
      if(pos.breakEvenSet)
         continue;
      
      // Get effective config (CACHED)
      SGlobalPositionConfig config;
      if(!GetEffectiveConfigCached(pos.magic, config))
         continue;
      
      if(!config.enableBreakeven)
         continue;
      
      // ATR'yi optimize edilmiş cache'den al
      double atr = GetCachedATR(pos.symbol, config.atrTimeframe, config.atrPeriod);
      if(atr <= 0)
         continue;
      
      // Minimum ATR kar kontrolü
      if(pos.currentProfitATR < config.minProfitATRBE)
         continue;
      
      // Breakeven mesafesi
      double breakevenDistance = atr * config.atrMultiplierBE;
      double newSL = 0;
      
      if(pos.type == POSITION_TYPE_BUY)
      {
         newSL = pos.entryPrice + breakevenDistance;
         
         // Mevcut SL'den daha iyi olmalı
         if(pos.currentSL > 0 && newSL <= pos.currentSL)
            continue;
      }
      else
      {
         newSL = pos.entryPrice - breakevenDistance;
         
         // Mevcut SL'den daha iyi olmalı
         if(pos.currentSL > 0 && newSL >= pos.currentSL)
            continue;
      }
      
      string reason = StringFormat("Breakeven: Profit=%.2f ATR (min:%.2f), BE Offset=%.2f ATR", 
                                 pos.currentProfitATR, config.minProfitATRBE, config.atrMultiplierBE);
      
      if(ModifyPositionSL(pos.ticket, newSL, reason))
      {
         m_positions[i].breakEvenSet = true;
         m_totalBreakevenSets++;
         
         Print("BREAKEVEN SET: Ticket=", pos.ticket, " NewSL=", DoubleToString(newSL, _Digits), 
               " Profit=", DoubleToString(pos.currentProfitATR, 2), " ATR");
      }
   }
}

//+------------------------------------------------------------------+
//| Process Trailing Stops - ATR Based                              |
//+------------------------------------------------------------------+
void CFTMOPositionManager::ProcessTrailingStops()
{
   for(int i = 0; i < m_positionCount; i++)
   {
      SPositionStatus pos = m_positions[i];
      
      // Get effective config (CACHED)
      SGlobalPositionConfig config;
      if(!GetEffectiveConfigCached(pos.magic, config))
         continue;
      
      if(!config.enableTrailing)
         continue;
      
      // ATR'yi optimize edilmiş cache'den al
      double atr = GetCachedATR(pos.symbol, config.atrTimeframe, config.atrPeriod);
      if(atr <= 0)
         continue;
      
      // Minimum ATR kar kontrolü
      if(pos.currentProfitATR < config.minProfitATRTrail)
         continue;
      
      // Trailing mesafesi
      double trailingDistance = atr * config.atrMultiplierTrail;
      double currentPrice = (pos.type == POSITION_TYPE_BUY) ? 
                           SymbolInfoDouble(pos.symbol, SYMBOL_BID) :
                           SymbolInfoDouble(pos.symbol, SYMBOL_ASK);
      
      double newSL = 0;
      bool shouldUpdate = false;
      
      if(pos.type == POSITION_TYPE_BUY)
      {
         newSL = currentPrice - trailingDistance;
         
         // Yeni SL mevcut SL'den daha iyi olmalı
         if(pos.currentSL == 0 || newSL > pos.currentSL)
            shouldUpdate = true;
      }
      else
      {
         newSL = currentPrice + trailingDistance;
         
         // Yeni SL mevcut SL'den daha iyi olmalı
         if(pos.currentSL == 0 || newSL < pos.currentSL)
            shouldUpdate = true;
      }
      
      if(shouldUpdate)
      {
         string reason = StringFormat("Trailing: Profit=%.2f ATR, Distance=%.2f ATR", 
                                    pos.currentProfitATR, config.atrMultiplierTrail);
         
         if(ModifyPositionSL(pos.ticket, newSL, reason))
         {
            m_totalTrailingUpdates++;
            
            Print("TRAILING UPDATE: Ticket=", pos.ticket, " NewSL=", DoubleToString(newSL, _Digits), 
                  " Profit=", DoubleToString(pos.currentProfitATR, 2), " ATR");
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Process Partial Closes - Reward Based                           |
//+------------------------------------------------------------------+
void CFTMOPositionManager::ProcessPartialCloses()
{
   for(int i = 0; i < m_positionCount; i++)
   {
      SPositionStatus pos = m_positions[i];
      
      // Zaten partial close yapıldıysa atla
      if(pos.partialClosed)
         continue;
      
      // Get effective config (CACHED)
      SGlobalPositionConfig config;
      if(!GetEffectiveConfigCached(pos.magic, config))
         continue;
      
      if(!config.enablePartialClose)
         continue;
      
      // Reward ratio kontrolü
      if(pos.rewardRatio >= config.partialCloseTriggerReward)
      {
         string reason = StringFormat("Partial Close: %.1f%% reward reached (target: %.1f%%)", 
                                    pos.rewardRatio, config.partialCloseTriggerReward);
         
         SPositionCloseResult result = PartialClosePosition(pos.ticket, config.partialClosePercent, reason);
         
         if(result.success)
         {
            m_positions[i].partialClosed = true;
            m_totalPartialCloses++;
            
            Print("PARTIAL CLOSE: Ticket=", pos.ticket, " Volume=", 
                  DoubleToString(result.closedVolume, 2), " Reward=", 
                  DoubleToString(pos.rewardRatio, 1), "%");
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Check Time Based Closes                                         |
//+------------------------------------------------------------------+
void CFTMOPositionManager::CheckTimeBasedCloses()
{
   datetime currentTime = TimeCurrent();
   MqlDateTime timeStruct;
   TimeToStruct(currentTime, timeStruct);
   
   for(int i = 0; i < m_positionCount; i++)
   {
      SPositionStatus pos = m_positions[i];
      
      // Get effective config (CACHED)
      SGlobalPositionConfig config;
      if(!GetEffectiveConfigCached(pos.magic, config))
         continue;
      
      bool shouldClose = false;
      string closeReason = "";
      
      // Day End Close
      if(config.enableDayEndClose)
      {
         if(timeStruct.hour == config.dayEndHour && timeStruct.min >= config.dayEndMinute)
         {
            shouldClose = true;
            closeReason = StringFormat("Day End Close: %02d:%02d", config.dayEndHour, config.dayEndMinute);
         }
      }
      
      // Weekend Close (Cuma akşamı)
      if(config.enableWeekendClose)
      {
         if(timeStruct.day_of_week == 5) // Cuma
         {
            if(timeStruct.hour >= config.dayEndHour)
            {
               shouldClose = true;
               closeReason = StringFormat("Weekend Close: Friday %02d:%02d", config.dayEndHour, config.dayEndMinute);
            }
         }
      }
      
      if(shouldClose)
      {
         SPositionCloseResult result = ClosePosition(pos.ticket, closeReason);
         if(result.success)
         {
            Print("TIME CLOSE: ", closeReason, " - Ticket: ", pos.ticket);
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Get News Affected Positions                                     |
//+------------------------------------------------------------------+
int CFTMOPositionManager::GetNewsAffectedPositions()
{
   if(!m_globalNewsFilterEnabled || m_newsManager == NULL)
      return 0;
   
   int count = 0;
   
   for(int i = 0; i < m_positionCount; i++)
   {
      if(m_positions[i].newsAffected)
         count++;
   }
   
   return count;
}

//+------------------------------------------------------------------+
//| Close All Positions                                             |
//+------------------------------------------------------------------+
int CFTMOPositionManager::CloseAllPositions(string reason)
{
   int closedCount = 0;
   
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(m_position.SelectByIndex(i))
      {
         ulong magic = m_position.Magic();
         ulong ticket = m_position.Ticket();
         
         // Sadece konfigüre edilmiş strategy'leri yönet (veya global varsa hepsini)
         if(m_strategyConfigCount == 0 || IsConfiguredStrategy(magic))
         {
            SPositionCloseResult result = ClosePositionWithRetry(ticket, 0, reason);
            if(result.success)
            {
               closedCount++;
               m_totalClosedPositions++;
            }
         }
      }
   }
   
   return closedCount;
}

//+------------------------------------------------------------------+
//| Close All Positions by Magic                                    |
//+------------------------------------------------------------------+
int CFTMOPositionManager::CloseAllPositionsByMagic(ulong magic, string reason)
{
   int closedCount = 0;
   
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(m_position.SelectByIndex(i) && m_position.Magic() == magic)
      {
         ulong ticket = m_position.Ticket();
         SPositionCloseResult result = ClosePositionWithRetry(ticket, 0, reason);
         if(result.success)
         {
            closedCount++;
            m_totalClosedPositions++;
         }
      }
   }
   
   return closedCount;
}

//+------------------------------------------------------------------+
//| Close All Pending Orders                                        |
//+------------------------------------------------------------------+
int CFTMOPositionManager::CloseAllPendingOrders(string reason)
{
   int cancelledCount = 0;
   
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(m_order.SelectByIndex(i))
      {
         ulong magic = m_order.Magic();
         ulong ticket = m_order.Ticket();
         
         // Sadece konfigüre edilmiş strategy'leri yönet
         if(m_strategyConfigCount == 0 || IsConfiguredStrategy(magic))
         {
            Print("Cancelling pending order ", ticket, " - ", reason);
            
            if(m_trade.OrderDelete(ticket))
            {
               cancelledCount++;
               Print("Order ", ticket, " cancelled successfully");
            }
            else
            {
               Print("Failed to cancel order ", ticket, ": ", m_trade.ResultComment());
            }
         }
      }
   }
   
   return cancelledCount;
}

//+------------------------------------------------------------------+
//| Close Position with Retry                                       |
//+------------------------------------------------------------------+
SPositionCloseResult CFTMOPositionManager::ClosePositionWithRetry(ulong ticket, double volume, string reason)
{
   SPositionCloseResult result;
   ZeroMemory(result);
   result.ticket = ticket;
   
   if(!m_position.SelectByTicket(ticket))
   {
      result.errorMessage = "Position not found";
      return result;
   }
   
   double closeVolume = (volume <= 0) ? m_position.Volume() : volume;
   string symbol = m_position.Symbol();
   
   Print("Closing position ", ticket, " (", symbol, ") - Volume: ", 
         DoubleToString(closeVolume, 2), " - Reason: ", reason);
   
   // Retry mechanism
   for(int attempt = 1; attempt <= m_globalConfig.maxRetries; attempt++)
   {
      bool success = false;
      
      if(volume <= 0)
      {
         // Full close
         success = m_trade.PositionClose(ticket);
      }
      else
      {
         // Partial close
         success = m_trade.PositionClosePartial(ticket, volume);
      }
      
      if(success)
      {
         result.success = true;
         result.closedVolume = closeVolume;
         result.closePrice = m_trade.ResultPrice();
         result.comment = reason;
         
         // Remaining volume hesapla
         if(m_position.SelectByTicket(ticket))
            result.remainingVolume = m_position.Volume();
         else
            result.remainingVolume = 0;
         
         Print("Position ", ticket, " closed successfully");
         break;
      }
      else
      {
         result.retcode = (int)m_trade.ResultRetcode();
         result.errorMessage = m_trade.ResultComment();
         
         Print("Close attempt ", attempt, " failed: ", result.errorMessage, " (", result.retcode, ")");
         
         if(attempt < m_globalConfig.maxRetries)
         {
            Sleep(m_globalConfig.retryDelay);
         }
      }
   }
   
   return result;
}

//+------------------------------------------------------------------+
//| Close Position                                                  |
//+------------------------------------------------------------------+
SPositionCloseResult CFTMOPositionManager::ClosePosition(ulong ticket, string reason)
{
   return ClosePositionWithRetry(ticket, 0, reason);
}

//+------------------------------------------------------------------+
//| Partial Close Position                                          |
//+------------------------------------------------------------------+
SPositionCloseResult CFTMOPositionManager::PartialClosePosition(ulong ticket, double percent, string reason)
{
   SPositionCloseResult result;
   ZeroMemory(result);
   result.ticket = ticket;
   
   if(!m_position.SelectByTicket(ticket))
   {
      result.errorMessage = "Position not found";
      return result;
   }
   
   if(percent <= 0 || percent > 100)
   {
      result.errorMessage = "Invalid percentage: " + DoubleToString(percent, 1);
      return result;
   }
   
   double currentVolume = m_position.Volume();
   double closeVolume = NormalizeDouble(currentVolume * percent / 100.0, 2);
   
   // Minimum lot kontrolü
   string symbol = m_position.Symbol();
   double minLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
   double lotStep = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
   
   if(closeVolume < minLot)
   {
      result.errorMessage = "Close volume below minimum lot size";
      return result;
   }
   
   // Lot step'e göre normalize et
   if(lotStep > 0)
   {
      closeVolume = NormalizeDouble(MathRound(closeVolume / lotStep) * lotStep, 2);
   }
   
   return ClosePositionWithRetry(ticket, closeVolume, reason);
}

//+------------------------------------------------------------------+
//| Modify Position Stop Loss                                       |
//+------------------------------------------------------------------+
bool CFTMOPositionManager::ModifyPositionSL(ulong ticket, double newSL, string reason)
{
   if(!m_position.SelectByTicket(ticket))
   {
      Print("ERROR: Cannot select position ", ticket, " for SL modification");
      return false;
   }
   
   double currentTP = m_position.TakeProfit();
   
   Print("Modifying SL for position ", ticket, " - New SL: ", 
         DoubleToString(newSL, _Digits), " - Reason: ", reason);
   
   // Retry mechanism
   for(int attempt = 1; attempt <= m_globalConfig.maxRetries; attempt++)
   {
      if(m_trade.PositionModify(ticket, newSL, currentTP))
      {
         Print("SL modified successfully for position ", ticket);
         return true;
      }
      
      Print("SL modification attempt ", attempt, " failed: ", m_trade.ResultComment(), 
            " (", m_trade.ResultRetcode(), ")");
      
      if(attempt < m_globalConfig.maxRetries)
      {
         Sleep(m_globalConfig.retryDelay);
      }
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Modify Stop Loss (Public Method)                                |
//+------------------------------------------------------------------+
bool CFTMOPositionManager::ModifyStopLoss(ulong ticket, double newSL, string reason)
{
   return ModifyPositionSL(ticket, newSL, reason);
}

//+------------------------------------------------------------------+
//| Get Managed Positions Count                                     |
//+------------------------------------------------------------------+
int CFTMOPositionManager::GetManagedPositionsCount()
{
   return m_positionCount;
}

//+------------------------------------------------------------------+
//| Get Managed Positions by Magic                                  |
//+------------------------------------------------------------------+
int CFTMOPositionManager::GetManagedPositionsByMagic(ulong magic)
{
   int count = 0;
   
   for(int i = 0; i < m_positionCount; i++)
   {
      if(m_positions[i].magic == magic)
         count++;
   }
   
   return count;
}

//+------------------------------------------------------------------+
//| Get Position Status                                             |
//+------------------------------------------------------------------+
SPositionStatus CFTMOPositionManager::GetPositionStatus(ulong ticket)
{
   SPositionStatus emptyStatus;
   ZeroMemory(emptyStatus);
   
   int index = FindPositionIndex(ticket);
   if(index >= 0)
      return m_positions[index];
   
   return emptyStatus;
}

//+------------------------------------------------------------------+
//| Reset Statistics                                                |
//+------------------------------------------------------------------+
void CFTMOPositionManager::ResetStatistics()
{
   m_totalClosedPositions = 0;
   m_totalPartialCloses = 0;
   m_totalBreakevenSets = 0;
   m_totalTrailingUpdates = 0;
   m_newsClosedPositions = 0;
   m_newsCancelledOrders = 0;
   Print("Position Manager statistics reset");
}

//+------------------------------------------------------------------+
//| Get Status Summary                                              |
//+------------------------------------------------------------------+
string CFTMOPositionManager::GetStatusSummary()
{
   string summary = StringFormat(
      "Positions: %d managed, %d closed, %d partial, %d BE, %d trail, %d news",
      m_positionCount,
      m_totalClosedPositions,
      m_totalPartialCloses,
      m_totalBreakevenSets,
      m_totalTrailingUpdates,
      m_newsClosedPositions
   );
   
   if(m_emergencyCloseExecuted)
   {
      summary += " | EMERGENCY: " + m_lastEmergencyReason;
   }
   
   int newsAffected = GetNewsAffectedPositions();
   if(newsAffected > 0)
   {
      summary += " | NEWS: " + IntegerToString(newsAffected) + " affected";
   }
   
   return summary;
}

//+------------------------------------------------------------------+
//| Print News Status                                               |
//+------------------------------------------------------------------+
void CFTMOPositionManager::PrintNewsStatus()
{
   Print("\n========== POSITION MANAGER NEWS STATUS ==========");
   Print("Global News Filter: ", m_globalNewsFilterEnabled ? "Enabled" : "Disabled");
   Print("News Manager: ", m_newsManager != NULL ? "Connected (via RiskManager)" : "Not Connected");
   Print("News Closed Positions: ", m_newsClosedPositions);
   Print("News Cancelled Orders: ", m_newsCancelledOrders);
   
   if(m_newsManager != NULL && m_globalNewsFilterEnabled)
   {
      // News affected positions
      int newsAffectedCount = GetNewsAffectedPositions();
      
      if(newsAffectedCount > 0)
      {
         Print("\n--- NEWS AFFECTED POSITIONS ---");
         for(int i = 0; i < m_positionCount; i++)
         {
            if(m_positions[i].newsAffected)
            {
               Print("Position ", m_positions[i].ticket, " (", m_positions[i].symbol, ") - NEWS: ", 
                     m_positions[i].newsReason);
            }
         }
      }
      else
      {
         Print("No positions currently affected by news");
      }
      
      // Strategy-specific news settings
      Print("\n--- STRATEGY NEWS SETTINGS ---");
      for(int i = 0; i < m_strategyConfigCount; i++)
      {
         SStrategyPositionConfig config = m_strategyConfigs[i];
         if(config.useCustomNews)
         {
            Print("Strategy: ", config.strategyName, " (Magic: ", config.magic, ")");
            Print("  News Close: ", config.enableNewsClose ? "Enabled" : "Disabled");
            Print("  Minutes Before: ", config.newsMinutesBefore);
            Print("  Minutes After: ", config.newsMinutesAfter);
         }
      }
   }
   
   Print("==============================================\n");
}

//+------------------------------------------------------------------+
//| Print Position Report                                           |
//+------------------------------------------------------------------+
void CFTMOPositionManager::PrintPositionReport()
{
   Print("\n========== FTMO POSITION MANAGER V3 REPORT ==========");
   Print("Managed Positions: ", m_positionCount);
   Print("Emergency Status: ", (m_emergencyCloseExecuted ? "ACTIVE - " + m_lastEmergencyReason : "NORMAL"));
   Print("News Filter: ", m_globalNewsFilterEnabled ? "Enabled" : "Disabled");
   
   if(m_positionCount > 0)
   {
      Print("\n--- ACTIVE POSITIONS ---");
      for(int i = 0; i < m_positionCount; i++)
      {
         SPositionStatus pos = m_positions[i];
         Print("Ticket: ", pos.ticket, " | Magic: ", pos.magic, " | Symbol: ", pos.symbol);
         Print("  Type: ", (pos.type == POSITION_TYPE_BUY ? "BUY" : "SELL"));
         Print("  Lots: ", DoubleToString(pos.lotSize, 2), " (Original: ", DoubleToString(pos.originalLotSize, 2), ")");
         Print("  Entry: ", DoubleToString(pos.entryPrice, _Digits));
         Print("  SL: ", DoubleToString(pos.currentSL, _Digits));
         Print("  TP: ", DoubleToString(pos.currentTP, _Digits));
         Print("  Profit: $", DoubleToString(pos.currentProfit, 2), " (", DoubleToString(pos.currentProfitATR, 2), " ATR)");
         Print("  Reward: ", DoubleToString(pos.rewardRatio, 1), "%");
         Print("  Status: BE=", (pos.breakEvenSet ? "YES" : "NO"), " | PC=", (pos.partialClosed ? "YES" : "NO"));
         
         if(pos.newsAffected)
         {
            Print("  NEWS: ", pos.newsReason);
         }
         
         Print("");
      }
   }
   
   Print("==============================================\n");
}

//+------------------------------------------------------------------+
//| Print Configuration Report                                      |
//+------------------------------------------------------------------+
void CFTMOPositionManager::PrintConfigurationReport()
{
   Print("\n========== POSITION MANAGER CONFIGURATION ==========");
   
   Print("--- GLOBAL CONFIGURATION ---");
   Print("Trailing: ", (m_globalConfig.enableTrailing ? "ON" : "OFF"));
   Print("Breakeven: ", (m_globalConfig.enableBreakeven ? "ON" : "OFF"));
   Print("Partial Close: ", (m_globalConfig.enablePartialClose ? "ON" : "OFF"));
   Print("Day End Close: ", (m_globalConfig.enableDayEndClose ? "ON" : "OFF"));
   Print("Weekend Close: ", (m_globalConfig.enableWeekendClose ? "ON" : "OFF"));
   Print("News Close: ", (m_globalConfig.enableNewsClose ? "ON" : "OFF"));
   Print("ATR Period: ", m_globalConfig.atrPeriod);
   Print("ATR Timeframe: ", EnumToString(m_globalConfig.atrTimeframe));
   Print("Trail Multiplier: ", m_globalConfig.atrMultiplierTrail);
   Print("Trail Min Profit: ", m_globalConfig.minProfitATRTrail, " ATR");
   Print("BE Multiplier: ", m_globalConfig.atrMultiplierBE);
   Print("BE Min Profit: ", m_globalConfig.minProfitATRBE, " ATR");
   
   if(m_globalConfig.enableNewsClose)
   {
      Print("News Minutes Before: ", m_globalConfig.newsMinutesBefore);
      Print("News Minutes After: ", m_globalConfig.newsMinutesAfter);
   }
   
   if(m_strategyConfigCount > 0)
   {
      Print("\n--- STRATEGY SPECIFIC CONFIGURATIONS ---");
      for(int i = 0; i < m_strategyConfigCount; i++)
      {
         SStrategyPositionConfig config = m_strategyConfigs[i];
         Print("Strategy: ", config.strategyName, " (Magic: ", config.magic, ")");
         Print("  Custom Trailing: ", (config.useCustomTrailing ? "YES" : "NO"));
         if(config.useCustomTrailing)
         {
            Print("    ATR Period: ", config.atrPeriodTrail);
            Print("    ATR Timeframe: ", EnumToString(config.atrTimeframeTrail));
            Print("    ATR Multiplier: ", config.atrMultiplierTrail);
            Print("    Min Profit: ", config.minProfitATRTrail, " ATR");
         }
         Print("  Custom Breakeven: ", (config.useCustomBreakeven ? "YES" : "NO"));
         if(config.useCustomBreakeven)
         {
            Print("    ATR Period: ", config.atrPeriodBE);
            Print("    ATR Timeframe: ", EnumToString(config.atrTimeframeBE));
            Print("    ATR Multiplier: ", config.atrMultiplierBE);
            Print("    Min Profit: ", config.minProfitATRBE, " ATR");
         }
         Print("  Custom Partial: ", (config.useCustomPartial ? "YES" : "NO"));
         Print("  Custom Time: ", (config.useCustomTime ? "YES" : "NO"));
         Print("  Custom News: ", (config.useCustomNews ? "YES" : "NO"));
         if(config.useCustomNews)
         {
            Print("    News Close: ", config.enableNewsClose ? "Enabled" : "Disabled");
            Print("    Minutes Before: ", config.newsMinutesBefore);
            Print("    Minutes After: ", config.newsMinutesAfter);
         }
         Print("  Status: ", (config.isActive ? "ACTIVE" : "INACTIVE"));
         Print("");
      }
   }
   
   Print("==============================================\n");
}

//+------------------------------------------------------------------+
//| Print Statistics Report                                         |
//+------------------------------------------------------------------+
void CFTMOPositionManager::PrintStatisticsReport()
{
   Print("\n========== POSITION MANAGER STATISTICS ==========");
   Print("Total Positions Closed: ", m_totalClosedPositions);
   Print("Total Partial Closes: ", m_totalPartialCloses);
   Print("Total Breakeven Sets: ", m_totalBreakevenSets);
   Print("Total Trailing Updates: ", m_totalTrailingUpdates);
   Print("News Closed Positions: ", m_newsClosedPositions);
   Print("News Cancelled Orders: ", m_newsCancelledOrders);
   Print("Currently Managed: ", m_positionCount);
   Print("News Affected: ", GetNewsAffectedPositions());
   
   // ATR Cache Statistics
   PrintCacheStatistics();
   
   if(m_emergencyCloseExecuted)
   {
      Print("Last Emergency: ", m_lastEmergencyReason);
      Print("Emergency Time: ", TimeToString(m_lastEmergencyTime));
   }
   
   Print("==============================================\n");
}
