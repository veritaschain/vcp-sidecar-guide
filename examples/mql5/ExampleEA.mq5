//+------------------------------------------------------------------+
//| ExampleEA.mq5                                                     |
//| VCP Sidecar Integration Example                                   |
//| Copyright © 2025 VeritasChain Standards Organization (VSO)       |
//+------------------------------------------------------------------+
#property copyright "VeritasChain Standards Organization"
#property link      "https://veritaschain.org"
#property version   "1.0.0"
#property description "Example EA demonstrating VCP v1.0 Sidecar Integration"
#property description "This EA shows how to log trading events to VeritasChain Cloud"

//+------------------------------------------------------------------+
//| Include VCP Bridge Library                                        |
//+------------------------------------------------------------------+
#include <VCP/vcp_mql_bridge_v1_0.mqh>

//+------------------------------------------------------------------+
//| Input Parameters                                                  |
//+------------------------------------------------------------------+
// VCP Configuration
input group "=== VCP Settings ==="
input string   InpVCPApiKey     = "";                                    // VCP API Key (DO NOT hardcode)
input string   InpVCPEndpoint   = "https://api.veritaschain.org";        // VCP Endpoint
input string   InpVCPVenueId    = "MY_PROP_FIRM";                        // Venue ID

// Trading Parameters
input group "=== Trading Settings ==="
input double   InpLotSize       = 0.01;                                  // Lot Size
input int      InpMAPeriodFast  = 10;                                    // Fast MA Period
input int      InpMAPeriodSlow  = 20;                                    // Slow MA Period
input int      InpRSIPeriod     = 14;                                    // RSI Period
input double   InpRSIOverbought = 70.0;                                  // RSI Overbought
input double   InpRSIOversold   = 30.0;                                  // RSI Oversold

// Algorithm Info (for VCP-GOV)
input group "=== Algorithm Info ==="
input string   InpAlgoId        = "MA_CROSS_RSI_FILTER";                 // Algorithm ID
input string   InpAlgoVersion   = "1.0.0";                               // Algorithm Version

//+------------------------------------------------------------------+
//| Global Variables                                                  |
//+------------------------------------------------------------------+
int      g_handleMAFast;
int      g_handleMASlow;
int      g_handleRSI;
double   g_maFast[], g_maSlow[], g_rsi[];
string   g_currentTraceId = "";
datetime g_lastHeartbeat = 0;

// TraceID storage for order lifecycle
string   g_orderTraceIds[];
ulong    g_orderTickets[];

//+------------------------------------------------------------------+
//| Expert initialization function                                    |
//+------------------------------------------------------------------+
int OnInit()
{
    Print("=== VCP Example EA Initializing ===");
    
    //--- Initialize VCP Logger
    VCP_CONFIG config;
    config.api_key = InpVCPApiKey;
    config.endpoint = InpVCPEndpoint;
    config.venue_id = InpVCPVenueId;
    config.tier = VCP_TIER_SILVER;
    config.async_mode = true;
    config.queue_max_size = 10000;
    config.batch_size = 100;
    config.retry_count = 3;
    
    int result = VCP_Initialize(config);
    if(result != 0)
    {
        Print("VCP initialization failed with error: ", result);
        Print("Make sure to add ", InpVCPEndpoint, " to WebRequest allowed URLs");
        // Continue without VCP - for demo purposes
    }
    else
    {
        Print("VCP Logger initialized successfully");
    }
    
    //--- Initialize indicators
    g_handleMAFast = iMA(_Symbol, PERIOD_CURRENT, InpMAPeriodFast, 0, MODE_EMA, PRICE_CLOSE);
    g_handleMASlow = iMA(_Symbol, PERIOD_CURRENT, InpMAPeriodSlow, 0, MODE_EMA, PRICE_CLOSE);
    g_handleRSI = iRSI(_Symbol, PERIOD_CURRENT, InpRSIPeriod, PRICE_CLOSE);
    
    if(g_handleMAFast == INVALID_HANDLE || g_handleMASlow == INVALID_HANDLE || g_handleRSI == INVALID_HANDLE)
    {
        Print("Failed to create indicator handles");
        return INIT_FAILED;
    }
    
    //--- Set arrays as series
    ArraySetAsSeries(g_maFast, true);
    ArraySetAsSeries(g_maSlow, true);
    ArraySetAsSeries(g_rsi, true);
    
    //--- Initialize TraceID storage
    ArrayResize(g_orderTraceIds, 0);
    ArrayResize(g_orderTickets, 0);
    
    //--- Start timer for queue processing
    EventSetTimer(1);
    
    Print("=== VCP Example EA Initialized ===");
    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                  |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    Print("=== VCP Example EA Shutting Down ===");
    
    //--- Cleanup
    EventKillTimer();
    
    IndicatorRelease(g_handleMAFast);
    IndicatorRelease(g_handleMASlow);
    IndicatorRelease(g_handleRSI);
    
    //--- Shutdown VCP (flushes remaining events)
    VCP_Shutdown();
    
    Print("VCP Example EA shutdown complete. Reason: ", reason);
}

//+------------------------------------------------------------------+
//| Timer function - Process VCP queue and heartbeat                  |
//+------------------------------------------------------------------+
void OnTimer()
{
    //--- Process VCP event queue
    int processed = VCP_ProcessQueue();
    if(processed > 0)
    {
        Print("VCP: Processed ", processed, " events. Remaining: ", VCP_GetQueueSize());
    }
    
    //--- Send heartbeat every 60 seconds
    if(TimeCurrent() - g_lastHeartbeat >= 60)
    {
        VCP_LogHeartbeat();
        g_lastHeartbeat = TimeCurrent();
        Print("VCP: Heartbeat sent");
    }
}

//+------------------------------------------------------------------+
//| Expert tick function                                              |
//+------------------------------------------------------------------+
void OnTick()
{
    //--- Get indicator values
    if(CopyBuffer(g_handleMAFast, 0, 0, 3, g_maFast) < 3) return;
    if(CopyBuffer(g_handleMASlow, 0, 0, 3, g_maSlow) < 3) return;
    if(CopyBuffer(g_handleRSI, 0, 0, 3, g_rsi) < 3) return;
    
    //--- Check for signals
    CheckForSignal();
}

//+------------------------------------------------------------------+
//| Check for trading signals                                         |
//+------------------------------------------------------------------+
void CheckForSignal()
{
    static datetime lastSignalTime = 0;
    
    // Only check once per bar
    datetime currentBarTime = iTime(_Symbol, PERIOD_CURRENT, 0);
    if(currentBarTime == lastSignalTime) return;
    
    // Check for MA crossover
    bool maCrossUp = g_maFast[1] <= g_maSlow[1] && g_maFast[0] > g_maSlow[0];
    bool maCrossDown = g_maFast[1] >= g_maSlow[1] && g_maFast[0] < g_maSlow[0];
    
    // RSI filter
    bool rsiOversold = g_rsi[0] < InpRSIOversold;
    bool rsiOverbought = g_rsi[0] > InpRSIOverbought;
    
    // Generate signals
    if(maCrossUp && rsiOversold && !HasOpenPosition(POSITION_TYPE_BUY))
    {
        lastSignalTime = currentBarTime;
        ProcessBuySignal();
    }
    else if(maCrossDown && rsiOverbought && !HasOpenPosition(POSITION_TYPE_SELL))
    {
        lastSignalTime = currentBarTime;
        ProcessSellSignal();
    }
}

//+------------------------------------------------------------------+
//| Process BUY signal                                                |
//+------------------------------------------------------------------+
void ProcessBuySignal()
{
    Print("=== BUY Signal Detected ===");
    
    //--- Calculate confidence based on RSI distance from threshold
    double confidence = NormalizeDouble((InpRSIOversold - g_rsi[0]) / InpRSIOversold + 0.5, 2);
    confidence = MathMin(MathMax(confidence, 0.1), 0.99);
    
    //--- Build decision factors JSON
    string decisionFactors = BuildDecisionFactorsJSON("BUY");
    
    //--- Log VCP Signal Event (SIG)
    g_currentTraceId = LogSignalEvent("BUY", confidence, decisionFactors);
    
    //--- Execute trade
    ExecuteTrade(ORDER_TYPE_BUY, g_currentTraceId);
}

//+------------------------------------------------------------------+
//| Process SELL signal                                               |
//+------------------------------------------------------------------+
void ProcessSellSignal()
{
    Print("=== SELL Signal Detected ===");
    
    //--- Calculate confidence
    double confidence = NormalizeDouble((g_rsi[0] - InpRSIOverbought) / (100 - InpRSIOverbought) + 0.5, 2);
    confidence = MathMin(MathMax(confidence, 0.1), 0.99);
    
    //--- Build decision factors JSON
    string decisionFactors = BuildDecisionFactorsJSON("SELL");
    
    //--- Log VCP Signal Event (SIG)
    g_currentTraceId = LogSignalEvent("SELL", confidence, decisionFactors);
    
    //--- Execute trade
    ExecuteTrade(ORDER_TYPE_SELL, g_currentTraceId);
}

//+------------------------------------------------------------------+
//| Build decision factors JSON for VCP-GOV                           |
//+------------------------------------------------------------------+
string BuildDecisionFactorsJSON(string direction)
{
    string json = "[";
    
    // MA Fast
    json += "{\"name\":\"MA_FAST\",\"period\":\"" + IntegerToString(InpMAPeriodFast) + 
            "\",\"value\":\"" + DoubleToString(g_maFast[0], _Digits) + 
            "\",\"weight\":\"0.35\"},";
    
    // MA Slow
    json += "{\"name\":\"MA_SLOW\",\"period\":\"" + IntegerToString(InpMAPeriodSlow) + 
            "\",\"value\":\"" + DoubleToString(g_maSlow[0], _Digits) + 
            "\",\"weight\":\"0.35\"},";
    
    // RSI
    json += "{\"name\":\"RSI\",\"period\":\"" + IntegerToString(InpRSIPeriod) + 
            "\",\"value\":\"" + DoubleToString(g_rsi[0], 2) + 
            "\",\"weight\":\"0.30\"},";
    
    // Direction
    json += "{\"name\":\"SIGNAL\",\"value\":\"" + direction + "\",\"weight\":\"1.0\"}";
    
    json += "]";
    return json;
}

//+------------------------------------------------------------------+
//| Log VCP Signal Event                                              |
//+------------------------------------------------------------------+
string LogSignalEvent(string direction, double confidence, string decisionFactors)
{
    Print("VCP: Logging SIG event - Direction: ", direction, ", Confidence: ", confidence);
    
    int result = VCP_LogSignal(
        _Symbol,
        InpAlgoId,
        InpAlgoVersion,
        DoubleToString(confidence, 2),
        decisionFactors
    );
    
    if(result != 0)
    {
        Print("VCP: Signal logging queued (async mode)");
    }
    
    // Generate new TraceID for this order lifecycle
    return g_VCPLogger.GenerateUUIDv7();
}

//+------------------------------------------------------------------+
//| Execute trade and log VCP events                                  |
//+------------------------------------------------------------------+
void ExecuteTrade(ENUM_ORDER_TYPE orderType, string traceId)
{
    string side = (orderType == ORDER_TYPE_BUY) ? "BUY" : "SELL";
    double price = (orderType == ORDER_TYPE_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) 
                                                  : SymbolInfoDouble(_Symbol, SYMBOL_BID);
    
    //--- Prepare trade request
    MqlTradeRequest request = {};
    MqlTradeResult result = {};
    
    request.action = TRADE_ACTION_DEAL;
    request.symbol = _Symbol;
    request.volume = InpLotSize;
    request.type = orderType;
    request.price = price;
    request.deviation = 10;
    request.magic = 123456;
    request.comment = "VCP_Example_" + traceId;
    
    //--- Log VCP Order Event (ORD) BEFORE sending
    Print("VCP: Logging ORD event - TraceID: ", traceId);
    VCP_LogOrder(
        _Symbol,
        traceId,
        0,  // Ticket not yet known
        side,
        "MARKET",
        DoubleToString(price, _Digits),
        DoubleToString(InpLotSize, 2)
    );
    
    //--- Send order
    if(OrderSend(request, result))
    {
        if(result.retcode == TRADE_RETCODE_DONE || result.retcode == TRADE_RETCODE_PLACED)
        {
            Print("Order executed successfully. Ticket: ", result.order);
            
            // Store TraceID for this order
            StoreTraceId(result.order, traceId);
            
            // Note: EXE event will be logged in OnTradeTransaction
        }
        else
        {
            Print("Order failed with retcode: ", result.retcode);
            
            //--- Log VCP Reject Event (REJ)
            VCP_LogReject(
                _Symbol,
                traceId,
                0,
                "Order rejected: " + IntegerToString(result.retcode),
                IntegerToString(result.retcode)
            );
        }
    }
    else
    {
        int error = GetLastError();
        Print("OrderSend failed with error: ", error);
        
        //--- Log VCP Reject Event (REJ)
        VCP_LogReject(
            _Symbol,
            traceId,
            0,
            "OrderSend failed: " + IntegerToString(error),
            IntegerToString(error)
        );
    }
}

//+------------------------------------------------------------------+
//| Trade transaction handler                                         |
//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction& trans,
                        const MqlTradeRequest& request,
                        const MqlTradeResult& result)
{
    //--- Handle deal execution
    if(trans.type == TRADE_TRANSACTION_DEAL_ADD)
    {
        // Get deal info
        if(HistoryDealSelect(trans.deal))
        {
            long dealMagic = HistoryDealGetInteger(trans.deal, DEAL_MAGIC);
            
            // Check if this is our deal
            if(dealMagic == 123456)
            {
                double dealPrice = HistoryDealGetDouble(trans.deal, DEAL_PRICE);
                double dealVolume = HistoryDealGetDouble(trans.deal, DEAL_VOLUME);
                double dealCommission = HistoryDealGetDouble(trans.deal, DEAL_COMMISSION);
                ulong orderTicket = HistoryDealGetInteger(trans.deal, DEAL_ORDER);
                
                // Get TraceID for this order
                string traceId = GetTraceId(orderTicket);
                
                if(traceId != "")
                {
                    // Calculate slippage (simplified)
                    double expectedPrice = (trans.deal_type == DEAL_TYPE_BUY) 
                                           ? SymbolInfoDouble(trans.symbol, SYMBOL_ASK)
                                           : SymbolInfoDouble(trans.symbol, SYMBOL_BID);
                    double slippage = MathAbs(dealPrice - expectedPrice);
                    
                    //--- Log VCP Execution Event (EXE)
                    Print("VCP: Logging EXE event - Deal: ", trans.deal, ", Price: ", dealPrice);
                    VCP_LogExecution(
                        trans.symbol,
                        traceId,
                        orderTicket,
                        trans.deal,
                        DoubleToString(dealPrice, _Digits),
                        DoubleToString(dealVolume, 2),
                        DoubleToString(slippage, _Digits)
                    );
                }
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Store TraceID for order                                           |
//+------------------------------------------------------------------+
void StoreTraceId(ulong ticket, string traceId)
{
    int size = ArraySize(g_orderTickets);
    ArrayResize(g_orderTickets, size + 1);
    ArrayResize(g_orderTraceIds, size + 1);
    g_orderTickets[size] = ticket;
    g_orderTraceIds[size] = traceId;
    
    // Limit storage size
    if(size > 100)
    {
        ArrayRemove(g_orderTickets, 0, 1);
        ArrayRemove(g_orderTraceIds, 0, 1);
    }
}

//+------------------------------------------------------------------+
//| Get TraceID for order                                             |
//+------------------------------------------------------------------+
string GetTraceId(ulong ticket)
{
    int size = ArraySize(g_orderTickets);
    for(int i = size - 1; i >= 0; i--)
    {
        if(g_orderTickets[i] == ticket)
            return g_orderTraceIds[i];
    }
    return "";
}

//+------------------------------------------------------------------+
//| Check if there's an open position of specified type               |
//+------------------------------------------------------------------+
bool HasOpenPosition(ENUM_POSITION_TYPE posType)
{
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        if(PositionSelectByTicket(PositionGetTicket(i)))
        {
            if(PositionGetString(POSITION_SYMBOL) == _Symbol &&
               PositionGetInteger(POSITION_TYPE) == posType &&
               PositionGetInteger(POSITION_MAGIC) == 123456)
            {
                return true;
            }
        }
    }
    return false;
}
//+------------------------------------------------------------------+
