# VCP MQL5 Bridge

**VCP v1.0 Compliant MQL5 Implementation**

[![License: CC BY 4.0](https://img.shields.io/badge/License-CC%20BY%204.0-lightgrey.svg)](https://creativecommons.org/licenses/by/4.0/)
[![MQL5](https://img.shields.io/badge/MQL5-MetaTrader%205-blue.svg)](https://www.mql5.com/)
[![VCP v1.0](https://img.shields.io/badge/VCP-v1.0-green.svg)](https://github.com/veritaschain/vcp-spec)

## Overview

This library provides a VCP v1.0 specification-compliant implementation for generating cryptographically verifiable audit trails directly from MetaTrader 5 Expert Advisors (EAs).

### Features

- ✅ **VCP v1.0 Compliant** - Full specification compliance
- ✅ **UUID v7 (RFC 9562)** - Timestamp-ordered unique identifiers
- ✅ **3-Layer Event Structure** - header / payload / security
- ✅ **SHA-256 Hash Chain** - Tamper-evident audit trail
- ✅ **GDPR Compliant** - Account ID pseudonymization
- ✅ **Async Queue** - Non-blocking event transmission
- ✅ **Batch Processing** - Efficient network usage

## Installation

### Method 1: Direct Download

1. Download `vcp_mql_bridge_v1_0.mqh`
2. Copy to `MQL5/Include/VCP/` directory
3. Restart MetaEditor

### Method 2: Git Clone

```bash
cd "C:\Users\YourUser\AppData\Roaming\MetaQuotes\Terminal\XXXX\MQL5\Include"
git clone https://github.com/veritaschain/vcp-sidecar-guide.git
```

## Quick Start

```mql5
#include <VCP/vcp_mql_bridge_v1_0.mqh>

input string VCP_API_KEY = "";           // API Key (DO NOT hardcode)
input string VCP_ENDPOINT = "https://api.veritaschain.org";
input string VCP_VENUE_ID = "MY_PROP_FIRM";

int OnInit()
{
    VCP_CONFIG config;
    config.api_key = VCP_API_KEY;
    config.endpoint = VCP_ENDPOINT;
    config.venue_id = VCP_VENUE_ID;
    config.tier = VCP_TIER_SILVER;
    config.async_mode = true;
    config.queue_max_size = 10000;
    config.batch_size = 100;
    
    if(VCP_Initialize(config) != 0)
    {
        Print("VCP initialization failed");
        return INIT_FAILED;
    }
    
    EventSetTimer(1);  // Process queue every 1 second
    return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
    VCP_Shutdown();
}

void OnTimer()
{
    VCP_ProcessQueue();
    
    // Optional: Send heartbeat every 60 seconds
    static datetime last_heartbeat = 0;
    if(TimeCurrent() - last_heartbeat >= 60)
    {
        VCP_LogHeartbeat();
        last_heartbeat = TimeCurrent();
    }
}
```

## Usage Examples

### Signal Generation (SIG)

```mql5
void OnSignal()
{
    string decision_factors = "[";
    decision_factors += "{\"name\":\"RSI\",\"weight\":\"0.3\",\"value\":\"" + DoubleToString(rsi_value, 2) + "\"},";
    decision_factors += "{\"name\":\"MACD\",\"weight\":\"0.25\",\"value\":\"positive\"}";
    decision_factors += "]";
    
    VCP_LogSignal(
        _Symbol,                    // Symbol
        "MY_EA_V2",                 // Algorithm ID
        "2.1.0",                    // Version
        "0.85",                     // Confidence
        decision_factors            // Decision factors (JSON array)
    );
}
```

### Order Submission (ORD)

```mql5
void OnOrderSend()
{
    string trace_id = g_VCPLogger.GenerateUUIDv7();  // Create new trace
    
    MqlTradeRequest request;
    MqlTradeResult result;
    // ... setup request ...
    
    if(OrderSend(request, result))
    {
        VCP_LogOrder(
            _Symbol,
            trace_id,
            result.order,
            "BUY",
            "LIMIT",
            DoubleToString(request.price, _Digits),
            DoubleToString(request.volume, 2)
        );
        
        // Store trace_id for later events
        GlobalVariableSet("VCP_TRACE_" + IntegerToString(result.order), StringToDouble(trace_id));
    }
}
```

### Execution (EXE)

```mql5
void OnTradeTransaction(const MqlTradeTransaction& trans,
                        const MqlTradeRequest& request,
                        const MqlTradeResult& result)
{
    if(trans.type == TRADE_TRANSACTION_DEAL_ADD)
    {
        string trace_id = GetTraceIdForOrder(trans.order);
        double expected_price = GetExpectedPrice(trans.order);
        double slippage = MathAbs(trans.price - expected_price);
        
        VCP_LogExecution(
            trans.symbol,
            trace_id,
            trans.order,
            trans.deal,
            DoubleToString(trans.price, _Digits),
            DoubleToString(trans.volume, 2),
            DoubleToString(slippage, _Digits)
        );
    }
}
```

### Rejection (REJ)

```mql5
void OnOrderRejected(ulong ticket, int error_code)
{
    string trace_id = GetTraceIdForOrder(ticket);
    
    VCP_LogReject(
        _Symbol,
        trace_id,
        ticket,
        ErrorDescription(error_code),
        IntegerToString(error_code)
    );
}
```

## API Reference

### Configuration

```mql5
struct VCP_CONFIG
{
    string api_key;           // VCC API key
    string endpoint;          // VCC endpoint URL
    string venue_id;          // Your venue identifier
    ENUM_VCP_TIER tier;       // VCP_TIER_SILVER / GOLD / PLATINUM
    bool async_mode;          // Enable async queue
    int queue_max_size;       // Max events in queue (default: 10000)
    int batch_size;           // Events per batch (default: 100)
    int retry_count;          // Retry attempts (default: 3)
};
```

### Functions

| Function | Description |
|----------|-------------|
| `VCP_Initialize(config)` | Initialize VCP logger |
| `VCP_Shutdown()` | Graceful shutdown |
| `VCP_LogSignal(...)` | Log SIG event |
| `VCP_LogOrder(...)` | Log ORD event |
| `VCP_LogExecution(...)` | Log EXE event |
| `VCP_LogReject(...)` | Log REJ event |
| `VCP_LogHeartbeat()` | Log HBT event |
| `VCP_ProcessQueue()` | Process async queue |
| `VCP_GetQueueSize()` | Get pending events |

### Event Type Codes

| Code | Type | Description |
|------|------|-------------|
| 1 | SIG | Signal/Decision |
| 2 | ORD | Order sent |
| 3 | ACK | Order acknowledged |
| 4 | EXE | Full execution |
| 5 | PRT | Partial fill |
| 6 | REJ | Order rejected |
| 7 | CXL | Order cancelled |
| 98 | HBT | Heartbeat |

## MetaTrader Setup

### Allow WebRequest

1. Open MetaTrader 5
2. Go to **Tools** → **Options** → **Expert Advisors**
3. Enable **Allow WebRequest for listed URL**
4. Add: `https://api.veritaschain.org`

### Input Parameters

**⚠️ Security Warning:** Never hardcode API keys in source code.

```mql5
input string VCP_API_KEY = "";  // Set via input, not in code
```

## Event Structure (VCP v1.0)

```json
{
  "header": {
    "event_id": "019b591b-ea7e-7507-...",
    "trace_id": "019b591b-ea7e-7f6f-...",
    "timestamp_int": "1766726560382246912",
    "timestamp_iso": "2025-12-26T05:22:40.382Z",
    "event_type": "ORD",
    "event_type_code": 2,
    "timestamp_precision": "MILLISECOND",
    "clock_sync_status": "BEST_EFFORT",
    "hash_algo": "SHA256",
    "venue_id": "MY_PROP_FIRM",
    "symbol": "XAUUSD",
    "account_id": "acc_ca1ee1d09effaa36"
  },
  "payload": {
    "trade_data": {
      "order_id": "12345",
      "side": "BUY",
      "order_type": "LIMIT",
      "price": "2650.50",
      "quantity": "1.00"
    }
  },
  "security": {
    "event_hash": "a94a8cf1...",
    "prev_hash": "1caae2ed..."
  }
}
```

## Troubleshooting

### Common Issues

| Error | Cause | Solution |
|-------|-------|----------|
| `WebRequest failed: 4060` | URL not allowed | Add URL to Expert Advisors settings |
| `WebRequest failed: 5203` | Network error | Check internet connection |
| `Queue full` | Too many events | Increase `queue_max_size` or `batch_size` |

### Debug Mode

```mql5
// Enable verbose logging
#define VCP_DEBUG_MODE
#include <VCP/vcp_mql_bridge_v1_0.mqh>
```

## License

CC BY 4.0 International

Copyright © 2025 VeritasChain Standards Organization (VSO)

## Resources

- [VCP Specification](https://github.com/veritaschain/vcp-spec)
- [Integration Guide](../VCP_SIDECAR_INTEGRATION_GUIDE_EN.md)
- [VSO Website](https://veritaschain.org)
- [Support](mailto:support@veritaschain.org)
