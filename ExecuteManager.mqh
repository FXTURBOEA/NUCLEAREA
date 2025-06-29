//+------------------------------------------------------------------+
//|                                               ExecuteManager.mqh |
//|                                          FTMO Algorithmic Trading |
//|                                     Professional Trade Execution  |
//+------------------------------------------------------------------+
#property copyright "FTMO Algorithmic Trading"
#property version   "2.10"
#property strict

#include <Trade\Trade.mqh>
#include <Trade\SymbolInfo.mqh>
#include <Trade\OrderInfo.mqh>
#include "RiskManager.mqh"

//+------------------------------------------------------------------+
//| Trade Request Result Structure                                   |
//+------------------------------------------------------------------+
struct STradeRequestResult
{
   bool              success;                 // İşlem başarılı mı
   ulong             ticket;                  // Position/Order ticket
   double            actualLotSize;           // Gerçek lot büyüklüğü
   double            actualEntryPrice;        // Gerçek giriş fiyatı
   double            actualStopLoss;          // Gerçek stop loss
   double            actualTakeProfit;        // Gerçek take profit
   double            actualRisk;              // Gerçek risk miktarı
   double            actualRiskPercent;       // Gerçek risk yüzdesi
   int               retcode;                 // Trade server return code
   string            comment;                 // İşlem yorumu
   string            errorMessage;            // Hata mesajı
};

//+------------------------------------------------------------------+
//| Pending Order Parameters Structure                               |
//+------------------------------------------------------------------+
struct SPendingOrderParams
{
   // Order Parameters
   string            symbol;                  // Sembol
   ENUM_ORDER_TYPE   orderType;              // Order tipi (PENDING)
   double            lotSize;                 // Lot büyüklüğü
   double            price;                   // Pending order fiyatı
   double            stopLoss;                // Stop loss fiyatı
   double            takeProfit;              // Take profit fiyatı
   
   // Expiration
   ENUM_ORDER_TYPE_TIME typeTime;            // Zaman tipi
   datetime          expiration;             // Son kullanma tarihi
   
   // Identification
   ulong             magic;                  // Magic number
   string            comment;                // Yorum
   
   // Risk Override (opsiyonel)
   bool              overrideRisk;           // Risk kontrolünü atla
   string            overrideReason;         // Atlama sebebi
};

//+------------------------------------------------------------------+
//| Market Order Parameters Structure                                |
//+------------------------------------------------------------------+
struct SMarketOrderParams
{
   // Order Parameters
   string            symbol;                  // Sembol
   ENUM_ORDER_TYPE   orderType;              // Order tipi (BUY/SELL)
   double            lotSize;                 // Lot büyüklüğü (0 = auto calculate)
   double            stopLoss;                // Stop loss fiyatı (0 = auto calculate)
   double            takeProfit;              // Take profit fiyatı (0 = auto calculate)
   
   // Price Parameters
   double            entryPrice;              // Giriş fiyatı (0 = market price)
   double            slippage;                // Slippage tolerance (points)
   
   // Identification
   ulong             magic;                  // Magic number
   string            comment;                // Yorum
   
   // Risk Override (opsiyonel)
   bool              overrideRisk;           // Risk kontrolünü atla
   string            overrideReason;         // Atlama sebebi
   
   // Auto-calculation flags
   bool              useAutoLotSize;         // Otomatik lot hesapla
   bool              useAutoStopLoss;        // Otomatik SL hesapla (ATR)
   bool              useAutoTakeProfit;      // Otomatik TP hesapla
};

//+------------------------------------------------------------------+
//| FTMO Execute Manager Class                                      |
//+------------------------------------------------------------------+
class CFTMOExecuteManager
{
private:
   // Core Objects
   CTrade            m_trade;
   CSymbolInfo       m_symbolInfo;
   COrderInfo        m_orderInfo;
   CFTMORiskManager  *m_riskManager;
   
   // Execution Settings
   int               m_maxRetries;            // Maksimum yeniden deneme
   int               m_retryDelay;            // Yeniden deneme gecikmesi (ms)
   double            m_slippagePoints;        // Varsayılan slippage (points)
   
   // Statistics
   int               m_totalExecutions;       // Toplam işlem sayısı
   int               m_successfulExecutions;  // Başarılı işlem sayısı
   int               m_failedExecutions;      // Başarısız işlem sayısı
   
   // Internal Methods
   bool              ValidateSymbol(string symbol);
   bool              ValidateOrderType(ENUM_ORDER_TYPE orderType);
   bool              ValidateLotSize(string symbol, double lotSize);
   bool              ValidatePrice(string symbol, double price, ENUM_ORDER_TYPE orderType);
   bool              PrepareSymbol(string symbol);
   double            GetMarketPrice(string symbol, ENUM_ORDER_TYPE orderType);
   double            AdjustPrice(string symbol, double price, ENUM_ORDER_TYPE orderType);
   double            CalculateSlippage(string symbol, double slippagePoints);
   void              FillTradeResult(STradeRequestResult &result, bool success, ulong ticket = 0);
   string            GetOrderTypeString(ENUM_ORDER_TYPE orderType);
   void              LogTradeAttempt(string symbol, ENUM_ORDER_TYPE orderType, double lotSize, 
                                   double price, double sl, double tp, ulong magic);
   void              LogTradeResult(const STradeRequestResult &result);

public:
   // Constructor & Destructor
                     CFTMOExecuteManager(CFTMORiskManager *riskManager);
                    ~CFTMOExecuteManager();
   
   // Configuration
   void              SetMaxRetries(int retries) { m_maxRetries = MathMax(1, MathMin(10, retries)); }
   void              SetRetryDelay(int delayMs) { m_retryDelay = MathMax(100, MathMin(5000, delayMs)); }
   void              SetDefaultSlippage(double points) { m_slippagePoints = MathMax(0, points); }
   int               GetMaxRetries() const { return m_maxRetries; }
   int               GetRetryDelay() const { return m_retryDelay; }
   double            GetDefaultSlippage() const { return m_slippagePoints; }
   
   // Statistics
   int               GetTotalExecutions() const { return m_totalExecutions; }
   int               GetSuccessfulExecutions() const { return m_successfulExecutions; }
   int               GetFailedExecutions() const { return m_failedExecutions; }
   double            GetSuccessRate() const;
   void              ResetStatistics();
   
   // Market Order Execution
   STradeRequestResult ExecuteMarketOrder(const SMarketOrderParams &params);
   STradeRequestResult OpenBuyPosition(string symbol, double lotSize, double stopLoss, 
                                     double takeProfit, ulong magic, string comment = "");
   STradeRequestResult OpenSellPosition(string symbol, double lotSize, double stopLoss, 
                                      double takeProfit, ulong magic, string comment = "");
   
   // Auto Market Orders (with Risk Manager integration)
   STradeRequestResult ExecuteAutoMarketOrder(ulong magic, string symbol, ENUM_ORDER_TYPE orderType, 
                                            double entryPrice = 0, double stopLoss = 0, string comment = "");
   STradeRequestResult OpenAutoBuyPosition(ulong magic, string symbol, double entryPrice = 0, 
                                         double stopLoss = 0, string comment = "");
   STradeRequestResult OpenAutoSellPosition(ulong magic, string symbol, double entryPrice = 0, 
                                          double stopLoss = 0, string comment = "");
   
   // Pending Order Execution
   STradeRequestResult ExecutePendingOrder(const SPendingOrderParams &params);
   STradeRequestResult PlaceBuyStop(string symbol, double lotSize, double price, double stopLoss, 
                                  double takeProfit, ulong magic, string comment = "");
   STradeRequestResult PlaceBuyLimit(string symbol, double lotSize, double price, double stopLoss, 
                                   double takeProfit, ulong magic, string comment = "");
   STradeRequestResult PlaceSellStop(string symbol, double lotSize, double price, double stopLoss, 
                                   double takeProfit, ulong magic, string comment = "");
   STradeRequestResult PlaceSellLimit(string symbol, double lotSize, double price, double stopLoss, 
                                    double takeProfit, ulong magic, string comment = "");
   
   // Auto Pending Orders (with Risk Manager integration)
   STradeRequestResult ExecuteAutoPendingOrder(ulong magic, string symbol, ENUM_ORDER_TYPE orderType, 
                                             double price, double stopLoss = 0, string comment = "");
   
   // Order Management
   bool              CancelPendingOrder(ulong ticket);
   bool              ModifyPendingOrder(ulong ticket, double price, double stopLoss, double takeProfit, 
                                      datetime expiration = 0);
   
   // Pending Order Risk Control
   bool              CheckPendingOrderCapacity(ulong magic, double orderRisk, string &errorMsg);
   
   // Batch Operations
   int               ExecuteMultipleOrders(const SMarketOrderParams &orders[], STradeRequestResult &results[]);
   int               PlaceMultiplePendingOrders(const SPendingOrderParams &orders[], STradeRequestResult &results[]);
   
   // Validation Methods
   bool              ValidateMarketOrderParams(const SMarketOrderParams &params, string &errorMsg);
   bool              ValidatePendingOrderParams(const SPendingOrderParams &params, string &errorMsg);
   
   // Advanced Trading Controls
   bool              CheckTradingPermission(ulong magic, string &errorMsg);
   bool              CheckNewsRestrictions(string symbol, string &errorMsg);
   bool              CheckTimeRestrictions(string &errorMsg);
   
   // Information Methods
   string            GetLastTradeComment() const;
   string            GetTradingStatus();
   void              PrintExecutionReport();
   void              PrintExecutionStatistics();
};

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CFTMOExecuteManager::CFTMOExecuteManager(CFTMORiskManager *riskManager)
{
   m_riskManager = riskManager;
   m_maxRetries = 3;
   m_retryDelay = 1000;
   m_slippagePoints = 3.0;
   
   m_totalExecutions = 0;
   m_successfulExecutions = 0;
   m_failedExecutions = 0;
   
   // Trade class konfigürasyonu
   m_trade.SetExpertMagicNumber(0);  // Magic her işlemde ayrı set edilecek
   m_trade.SetMarginMode();
   m_trade.SetTypeFillingBySymbol(Symbol());
   
   Print("=== FTMO Execute Manager Initialized ===");
   Print("Max Retries: ", m_maxRetries);
   Print("Retry Delay: ", m_retryDelay, " ms");
   Print("Default Slippage: ", m_slippagePoints, " points");
}

//+------------------------------------------------------------------+
//| Destructor                                                      |
//+------------------------------------------------------------------+
CFTMOExecuteManager::~CFTMOExecuteManager()
{
   Print("=== FTMO Execute Manager Destroyed ===");
   Print("Total Executions: ", m_totalExecutions);
   Print("Success Rate: ", DoubleToString(GetSuccessRate(), 1), "%");
}

//+------------------------------------------------------------------+
//| Validate Symbol                                                 |
//+------------------------------------------------------------------+
bool CFTMOExecuteManager::ValidateSymbol(string symbol)
{
   if(!m_symbolInfo.Name(symbol))
   {
      Print("ERROR: Invalid symbol: ", symbol);
      return false;
   }
   
   if(!m_symbolInfo.Select())
   {
      Print("ERROR: Symbol not selected in Market Watch: ", symbol);
      return false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Validate Order Type                                             |
//+------------------------------------------------------------------+
bool CFTMOExecuteManager::ValidateOrderType(ENUM_ORDER_TYPE orderType)
{
   return (orderType >= ORDER_TYPE_BUY && orderType <= ORDER_TYPE_SELL_STOP_LIMIT);
}

//+------------------------------------------------------------------+
//| Validate Lot Size                                               |
//+------------------------------------------------------------------+
bool CFTMOExecuteManager::ValidateLotSize(string symbol, double lotSize)
{
   if(!m_symbolInfo.Name(symbol))
      return false;
   
   double minLot = m_symbolInfo.LotsMin();
   double maxLot = m_symbolInfo.LotsMax();
   double stepLot = m_symbolInfo.LotsStep();
   
   if(lotSize < minLot || lotSize > maxLot)
   {
      Print("ERROR: Invalid lot size ", lotSize, " for ", symbol, 
            " (min: ", minLot, ", max: ", maxLot, ")");
      return false;
   }
   
   if(stepLot > 0)
   {
      double remainder = fmod(lotSize, stepLot);
      if(remainder > 0.0001)  // Floating point tolerance
      {
         Print("ERROR: Lot size ", lotSize, " not aligned with step ", stepLot, " for ", symbol);
         return false;
      }
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Validate Price                                                  |
//+------------------------------------------------------------------+
bool CFTMOExecuteManager::ValidatePrice(string symbol, double price, ENUM_ORDER_TYPE orderType)
{
   if(!m_symbolInfo.Name(symbol))
      return false;
   
   if(price <= 0)
      return false;
   
   double currentAsk = m_symbolInfo.Ask();
   double currentBid = m_symbolInfo.Bid();
   
   switch(orderType)
   {
      case ORDER_TYPE_BUY_LIMIT:
         if(price >= currentAsk)
         {
            Print("ERROR: Buy Limit price (", price, ") must be below current Ask (", currentAsk, ")");
            return false;
         }
         break;
         
      case ORDER_TYPE_BUY_STOP:
         if(price <= currentAsk)
         {
            Print("ERROR: Buy Stop price (", price, ") must be above current Ask (", currentAsk, ")");
            return false;
         }
         break;
         
      case ORDER_TYPE_SELL_LIMIT:
         if(price <= currentBid)
         {
            Print("ERROR: Sell Limit price (", price, ") must be above current Bid (", currentBid, ")");
            return false;
         }
         break;
         
      case ORDER_TYPE_SELL_STOP:
         if(price >= currentBid)
         {
            Print("ERROR: Sell Stop price (", price, ") must be below current Bid (", currentBid, ")");
            return false;
         }
         break;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Prepare Symbol for Trading                                      |
//+------------------------------------------------------------------+
bool CFTMOExecuteManager::PrepareSymbol(string symbol)
{
   if(!ValidateSymbol(symbol))
      return false;
   
   if(!m_symbolInfo.RefreshRates())
   {
      Print("ERROR: Cannot refresh rates for ", symbol);
      return false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Get Market Price                                                |
//+------------------------------------------------------------------+
double CFTMOExecuteManager::GetMarketPrice(string symbol, ENUM_ORDER_TYPE orderType)
{
   if(!m_symbolInfo.Name(symbol) || !m_symbolInfo.RefreshRates())
      return 0;
   
   switch(orderType)
   {
      case ORDER_TYPE_BUY:
         return m_symbolInfo.Ask();
         
      case ORDER_TYPE_SELL:
         return m_symbolInfo.Bid();
         
      default:
         return 0;
   }
}

//+------------------------------------------------------------------+
//| Adjust Price for Slippage                                       |
//+------------------------------------------------------------------+
double CFTMOExecuteManager::AdjustPrice(string symbol, double price, ENUM_ORDER_TYPE orderType)
{
   if(!m_symbolInfo.Name(symbol) || price <= 0)
      return price;
   
   double point = m_symbolInfo.Point();
   double slippage = m_slippagePoints * point;
   
   switch(orderType)
   {
      case ORDER_TYPE_BUY:
         return price + slippage;
         
      case ORDER_TYPE_SELL:
         return price - slippage;
         
      default:
         return price;
   }
}

//+------------------------------------------------------------------+
//| Calculate Slippage                                              |
//+------------------------------------------------------------------+
double CFTMOExecuteManager::CalculateSlippage(string symbol, double slippagePoints)
{
   if(!m_symbolInfo.Name(symbol))
      return 0;
   
   return slippagePoints * m_symbolInfo.Point();
}

//+------------------------------------------------------------------+
//| Fill Trade Result Structure                                     |
//+------------------------------------------------------------------+
void CFTMOExecuteManager::FillTradeResult(STradeRequestResult &result, bool success, ulong ticket = 0)
{
   result.success = success;
   result.ticket = ticket;
   result.retcode = (int)m_trade.ResultRetcode();
   result.comment = m_trade.ResultComment();
   
   if(success && ticket > 0)
   {
      if(m_trade.ResultDeal() > 0)  // Market order
      {
         result.actualLotSize = m_trade.ResultVolume();
         result.actualEntryPrice = m_trade.ResultPrice();
      }
      else  // Pending order
      {
         if(m_orderInfo.Select(ticket))
         {
            result.actualLotSize = m_orderInfo.VolumeInitial();
            result.actualEntryPrice = m_orderInfo.PriceOpen();
            result.actualStopLoss = m_orderInfo.StopLoss();
            result.actualTakeProfit = m_orderInfo.TakeProfit();
         }
      }
      
      m_successfulExecutions++;
   }
   else
   {
      result.errorMessage = "Trade failed: " + result.comment + " (Code: " + IntegerToString(result.retcode) + ")";
      m_failedExecutions++;
   }
   
   m_totalExecutions++;
}

//+------------------------------------------------------------------+
//| Get Order Type String                                           |
//+------------------------------------------------------------------+
string CFTMOExecuteManager::GetOrderTypeString(ENUM_ORDER_TYPE orderType)
{
   switch(orderType)
   {
      case ORDER_TYPE_BUY: return "BUY";
      case ORDER_TYPE_SELL: return "SELL";
      case ORDER_TYPE_BUY_LIMIT: return "BUY_LIMIT";
      case ORDER_TYPE_SELL_LIMIT: return "SELL_LIMIT";
      case ORDER_TYPE_BUY_STOP: return "BUY_STOP";
      case ORDER_TYPE_SELL_STOP: return "SELL_STOP";
      case ORDER_TYPE_BUY_STOP_LIMIT: return "BUY_STOP_LIMIT";
      case ORDER_TYPE_SELL_STOP_LIMIT: return "SELL_STOP_LIMIT";
      default: return "UNKNOWN";
   }
}

//+------------------------------------------------------------------+
//| Log Trade Attempt                                               |
//+------------------------------------------------------------------+
void CFTMOExecuteManager::LogTradeAttempt(string symbol, ENUM_ORDER_TYPE orderType, double lotSize, 
                                        double price, double sl, double tp, ulong magic)
{
   Print("TRADE ATTEMPT: ", GetOrderTypeString(orderType), " ", DoubleToString(lotSize, 2), 
         " ", symbol, " @ ", DoubleToString(price, _Digits), 
         " SL:", DoubleToString(sl, _Digits), " TP:", DoubleToString(tp, _Digits), 
         " Magic:", magic);
}

//+------------------------------------------------------------------+
//| Log Trade Result                                                |
//+------------------------------------------------------------------+
void CFTMOExecuteManager::LogTradeResult(const STradeRequestResult &result)
{
   if(result.success)
   {
      Print("TRADE SUCCESS: Ticket=", result.ticket, 
            " ActualLot=", DoubleToString(result.actualLotSize, 2),
            " ActualPrice=", DoubleToString(result.actualEntryPrice, _Digits),
            " Risk=", DoubleToString(result.actualRiskPercent, 2), "%");
   }
   else
   {
      Print("TRADE FAILED: ", result.errorMessage);
   }
}

//+------------------------------------------------------------------+
//| Get Success Rate                                                |
//+------------------------------------------------------------------+
double CFTMOExecuteManager::GetSuccessRate() const
{
   if(m_totalExecutions == 0)
      return 0;
   
   return (double)m_successfulExecutions / m_totalExecutions * 100.0;
}

//+------------------------------------------------------------------+
//| Reset Statistics                                                |
//+------------------------------------------------------------------+
void CFTMOExecuteManager::ResetStatistics()
{
   m_totalExecutions = 0;
   m_successfulExecutions = 0;
   m_failedExecutions = 0;
   Print("Execution statistics reset");
}

//+------------------------------------------------------------------+
//| Check Pending Order Capacity                                    |
//+------------------------------------------------------------------+
bool CFTMOExecuteManager::CheckPendingOrderCapacity(ulong magic, double orderRisk, string &errorMsg)
{
   if(m_riskManager == NULL)
   {
      errorMsg = "Risk Manager not initialized";
      return false;
   }
   
   double remainingCapacity = m_riskManager.GetRemainingRiskCapacity(magic);
   
   if(orderRisk > remainingCapacity)
   {
      errorMsg = StringFormat("Insufficient risk capacity - Required: %.2f%%, Available: %.2f%%", 
                            orderRisk, remainingCapacity);
      Print("WARNING: Cannot place pending order - ", errorMsg);
      return false;
   }
   
   // Güvenlik marjı kontrolü (%0.5)
   if(remainingCapacity - orderRisk < 0.5)
   {
      errorMsg = StringFormat("Risk capacity would be too low after order - Remaining after: %.2f%%", 
                            remainingCapacity - orderRisk);
      Print("WARNING: Pending order would leave very low risk capacity - ", errorMsg);
      return false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Execute Market Order                                            |
//+------------------------------------------------------------------+
STradeRequestResult CFTMOExecuteManager::ExecuteMarketOrder(const SMarketOrderParams &params)
{
   STradeRequestResult result;
   ZeroMemory(result);
   
   // Parametre validasyonu
   string errorMsg;
   if(!ValidateMarketOrderParams(params, errorMsg))
   {
      result.errorMessage = errorMsg;
      LogTradeResult(result);
      return result;
   }
   
   // Sembol hazırlığı
   if(!PrepareSymbol(params.symbol))
   {
      result.errorMessage = "Symbol preparation failed: " + params.symbol;
      LogTradeResult(result);
      return result;
   }
   
   // Fiyat hesaplama
   double entryPrice = params.entryPrice;
   if(entryPrice <= 0)
   {
      entryPrice = GetMarketPrice(params.symbol, params.orderType);
      if(entryPrice <= 0)
      {
         result.errorMessage = "Cannot get market price for " + params.symbol;
         LogTradeResult(result);
         return result;
      }
   }
   
   // Risk analizi (override değilse)
   double finalLotSize = params.lotSize;
   double finalStopLoss = params.stopLoss;
   double finalTakeProfit = params.takeProfit;
   
   if(!params.overrideRisk && m_riskManager != NULL)
   {
      // 1. Trading genel kontrolü - EN ÖNCELİKLİ
      if(!m_riskManager.IsTradingAllowed())
      {
         result.errorMessage = "Trading not allowed - daily limits reached";
         LogTradeResult(result);
         return result;
      }
      
      // 2. Spesifik limit kontrolleri
      if(m_riskManager.ShouldStopTradingProfit())
      {
         result.errorMessage = "Daily profit target reached - trading stopped";
         LogTradeResult(result);
         return result;
      }
      
      if(m_riskManager.ShouldStopTradingDrawdown())
      {
         result.errorMessage = "Daily drawdown limit exceeded - trading stopped";
         LogTradeResult(result);
         return result;
      }
      
      // 3. Magic konfigürasyonu kontrolü
      if(!m_riskManager.IsMagicConfigured(params.magic))
      {
         result.errorMessage = "Magic " + IntegerToString(params.magic) + " not configured in Risk Manager";
         LogTradeResult(result);
         return result;
      }
      
      // 4. Profit realization bilgilendirmesi
      if(m_riskManager.ShouldRealizeProfits())
      {
         Print("INFO: Floating profit target reached - consider profit realization");
         Print("Current floating profit: ", DoubleToString(m_riskManager.GetFloatingProfitPercent(), 2), "%");
         Print("Target: ", DoubleToString(m_riskManager.GetProfitRealizeTarget(), 2), "%");
         // Devam edebilir ama bilgilendirme yapıldı
      }
      
      // 5. Risk analizi
      ENUM_POSITION_TYPE posType = (params.orderType == ORDER_TYPE_BUY) ? POSITION_TYPE_BUY : POSITION_TYPE_SELL;
      SRiskAnalysisResult riskAnalysis = m_riskManager.AnalyzePositionRisk(params.magic, params.symbol, 
                                                                          entryPrice, posType, params.stopLoss);
      
      if(!riskAnalysis.isValid)
      {
         result.errorMessage = "Risk validation failed: " + riskAnalysis.riskMessage;
         LogTradeResult(result);
         return result;
      }
      
      if(params.useAutoLotSize)
         finalLotSize = riskAnalysis.recommendedLotSize;
      
      if(params.useAutoStopLoss && params.stopLoss <= 0)
         finalStopLoss = riskAnalysis.stopLoss;
      
      if(params.useAutoTakeProfit && params.takeProfit <= 0)
         finalTakeProfit = riskAnalysis.takeProfit;
      
      result.actualRisk = riskAnalysis.calculatedRisk;
      result.actualRiskPercent = riskAnalysis.calculatedRiskPercent;
   }
   
   // Final validasyon
   if(!ValidateLotSize(params.symbol, finalLotSize))
   {
      result.errorMessage = "Invalid final lot size: " + DoubleToString(finalLotSize, 2);
      LogTradeResult(result);
      return result;
   }
   
   // Trade execution
   LogTradeAttempt(params.symbol, params.orderType, finalLotSize, entryPrice, finalStopLoss, finalTakeProfit, params.magic);
   
   m_trade.SetExpertMagicNumber(params.magic);
   m_trade.SetDeviationInPoints((int)MathRound(params.slippage));
   
   bool success = false;
   ulong ticket = 0;
   
   // Retry mechanism
   for(int attempt = 1; attempt <= m_maxRetries; attempt++)
   {
      if(params.orderType == ORDER_TYPE_BUY)
      {
         success = m_trade.Buy(finalLotSize, params.symbol, entryPrice, finalStopLoss, finalTakeProfit, params.comment);
      }
      else if(params.orderType == ORDER_TYPE_SELL)
      {
         success = m_trade.Sell(finalLotSize, params.symbol, entryPrice, finalStopLoss, finalTakeProfit, params.comment);
      }
      
      if(success)
      {
         ticket = m_trade.ResultOrder();
         break;
      }
      
      Print("Trade attempt ", attempt, " failed: ", m_trade.ResultComment(), " (", m_trade.ResultRetcode(), ")");
      
      if(attempt < m_maxRetries)
      {
         Sleep(m_retryDelay);
         m_symbolInfo.RefreshRates();  // Refresh prices
      }
   }
   
   FillTradeResult(result, success, ticket);
   LogTradeResult(result);
   
   return result;
}

//+------------------------------------------------------------------+
//| Open Buy Position                                               |
//+------------------------------------------------------------------+
STradeRequestResult CFTMOExecuteManager::OpenBuyPosition(string symbol, double lotSize, double stopLoss, 
                                                       double takeProfit, ulong magic, string comment = "")
{
   SMarketOrderParams params;
   ZeroMemory(params);
   
   params.symbol = symbol;
   params.orderType = ORDER_TYPE_BUY;
   params.lotSize = lotSize;
   params.stopLoss = stopLoss;
   params.takeProfit = takeProfit;
   params.magic = magic;
   params.comment = (comment == "") ? "Buy Position" : comment;
   params.slippage = m_slippagePoints;
   
   return ExecuteMarketOrder(params);
}

//+------------------------------------------------------------------+
//| Open Sell Position                                              |
//+------------------------------------------------------------------+
STradeRequestResult CFTMOExecuteManager::OpenSellPosition(string symbol, double lotSize, double stopLoss, 
                                                        double takeProfit, ulong magic, string comment = "")
{
   SMarketOrderParams params;
   ZeroMemory(params);
   
   params.symbol = symbol;
   params.orderType = ORDER_TYPE_SELL;
   params.lotSize = lotSize;
   params.stopLoss = stopLoss;
   params.takeProfit = takeProfit;
   params.magic = magic;
   params.comment = (comment == "") ? "Sell Position" : comment;
   params.slippage = m_slippagePoints;
   
   return ExecuteMarketOrder(params);
}

//+------------------------------------------------------------------+
//| Execute Auto Market Order (Risk Manager Integration)            |
//+------------------------------------------------------------------+
STradeRequestResult CFTMOExecuteManager::ExecuteAutoMarketOrder(ulong magic, string symbol, ENUM_ORDER_TYPE orderType, 
                                                              double entryPrice = 0, double stopLoss = 0, string comment = "")
{
   SMarketOrderParams params;
   ZeroMemory(params);
   
   params.symbol = symbol;
   params.orderType = orderType;
   params.entryPrice = entryPrice;
   params.stopLoss = stopLoss;
   params.magic = magic;
   params.comment = (comment == "") ? "Auto " + GetOrderTypeString(orderType) : comment;
   params.slippage = m_slippagePoints;
   params.useAutoLotSize = true;
   params.useAutoStopLoss = (stopLoss <= 0);
   params.useAutoTakeProfit = true;
   
   return ExecuteMarketOrder(params);
}

//+------------------------------------------------------------------+
//| Open Auto Buy Position                                          |
//+------------------------------------------------------------------+
STradeRequestResult CFTMOExecuteManager::OpenAutoBuyPosition(ulong magic, string symbol, double entryPrice = 0, 
                                                           double stopLoss = 0, string comment = "")
{
   return ExecuteAutoMarketOrder(magic, symbol, ORDER_TYPE_BUY, entryPrice, stopLoss, 
                               (comment == "") ? "Auto Buy" : comment);
}

//+------------------------------------------------------------------+
//| Open Auto Sell Position                                         |
//+------------------------------------------------------------------+
STradeRequestResult CFTMOExecuteManager::OpenAutoSellPosition(ulong magic, string symbol, double entryPrice = 0, 
                                                            double stopLoss = 0, string comment = "")
{
   return ExecuteAutoMarketOrder(magic, symbol, ORDER_TYPE_SELL, entryPrice, stopLoss, 
                                (comment == "") ? "Auto Sell" : comment);
}

//+------------------------------------------------------------------+
//| Execute Pending Order                                           |
//+------------------------------------------------------------------+
STradeRequestResult CFTMOExecuteManager::ExecutePendingOrder(const SPendingOrderParams &params)
{
   STradeRequestResult result;
   ZeroMemory(result);
   
   // Parametre validasyonu
   string errorMsg;
   if(!ValidatePendingOrderParams(params, errorMsg))
   {
      result.errorMessage = errorMsg;
      LogTradeResult(result);
      return result;
   }
   
   // Sembol hazırlığı
   if(!PrepareSymbol(params.symbol))
   {
      result.errorMessage = "Symbol preparation failed: " + params.symbol;
      LogTradeResult(result);
      return result;
   }
   
   // Risk analizi (override değilse)
   double finalLotSize = params.lotSize;
   double finalStopLoss = params.stopLoss;
   double finalTakeProfit = params.takeProfit;
   
   if(!params.overrideRisk && m_riskManager != NULL)
   {
      // 1. Trading genel kontrolü - EN ÖNCELİKLİ
      if(!m_riskManager.IsTradingAllowed())
      {
         result.errorMessage = "Trading not allowed - daily limits reached";
         LogTradeResult(result);
         return result;
      }
      
      // 2. Spesifik limit kontrolleri
      if(m_riskManager.ShouldStopTradingProfit())
      {
         result.errorMessage = "Daily profit target reached - trading stopped";
         LogTradeResult(result);
         return result;
      }
      
      if(m_riskManager.ShouldStopTradingDrawdown())
      {
         result.errorMessage = "Daily drawdown limit exceeded - trading stopped";
         LogTradeResult(result);
         return result;
      }
      
      // 3. Magic konfigürasyonu kontrolü
      if(!m_riskManager.IsMagicConfigured(params.magic))
      {
         result.errorMessage = "Magic " + IntegerToString(params.magic) + " not configured in Risk Manager";
         LogTradeResult(result);
         return result;
      }
      
      // 4. Profit realization bilgilendirmesi
      if(m_riskManager.ShouldRealizeProfits())
      {
         Print("INFO: Floating profit target reached - consider profit realization");
         Print("Current floating profit: ", DoubleToString(m_riskManager.GetFloatingProfitPercent(), 2), "%");
         Print("Target: ", DoubleToString(m_riskManager.GetProfitRealizeTarget(), 2), "%");
         // Devam edebilir ama bilgilendirme yapıldı
      }
      
      // 5. Risk analizi
      ENUM_POSITION_TYPE posType = (params.orderType == ORDER_TYPE_BUY_LIMIT || 
                                   params.orderType == ORDER_TYPE_BUY_STOP) ? 
                                   POSITION_TYPE_BUY : POSITION_TYPE_SELL;
      
      SRiskAnalysisResult riskAnalysis = m_riskManager.AnalyzePositionRisk(params.magic, params.symbol, 
                                                                          params.price, posType, params.stopLoss);
      
      if(!riskAnalysis.isValid)
      {
         result.errorMessage = "Risk validation failed: " + riskAnalysis.riskMessage;
         LogTradeResult(result);
         return result;
      }
      
      finalLotSize = riskAnalysis.recommendedLotSize;
      
      if(params.stopLoss <= 0)
         finalStopLoss = riskAnalysis.stopLoss;
      
      if(params.takeProfit <= 0)
         finalTakeProfit = riskAnalysis.takeProfit;
      
      result.actualRisk = riskAnalysis.calculatedRisk;
      result.actualRiskPercent = riskAnalysis.calculatedRiskPercent;
      
      // 6. Pending Order Risk Capacity kontrolü
      string capacityError;
      if(!CheckPendingOrderCapacity(params.magic, riskAnalysis.calculatedRiskPercent, capacityError))
      {
         result.errorMessage = "Pending order capacity check failed: " + capacityError;
         LogTradeResult(result);
         return result;
      }
   }
   
   // Trade execution
   LogTradeAttempt(params.symbol, params.orderType, finalLotSize, params.price, finalStopLoss, finalTakeProfit, params.magic);
   
   m_trade.SetExpertMagicNumber(params.magic);
   m_trade.SetTypeFilling(ORDER_FILLING_RETURN);
   
   bool success = false;
   ulong ticket = 0;
   
   // Retry mechanism
   for(int attempt = 1; attempt <= m_maxRetries; attempt++)
   {
      success = m_trade.OrderOpen(params.symbol, params.orderType, finalLotSize, 0, params.price, 
                                finalStopLoss, finalTakeProfit, params.typeTime, params.expiration, params.comment);
      
      if(success)
      {
         ticket = m_trade.ResultOrder();
         break;
      }
      
      Print("Pending order attempt ", attempt, " failed: ", m_trade.ResultComment(), " (", m_trade.ResultRetcode(), ")");
      
      if(attempt < m_maxRetries)
      {
         Sleep(m_retryDelay);
         m_symbolInfo.RefreshRates();
      }
   }
   
   FillTradeResult(result, success, ticket);
   LogTradeResult(result);
   
   return result;
}

//+------------------------------------------------------------------+
//| Place Buy Stop Order                                            |
//+------------------------------------------------------------------+
STradeRequestResult CFTMOExecuteManager::PlaceBuyStop(string symbol, double lotSize, double price, double stopLoss, 
                                                    double takeProfit, ulong magic, string comment = "")
{
   SPendingOrderParams params;
   ZeroMemory(params);
   
   params.symbol = symbol;
   params.orderType = ORDER_TYPE_BUY_STOP;
   params.lotSize = lotSize;
   params.price = price;
   params.stopLoss = stopLoss;
   params.takeProfit = takeProfit;
   params.magic = magic;
   params.comment = (comment == "") ? "Buy Stop" : comment;
   params.typeTime = ORDER_TIME_GTC;
   
   return ExecutePendingOrder(params);
}

//+------------------------------------------------------------------+
//| Place Buy Limit Order                                           |
//+------------------------------------------------------------------+
STradeRequestResult CFTMOExecuteManager::PlaceBuyLimit(string symbol, double lotSize, double price, double stopLoss, 
                                                     double takeProfit, ulong magic, string comment = "")
{
   SPendingOrderParams params;
   ZeroMemory(params);
   
   params.symbol = symbol;
   params.orderType = ORDER_TYPE_BUY_LIMIT;
   params.lotSize = lotSize;
   params.price = price;
   params.stopLoss = stopLoss;
   params.takeProfit = takeProfit;
   params.magic = magic;
   params.comment = (comment == "") ? "Buy Limit" : comment;
   params.typeTime = ORDER_TIME_GTC;
   
   return ExecutePendingOrder(params);
}

//+------------------------------------------------------------------+
//| Place Sell Stop Order                                           |
//+------------------------------------------------------------------+
STradeRequestResult CFTMOExecuteManager::PlaceSellStop(string symbol, double lotSize, double price, double stopLoss, 
                                                     double takeProfit, ulong magic, string comment = "")
{
   SPendingOrderParams params;
   ZeroMemory(params);
   
   params.symbol = symbol;
   params.orderType = ORDER_TYPE_SELL_STOP;
   params.lotSize = lotSize;
   params.price = price;
   params.stopLoss = stopLoss;
   params.takeProfit = takeProfit;
   params.magic = magic;
   params.comment = (comment == "") ? "Sell Stop" : comment;
   params.typeTime = ORDER_TIME_GTC;
   
   return ExecutePendingOrder(params);
}

//+------------------------------------------------------------------+
//| Place Sell Limit Order                                          |
//+------------------------------------------------------------------+
STradeRequestResult CFTMOExecuteManager::PlaceSellLimit(string symbol, double lotSize, double price, double stopLoss, 
                                                      double takeProfit, ulong magic, string comment = "")
{
   SPendingOrderParams params;
   ZeroMemory(params);
   
   params.symbol = symbol;
   params.orderType = ORDER_TYPE_SELL_LIMIT;
   params.lotSize = lotSize;
   params.price = price;
   params.stopLoss = stopLoss;
   params.takeProfit = takeProfit;
   params.magic = magic;
   params.comment = (comment == "") ? "Sell Limit" : comment;
   params.typeTime = ORDER_TIME_GTC;
   
   return ExecutePendingOrder(params);
}

//+------------------------------------------------------------------+
//| Execute Auto Pending Order                                      |
//+------------------------------------------------------------------+
STradeRequestResult CFTMOExecuteManager::ExecuteAutoPendingOrder(ulong magic, string symbol, ENUM_ORDER_TYPE orderType, 
                                                               double price, double stopLoss = 0, string comment = "")
{
   SPendingOrderParams params;
   ZeroMemory(params);
   
   params.symbol = symbol;
   params.orderType = orderType;
   params.price = price;
   params.stopLoss = stopLoss;
   params.magic = magic;
   params.comment = (comment == "") ? "Auto " + GetOrderTypeString(orderType) : comment;
   params.typeTime = ORDER_TIME_GTC;
   
   return ExecutePendingOrder(params);
}

//+------------------------------------------------------------------+
//| Cancel Pending Order                                            |
//+------------------------------------------------------------------+
bool CFTMOExecuteManager::CancelPendingOrder(ulong ticket)
{
   if(!m_orderInfo.Select(ticket))
   {
      Print("ERROR: Cannot select order ", ticket, " for cancellation");
      return false;
   }
   
   Print("Cancelling order ", ticket, " (", GetOrderTypeString((ENUM_ORDER_TYPE)m_orderInfo.Type()), 
         " ", m_orderInfo.VolumeInitial(), " ", m_orderInfo.Symbol(), ")");
   
   bool success = m_trade.OrderDelete(ticket);
   
   if(success)
   {
      Print("Order ", ticket, " successfully cancelled");
   }
   else
   {
      Print("Failed to cancel order ", ticket, ": ", m_trade.ResultComment(), " (", m_trade.ResultRetcode(), ")");
   }
   
   return success;
}

//+------------------------------------------------------------------+
//| Modify Pending Order                                            |
//+------------------------------------------------------------------+
bool CFTMOExecuteManager::ModifyPendingOrder(ulong ticket, double price, double stopLoss, double takeProfit, 
                                           datetime expiration = 0)
{
   if(!m_orderInfo.Select(ticket))
   {
      Print("ERROR: Cannot select order ", ticket, " for modification");
      return false;
   }
   
   string symbol = m_orderInfo.Symbol();
   ENUM_ORDER_TYPE orderType = (ENUM_ORDER_TYPE)m_orderInfo.Type();
   
   if(!ValidatePrice(symbol, price, orderType))
   {
      Print("ERROR: Invalid price for order modification");
      return false;
   }
   
   Print("Modifying order ", ticket, " - New price: ", price, " SL: ", stopLoss, " TP: ", takeProfit);
   
   // CTrade::OrderModify için tüm parametreler
   ENUM_ORDER_TYPE_TIME orderTimeType = (expiration == 0) ? ORDER_TIME_GTC : ORDER_TIME_SPECIFIED;
   datetime orderExpiration = (expiration == 0) ? 0 : expiration;
   
   bool success = m_trade.OrderModify(ticket, price, stopLoss, takeProfit, orderTimeType, orderExpiration, 0.0);
   
   if(success)
   {
      Print("Order ", ticket, " successfully modified");
   }
   else
   {
      Print("Failed to modify order ", ticket, ": ", m_trade.ResultComment(), " (", m_trade.ResultRetcode(), ")");
   }
   
   return success;
}

//+------------------------------------------------------------------+
//| Execute Multiple Orders (Batch)                                 |
//+------------------------------------------------------------------+
int CFTMOExecuteManager::ExecuteMultipleOrders(const SMarketOrderParams &orders[], STradeRequestResult &results[])
{
   int orderCount = ArraySize(orders);
   if(orderCount == 0)
      return 0;
   
   ArrayResize(results, orderCount);
   
   int successCount = 0;
   
   for(int i = 0; i < orderCount; i++)
   {
      results[i] = ExecuteMarketOrder(orders[i]);
      if(results[i].success)
         successCount++;
      
      Sleep(100);  // Small delay between orders
   }
   
   Print("Batch execution completed: ", successCount, "/", orderCount, " successful");
   return successCount;
}

//+------------------------------------------------------------------+
//| Place Multiple Pending Orders (Batch)                           |
//+------------------------------------------------------------------+
int CFTMOExecuteManager::PlaceMultiplePendingOrders(const SPendingOrderParams &orders[], STradeRequestResult &results[])
{
   int orderCount = ArraySize(orders);
   if(orderCount == 0)
      return 0;
   
   ArrayResize(results, orderCount);
   
   int successCount = 0;
   
   for(int i = 0; i < orderCount; i++)
   {
      results[i] = ExecutePendingOrder(orders[i]);
      if(results[i].success)
         successCount++;
      
      Sleep(100);  // Small delay between orders
   }
   
   Print("Batch pending order placement completed: ", successCount, "/", orderCount, " successful");
   return successCount;
}

//+------------------------------------------------------------------+
//| Validate Market Order Parameters                                |
//+------------------------------------------------------------------+
bool CFTMOExecuteManager::ValidateMarketOrderParams(const SMarketOrderParams &params, string &errorMsg)
{
   if(params.symbol == "")
   {
      errorMsg = "Symbol cannot be empty";
      return false;
   }
   
   if(params.orderType != ORDER_TYPE_BUY && params.orderType != ORDER_TYPE_SELL)
   {
      errorMsg = "Invalid order type for market order";
      return false;
   }
   
   if(params.lotSize <= 0 && !params.useAutoLotSize)
   {
      errorMsg = "Lot size must be positive or auto-calculation enabled";
      return false;
   }
   
   if(params.magic == 0)
   {
      errorMsg = "Magic number cannot be zero";
      return false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Validate Pending Order Parameters                               |
//+------------------------------------------------------------------+
bool CFTMOExecuteManager::ValidatePendingOrderParams(const SPendingOrderParams &params, string &errorMsg)
{
   if(params.symbol == "")
   {
      errorMsg = "Symbol cannot be empty";
      return false;
   }
   
   if(params.orderType < ORDER_TYPE_BUY_LIMIT || params.orderType > ORDER_TYPE_SELL_STOP_LIMIT)
   {
      errorMsg = "Invalid order type for pending order";
      return false;
   }
   
   if(params.lotSize <= 0)
   {
      errorMsg = "Lot size must be positive";
      return false;
   }
   
   if(params.price <= 0)
   {
      errorMsg = "Price must be positive";
      return false;
   }
   
   if(params.magic == 0)
   {
      errorMsg = "Magic number cannot be zero";
      return false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Check Trading Permission                                        |
//+------------------------------------------------------------------+
bool CFTMOExecuteManager::CheckTradingPermission(ulong magic, string &errorMsg)
{
   if(m_riskManager == NULL)
   {
      errorMsg = "Risk Manager not initialized";
      return false;
   }
   
   // 1. Trading genel kontrolü
   if(!m_riskManager.IsTradingAllowed())
   {
      errorMsg = "Trading not allowed - daily limits reached";
      return false;
   }
   
   // 2. Daily profit target kontrolü
   if(m_riskManager.ShouldStopTradingProfit())
   {
      errorMsg = "Daily profit target reached - trading stopped";
      return false;
   }
   
   // 3. Daily drawdown kontrolü
   if(m_riskManager.ShouldStopTradingDrawdown())
   {
      errorMsg = "Daily drawdown limit exceeded - trading stopped";
      return false;
   }
   
   // 4. Magic konfigürasyonu
   if(!m_riskManager.IsMagicConfigured(magic))
   {
      errorMsg = "Magic " + IntegerToString(magic) + " not configured";
      return false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Check News Restrictions                                         |
//+------------------------------------------------------------------+
bool CFTMOExecuteManager::CheckNewsRestrictions(string symbol, string &errorMsg)
{
   // Bu fonksiyon gelecekte news calendar entegrasyonu için hazır
   // Şu anda sadece placeholder
   
   // Örnek: Major news 30 dakika öncesi trading durdur
   // if(IsHighImpactNewsNear(symbol, 30)) {
   //    errorMsg = "High impact news approaching - trading restricted";
   //    return false;
   // }
   
   return true; // Şu anda her zaman true
}

//+------------------------------------------------------------------+
//| Check Time Restrictions                                         |
//+------------------------------------------------------------------+
bool CFTMOExecuteManager::CheckTimeRestrictions(string &errorMsg)
{
   datetime currentTime = TimeCurrent();
   MqlDateTime timeStruct;
   TimeToStruct(currentTime, timeStruct);
   
   // Örnek: Cuma 22:00 - Pazar 22:00 arası trading yasak
   if(timeStruct.day_of_week == 5 && timeStruct.hour >= 22) // Cuma 22:00+
   {
      errorMsg = "Weekend trading restriction - Friday 22:00+";
      return false;
   }
   
   if(timeStruct.day_of_week == 6) // Cumartesi
   {
      errorMsg = "Weekend trading restriction - Saturday";
      return false;
   }
   
   if(timeStruct.day_of_week == 0 && timeStruct.hour < 22) // Pazar 22:00-
   {
      errorMsg = "Weekend trading restriction - Sunday before 22:00";
      return false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Get Last Trade Comment                                          |
//+------------------------------------------------------------------+
string CFTMOExecuteManager::GetLastTradeComment() const
{
   return m_trade.ResultComment();
}

//+------------------------------------------------------------------+
//| Get Trading Status                                              |
//+------------------------------------------------------------------+
string CFTMOExecuteManager::GetTradingStatus()
{
   if(m_riskManager == NULL)
      return "Risk Manager not initialized";
   
   if(!m_riskManager.IsTradingAllowed())
      return "TRADING STOPPED - Daily limits reached";
   
   if(m_riskManager.ShouldStopTradingProfit())
      return "TRADING STOPPED - Daily profit target reached";
   
   if(m_riskManager.ShouldStopTradingDrawdown())
      return "TRADING STOPPED - Daily drawdown limit exceeded";
   
   if(m_riskManager.ShouldRealizeProfits())
      return "PROFIT REALIZATION - Consider closing positions";
   
   return "TRADING ALLOWED - All systems normal";
}

//+------------------------------------------------------------------+
//| Print Execution Report                                          |
//+------------------------------------------------------------------+
void CFTMOExecuteManager::PrintExecutionReport()
{
   Print("\n========== FTMO EXECUTE MANAGER REPORT ==========");
   Print("Total Executions: ", m_totalExecutions);
   Print("Successful: ", m_successfulExecutions);
   Print("Failed: ", m_failedExecutions);
   Print("Success Rate: ", DoubleToString(GetSuccessRate(), 1), "%");
   Print("Max Retries: ", m_maxRetries);
   Print("Retry Delay: ", m_retryDelay, " ms");
   Print("Default Slippage: ", m_slippagePoints, " points");
   Print("Trading Status: ", GetTradingStatus());
   
   if(m_riskManager != NULL)
   {
      Print("--- RISK STATUS ---");
      Print("Daily Total P&L: ", DoubleToString(m_riskManager.GetDailyTotalPnLPercent(), 2), "%");
      Print("Daily Floating P&L: ", DoubleToString(m_riskManager.GetFloatingProfitPercent(), 2), "%");
      Print("Daily Drawdown: ", DoubleToString(m_riskManager.GetDailyDrawdownPercent(), 2), "%");
      Print("Current Positions: ", PositionsTotal(), "/", m_riskManager.GetMaxGlobalPositions());
   }
   
   Print("==============================================\n");
}

//+------------------------------------------------------------------+
//| Print Execution Statistics                                      |
//+------------------------------------------------------------------+
void CFTMOExecuteManager::PrintExecutionStatistics()
{
   Print("=== EXECUTION STATISTICS ===");
   Print("Total: ", m_totalExecutions, " | Success: ", m_successfulExecutions, 
         " | Failed: ", m_failedExecutions, " | Rate: ", DoubleToString(GetSuccessRate(), 1), "%");
   Print("Trading Status: ", GetTradingStatus());
   
   if(m_riskManager != NULL)
   {
      Print("Risk Summary: ", m_riskManager.GetRiskSummary());
   }
}
