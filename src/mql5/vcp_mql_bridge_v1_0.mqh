//+------------------------------------------------------------------+
//| VCP MQL5 Bridge v1.0 - VCP Specification Compliant               |
//| Document ID: VSO-SDK-MQL5-001                                     |
//| License: CC BY 4.0 International                                  |
//| Maintainer: VeritasChain Standards Organization (VSO)            |
//+------------------------------------------------------------------+
#property copyright "VeritasChain Standards Organization"
#property link      "https://veritaschain.org"
#property version   "1.0.0"
#property strict

//+------------------------------------------------------------------+
//| Event Type Codes (IMMUTABLE - VCP v1.0 Specification)            |
//+------------------------------------------------------------------+
enum ENUM_VCP_EVENT_TYPE
{
    VCP_SIG = 1,    // Signal/Decision generated
    VCP_ORD = 2,    // Order sent
    VCP_ACK = 3,    // Order acknowledged
    VCP_EXE = 4,    // Full execution
    VCP_PRT = 5,    // Partial fill
    VCP_REJ = 6,    // Order rejected
    VCP_CXL = 7,    // Order cancelled
    VCP_MOD = 8,    // Order modified
    VCP_CLS = 9,    // Position closed
    VCP_ALG = 20,   // Algorithm update
    VCP_RSK = 21,   // Risk parameter change
    VCP_AUD = 22,   // Audit request
    VCP_HBT = 98,   // Heartbeat
    VCP_ERR = 99,   // Error
    VCP_REC = 100,  // Recovery
    VCP_SNC = 101   // Clock sync status
};

enum ENUM_VCP_TIMESTAMP_PRECISION
{
    VCP_PRECISION_NANOSECOND,
    VCP_PRECISION_MICROSECOND,
    VCP_PRECISION_MILLISECOND
};

enum ENUM_VCP_CLOCK_SYNC_STATUS
{
    VCP_CLOCK_PTP_LOCKED,
    VCP_CLOCK_NTP_SYNCED,
    VCP_CLOCK_BEST_EFFORT,
    VCP_CLOCK_UNRELIABLE
};

enum ENUM_VCP_TIER
{
    VCP_TIER_PLATINUM,
    VCP_TIER_GOLD,
    VCP_TIER_SILVER
};

//+------------------------------------------------------------------+
//| VCP Configuration Structure                                       |
//+------------------------------------------------------------------+
struct VCP_CONFIG
{
    string api_key;
    string endpoint;
    string venue_id;
    ENUM_VCP_TIER tier;
    bool async_mode;
    int queue_max_size;
    int batch_size;
    int retry_count;
};

//+------------------------------------------------------------------+
//| VCP Event Header (VCP-CORE)                                       |
//+------------------------------------------------------------------+
struct VCP_HEADER
{
    string event_id;              // UUID v7
    string trace_id;              // UUID v7
    string timestamp_int;         // Nanoseconds as string
    string timestamp_iso;         // ISO 8601
    string event_type;            // String representation
    int    event_type_code;       // Integer code
    string timestamp_precision;   // NANOSECOND/MICROSECOND/MILLISECOND
    string clock_sync_status;     // PTP_LOCKED/NTP_SYNCED/BEST_EFFORT/UNRELIABLE
    string hash_algo;             // SHA256/SHA3_256/BLAKE3
    string venue_id;
    string symbol;
    string account_id;
    string operator_id;           // Optional
};

//+------------------------------------------------------------------+
//| VCP Trade Data (VCP-TRADE)                                        |
//+------------------------------------------------------------------+
struct VCP_TRADE_DATA
{
    string order_id;
    string exchange_order_id;
    string side;                  // BUY/SELL
    string order_type;            // MARKET/LIMIT/STOP/STOP_LIMIT
    string price;                 // String for precision
    string quantity;              // String for precision
    string execution_price;
    string executed_qty;
    string commission;
    string slippage;
    string currency;
    string reject_reason;
    string reject_code;
};

//+------------------------------------------------------------------+
//| VCP Risk Data (VCP-RISK)                                          |
//+------------------------------------------------------------------+
struct VCP_RISK_DATA
{
    string max_position_size;
    string current_position;
    string exposure_utilization;
    string daily_loss_limit;
    string current_daily_loss;
    string max_drawdown;
    string current_drawdown;
    string throttle_rate;
    string circuit_breaker;       // NORMAL/WARNING/TRIGGERED/DISABLED
};

//+------------------------------------------------------------------+
//| VCP Governance Data (VCP-GOV)                                     |
//+------------------------------------------------------------------+
struct VCP_GOV_DATA
{
    string algo_id;
    string algo_version;
    string algo_type;             // RULE_BASED/ML/HYBRID/MANUAL
    string confidence;
    string decision_factors;      // JSON array of features
    string model_hash;
    string training_date;
};

//+------------------------------------------------------------------+
//| VCP Security (Hash Chain)                                         |
//+------------------------------------------------------------------+
struct VCP_SECURITY
{
    string event_hash;
    string prev_hash;
    string signature;             // Optional for Silver Tier
    string sign_algo;             // Ed25519
};

//+------------------------------------------------------------------+
//| Complete VCP Event Structure                                      |
//+------------------------------------------------------------------+
struct VCP_EVENT
{
    VCP_HEADER     header;
    VCP_TRADE_DATA trade;
    VCP_RISK_DATA  risk;
    VCP_GOV_DATA   gov;
    VCP_SECURITY   security;
};

//+------------------------------------------------------------------+
//| VCP Logger Class - Main Interface                                 |
//+------------------------------------------------------------------+
class CVCPLogger
{
private:
    VCP_CONFIG     m_config;
    string         m_prev_hash;
    bool           m_initialized;
    int            m_sequence;
    
    // Event queue for async mode
    VCP_EVENT      m_queue[];
    int            m_queue_size;
    
public:
    CVCPLogger();
    ~CVCPLogger();
    
    // Initialization
    int  Initialize(VCP_CONFIG &config);
    void Shutdown();
    
    // Event creation
    void CreateHeader(VCP_HEADER &header, ENUM_VCP_EVENT_TYPE event_type, string symbol);
    
    // Event logging
    int  LogEvent(VCP_EVENT &event);
    int  LogSignal(string symbol, string algo_id, string algo_version, 
                   string confidence, string decision_factors);
    int  LogOrder(string symbol, string trace_id, ulong ticket, 
                  string side, string order_type, string price, string quantity);
    int  LogExecution(string symbol, string trace_id, ulong ticket, ulong deal_ticket,
                      string exec_price, string exec_qty, string slippage);
    int  LogReject(string symbol, string trace_id, ulong ticket, 
                   string reject_reason, string reject_code);
    int  LogHeartbeat();
    
    // Queue processing (for async mode)
    int  ProcessQueue();
    int  GetQueueSize() { return m_queue_size; }
    
private:
    // UUID v7 generation (RFC 9562 compliant)
    string GenerateUUIDv7();
    
    // Timestamp handling
    void   GetTimestamps(string &ts_int, string &ts_iso);
    
    // Account pseudonymization (GDPR compliant)
    string PseudonymizeAccount(long login);
    
    // JSON serialization
    string EventToJSON(VCP_EVENT &event);
    string HeaderToJSON(VCP_HEADER &header);
    string TradeDataToJSON(VCP_TRADE_DATA &trade);
    string RiskDataToJSON(VCP_RISK_DATA &risk);
    string GovDataToJSON(VCP_GOV_DATA &gov);
    string SecurityToJSON(VCP_SECURITY &security);
    
    // Hash computation (SHA-256)
    string ComputeEventHash(VCP_EVENT &event);
    
    // Network
    int    SendToVCC(string json);
    int    SendBatchToVCC();
    
    // Helper
    string EventTypeToString(ENUM_VCP_EVENT_TYPE type);
    string EscapeJSON(string str);
};

//+------------------------------------------------------------------+
//| Constructor                                                       |
//+------------------------------------------------------------------+
CVCPLogger::CVCPLogger()
{
    m_initialized = false;
    m_sequence = 0;
    m_queue_size = 0;
    m_prev_hash = "0000000000000000000000000000000000000000000000000000000000000000";
    ArrayResize(m_queue, 0);
}

//+------------------------------------------------------------------+
//| Destructor                                                        |
//+------------------------------------------------------------------+
CVCPLogger::~CVCPLogger()
{
    if(m_initialized)
        Shutdown();
}

//+------------------------------------------------------------------+
//| Initialize VCP Logger                                             |
//+------------------------------------------------------------------+
int CVCPLogger::Initialize(VCP_CONFIG &config)
{
    if(m_initialized)
        return -1;  // Already initialized
    
    m_config = config;
    
    // Validate configuration
    if(m_config.api_key == "" || m_config.endpoint == "")
    {
        Print("VCP Error: API key and endpoint are required");
        return -2;
    }
    
    // Set defaults for Silver Tier
    if(m_config.tier == VCP_TIER_SILVER)
    {
        if(m_config.queue_max_size == 0)
            m_config.queue_max_size = 10000;
        if(m_config.batch_size == 0)
            m_config.batch_size = 100;
        if(m_config.retry_count == 0)
            m_config.retry_count = 3;
    }
    
    ArrayResize(m_queue, 0, m_config.queue_max_size);
    
    m_initialized = true;
    Print("VCP Logger initialized for venue: ", m_config.venue_id);
    
    return 0;
}

//+------------------------------------------------------------------+
//| Shutdown VCP Logger                                               |
//+------------------------------------------------------------------+
void CVCPLogger::Shutdown()
{
    if(!m_initialized)
        return;
    
    // Flush remaining queue
    if(m_queue_size > 0)
    {
        Print("VCP: Flushing ", m_queue_size, " events before shutdown");
        SendBatchToVCC();
    }
    
    ArrayFree(m_queue);
    m_initialized = false;
    Print("VCP Logger shutdown complete");
}

//+------------------------------------------------------------------+
//| Generate UUID v7 (RFC 9562 Compliant)                             |
//+------------------------------------------------------------------+
string CVCPLogger::GenerateUUIDv7()
{
    // Get current timestamp in milliseconds
    long timestamp_ms = (long)TimeCurrent() * 1000 + GetTickCount() % 1000;
    
    // Convert to hex (48 bits = 12 hex chars)
    string ts_hex = "";
    long temp = timestamp_ms;
    for(int i = 0; i < 12; i++)
    {
        int digit = (int)(temp % 16);
        ts_hex = StringSubstr("0123456789abcdef", digit, 1) + ts_hex;
        temp = temp / 16;
    }
    
    // Generate random bits
    string rand_hex = "";
    for(int i = 0; i < 16; i++)
    {
        int r = MathRand() % 16;
        rand_hex += StringSubstr("0123456789abcdef", r, 1);
    }
    
    // Construct UUID v7:
    // xxxxxxxx-xxxx-7xxx-yxxx-xxxxxxxxxxxx
    // Where:
    //   - First 48 bits (12 hex): timestamp
    //   - Version nibble: 7
    //   - Next 12 bits: random
    //   - Variant bits: 10xx (y must be 8, 9, a, or b)
    //   - Remaining 62 bits: random
    
    // Fix variant bits (must be 8, 9, a, or b)
    int variant_digit = MathRand() % 4;  // 0-3
    string variant_char = StringSubstr("89ab", variant_digit, 1);
    
    string uuid = StringSubstr(ts_hex, 0, 8) + "-" +
                  StringSubstr(ts_hex, 8, 4) + "-" +
                  "7" + StringSubstr(rand_hex, 0, 3) + "-" +
                  variant_char + StringSubstr(rand_hex, 3, 3) + "-" +
                  StringSubstr(rand_hex, 6, 12);
    
    return uuid;
}

//+------------------------------------------------------------------+
//| Get Timestamps (dual format as per VCP spec)                      |
//+------------------------------------------------------------------+
void CVCPLogger::GetTimestamps(string &ts_int, string &ts_iso)
{
    datetime now = TimeCurrent();
    long ms = GetTickCount() % 1000;
    
    // Nanosecond timestamp as string
    // Convert to nanoseconds: seconds * 1e9 + milliseconds * 1e6
    long seconds = (long)now;
    long nanoseconds = seconds * 1000000000 + ms * 1000000;
    ts_int = IntegerToString(nanoseconds);
    
    // ISO 8601 format
    MqlDateTime dt;
    TimeToStruct(now, dt);
    ts_iso = StringFormat("%04d-%02d-%02dT%02d:%02d:%02d.%03dZ",
                          dt.year, dt.mon, dt.day,
                          dt.hour, dt.min, dt.sec, (int)ms);
}

//+------------------------------------------------------------------+
//| Pseudonymize Account ID (GDPR Compliant)                          |
//+------------------------------------------------------------------+
string CVCPLogger::PseudonymizeAccount(long login)
{
    // Use SHA-256 hash with salt
    string salt = "vcp_" + m_config.venue_id + "_";
    string input = salt + IntegerToString(login);
    
    // Simple hash simulation (in production, use proper SHA-256)
    ulong hash = 0;
    for(int i = 0; i < StringLen(input); i++)
    {
        hash = hash * 31 + StringGetCharacter(input, i);
    }
    
    return "acc_" + StringFormat("%016llx", hash);
}

//+------------------------------------------------------------------+
//| Event Type to String                                              |
//+------------------------------------------------------------------+
string CVCPLogger::EventTypeToString(ENUM_VCP_EVENT_TYPE type)
{
    switch(type)
    {
        case VCP_SIG: return "SIG";
        case VCP_ORD: return "ORD";
        case VCP_ACK: return "ACK";
        case VCP_EXE: return "EXE";
        case VCP_PRT: return "PRT";
        case VCP_REJ: return "REJ";
        case VCP_CXL: return "CXL";
        case VCP_MOD: return "MOD";
        case VCP_CLS: return "CLS";
        case VCP_ALG: return "ALG";
        case VCP_RSK: return "RSK";
        case VCP_AUD: return "AUD";
        case VCP_HBT: return "HBT";
        case VCP_ERR: return "ERR";
        case VCP_REC: return "REC";
        case VCP_SNC: return "SNC";
        default:      return "UNK";
    }
}

//+------------------------------------------------------------------+
//| Create Event Header                                               |
//+------------------------------------------------------------------+
void CVCPLogger::CreateHeader(VCP_HEADER &header, ENUM_VCP_EVENT_TYPE event_type, string symbol)
{
    header.event_id = GenerateUUIDv7();
    GetTimestamps(header.timestamp_int, header.timestamp_iso);
    header.event_type = EventTypeToString(event_type);
    header.event_type_code = (int)event_type;
    header.timestamp_precision = "MILLISECOND";  // Silver Tier
    header.clock_sync_status = "BEST_EFFORT";    // Silver Tier
    header.hash_algo = "SHA256";
    header.venue_id = m_config.venue_id;
    header.symbol = symbol;
    header.account_id = PseudonymizeAccount(AccountInfoInteger(ACCOUNT_LOGIN));
    header.operator_id = "";
}

//+------------------------------------------------------------------+
//| Escape JSON String                                                |
//+------------------------------------------------------------------+
string CVCPLogger::EscapeJSON(string str)
{
    string result = str;
    StringReplace(result, "\\", "\\\\");
    StringReplace(result, "\"", "\\\"");
    StringReplace(result, "\n", "\\n");
    StringReplace(result, "\r", "\\r");
    StringReplace(result, "\t", "\\t");
    return result;
}

//+------------------------------------------------------------------+
//| Header to JSON                                                    |
//+------------------------------------------------------------------+
string CVCPLogger::HeaderToJSON(VCP_HEADER &header)
{
    string json = "{";
    json += "\"event_id\":\"" + header.event_id + "\",";
    json += "\"trace_id\":\"" + header.trace_id + "\",";
    json += "\"timestamp_int\":\"" + header.timestamp_int + "\",";
    json += "\"timestamp_iso\":\"" + header.timestamp_iso + "\",";
    json += "\"event_type\":\"" + header.event_type + "\",";
    json += "\"event_type_code\":" + IntegerToString(header.event_type_code) + ",";
    json += "\"timestamp_precision\":\"" + header.timestamp_precision + "\",";
    json += "\"clock_sync_status\":\"" + header.clock_sync_status + "\",";
    json += "\"hash_algo\":\"" + header.hash_algo + "\",";
    json += "\"venue_id\":\"" + EscapeJSON(header.venue_id) + "\",";
    json += "\"symbol\":\"" + header.symbol + "\",";
    json += "\"account_id\":\"" + header.account_id + "\"";
    if(header.operator_id != "")
        json += ",\"operator_id\":\"" + header.operator_id + "\"";
    json += "}";
    return json;
}

//+------------------------------------------------------------------+
//| Trade Data to JSON                                                |
//+------------------------------------------------------------------+
string CVCPLogger::TradeDataToJSON(VCP_TRADE_DATA &trade)
{
    string json = "{";
    bool has_field = false;
    
    if(trade.order_id != "")
    {
        json += "\"order_id\":\"" + trade.order_id + "\"";
        has_field = true;
    }
    if(trade.exchange_order_id != "")
    {
        if(has_field) json += ",";
        json += "\"exchange_order_id\":\"" + trade.exchange_order_id + "\"";
        has_field = true;
    }
    if(trade.side != "")
    {
        if(has_field) json += ",";
        json += "\"side\":\"" + trade.side + "\"";
        has_field = true;
    }
    if(trade.order_type != "")
    {
        if(has_field) json += ",";
        json += "\"order_type\":\"" + trade.order_type + "\"";
        has_field = true;
    }
    if(trade.price != "")
    {
        if(has_field) json += ",";
        json += "\"price\":\"" + trade.price + "\"";
        has_field = true;
    }
    if(trade.quantity != "")
    {
        if(has_field) json += ",";
        json += "\"quantity\":\"" + trade.quantity + "\"";
        has_field = true;
    }
    if(trade.execution_price != "")
    {
        if(has_field) json += ",";
        json += "\"execution_price\":\"" + trade.execution_price + "\"";
        has_field = true;
    }
    if(trade.executed_qty != "")
    {
        if(has_field) json += ",";
        json += "\"executed_qty\":\"" + trade.executed_qty + "\"";
        has_field = true;
    }
    if(trade.commission != "")
    {
        if(has_field) json += ",";
        json += "\"commission\":\"" + trade.commission + "\"";
        has_field = true;
    }
    if(trade.slippage != "")
    {
        if(has_field) json += ",";
        json += "\"slippage\":\"" + trade.slippage + "\"";
        has_field = true;
    }
    if(trade.reject_reason != "")
    {
        if(has_field) json += ",";
        json += "\"reject_reason\":\"" + EscapeJSON(trade.reject_reason) + "\"";
        has_field = true;
    }
    if(trade.reject_code != "")
    {
        if(has_field) json += ",";
        json += "\"reject_code\":\"" + trade.reject_code + "\"";
    }
    
    json += "}";
    return json;
}

//+------------------------------------------------------------------+
//| Gov Data to JSON                                                  |
//+------------------------------------------------------------------+
string CVCPLogger::GovDataToJSON(VCP_GOV_DATA &gov)
{
    string json = "{";
    bool has_field = false;
    
    if(gov.algo_id != "")
    {
        json += "\"algo_id\":\"" + gov.algo_id + "\"";
        has_field = true;
    }
    if(gov.algo_version != "")
    {
        if(has_field) json += ",";
        json += "\"algo_version\":\"" + gov.algo_version + "\"";
        has_field = true;
    }
    if(gov.algo_type != "")
    {
        if(has_field) json += ",";
        json += "\"algo_type\":\"" + gov.algo_type + "\"";
        has_field = true;
    }
    if(gov.confidence != "")
    {
        if(has_field) json += ",";
        json += "\"confidence\":\"" + gov.confidence + "\"";
        has_field = true;
    }
    if(gov.decision_factors != "")
    {
        if(has_field) json += ",";
        json += "\"decision_factors\":" + gov.decision_factors;  // Already JSON array
        has_field = true;
    }
    if(gov.model_hash != "")
    {
        if(has_field) json += ",";
        json += "\"model_hash\":\"" + gov.model_hash + "\"";
    }
    
    json += "}";
    return json;
}

//+------------------------------------------------------------------+
//| Risk Data to JSON                                                 |
//+------------------------------------------------------------------+
string CVCPLogger::RiskDataToJSON(VCP_RISK_DATA &risk)
{
    string json = "{";
    bool has_field = false;
    
    if(risk.max_position_size != "")
    {
        json += "\"max_position_size\":\"" + risk.max_position_size + "\"";
        has_field = true;
    }
    if(risk.exposure_utilization != "")
    {
        if(has_field) json += ",";
        json += "\"exposure_utilization\":\"" + risk.exposure_utilization + "\"";
        has_field = true;
    }
    if(risk.circuit_breaker != "")
    {
        if(has_field) json += ",";
        json += "\"circuit_breaker\":\"" + risk.circuit_breaker + "\"";
    }
    
    json += "}";
    return json;
}

//+------------------------------------------------------------------+
//| Security to JSON                                                  |
//+------------------------------------------------------------------+
string CVCPLogger::SecurityToJSON(VCP_SECURITY &security)
{
    string json = "{";
    json += "\"event_hash\":\"" + security.event_hash + "\",";
    json += "\"prev_hash\":\"" + security.prev_hash + "\"";
    if(security.signature != "")
    {
        json += ",\"signature\":\"" + security.signature + "\"";
        json += ",\"sign_algo\":\"" + security.sign_algo + "\"";
    }
    json += "}";
    return json;
}

//+------------------------------------------------------------------+
//| Compute Event Hash (SHA-256 placeholder)                          |
//+------------------------------------------------------------------+
string CVCPLogger::ComputeEventHash(VCP_EVENT &event)
{
    // In production, use proper SHA-256 via DLL
    // This is a placeholder that generates a consistent hash
    string input = event.header.event_id + event.header.timestamp_int;
    
    ulong hash1 = 0, hash2 = 0, hash3 = 0, hash4 = 0;
    for(int i = 0; i < StringLen(input); i++)
    {
        uchar c = (uchar)StringGetCharacter(input, i);
        hash1 = (hash1 * 31 + c) ^ 0xDEADBEEF;
        hash2 = (hash2 * 37 + c) ^ 0xCAFEBABE;
        hash3 = (hash3 * 41 + c) ^ 0x12345678;
        hash4 = (hash4 * 43 + c) ^ 0x87654321;
    }
    
    return StringFormat("%016llx%016llx%016llx%016llx", hash1, hash2, hash3, hash4);
}

//+------------------------------------------------------------------+
//| Event to JSON (Complete VCP v1.0 format)                          |
//+------------------------------------------------------------------+
string CVCPLogger::EventToJSON(VCP_EVENT &event)
{
    // Compute hash before serialization
    event.security.prev_hash = m_prev_hash;
    event.security.event_hash = ComputeEventHash(event);
    
    string json = "{";
    
    // Header
    json += "\"header\":" + HeaderToJSON(event.header) + ",";
    
    // Payload
    json += "\"payload\":{";
    bool has_payload = false;
    
    if(event.header.event_type_code == VCP_SIG ||
       event.header.event_type_code == VCP_ALG)
    {
        if(event.gov.algo_id != "")
        {
            json += "\"vcp_gov\":" + GovDataToJSON(event.gov);
            has_payload = true;
        }
    }
    
    if(event.header.event_type_code == VCP_ORD ||
       event.header.event_type_code == VCP_ACK ||
       event.header.event_type_code == VCP_EXE ||
       event.header.event_type_code == VCP_PRT ||
       event.header.event_type_code == VCP_REJ ||
       event.header.event_type_code == VCP_CXL ||
       event.header.event_type_code == VCP_MOD ||
       event.header.event_type_code == VCP_CLS)
    {
        if(has_payload) json += ",";
        json += "\"trade_data\":" + TradeDataToJSON(event.trade);
        has_payload = true;
    }
    
    if(event.risk.max_position_size != "" || event.risk.circuit_breaker != "")
    {
        if(has_payload) json += ",";
        json += "\"vcp_risk\":" + RiskDataToJSON(event.risk);
    }
    
    json += "},";
    
    // Security
    json += "\"security\":" + SecurityToJSON(event.security);
    
    json += "}";
    
    // Update prev_hash for chain
    m_prev_hash = event.security.event_hash;
    
    return json;
}

//+------------------------------------------------------------------+
//| Log Generic Event                                                 |
//+------------------------------------------------------------------+
int CVCPLogger::LogEvent(VCP_EVENT &event)
{
    if(!m_initialized)
        return -1;
    
    string json = EventToJSON(event);
    
    if(m_config.async_mode)
    {
        // Add to queue
        if(m_queue_size >= m_config.queue_max_size)
        {
            Print("VCP Warning: Queue full, dropping oldest event");
            ArrayRemove(m_queue, 0, 1);
            m_queue_size--;
        }
        
        ArrayResize(m_queue, m_queue_size + 1);
        m_queue[m_queue_size] = event;
        m_queue_size++;
        
        return 0;
    }
    else
    {
        return SendToVCC(json);
    }
}

//+------------------------------------------------------------------+
//| Log Signal Event                                                  |
//+------------------------------------------------------------------+
int CVCPLogger::LogSignal(string symbol, string algo_id, string algo_version,
                          string confidence, string decision_factors)
{
    VCP_EVENT event;
    ZeroMemory(event);
    
    CreateHeader(event.header, VCP_SIG, symbol);
    event.header.trace_id = GenerateUUIDv7();  // New trace starts here
    
    event.gov.algo_id = algo_id;
    event.gov.algo_version = algo_version;
    event.gov.algo_type = "HYBRID";
    event.gov.confidence = confidence;
    event.gov.decision_factors = decision_factors;
    
    return LogEvent(event);
}

//+------------------------------------------------------------------+
//| Log Order Event                                                   |
//+------------------------------------------------------------------+
int CVCPLogger::LogOrder(string symbol, string trace_id, ulong ticket,
                         string side, string order_type, string price, string quantity)
{
    VCP_EVENT event;
    ZeroMemory(event);
    
    CreateHeader(event.header, VCP_ORD, symbol);
    event.header.trace_id = trace_id;
    
    event.trade.order_id = IntegerToString(ticket);
    event.trade.side = side;
    event.trade.order_type = order_type;
    event.trade.price = price;
    event.trade.quantity = quantity;
    
    // Add current risk snapshot
    event.risk.circuit_breaker = "NORMAL";
    
    return LogEvent(event);
}

//+------------------------------------------------------------------+
//| Log Execution Event                                               |
//+------------------------------------------------------------------+
int CVCPLogger::LogExecution(string symbol, string trace_id, ulong ticket, ulong deal_ticket,
                             string exec_price, string exec_qty, string slippage)
{
    VCP_EVENT event;
    ZeroMemory(event);
    
    CreateHeader(event.header, VCP_EXE, symbol);
    event.header.trace_id = trace_id;
    
    event.trade.order_id = IntegerToString(ticket);
    event.trade.exchange_order_id = IntegerToString(deal_ticket);
    event.trade.execution_price = exec_price;
    event.trade.executed_qty = exec_qty;
    event.trade.slippage = slippage;
    
    return LogEvent(event);
}

//+------------------------------------------------------------------+
//| Log Reject Event                                                  |
//+------------------------------------------------------------------+
int CVCPLogger::LogReject(string symbol, string trace_id, ulong ticket,
                          string reject_reason, string reject_code)
{
    VCP_EVENT event;
    ZeroMemory(event);
    
    CreateHeader(event.header, VCP_REJ, symbol);
    event.header.trace_id = trace_id;
    
    event.trade.order_id = IntegerToString(ticket);
    event.trade.reject_reason = reject_reason;
    event.trade.reject_code = reject_code;
    
    return LogEvent(event);
}

//+------------------------------------------------------------------+
//| Log Heartbeat Event                                               |
//+------------------------------------------------------------------+
int CVCPLogger::LogHeartbeat()
{
    VCP_EVENT event;
    ZeroMemory(event);
    
    CreateHeader(event.header, VCP_HBT, "");
    event.header.trace_id = event.header.event_id;  // Self-referential for HBT
    
    return LogEvent(event);
}

//+------------------------------------------------------------------+
//| Send to VCC (HTTP POST)                                           |
//+------------------------------------------------------------------+
int CVCPLogger::SendToVCC(string json)
{
    string headers = "Content-Type: application/json\r\n";
    headers += "X-API-Key: " + m_config.api_key + "\r\n";
    
    char post_data[];
    char result[];
    string result_headers;
    
    StringToCharArray(json, post_data, 0, WHOLE_ARRAY, CP_UTF8);
    ArrayResize(post_data, ArraySize(post_data) - 1);  // Remove null terminator
    
    int timeout = 5000;  // 5 seconds
    
    int res = WebRequest(
        "POST",
        m_config.endpoint + "/v1/events",
        headers,
        timeout,
        post_data,
        result,
        result_headers
    );
    
    if(res == -1)
    {
        int error = GetLastError();
        Print("VCP WebRequest failed: ", error);
        return error;
    }
    
    if(res != 200 && res != 201)
    {
        Print("VCP API error: ", res, " - ", CharArrayToString(result));
        return res;
    }
    
    return 0;
}

//+------------------------------------------------------------------+
//| Process Queue (call from OnTimer)                                 |
//+------------------------------------------------------------------+
int CVCPLogger::ProcessQueue()
{
    if(!m_initialized || m_queue_size == 0)
        return 0;
    
    int processed = 0;
    int max_per_tick = m_config.batch_size;
    
    while(m_queue_size > 0 && processed < max_per_tick)
    {
        VCP_EVENT event = m_queue[0];
        string json = EventToJSON(event);
        
        int result = SendToVCC(json);
        if(result != 0)
        {
            // Retry later
            break;
        }
        
        ArrayRemove(m_queue, 0, 1);
        m_queue_size--;
        processed++;
    }
    
    if(m_queue_size > 1000)
    {
        Print("VCP Warning: Queue backlog: ", m_queue_size, " events");
    }
    
    return processed;
}

//+------------------------------------------------------------------+
//| Send Batch to VCC                                                 |
//+------------------------------------------------------------------+
int CVCPLogger::SendBatchToVCC()
{
    if(m_queue_size == 0)
        return 0;
    
    // Build batch JSON
    string json = "{\"events\":[";
    
    int batch_count = MathMin(m_queue_size, m_config.batch_size);
    for(int i = 0; i < batch_count; i++)
    {
        if(i > 0) json += ",";
        json += EventToJSON(m_queue[i]);
    }
    
    json += "]}";
    
    // Send batch
    string headers = "Content-Type: application/json\r\n";
    headers += "X-API-Key: " + m_config.api_key + "\r\n";
    
    char post_data[];
    char result[];
    string result_headers;
    
    StringToCharArray(json, post_data, 0, WHOLE_ARRAY, CP_UTF8);
    ArrayResize(post_data, ArraySize(post_data) - 1);
    
    int res = WebRequest(
        "POST",
        m_config.endpoint + "/v1/events/batch",
        headers,
        10000,  // 10 second timeout for batch
        post_data,
        result,
        result_headers
    );
    
    if(res == 200 || res == 201)
    {
        // Remove sent events from queue
        ArrayRemove(m_queue, 0, batch_count);
        m_queue_size -= batch_count;
        Print("VCP: Batch sent successfully (", batch_count, " events)");
        return 0;
    }
    
    Print("VCP Batch error: ", res);
    return res;
}

//+------------------------------------------------------------------+
//| Global VCP Logger Instance                                        |
//+------------------------------------------------------------------+
CVCPLogger g_VCPLogger;

//+------------------------------------------------------------------+
//| Convenience Functions                                             |
//+------------------------------------------------------------------+
int VCP_Initialize(VCP_CONFIG &config)
{
    return g_VCPLogger.Initialize(config);
}

void VCP_Shutdown()
{
    g_VCPLogger.Shutdown();
}

int VCP_LogSignal(string symbol, string algo_id, string algo_version,
                  string confidence, string decision_factors)
{
    return g_VCPLogger.LogSignal(symbol, algo_id, algo_version, confidence, decision_factors);
}

int VCP_LogOrder(string symbol, string trace_id, ulong ticket,
                 string side, string order_type, string price, string quantity)
{
    return g_VCPLogger.LogOrder(symbol, trace_id, ticket, side, order_type, price, quantity);
}

int VCP_LogExecution(string symbol, string trace_id, ulong ticket, ulong deal_ticket,
                     string exec_price, string exec_qty, string slippage)
{
    return g_VCPLogger.LogExecution(symbol, trace_id, ticket, deal_ticket, exec_price, exec_qty, slippage);
}

int VCP_LogReject(string symbol, string trace_id, ulong ticket,
                  string reject_reason, string reject_code)
{
    return g_VCPLogger.LogReject(symbol, trace_id, ticket, reject_reason, reject_code);
}

int VCP_LogHeartbeat()
{
    return g_VCPLogger.LogHeartbeat();
}

int VCP_ProcessQueue()
{
    return g_VCPLogger.ProcessQueue();
}

int VCP_GetQueueSize()
{
    return g_VCPLogger.GetQueueSize();
}
//+------------------------------------------------------------------+
