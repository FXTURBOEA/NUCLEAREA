//+------------------------------------------------------------------+
//|                                              NewsManager.mqh      |
//|                                  FTMO News Control System         |
//|                             Professional News Management V1       |
//+------------------------------------------------------------------+
#property copyright "FTMO News Control"
#property version   "1.00"
#property strict

//+------------------------------------------------------------------+
//| News Event Structure                                            |
//+------------------------------------------------------------------+
struct SNewsEvent
{
   datetime          time;              // Event time
   string            currency;          // Currency (USD, EUR, etc)
   string            title;             // Event title
   string            impact;            // Impact level (Low, Medium, High)
   string            forecast;          // Forecast value
   string            previous;          // Previous value
   string            actual;            // Actual value (if released)
   bool              isHighImpact;      // Is high impact event
};

//+------------------------------------------------------------------+
//| News Filter Configuration                                       |
//+------------------------------------------------------------------+
struct SNewsFilterConfig
{
   bool              filterHighImpact;   // Filter only high impact
   bool              filterByCurrency;   // Filter by currency
   string            currencies[];       // Currency list to filter
   int               minutesBefore;      // Minutes before news
   int               minutesAfter;       // Minutes after news
   bool              closePositions;     // Close positions during news
   bool              blockNewTrades;     // Block new trades during news
};

//+------------------------------------------------------------------+
//| FTMO News Manager Class                                        |
//+------------------------------------------------------------------+
class CFTMONewsManager
{
private:
   // Configuration
   SNewsFilterConfig m_config;
   string            m_apiUrl;
   
   // News Data
   SNewsEvent        m_newsEvents[];
   int               m_newsCount;
   datetime          m_lastUpdate;
   int               m_updateInterval;    // Update interval in seconds
   
   // Symbol Currency Info
   string            m_symbolCurrencies[][2]; // [symbol][base/profit]
   int               m_symbolCount;
   
   // Timezone Info
   int               m_brokerGMTOffset;   // Broker GMT offset in hours
   datetime          m_lastOffsetCheck;   // Last GMT offset check time
   
   // Internal Methods
   bool              DownloadNewsData();
   bool              ParseNewsJSON(string jsonData);
   string            ExtractJSONValue(string json, string key);
   datetime          ParseISODateTime(string isoDate);
   int               GetBrokerGMTOffset();
   bool              IsHighImpactEvent(string impact);
   void              UpdateSymbolCurrencies();
   string            GetSymbolBaseCurrency(string symbol);
   string            GetSymbolProfitCurrency(string symbol);
   bool              IsSymbolAffectedByNews(string symbol, SNewsEvent &news);
   
public:
   // Constructor & Destructor
                     CFTMONewsManager();
                    ~CFTMONewsManager();
   
   // Configuration
   void              SetFilterConfig(const SNewsFilterConfig &config);
   void              SetUpdateInterval(int seconds) { m_updateInterval = seconds; }
   void              SetApiUrl(string url) { m_apiUrl = url; }
   
   // Main Methods
   bool              UpdateNewsData();
   bool              IsNewsTime(string symbol);
   bool              IsNewsTimeForCurrency(string currency);
   int               GetUpcomingHighImpactNews(SNewsEvent &events[], int hoursAhead = 24);
   int               GetActiveNewsForSymbol(string symbol, SNewsEvent &events[]);
   
   // Information Methods
   int               GetTotalNewsCount() const { return m_newsCount; }
   datetime          GetLastUpdateTime() const { return m_lastUpdate; }
   bool              NeedsUpdate();
   
   // Currency Methods
   void              AddSymbolToMonitor(string symbol);
   void              RemoveSymbolFromMonitor(string symbol);
   bool              IsSymbolMonitored(string symbol);
   
   // Integration Methods
   bool              ShouldClosePosition(string symbol);
   bool              ShouldBlockNewTrade(string symbol);
   string            GetNewsRestrictionReason(string symbol);
   
   // Reporting
   void              PrintNewsReport();
   void              PrintUpcomingHighImpact(int hoursAhead = 24);
   void              PrintSymbolNewsStatus(string symbol);
};

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CFTMONewsManager::CFTMONewsManager()
{
   m_apiUrl = "https://nfs.faireconomy.media/ff_calendar_thisweek.json";
   m_newsCount = 0;
   m_lastUpdate = 0;
   m_updateInterval = 300; // 5 minutes default
   m_symbolCount = 0;
   m_brokerGMTOffset = 0;
   m_lastOffsetCheck = 0;
   
   // Default configuration
   m_config.filterHighImpact = true;
   m_config.filterByCurrency = false;
   m_config.minutesBefore = 30;
   m_config.minutesAfter = 30;
   m_config.closePositions = false;
   m_config.blockNewTrades = true;
   
   ArrayResize(m_newsEvents, 0);
   ArrayResize(m_symbolCurrencies, 0);
   ArrayResize(m_config.currencies, 0);
   
   // Initial GMT offset calculation
   m_brokerGMTOffset = GetBrokerGMTOffset();
   
   Print("=== FTMO News Manager Initialized ===");
   Print("API URL: ", m_apiUrl);
   Print("Update Interval: ", m_updateInterval, " seconds");
   Print("Broker GMT Offset: ", m_brokerGMTOffset > 0 ? "+" : "", m_brokerGMTOffset, " hours");
}

//+------------------------------------------------------------------+
//| Destructor                                                      |
//+------------------------------------------------------------------+
CFTMONewsManager::~CFTMONewsManager()
{
   ArrayFree(m_newsEvents);
   ArrayFree(m_symbolCurrencies);
   ArrayFree(m_config.currencies);
   
   Print("=== FTMO News Manager Destroyed ===");
}

//+------------------------------------------------------------------+
//| Set Filter Configuration                                        |
//+------------------------------------------------------------------+
void CFTMONewsManager::SetFilterConfig(const SNewsFilterConfig &config)
{
   m_config = config;
   
   Print("News Filter Configuration Updated:");
   Print("Filter High Impact: ", config.filterHighImpact);
   Print("Minutes Before: ", config.minutesBefore);
   Print("Minutes After: ", config.minutesAfter);
   Print("Close Positions: ", config.closePositions);
   Print("Block New Trades: ", config.blockNewTrades);
}

//+------------------------------------------------------------------+
//| Download News Data from API                                     |
//+------------------------------------------------------------------+
bool CFTMONewsManager::DownloadNewsData()
{
   char post[];
   char result[];
   string headers;
   int res;
   
   Print("Downloading news data from: ", m_apiUrl);
   
   // WebRequest çağrısı
   res = WebRequest("GET", m_apiUrl, NULL, NULL, 5000, post, 0, result, headers);
   
   if(res == -1)
   {
      int error = GetLastError();
      Print("ERROR: WebRequest failed. Error code: ", error);
      
      if(error == 4060)
      {
         Print("Please add ", m_apiUrl, " to allowed URLs in Terminal settings");
      }
      
      return false;
   }
   
   // Convert result to string
   string jsonData = CharArrayToString(result);
   
   if(StringLen(jsonData) == 0)
   {
      Print("ERROR: Empty response from API");
      return false;
   }
   
   Print("News data downloaded successfully. Size: ", StringLen(jsonData), " characters");
   
   // Parse JSON data
   return ParseNewsJSON(jsonData);
}

//+------------------------------------------------------------------+
//| Parse News JSON Data                                            |
//+------------------------------------------------------------------+
bool CFTMONewsManager::ParseNewsJSON(string jsonData)
{
   // Clear existing events
   ArrayResize(m_newsEvents, 0);
   m_newsCount = 0;
   
   // Simple JSON array parser
   // Remove array brackets
   StringReplace(jsonData, "[", "");
   StringReplace(jsonData, "]", "");
   
   int startPos = 0;
   
   // Find each JSON object
   while(startPos < StringLen(jsonData))
   {
      // Find start of object
      int objStart = StringFind(jsonData, "{", startPos);
      if(objStart == -1) break;
      
      // Find end of object
      int objEnd = StringFind(jsonData, "}", objStart);
      if(objEnd == -1) break;
      
      // Extract object
      string objStr = StringSubstr(jsonData, objStart + 1, objEnd - objStart - 1);
      
      // Parse the object
      SNewsEvent newsEvent;
      ZeroMemory(newsEvent);
      
      // Extract fields using helper function
      newsEvent.title = ExtractJSONValue(objStr, "title");
      newsEvent.currency = ExtractJSONValue(objStr, "country");  // API uses "country" for currency
      newsEvent.impact = ExtractJSONValue(objStr, "impact");
      newsEvent.forecast = ExtractJSONValue(objStr, "forecast");
      newsEvent.previous = ExtractJSONValue(objStr, "previous");
      newsEvent.actual = ExtractJSONValue(objStr, "actual");
      
      // Parse date
      string dateStr = ExtractJSONValue(objStr, "date");
      newsEvent.time = ParseISODateTime(dateStr);
      
      // Check if high impact
      newsEvent.isHighImpact = IsHighImpactEvent(newsEvent.impact);
      
      // Add to array if meets filter criteria
      if(!m_config.filterHighImpact || newsEvent.isHighImpact)
      {
         ArrayResize(m_newsEvents, m_newsCount + 1);
         m_newsEvents[m_newsCount] = newsEvent;
         m_newsCount++;
      }
      
      // Move to next object
      startPos = objEnd + 1;
   }
   
   m_lastUpdate = TimeCurrent();
   
   Print("News events parsed successfully. High impact events: ", m_newsCount);
   
   return m_newsCount > 0;
}

//+------------------------------------------------------------------+
//| Extract JSON Value Helper                                       |
//+------------------------------------------------------------------+
string CFTMONewsManager::ExtractJSONValue(string json, string key)
{
   // Find the key
   string searchKey = "\"" + key + "\":";
   int keyPos = StringFind(json, searchKey);
   
   if(keyPos == -1)
      return "";
   
   // Move past the key and colon
   int valueStart = keyPos + StringLen(searchKey);
   
   // Skip whitespace
   while(valueStart < StringLen(json) && 
         (StringGetCharacter(json, valueStart) == ' ' || 
          StringGetCharacter(json, valueStart) == '\t' || 
          StringGetCharacter(json, valueStart) == '\n'))
   {
      valueStart++;
   }
   
   // Check if value starts with quote
   bool isString = (StringGetCharacter(json, valueStart) == '"');
   
   if(isString)
   {
      valueStart++; // Skip opening quote
      
      // Find closing quote
      int valueEnd = StringFind(json, "\"", valueStart);
      if(valueEnd == -1)
         return "";
      
      return StringSubstr(json, valueStart, valueEnd - valueStart);
   }
   else
   {
      // Find end of value (comma or end of object)
      int commaPos = StringFind(json, ",", valueStart);
      int endPos = StringLen(json);
      
      if(commaPos > valueStart)
         endPos = commaPos;
      
      string value = StringSubstr(json, valueStart, endPos - valueStart);
      StringTrimLeft(value);
      StringTrimRight(value);
      
      return value;
   }
}

//+------------------------------------------------------------------+
//| Get Broker GMT Offset                                           |
//+------------------------------------------------------------------+
int CFTMONewsManager::GetBrokerGMTOffset()
{
   datetime serverTime = TimeCurrent();
   datetime gmtTime = TimeGMT();
   
   // Calculate offset in seconds and convert to hours
   int offsetSeconds = (int)(serverTime - gmtTime);
   int offsetHours = (int)MathRound(offsetSeconds / 3600.0);
   
   return offsetHours;
}

//+------------------------------------------------------------------+
//| Parse ISO 8601 DateTime Format                                   |
//+------------------------------------------------------------------+
datetime CFTMONewsManager::ParseISODateTime(string isoDate)
{
   // Format: 2025-05-05T02:30:00-04:00
   
   // Check if we need to update GMT offset (every hour)
   datetime currentTime = TimeCurrent();
   if(m_lastOffsetCheck == 0 || (currentTime - m_lastOffsetCheck) > 3600)
   {
      m_brokerGMTOffset = GetBrokerGMTOffset();
      m_lastOffsetCheck = currentTime;
   }
   
   // Replace T with space
   StringReplace(isoDate, "T", " ");
   
   // Find timezone offset
   int tzStart = -1;
   int apiOffset = 0;
   
   // Look for + or - after time part
   int plusPos = StringFind(isoDate, "+", 10);
   int minusPos = StringFind(isoDate, "-", 10);
   
   if(plusPos > 0)
   {
      tzStart = plusPos;
      // Extract offset hours (e.g., from "+02:00" extract 2)
      string offsetStr = StringSubstr(isoDate, plusPos + 1, 2);
      apiOffset = (int)StringToInteger(offsetStr);
   }
   else if(minusPos > 0)
   {
      tzStart = minusPos;
      // Extract offset hours (e.g., from "-04:00" extract 4 and make it -4)
      string offsetStr = StringSubstr(isoDate, minusPos + 1, 2);
      apiOffset = -(int)StringToInteger(offsetStr);
   }
   
   // Remove timezone part
   if(tzStart > 0)
   {
      isoDate = StringSubstr(isoDate, 0, tzStart);
   }
   
   // Fix date format for MQL5
   string datePart = StringSubstr(isoDate, 0, 10);
   string timePart = StringSubstr(isoDate, 11);
   
   StringReplace(datePart, "-", ".");
   string finalDateTime = datePart + " " + timePart;
   
   // Convert to datetime
   datetime apiTime = StringToTime(finalDateTime);
   
   // Convert from API timezone to broker timezone
   // API time is in UTC+apiOffset, need to convert to UTC+brokerOffset
   // Formula: brokerTime = apiTime + (brokerOffset - apiOffset) * 3600
   int conversionHours = m_brokerGMTOffset - apiOffset;
   datetime brokerTime = apiTime + (conversionHours * 3600);
   
   /* Debug print (uncomment for troubleshooting)
   Print("API Time: ", finalDateTime, " (UTC", apiOffset >= 0 ? "+" : "", apiOffset, ")");
   Print("Broker GMT Offset: UTC", m_brokerGMTOffset >= 0 ? "+" : "", m_brokerGMTOffset);
   Print("Conversion: ", conversionHours >= 0 ? "+" : "", conversionHours, " hours");
   Print("Result: ", TimeToString(brokerTime, TIME_DATE|TIME_MINUTES));
   */
   
   return brokerTime;
}

//+------------------------------------------------------------------+
//| Check if Event is High Impact                                   |
//+------------------------------------------------------------------+
bool CFTMONewsManager::IsHighImpactEvent(string impact)
{
   // Convert to uppercase for comparison
   StringToUpper(impact);
   
   // Check for different high impact indicators
   return (impact == "HIGH" || impact == "RED" || impact == "3");
}

//+------------------------------------------------------------------+
//| Update News Data                                                |
//+------------------------------------------------------------------+
bool CFTMONewsManager::UpdateNewsData()
{
   if(!NeedsUpdate())
   {
      return true; // No update needed
   }
   
   if(!DownloadNewsData())
   {
      Print("Failed to update news data");
      return false;
   }
   
   // Update symbol currencies
   UpdateSymbolCurrencies();
   
   return true;
}

//+------------------------------------------------------------------+
//| Check if Update is Needed                                       |
//+------------------------------------------------------------------+
bool CFTMONewsManager::NeedsUpdate()
{
   if(m_lastUpdate == 0)
      return true;
   
   datetime currentTime = TimeCurrent();
   if((currentTime - m_lastUpdate) >= m_updateInterval)
      return true;
   
   return false;
}

//+------------------------------------------------------------------+
//| Update Symbol Currencies                                        |
//+------------------------------------------------------------------+
void CFTMONewsManager::UpdateSymbolCurrencies()
{
   for(int i = 0; i < m_symbolCount; i++)
   {
      string symbol = m_symbolCurrencies[i][0];
      m_symbolCurrencies[i][1] = GetSymbolBaseCurrency(symbol) + "/" + GetSymbolProfitCurrency(symbol);
   }
}

//+------------------------------------------------------------------+
//| Get Symbol Base Currency                                        |
//+------------------------------------------------------------------+
string CFTMONewsManager::GetSymbolBaseCurrency(string symbol)
{
   return SymbolInfoString(symbol, SYMBOL_CURRENCY_BASE);
}

//+------------------------------------------------------------------+
//| Get Symbol Profit Currency                                      |
//+------------------------------------------------------------------+
string CFTMONewsManager::GetSymbolProfitCurrency(string symbol)
{
   return SymbolInfoString(symbol, SYMBOL_CURRENCY_PROFIT);
}

//+------------------------------------------------------------------+
//| Add Symbol to Monitor                                           |
//+------------------------------------------------------------------+
void CFTMONewsManager::AddSymbolToMonitor(string symbol)
{
   // Check if already exists
   for(int i = 0; i < m_symbolCount; i++)
   {
      if(m_symbolCurrencies[i][0] == symbol)
         return;
   }
   
   // Add new symbol
   ArrayResize(m_symbolCurrencies, m_symbolCount + 1);
   m_symbolCurrencies[m_symbolCount][0] = symbol;
   m_symbolCurrencies[m_symbolCount][1] = GetSymbolBaseCurrency(symbol) + "/" + GetSymbolProfitCurrency(symbol);
   m_symbolCount++;
   
   Print("Added symbol to news monitoring: ", symbol, " (", m_symbolCurrencies[m_symbolCount-1][1], ")");
}

//+------------------------------------------------------------------+
//| Remove Symbol from Monitor                                      |
//+------------------------------------------------------------------+
void CFTMONewsManager::RemoveSymbolFromMonitor(string symbol)
{
   for(int i = 0; i < m_symbolCount; i++)
   {
      if(m_symbolCurrencies[i][0] == symbol)
      {
         // Shift array elements
         for(int j = i; j < m_symbolCount - 1; j++)
         {
            m_symbolCurrencies[j][0] = m_symbolCurrencies[j + 1][0];
            m_symbolCurrencies[j][1] = m_symbolCurrencies[j + 1][1];
         }
         
         m_symbolCount--;
         ArrayResize(m_symbolCurrencies, m_symbolCount);
         
         Print("Removed symbol from news monitoring: ", symbol);
         return;
      }
   }
}

//+------------------------------------------------------------------+
//| Check if Symbol is Monitored                                    |
//+------------------------------------------------------------------+
bool CFTMONewsManager::IsSymbolMonitored(string symbol)
{
   for(int i = 0; i < m_symbolCount; i++)
   {
      if(m_symbolCurrencies[i][0] == symbol)
         return true;
   }
   return false;
}

//+------------------------------------------------------------------+
//| Check if Symbol is Affected by News Event                      |
//+------------------------------------------------------------------+
bool CFTMONewsManager::IsSymbolAffectedByNews(string symbol, SNewsEvent &news)
{
   string baseCurrency = GetSymbolBaseCurrency(symbol);
   string profitCurrency = GetSymbolProfitCurrency(symbol);
   
   // Check if news currency matches symbol currencies
   return (news.currency == baseCurrency || news.currency == profitCurrency);
}

//+------------------------------------------------------------------+
//| Check if Currently News Time for Symbol                         |
//+------------------------------------------------------------------+
bool CFTMONewsManager::IsNewsTime(string symbol)
{
   datetime currentTime = TimeCurrent();
   
   for(int i = 0; i < m_newsCount; i++)
   {
      if(!IsSymbolAffectedByNews(symbol, m_newsEvents[i]))
         continue;
      
      datetime newsTime = m_newsEvents[i].time;
      datetime newsBefore = newsTime - (m_config.minutesBefore * 60);
      datetime newsAfter = newsTime + (m_config.minutesAfter * 60);
      
      if(currentTime >= newsBefore && currentTime <= newsAfter)
      {
         return true;
      }
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Check if Currently News Time for Currency                       |
//+------------------------------------------------------------------+
bool CFTMONewsManager::IsNewsTimeForCurrency(string currency)
{
   datetime currentTime = TimeCurrent();
   
   for(int i = 0; i < m_newsCount; i++)
   {
      if(m_newsEvents[i].currency != currency)
         continue;
      
      datetime newsTime = m_newsEvents[i].time;
      datetime newsBefore = newsTime - (m_config.minutesBefore * 60);
      datetime newsAfter = newsTime + (m_config.minutesAfter * 60);
      
      if(currentTime >= newsBefore && currentTime <= newsAfter)
      {
         return true;
      }
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Get Upcoming High Impact News                                   |
//+------------------------------------------------------------------+
int CFTMONewsManager::GetUpcomingHighImpactNews(SNewsEvent &events[], int hoursAhead)
{
   datetime currentTime = TimeCurrent();
   datetime limitTime = currentTime + (hoursAhead * 3600);
   
   ArrayResize(events, 0);
   int count = 0;
   
   for(int i = 0; i < m_newsCount; i++)
   {
      if(m_newsEvents[i].time >= currentTime && m_newsEvents[i].time <= limitTime)
      {
         ArrayResize(events, count + 1);
         events[count] = m_newsEvents[i];
         count++;
      }
   }
   
   return count;
}

//+------------------------------------------------------------------+
//| Get Active News for Symbol                                      |
//+------------------------------------------------------------------+
int CFTMONewsManager::GetActiveNewsForSymbol(string symbol, SNewsEvent &events[])
{
   datetime currentTime = TimeCurrent();
   ArrayResize(events, 0);
   int count = 0;
   
   for(int i = 0; i < m_newsCount; i++)
   {
      if(!IsSymbolAffectedByNews(symbol, m_newsEvents[i]))
         continue;
      
      datetime newsTime = m_newsEvents[i].time;
      datetime newsBefore = newsTime - (m_config.minutesBefore * 60);
      datetime newsAfter = newsTime + (m_config.minutesAfter * 60);
      
      if(currentTime >= newsBefore && currentTime <= newsAfter)
      {
         ArrayResize(events, count + 1);
         events[count] = m_newsEvents[i];
         count++;
      }
   }
   
   return count;
}

//+------------------------------------------------------------------+
//| Should Close Position Due to News                               |
//+------------------------------------------------------------------+
bool CFTMONewsManager::ShouldClosePosition(string symbol)
{
   if(!m_config.closePositions)
      return false;
   
   return IsNewsTime(symbol);
}

//+------------------------------------------------------------------+
//| Should Block New Trade Due to News                              |
//+------------------------------------------------------------------+
bool CFTMONewsManager::ShouldBlockNewTrade(string symbol)
{
   if(!m_config.blockNewTrades)
      return false;
   
   return IsNewsTime(symbol);
}

//+------------------------------------------------------------------+
//| Get News Restriction Reason                                     |
//+------------------------------------------------------------------+
string CFTMONewsManager::GetNewsRestrictionReason(string symbol)
{
   if(!IsNewsTime(symbol))
      return "";
   
   SNewsEvent activeNews[];
   int activeCount = GetActiveNewsForSymbol(symbol, activeNews);
   
   if(activeCount == 0)
      return "";
   
   string reason = "High impact news: ";
   for(int i = 0; i < activeCount && i < 3; i++)
   {
      if(i > 0) reason += ", ";
      reason += activeNews[i].currency + " - " + activeNews[i].title;
   }
   
   return reason;
}

//+------------------------------------------------------------------+
//| Print News Report                                               |
//+------------------------------------------------------------------+
void CFTMONewsManager::PrintNewsReport()
{
   Print("\n========== FTMO NEWS MANAGER REPORT ==========");
   Print("Last Update: ", TimeToString(m_lastUpdate, TIME_DATE|TIME_MINUTES));
   Print("Total High Impact Events: ", m_newsCount);
   Print("Broker GMT Offset: ", m_brokerGMTOffset > 0 ? "+" : "", m_brokerGMTOffset, " hours");
   Print("Broker Time: ", TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTES));
   Print("GMT Time: ", TimeToString(TimeGMT(), TIME_DATE|TIME_MINUTES));
   
   Print("\n--- FILTER CONFIGURATION ---");
   Print("  Minutes Before: ", m_config.minutesBefore);
   Print("  Minutes After: ", m_config.minutesAfter);
   Print("  Close Positions: ", m_config.closePositions);
   Print("  Block New Trades: ", m_config.blockNewTrades);
   
   Print("\n--- UPCOMING HIGH IMPACT NEWS (24H) ---");
   PrintUpcomingHighImpact(24);
   
   Print("\n--- MONITORED SYMBOLS ---");
   for(int i = 0; i < m_symbolCount; i++)
   {
      string symbol = m_symbolCurrencies[i][0];
      Print(symbol, " (", m_symbolCurrencies[i][1], "): ", 
            IsNewsTime(symbol) ? "NEWS ACTIVE" : "Clear");
   }
   
   Print("==============================================\n");
}

//+------------------------------------------------------------------+
//| Print Upcoming High Impact News                                 |
//+------------------------------------------------------------------+
void CFTMONewsManager::PrintUpcomingHighImpact(int hoursAhead)
{
   SNewsEvent upcomingNews[];
   int count = GetUpcomingHighImpactNews(upcomingNews, hoursAhead);
   
   if(count == 0)
   {
      Print("No high impact news in the next ", hoursAhead, " hours");
      return;
   }
   
   for(int i = 0; i < count; i++)
   {
      Print(TimeToString(upcomingNews[i].time, TIME_DATE|TIME_MINUTES), " - ",
            upcomingNews[i].currency, " - ", upcomingNews[i].title);
      
      if(StringLen(upcomingNews[i].forecast) > 0)
      {
         Print("  Forecast: ", upcomingNews[i].forecast, 
               " | Previous: ", upcomingNews[i].previous);
      }
   }
}

//+------------------------------------------------------------------+
//| Print Symbol News Status                                        |
//+------------------------------------------------------------------+
void CFTMONewsManager::PrintSymbolNewsStatus(string symbol)
{
   Print("\n========== NEWS STATUS FOR ", symbol, " ==========");
   
   string baseCurrency = GetSymbolBaseCurrency(symbol);
   string profitCurrency = GetSymbolProfitCurrency(symbol);
   
   Print("Base Currency: ", baseCurrency);
   Print("Profit Currency: ", profitCurrency);
   Print("News Time Active: ", IsNewsTime(symbol) ? "YES" : "NO");
   
   if(IsNewsTime(symbol))
   {
      Print("Restriction Reason: ", GetNewsRestrictionReason(symbol));
   }
   
   SNewsEvent activeNews[];
   int activeCount = GetActiveNewsForSymbol(symbol, activeNews);
   
   if(activeCount > 0)
   {
      Print("\n--- ACTIVE NEWS EVENTS ---");
      for(int i = 0; i < activeCount; i++)
      {
         Print(TimeToString(activeNews[i].time, TIME_DATE|TIME_MINUTES), " - ",
               activeNews[i].currency, " - ", activeNews[i].title);
      }
   }
   
   Print("==============================================\n");
}
