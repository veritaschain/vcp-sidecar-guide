# VCP Sidecar Integration Guide
## Silver Tier Technical Guide v1.0

**Document ID:** VSO-TECH-SIG-001  
**Status:** Production Ready  
**Category:** Implementation Guide / Silver Tier  
**Date:** 2025-11-25  
**Maintainer:** VeritasChain Standards Organization (VSO)  
**License:** CC BY 4.0 International

---

## Table of Contents

1. [Overview](#1-overview)
   - 1.1 [Purpose of This Guide](#11-purpose-of-this-guide)
   - 1.2 [Target Audience](#12-target-audience)
   - 1.3 [Prerequisites](#13-prerequisites)
   - 1.4 [Terminology](#14-terminology)
2. [Architecture](#2-architecture)
   - 2.1 [Sidecar Integration Concept](#21-sidecar-integration-concept)
   - 2.2 [Data Flow](#22-data-flow)
   - 2.3 [Why Sidecar Integration](#23-why-sidecar-integration)
3. [Integration Patterns](#3-integration-patterns)
   - 3.1 [Pattern A: Direct EA/Indicator Integration](#31-pattern-a-direct-eaindicator-integration)
   - 3.2 [Pattern B: Manager API Integration](#32-pattern-b-manager-api-integration)
   - 3.3 [Pattern C: Hybrid Integration (Recommended)](#33-pattern-c-hybrid-integration-recommended)
4. [vcp-mql-bridge Implementation Guide](#4-vcp-mql-bridge-implementation-guide)
   - 4.1 [Overview](#41-overview)
   - 4.2 [Installation](#42-installation)
   - 4.3 [Basic Usage](#43-basic-usage)
   - 4.4 [Advanced Configuration](#44-advanced-configuration)
5. [Manager API Integration](#5-manager-api-integration)
   - 5.1 [Overview](#51-overview)
   - 5.2 [Polling Architecture](#52-polling-architecture)
   - 5.3 [Implementation Example (Python)](#53-implementation-example-python)
   - 5.4 [Event Transformation](#54-event-transformation)
6. [Two-Layer Logging Architecture](#6-two-layer-logging-architecture)
   - 6.1 [Architecture Overview](#61-architecture-overview)
   - 6.2 [Layer 1: EA Hook](#62-layer-1-ea-hook)
   - 6.3 [Layer 2: Manager API Poller](#63-layer-2-manager-api-poller)
   - 6.4 [Event Correlator](#64-event-correlator)
   - 6.5 [Data Flow Sequence](#65-data-flow-sequence)
7. [VCP Explorer API Integration](#7-vcp-explorer-api-integration)
   - 7.1 [Overview](#71-overview)
   - 7.2 [API Endpoints](#72-api-endpoints)
   - 7.3 [Event Query Parameters](#73-event-query-parameters)
   - 7.4 [Authentication](#74-authentication)
   - 7.5 [Rate Limiting](#75-rate-limiting)
8. [Disconnection Detection and Recovery](#8-disconnection-detection-and-recovery)
   - 8.1 [Connection Monitoring](#81-connection-monitoring)
   - 8.2 [Local Event Queue](#82-local-event-queue)
   - 8.3 [Automatic Reconnection](#83-automatic-reconnection)
   - 8.4 [Recovery Event (REC)](#84-recovery-event-rec)
9. [Silver Tier Technical Requirements](#9-silver-tier-technical-requirements)
   - 9.1 [Mandatory Requirements](#91-mandatory-requirements)
   - 9.2 [Optional Requirements](#92-optional-requirements)
   - 9.3 [Numeric Precision Requirements](#93-numeric-precision-requirements)
   - 9.4 [Event Type Codes (Silver Tier)](#94-event-type-codes-silver-tier)
10. [Security Considerations](#10-security-considerations)
    - 10.1 [API Key Management](#101-api-key-management)
    - 10.2 [Data Pseudonymization](#102-data-pseudonymization)
    - 10.3 [Communication Security](#103-communication-security)
    - 10.4 [Local Cache Protection](#104-local-cache-protection)
11. [Troubleshooting](#11-troubleshooting)
    - 11.1 [Common Issues and Solutions](#111-common-issues-and-solutions)
    - 11.2 [Debug Mode](#112-debug-mode)
    - 11.3 [Health Check Endpoint](#113-health-check-endpoint)
12. [Appendices](#12-appendices)
    - [Appendix A: Complete VCP Event Schema](#appendix-a-complete-vcp-event-schema)
    - [Appendix B: Checklists](#appendix-b-checklists)
    - [Appendix C: Related Documents](#appendix-c-related-documents)

---

## 1. Overview

### 1.1 Purpose of This Guide

This guide defines the technical specifications for implementing the VeritasChain Protocol (VCP) in **environments without server administrator privileges** (white-label platforms, MT4/MT5 rental servers, etc.).

**"Sidecar Integration"** is a non-invasive integration approach that allows VCP logging systems to operate in parallel with existing trading infrastructure without requiring modifications.

**Formal Definition:**
- **VCC (VeritasChain Cloud)**: The official cloud-based implementation platform of VCP, providing Logging API, Explorer API, and delegated signature services for Silver Tier participants.

### 1.2 Target Audience

- Technical Directors of Proprietary Trading Firms (Prop Firms)
- System Administrators of White-Label Brokers
- MT4/MT5 Platform Operators
- cTrader Environment Administrators
- Organizations seeking VCP Silver Tier Certification

### 1.3 Prerequisites

| Requirement | Details |
|-------------|---------|
| Platform | MT4/MT5, cTrader, or equivalent FX platform |
| Server Access | Server administrator privileges **NOT required** |
| Network | Outbound HTTPS/WSS connectivity required |
| Development Environment | MQL5, Python 3.8+, or Node.js 18+ |

### 1.4 Terminology

| Term | Definition |
|------|------------|
| **Sidecar** | An independent component that operates in parallel with an existing system |
| **White-Label (WL)** | A business model where servers are rented from external providers |
| **Manager API** | MT4/MT5 server management API (read-only access available) |
| **vcp-mql-bridge** | A bridge library for VCP logging from MQL5 |
| **Delegated Signature** | Signature method used in Silver Tier, processed via VSO or VCC |
| **VCC** | VeritasChain Cloud - Official cloud platform providing VCP implementation infrastructure |

---

## 2. Architecture

### 2.1 Sidecar Integration Concept

```
┌─────────────────────────────────────────────────────────────┐
│                     Trading Platform                         │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐          │
│  │   MT4/MT5   │  │   cTrader   │  │  Proprietary│          │
│  │   Server    │  │   Server    │  │   Platform  │          │
│  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘          │
│         │                │                │                  │
│         │    [Server Administrator Privilege Boundary]       │
│         │                │                │                  │
└─────────┼────────────────┼────────────────┼──────────────────┘
          │                │                │
          ▼                ▼                ▼
    ┌─────────────────────────────────────────────┐
    │           VCP Sidecar Layer                 │
    │  ┌───────────────────────────────────────┐  │
    │  │         vcp-mql-bridge                │  │
    │  │  • Event capture from EA/Indicator    │  │
    │  │  • Trade data fetch via Manager API   │  │
    │  │  • Asynchronous queueing              │  │
    │  └───────────────────────────────────────┘  │
    │                      │                      │
    │                      ▼                      │
    │  ┌───────────────────────────────────────┐  │
    │  │         VCP Local Logger              │  │
    │  │  • Event generation (VCP-CORE)        │  │
    │  │  • Hash chain construction            │  │
    │  │  • Local cache                        │  │
    │  └───────────────────────────────────────┘  │
    └──────────────────────┬──────────────────────┘
                           │
                           ▼
    ┌─────────────────────────────────────────────┐
    │           VeritasChain Cloud (VCC)          │
    │  ┌───────────────────────────────────────┐  │
    │  │         VCP Logging API               │  │
    │  │  • Delegated signature (Ed25519)      │  │
    │  │  • Merkle tree construction           │  │
    │  │  • Blockchain anchoring               │  │
    │  └───────────────────────────────────────┘  │
    │                      │                      │
    │                      ▼                      │
    │  ┌───────────────────────────────────────┐  │
    │  │         VCP Explorer API              │  │
    │  │  • Verification dashboard             │  │
    │  │  • Merkle proof provisioning          │  │
    │  │  • Certificate issuance               │  │
    │  └───────────────────────────────────────┘  │
    └─────────────────────────────────────────────┘
```

### 2.2 Data Flow

```
[Trading Event Occurs]
        │
        ▼
┌───────────────────┐
│ 1. Event Capture  │ ← vcp-mql-bridge / Manager API
└─────────┬─────────┘
          │
          ▼
┌───────────────────┐
│ 2. Local Process  │
│ • UUID v7 gen     │
│ • Timestamp       │
│ • JSON construct  │
│ • Local hash      │
└─────────┬─────────┘
          │
          ▼
┌───────────────────┐
│ 3. Async Send     │ ← Queueing (fault tolerance)
└─────────┬─────────┘
          │
          ▼
┌───────────────────┐
│ 4. VCC Process    │
│ • Signature verify│
│ • Chain append    │
│ • Merkle tree     │
└─────────┬─────────┘
          │
          ▼
┌───────────────────┐
│ 5. Anchor         │ ← Every 24 hours (Silver Tier)
└───────────────────┘
```

### 2.3 Why Sidecar Integration

| Challenge | Sidecar Integration Solution |
|-----------|------------------------------|
| No server privileges | No plugin installation required, operates client-side only |
| Impact on existing systems | Operates completely independently, no changes to production |
| Multi-platform support | Unified API for different platforms |
| Gradual adoption | Start with small PoC, expand incrementally |
| Vendor lock-in avoidance | Standards-compliant protocol, easy migration |

---

## 3. Integration Patterns

Three integration patterns are available for Silver Tier environments.

### 3.1 Pattern A: Direct EA/Indicator Integration

**Use Case:** When using self-developed EA/Indicators

```
┌─────────────────────────────────────┐
│           MT4/MT5 Terminal          │
│  ┌─────────────────────────────┐    │
│  │      Expert Advisor         │    │
│  │  ┌───────────────────────┐  │    │
│  │  │   Trading Logic       │  │    │
│  │  └──────────┬────────────┘  │    │
│  │             │               │    │
│  │  ┌──────────▼────────────┐  │    │
│  │  │   vcp-mql-bridge      │──┼────┼──▶ VCC API
│  │  │   (Integration Lib)   │  │    │
│  │  └───────────────────────┘  │    │
│  └─────────────────────────────┘    │
└─────────────────────────────────────┘
```

**Advantages:**
- Real-time event capture
- Complete lifecycle recording from signal (SIG) to execution (EXE)
- Detailed VCP-GOV (algorithm information) recording

**Disadvantages:**
- EA source code modification required
- Integration needed per EA

### 3.2 Pattern B: Manager API Integration

**Use Case:** When existing EAs cannot be modified, or batch management of multiple EAs

```
┌─────────────────────────────────────┐
│           MT4/MT5 Server            │
│  ┌─────────────────────────────┐    │
│  │      Trading Database       │    │
│  │   (Orders, Executions, etc) │    │
│  └──────────┬──────────────────┘    │
│             │ Manager API (Read-only)│
└─────────────┼───────────────────────┘
              │
              ▼
┌─────────────────────────────────────┐
│        VCP Sidecar Service          │
│  ┌─────────────────────────────┐    │
│  │   Manager API Poller        │    │
│  │   • Trade history polling   │    │
│  │   • Delta detection         │    │
│  │   • VCP event transform     │    │
│  └──────────┬──────────────────┘    │
│             │                       │
│  ┌──────────▼──────────────────┐    │
│  │   VCP Event Generator       │────┼──▶ VCC API
│  └─────────────────────────────┘    │
└─────────────────────────────────────┘
```

**Advantages:**
- No EA source code modification required
- Batch capture of all trades
- No server plugin installation needed (via Manager API)

**Disadvantages:**
- Cannot capture SIG events (signal generation)
- Latency due to polling interval
- Requires Manager API access privileges

### 3.3 Pattern C: Hybrid Integration (Recommended)

**Use Case:** When maximum audit trail coverage is required

```
┌──────────────────────────────────────────────────────────┐
│                  MT4/MT5 Environment                     │
│                                                          │
│  ┌─────────────────────┐    ┌─────────────────────┐     │
│  │   Expert Advisor    │    │   MT4/MT5 Server    │     │
│  │   (with VCP hook)   │    │                     │     │
│  │         │           │    │                     │     │
│  │   ┌─────▼─────┐     │    │   ┌─────────────┐   │     │
│  │   │ SIG Event │     │    │   │ Trade Data  │   │     │
│  │   │ VCP-GOV   │     │    │   │ ORD/ACK/EXE │   │     │
│  │   └─────┬─────┘     │    │   └──────┬──────┘   │     │
│  └─────────┼───────────┘    └──────────┼──────────┘     │
│            │                           │                │
│            │    ┌──────────────────────┘                │
│            │    │ Manager API                           │
│            ▼    ▼                                       │
│  ┌─────────────────────────────────────────────────┐    │
│  │            VCP Sidecar Service                  │    │
│  │  ┌───────────────────┐ ┌───────────────────┐    │    │
│  │  │ Layer 1: EA Hook  │ │ Layer 2: Manager  │    │    │
│  │  │ • SIG events      │ │ • ORD/ACK/EXE     │    │    │
│  │  │ • VCP-GOV data    │ │ • VCP-TRADE data  │    │    │
│  │  └─────────┬─────────┘ └─────────┬─────────┘    │    │
│  │            │                     │              │    │
│  │            └──────────┬──────────┘              │    │
│  │                       ▼                         │    │
│  │  ┌─────────────────────────────────────────┐    │    │
│  │  │         Event Correlator                │    │    │
│  │  │   • Correlation via TraceID             │    │    │
│  │  │   • Deduplication                       │    │    │
│  │  │   • Time-series consistency check       │    │    │
│  │  └───────────────────┬─────────────────────┘    │    │
│  └──────────────────────┼──────────────────────────┘    │
└─────────────────────────┼──────────────────────────────┘
                          │
                          ▼
                    VeritasChain Cloud
```

**Advantages:**
- Complete event lifecycle recording
- Both algorithm information (VCP-GOV) and trade data (VCP-TRADE)
- Loss prevention through redundancy

**Disadvantages:**
- Implementation complexity
- Event deduplication processing required

---

## 4. vcp-mql-bridge Implementation Guide

### 4.1 Overview

`vcp-mql-bridge` is a bridge library for generating and transmitting VCP events from MQL5.

### 4.2 Installation

**Method 1: GitHub Installation**

```bash
cd "C:\Users\YourUser\AppData\Roaming\MetaQuotes\Terminal\XXXX\MQL5\Include"
git clone https://github.com/veritaschain/vcp-mql-bridge.git VCP
```

**Method 2: Manual Installation**

1. Download the latest release from [Releases](https://github.com/veritaschain/vcp-mql-bridge/releases)
2. Extract to `MQL5/Include/VCP` directory
3. Restart MetaEditor

### 4.3 Basic Usage

**Step 1: Import Library**

```mql5
#include <VCP/VCPLogger.mqh>
```

**Step 2: Initialize**

```mql5
input string VCC_API_KEY = "";  // Set via input parameter (DO NOT hardcode)
input string VCC_ENDPOINT = "https://vcc.veritaschain.org/api/v1";

VCPLogger vcp_logger;

int OnInit()
{
    if(!vcp_logger.Initialize(VCC_API_KEY, VCC_ENDPOINT))
    {
        Print("VCP Logger initialization failed");
        return(INIT_FAILED);
    }
    return(INIT_SUCCEEDED);
}
```

**Step 3: Log Events**

```mql5
void OnTick()
{
    // Signal generation event
    if(BuySignalDetected())
    {
        string trace_id = vcp_logger.GenerateTraceID();
        
        VCPEvent sig_event;
        sig_event.event_type = VCP_EVENT_SIG;
        sig_event.trace_id = trace_id;
        sig_event.symbol = _Symbol;
        sig_event.timestamp = vcp_logger.GetCurrentTimestampMs();
        
        // Algorithm information (VCP-GOV)
        sig_event.gov_data.algo_id = "MA_CROSS_V2";
        sig_event.gov_data.version = "2.1.0";
        sig_event.gov_data.decision_factors = "MA_FAST=50,MA_SLOW=200,CROSS_UP";
        
        vcp_logger.LogEvent(sig_event);
        
        // Order submission
        int ticket = OrderSend(_Symbol, OP_BUY, 0.1, Ask, 3, 0, 0);
        
        if(ticket > 0)
        {
            VCPEvent ord_event;
            ord_event.event_type = VCP_EVENT_ORD;
            ord_event.trace_id = trace_id;  // Same TraceID for lifecycle tracking
            ord_event.trade_data.order_id = IntegerToString(ticket);
            ord_event.trade_data.side = "BUY";
            ord_event.trade_data.quantity = "0.1";
            ord_event.trade_data.price = DoubleToString(Ask, _Digits);
            
            vcp_logger.LogEvent(ord_event);
        }
    }
}
```

### 4.4 Advanced Configuration

**Asynchronous Queue Configuration**

```mql5
VCPConfig config;
config.async_mode = true;
config.queue_size = 1000;
config.batch_size = 50;
config.batch_interval_ms = 1000;
config.retry_count = 3;
config.retry_delay_ms = 500;

vcp_logger.Configure(config);
```

**Local Cache (Disconnection Recovery)**

```mql5
config.enable_local_cache = true;
config.cache_file_path = "VCP_cache_" + IntegerToString(AccountNumber()) + ".json";
config.max_cache_size_mb = 10;
```

**Heartbeat Configuration**

```mql5
config.enable_heartbeat = true;
config.heartbeat_interval_sec = 60;
```

---

## 5. Manager API Integration

### 5.1 Overview

Manager API integration enables VCP event generation without EA modification by polling trade data from MT4/MT5 servers.

**Key Point:** Silver Tier uses simplified key management through **delegated signature** processing by VCC. Private key management is not required.

### 5.2 Polling Architecture

```
┌────────────────────────────────────────┐
│         MT4/MT5 Server                 │
│  ┌──────────────────────────────┐      │
│  │   Manager API                │      │
│  │   • GetOrders()              │      │
│  │   • GetTrades()              │      │
│  │   • GetHistory()             │      │
│  └──────────┬───────────────────┘      │
└─────────────┼────────────────────────┘
              │ Polling (configurable interval)
              ▼
┌────────────────────────────────────────┐
│      VCP Manager API Adapter           │
│  ┌──────────────────────────────┐      │
│  │   Polling Service            │      │
│  │   • Fetch latest data        │      │
│  │   • Delta detection          │      │
│  │   • Deduplication            │      │
│  └──────────┬───────────────────┘      │
│             │                          │
│  ┌──────────▼───────────────────┐      │
│  │   Event Transformer          │      │
│  │   • Convert to VCP format    │      │
│  │   • TraceID generation       │      │
│  │   • Timestamp normalization  │      │
│  └──────────┬───────────────────┘      │
│             │                          │
│  ┌──────────▼───────────────────┐      │
│  │   VCP Client                 │      │
│  │   • Async queue              │      │
│  │   • Local cache              │      │
│  │   • Batch transmission       │      │
│  └──────────┬───────────────────┘      │
└─────────────┼────────────────────────┘
              │
              ▼
        VeritasChain Cloud (VCC)
```

### 5.3 Implementation Example (Python)

```python
import time
import hashlib
from typing import List, Dict, Optional
from datetime import datetime
from mt5_manager_api import MT5ManagerAPI  # Pseudo library
from vcp_client import VCPClient

class ManagerAPIAdapter:
    def __init__(
        self,
        manager_api: MT5ManagerAPI,
        vcp_client: VCPClient,
        poll_interval_sec: int = 5
    ):
        self.manager_api = manager_api
        self.vcp_client = vcp_client
        self.poll_interval = poll_interval_sec
        self.last_order_time = 0
        self.processed_orders = set()  # Deduplication
    
    def start(self):
        """Start polling loop"""
        print("Starting Manager API polling...")
        
        while True:
            try:
                self._poll_and_process()
                time.sleep(self.poll_interval)
            except KeyboardInterrupt:
                print("Polling stopped")
                break
            except Exception as e:
                print(f"Error during polling: {e}")
                time.sleep(self.poll_interval * 2)  # Backoff
    
    def _poll_and_process(self):
        """Fetch and process new trades"""
        # Fetch trades since last polling
        trades = self.manager_api.get_trades_since(self.last_order_time)
        
        for trade in trades:
            # Deduplication check
            order_id = trade['ticket']
            if order_id in self.processed_orders:
                continue
            
            # Convert to VCP events
            vcp_events = self._transform_trade_to_vcp(trade)
            
            # Submit to VCC
            for event in vcp_events:
                self.vcp_client.log_event(event)
            
            # Mark as processed
            self.processed_orders.add(order_id)
            self.last_order_time = max(
                self.last_order_time,
                trade['open_time']
            )
    
    def _transform_trade_to_vcp(self, trade: Dict) -> List[Dict]:
        """Convert Manager API trade data to VCP events"""
        events = []
        trace_id = self._generate_trace_id(trade)
        
        # ORD Event
        ord_event = {
            "event_type": 2,  # VCP_EVENT_ORD
            "trace_id": trace_id,
            "timestamp": int(trade['open_time'] * 1000),
            "symbol": trade['symbol'],
            "venue_id": "MT5_SERVER_01",
            "account_id": self._pseudonymize_account(trade['login']),
            "trade_data": {
                "order_id": str(trade['ticket']),
                "side": "BUY" if trade['type'] == 0 else "SELL",
                "quantity": str(trade['volume']),
                "price": str(trade['open_price']),
                "order_type": "MARKET"
            }
        }
        events.append(ord_event)
        
        # EXE Event (immediate for market orders)
        exe_event = ord_event.copy()
        exe_event['event_type'] = 4  # VCP_EVENT_EXE
        exe_event['trade_data']['exec_price'] = str(trade['open_price'])
        exe_event['trade_data']['exec_quantity'] = str(trade['volume'])
        events.append(exe_event)
        
        return events
    
    def _generate_trace_id(self, trade: Dict) -> str:
        """Generate TraceID from trade data"""
        unique_str = f"{trade['ticket']}-{trade['open_time']}"
        return hashlib.sha256(unique_str.encode()).hexdigest()[:16]
    
    def _pseudonymize_account(self, login: int) -> str:
        """Pseudonymize account ID (GDPR compliant)"""
        salt = "YOUR_SECRET_SALT"  # Load from environment variable
        combined = f"{salt}:{login}"
        hashed = hashlib.sha256(combined.encode()).hexdigest()
        return f"acc_{hashed[:16]}"

# Usage
if __name__ == "__main__":
    manager_api = MT5ManagerAPI(
        server="mt5.yourbroker.com:443",
        login=12345,
        password="manager_password"
    )
    
    vcp_client = VCPClient(
        api_key="your_vcc_api_key",
        endpoint="https://vcc.veritaschain.org/api/v1"
    )
    
    adapter = ManagerAPIAdapter(
        manager_api=manager_api,
        vcp_client=vcp_client,
        poll_interval_sec=5
    )
    
    adapter.start()
```

### 5.4 Event Transformation

**Manager API → VCP Mapping**

| Manager API Field | VCP Field | Notes |
|-------------------|-----------|-------|
| ticket | trade_data.order_id | String conversion |
| symbol | symbol | As-is |
| type (0=BUY, 1=SELL) | trade_data.side | Enum conversion |
| volume | trade_data.quantity | String with precision |
| open_price | trade_data.price | String with full precision |
| open_time | timestamp | Unix ms conversion |
| sl | trade_data.stop_loss | Optional |
| tp | trade_data.take_profit | Optional |

---

## 6. Two-Layer Logging Architecture

### 6.1 Architecture Overview

The two-layer logging architecture combines EA direct integration (Layer 1) with Manager API polling (Layer 2) to ensure maximum audit trail integrity.

```
┌────────────────────────────────────────────────────────┐
│                MT4/MT5 Environment                     │
│                                                        │
│  ┌──────────────────┐          ┌──────────────────┐   │
│  │  Expert Advisor  │          │  MT5 Server      │   │
│  │  (with VCP hook) │          │  Trading DB      │   │
│  └────────┬─────────┘          └────────┬─────────┘   │
│           │                             │             │
│           │ [Layer 1: Real-time]        │ [Layer 2]   │
│           │ • SIG events                │ • ORD/EXE   │
│           │ • VCP-GOV data              │ • Polling   │
│           │                             │             │
└───────────┼─────────────────────────────┼─────────────┘
            │                             │
            └──────────┬──────────────────┘
                       │
                       ▼
            ┌──────────────────────┐
            │  Event Correlator    │
            │  • TraceID matching  │
            │  • Deduplication     │
            │  • Integrity check   │
            └──────────┬───────────┘
                       │
                       ▼
                VeritasChain Cloud
```

### 6.2 Layer 1: EA Hook

**Characteristics:**
- Real-time event capture
- SIG (signal) events available
- VCP-GOV (algorithm decision factors) recordable
- Direct integration into EA logic

**Implementation:**
```mql5
// Inside EA OnTick()
if(SignalGenerated())
{
    string trace_id = vcp_logger.GenerateTraceID();
    vcp_logger.LogSIG(trace_id, algo_info);  // Layer 1 only
    
    // Order submission
    int ticket = OrderSend(...);
    vcp_logger.LogORD(trace_id, ticket);
}
```

### 6.3 Layer 2: Manager API Poller

**Characteristics:**
- No EA modification required
- Comprehensive coverage (all trades)
- Polling-based (slight delay)
- Independent redundancy layer

**Implementation:**
```python
# Polling service (separate process)
while True:
    new_trades = manager_api.get_new_trades()
    for trade in new_trades:
        vcp_client.log_event(transform_to_vcp(trade))
    time.sleep(polling_interval)
```

### 6.4 Event Correlator

The Event Correlator is responsible for:

1. **TraceID-based Correlation**
   - Links events from Layer 1 (SIG) and Layer 2 (ORD/EXE)
   - Constructs complete lifecycle chains

2. **Deduplication**
   - Detects identical events from both layers
   - Keeps the earlier timestamp

3. **Gap Detection**
   - Identifies missing events
   - Triggers alerts for audit review

4. **Sequence Validation**
   - Enforces event ordering rules: SIG → ORD → ACK → EXE
   - Flags out-of-order events

**Implementation Example:**

```python
class EventCorrelator:
    def __init__(self):
        self.event_buffer = {}  # trace_id -> [events]
        self.seen_event_ids = set()
    
    def process_event(self, event: Dict) -> Optional[Dict]:
        """
        Process incoming event with deduplication and correlation
        
        Returns:
            Event to forward, or None if duplicate
        """
        event_id = event['event_id']
        trace_id = event.get('trace_id')
        
        # Deduplication
        if event_id in self.seen_event_ids:
            print(f"Duplicate event detected: {event_id}")
            return None
        
        self.seen_event_ids.add(event_id)
        
        # Store in buffer for correlation
        if trace_id:
            if trace_id not in self.event_buffer:
                self.event_buffer[trace_id] = []
            self.event_buffer[trace_id].append(event)
            
            # Check for complete chain
            if self._is_chain_complete(trace_id):
                self._validate_chain(trace_id)
        
        return event
    
    def _is_chain_complete(self, trace_id: str) -> bool:
        """Check if event chain is complete"""
        events = self.event_buffer[trace_id]
        event_types = {e['event_type'] for e in events}
        
        # Minimum chain: ORD + EXE
        return 2 in event_types and 4 in event_types
    
    def _validate_chain(self, trace_id: str):
        """Validate event sequence"""
        events = sorted(
            self.event_buffer[trace_id],
            key=lambda e: e['timestamp']
        )
        
        event_sequence = [e['event_type'] for e in events]
        
        # Valid sequences
        valid_sequences = [
            [1, 2, 4],     # SIG → ORD → EXE
            [1, 2, 3, 4],  # SIG → ORD → ACK → EXE
            [2, 4],        # ORD → EXE (Manager API only)
            [2, 3, 4],     # ORD → ACK → EXE (Manager API)
        ]
        
        if event_sequence not in valid_sequences:
            print(f"⚠️  Invalid sequence for {trace_id}: {event_sequence}")
```

### 6.5 Data Flow Sequence

**Sequence Diagram: Two-Layer Logging with Correlation**

```
EA (Layer 1)          Manager API (Layer 2)     Event Correlator        VCC
     │                        │                         │                │
     │  1. Signal Generated   │                         │                │
     ├─────[SIG]──────────────┼─────────────────────────>                │
     │                        │                         │                │
     │  2. Order Submitted    │                         │                │
     ├─────[ORD]──────────────┼─────────────────────────>                │
     │                        │                         │                │
     │                        │  3. Polls trade DB      │                │
     │                        ├─────[ORD]───────────────>                │
     │                        │                         │ (Deduplicate)  │
     │                        │                         │ (Discard)      │
     │                        │                         │                │
     │  4. Order Acknowledged │                         │                │
     ├─────[ACK]──────────────┼─────────────────────────>                │
     │                        │                         │                │
     │  5. Execution          │                         │                │
     ├─────[EXE]──────────────┼─────────────────────────>────────────────>
     │                        │                         │                │
     │                        │  6. Polls execution     │                │
     │                        ├─────[EXE]───────────────>                │
     │                        │                         │ (Deduplicate)  │
     │                        │                         │ (Discard)      │
     │                        │                         │                │
     │                        │                         │  7. Validate   │
     │                        │                         │     Chain      │
     │                        │                         │  ✓ Complete    │
```

**Key Points:**
- Layer 1 provides real-time SIG, ORD, ACK, EXE events
- Layer 2 provides redundant ORD, EXE events via polling
- Event Correlator deduplicates by event_id
- Complete chains are validated: SIG → ORD → [ACK] → EXE
- Only unique events are forwarded to VCC

---

## 7. VCP Explorer API Integration

### 7.1 Overview

VCP Explorer API provides verification, querying, and proof generation capabilities for logged events.

**Base URL:**
```
https://explorer.veritaschain.org/api/v1
```

### 7.2 API Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/events` | GET | Query events |
| `/events/{event_id}` | GET | Get specific event |
| `/traces/{trace_id}` | GET | Get event chain by TraceID |
| `/merkle/proof/{event_id}` | GET | Get Merkle proof |
| `/merkle/verify` | POST | Verify Merkle proof |
| `/health` | GET | API health check |
| `/stats` | GET | Statistics |

### 7.3 Event Query Parameters

The `/events` endpoint supports the following query parameters:

| Parameter | Type | Description | Example |
|-----------|------|-------------|---------|
| `trace_id` | string | Filter by TraceID | `?trace_id=abc123...` |
| `symbol` | string | Filter by trading symbol | `?symbol=EURUSD` |
| `event_type_code` | integer | Filter by event type | `?event_type_code=4` (EXE) |
| `venue_id` | string | Filter by venue | `?venue_id=MT5_SERVER_01` |
| `account_id` | string | Filter by account (pseudonymized) | `?account_id=acc_1a2b3c...` |
| `start_time` | integer | Start timestamp (Unix ms) | `?start_time=1700000000000` |
| `end_time` | integer | End timestamp (Unix ms) | `?end_time=1700086400000` |
| `limit` | integer | Max results (1-1000) | `?limit=100` |
| `offset` | integer | Pagination offset | `?offset=100` |
| `sort` | string | Sort order (`asc` or `desc`) | `?sort=desc` |

**Query Example:**

```bash
# Get all executions for EURUSD in the last 24 hours
curl -X GET "https://explorer.veritaschain.org/api/v1/events?\
event_type_code=4&\
symbol=EURUSD&\
start_time=1700000000000&\
end_time=1700086400000&\
limit=100" \
-H "Authorization: Bearer YOUR_API_KEY"
```

### 7.4 Authentication

```bash
# API Key in Authorization header
curl -X GET "https://explorer.veritaschain.org/api/v1/events" \
  -H "Authorization: Bearer YOUR_VCC_API_KEY"
```

### 7.5 Rate Limiting

| Tier | Rate Limit | Burst Limit |
|------|-----------|-------------|
| Silver | 100 req/min | 200 req/min |
| Gold | 500 req/min | 1000 req/min |
| Platinum | 2000 req/min | 5000 req/min |

**Rate Limit Headers:**
```
X-RateLimit-Limit: 100
X-RateLimit-Remaining: 95
X-RateLimit-Reset: 1700000060
```

---

## 8. Disconnection Detection and Recovery

### 8.1 Connection Monitoring

**Heartbeat Implementation:**

```python
import time
import threading
from typing import Callable

class ConnectionMonitor:
    def __init__(
        self,
        vcp_client,
        heartbeat_interval: int = 60,
        timeout_threshold: int = 180
    ):
        self.vcp_client = vcp_client
        self.heartbeat_interval = heartbeat_interval
        self.timeout_threshold = timeout_threshold
        self.last_success_time = time.time()
        self.is_connected = True
        self.monitor_thread = None
    
    def start(self):
        """Start connection monitoring"""
        self.monitor_thread = threading.Thread(
            target=self._monitor_loop,
            daemon=True
        )
        self.monitor_thread.start()
    
    def _monitor_loop(self):
        """Continuous monitoring loop"""
        while True:
            try:
                # Send heartbeat
                response = self.vcp_client.send_heartbeat()
                
                if response.status_code == 200:
                    self.last_success_time = time.time()
                    self.is_connected = True
                else:
                    self._handle_heartbeat_failure()
                
            except Exception as e:
                print(f"Heartbeat error: {e}")
                self._handle_heartbeat_failure()
            
            time.sleep(self.heartbeat_interval)
    
    def _handle_heartbeat_failure(self):
        """Handle heartbeat failure"""
        time_since_success = time.time() - self.last_success_time
        
        if time_since_success > self.timeout_threshold:
            if self.is_connected:
                print("⚠️  VCC connection lost")
                self.is_connected = False
                self.vcp_client.enable_offline_mode()
    
    def get_status(self) -> dict:
        """Get current connection status"""
        return {
            "connected": self.is_connected,
            "last_success": self.last_success_time,
            "uptime_seconds": time.time() - self.last_success_time
        }
```

### 8.2 Local Event Queue

**Offline Queue with Persistence:**

```python
import json
import queue
import os
from typing import Dict, List

class PersistentEventQueue:
    def __init__(
        self,
        cache_file: str = "vcp_event_queue.json",
        max_size: int = 10000
    ):
        self.cache_file = cache_file
        self.max_size = max_size
        self.queue = queue.Queue(maxsize=max_size)
        self._load_from_disk()
    
    def enqueue(self, event: Dict):
        """Add event to queue"""
        try:
            self.queue.put_nowait(event)
            self._persist_to_disk()
        except queue.Full:
            print("⚠️  Event queue full, oldest event dropped")
            self.queue.get()  # Drop oldest
            self.queue.put(event)
            self._persist_to_disk()
    
    def dequeue(self) -> Dict:
        """Remove and return event from queue"""
        event = self.queue.get_nowait()
        self._persist_to_disk()
        return event
    
    def size(self) -> int:
        """Get current queue size"""
        return self.queue.qsize()
    
    def _persist_to_disk(self):
        """Save queue to disk"""
        events = list(self.queue.queue)
        with open(self.cache_file, 'w') as f:
            json.dump(events, f, indent=2)
    
    def _load_from_disk(self):
        """Load queue from disk"""
        if not os.path.exists(self.cache_file):
            return
        
        try:
            with open(self.cache_file, 'r') as f:
                events = json.load(f)
                for event in events:
                    self.queue.put(event)
            print(f"Loaded {len(events)} cached events from disk")
        except Exception as e:
            print(f"Failed to load cache: {e}")
```

### 8.3 Automatic Reconnection

**Exponential Backoff Strategy:**

```python
import time
import random

class VCPClientWithReconnect:
    def __init__(
        self,
        api_key: str,
        endpoint: str,
        max_retries: int = 10
    ):
        self.api_key = api_key
        self.endpoint = endpoint
        self.max_retries = max_retries
        self.event_queue = PersistentEventQueue()
        self.is_online = True
    
    def send_event(self, event: Dict):
        """Send event with automatic retry"""
        if not self.is_online:
            self.event_queue.enqueue(event)
            return
        
        for attempt in range(self.max_retries):
            try:
                response = self._http_post(event)
                
                if response.status_code == 200:
                    # Success - process queued events
                    self._flush_queue()
                    return
                else:
                    raise Exception(f"HTTP {response.status_code}")
                    
            except Exception as e:
                print(f"Send failed (attempt {attempt+1}): {e}")
                
                # Exponential backoff
                wait_time = min(2 ** attempt + random.uniform(0, 1), 60)
                time.sleep(wait_time)
        
        # All retries exhausted - go offline
        print("⚠️  Entering offline mode")
        self.is_online = False
        self.event_queue.enqueue(event)
    
    def _flush_queue(self):
        """Send all queued events"""
        while self.event_queue.size() > 0:
            try:
                cached_event = self.event_queue.dequeue()
                self._http_post(cached_event)
            except Exception as e:
                print(f"Failed to flush event: {e}")
                self.event_queue.enqueue(cached_event)
                break
```

### 8.4 Recovery Event (REC)

When reconnecting after a disconnection, a Recovery Event (REC) should be logged.

**Recovery Event Example:**

```python
def create_recovery_event(
    last_valid_event_id: str,
    last_valid_hash: str,
    break_timestamp: int,
    break_reason: str,
    recovered_events: int
) -> Dict:
    """
    Create a Recovery (REC) event
    
    Args:
        last_valid_event_id: Last successfully logged event ID
        last_valid_hash: Hash of last valid event
        break_timestamp: When the connection broke
        break_reason: Reason for disconnection
        recovered_events: Number of events recovered from cache
    
    Returns:
        VCP Recovery event
    """
    event = VCPEvent(
        event_type=100,  # VCP_EVENT_REC
        timestamp=int(time.time() * 1000),
        symbol="",
        venue_id="",
        account_id=""
    )
    
    event.recovery_data = {
        "version": "1.0",
        "recovery_type": "CHAIN_BREAK",
        "break_point": {
            "last_valid_event_id": last_valid_event_id,
            "last_valid_hash": last_valid_hash,
            "break_timestamp": break_timestamp,
            "break_reason": break_reason
        },
        "recovery_action": {
            "method": "REBUILD",
            "recovered_events": recovered_events,
            "validation_method": "CACHE_REPLAY"
        }
    }
    
    return event
```

---

## 9. Silver Tier Technical Requirements

### 9.1 Mandatory Requirements

| Requirement Category | Requirement | Threshold | Notes |
|---------------------|------------|-----------|-------|
| **Time Synchronization** | ClockSyncStatus | BEST_EFFORT or higher | UNRELIABLE tolerated (but recorded) |
| **Precision** | TimestampPrecision | MILLISECOND | Nano/microsecond optional |
| **Throughput** | Events/second | >1,000 | Sufficient for retail trading |
| **Latency** | Total processing time | <1 second | Including queueing |
| **Signature** | SignAlgo | Ed25519 (Delegated) | Delegated signature via VCC |
| **Anchoring** | Frequency | 24 hours | Merkle Root only |
| **Format** | Serialization | JSON | RFC 8785 compliant |

**Time Synchronization Note:**
- Recommended: NTP synchronization (±100ms tolerance)
- Not mandatory but recommended for improved audit accuracy
- System with poor time sync will be flagged as UNRELIABLE

### 9.2 Optional Requirements

| Requirement | Description | Recommendation Level |
|-------------|-------------|---------------------|
| VCP-GOV (Algorithm Info) | Algorithm ID, version, decision factors | Strongly Recommended |
| VCP-RISK (Risk Parameters) | Risk setting snapshots at trade time | Strongly Recommended |
| Heartbeat | 60-second interval health check | Recommended |
| Local Cache | Event retention during disconnection | Recommended |
| Two-Layer Logging | Direct EA + Manager API | For large-scale environments |

### 9.3 Numeric Precision Requirements

**Critical:** All financial values must be encoded as **strings**.

```json
// ✓ Correct
{
  "price": "123.456789",
  "quantity": "1000.00",
  "slippage": "0.00012"
}

// ✗ Incorrect (causes IEEE 754 precision issues)
{
  "price": 123.456789,
  "quantity": 1000,
  "slippage": 0.00012
}
```

### 9.4 Event Type Codes (Silver Tier)

| Code | Type | Mandatory/Optional | Description |
|------|------|-------------------|-------------|
| 1 | SIG | Optional | Signal generation (available with direct EA integration) |
| 2 | ORD | **Mandatory** | Order submission |
| 3 | ACK | Recommended | Order acknowledgment |
| 4 | EXE | **Mandatory** | Execution |
| 5 | PRT | Recommended | Partial execution |
| 6 | REJ | **Mandatory** | Order rejection |
| 7 | CXL | Recommended | Order cancellation |
| 98 | HBT | Recommended | Health check |
| 99 | ERR | Recommended | Error |
| 100 | REC | Recommended | Recovery |

---

## 10. Security Considerations

### 10.1 API Key Management

```python
# Recommended: Load from environment variables
import os

VCC_API_KEY = os.environ.get('VCC_API_KEY')
if not VCC_API_KEY:
    raise ValueError("VCC_API_KEY environment variable is required")

# For MQL5: Set as input parameter (DO NOT hardcode in source)
```

### 10.2 Data Pseudonymization

Account IDs and personally identifiable information must be pseudonymized before sending to VCC.

```python
def pseudonymize_account_id(login: int, salt: str) -> str:
    """Pseudonymize account ID (GDPR compliant)"""
    combined = f"{salt}:{login}"
    hashed = hashlib.sha256(combined.encode()).hexdigest()
    return f"acc_{hashed[:16]}"
```

### 10.3 Communication Security

- Use HTTPS/TLS 1.2 or higher for all communications
- Do not disable certificate validation
- Send API Key in Authorization header or dedicated header

### 10.4 Local Cache Protection

```python
# Cache file encryption (optional)
from cryptography.fernet import Fernet

def encrypt_cache(data: bytes, key: bytes) -> bytes:
    f = Fernet(key)
    return f.encrypt(data)

def decrypt_cache(encrypted_data: bytes, key: bytes) -> bytes:
    f = Fernet(key)
    return f.decrypt(encrypted_data)
```

---

## 11. Troubleshooting

### 11.1 Common Issues and Solutions

| Issue | Possible Cause | Solution |
|-------|---------------|----------|
| VCC connection timeout | Network issues, firewall | Verify outbound HTTPS(443) |
| Events not recorded | Invalid API key, auth error | Verify API key and permissions |
| Duplicate events | Two-layer logging conflict | Check Event Correlator deduplication |
| Timestamp drift | Inaccurate system time | Verify NTP synchronization |
| Hash verification failure | Numeric precision issues | Verify all numbers are strings |
| Queue overflow | Send rate < generation rate | Increase batch size, verify async processing |

### 11.2 Debug Mode

```python
import logging

# Enable debug logging
logging.basicConfig(
    level=logging.DEBUG,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)

# VCP client debug mode
vcp_client = VCPClient(
    debug=True,
    log_requests=True,
    log_responses=True
)
```

### 11.3 Health Check Endpoint

```python
# Local health check server (optional)
from flask import Flask, jsonify

app = Flask(__name__)

@app.route('/health')
def health_check():
    return jsonify({
        "status": "ok",
        "vcc_connection": connection_monitor.get_status(),
        "queue_size": event_queue.size(),
        "last_event_time": last_event_time
    })
```

---

## 12. Appendices

### Appendix A: Complete VCP Event Schema

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "title": "VCP Event Schema (Silver Tier)",
  "type": "object",
  "required": ["event_id", "trace_id", "timestamp", "event_type"],
  "properties": {
    "event_id": {
      "type": "string",
      "pattern": "^[0-9a-f]{8}-[0-9a-f]{4}-7[0-9a-f]{3}-[0-9a-f]{4}-[0-9a-f]{12}$",
      "description": "Event identifier in UUID v7 format"
    },
    "trace_id": {
      "type": "string",
      "description": "ID for tracking trade lifecycle"
    },
    "timestamp": {
      "type": "integer",
      "description": "Milliseconds since Unix epoch"
    },
    "event_type": {
      "type": "integer",
      "enum": [1, 2, 3, 4, 5, 6, 7, 8, 9, 20, 21, 22, 98, 99, 100, 101],
      "description": "VCP event type code"
    },
    "timestamp_precision": {
      "type": "string",
      "enum": ["NANOSECOND", "MICROSECOND", "MILLISECOND"],
      "default": "MILLISECOND"
    },
    "clock_sync_status": {
      "type": "string",
      "enum": ["PTP_LOCKED", "NTP_SYNCED", "BEST_EFFORT", "UNRELIABLE"],
      "default": "BEST_EFFORT"
    },
    "hash_algo": {
      "type": "string",
      "enum": ["SHA256", "SHA3_256", "BLAKE3"],
      "default": "SHA256"
    },
    "venue_id": {
      "type": "string",
      "description": "Trading venue identifier"
    },
    "symbol": {
      "type": "string",
      "description": "Trading symbol"
    },
    "account_id": {
      "type": "string",
      "description": "Pseudonymized account ID"
    },
    "trade_data": {
      "type": "object",
      "description": "VCP-TRADE payload"
    },
    "risk_data": {
      "type": "object",
      "description": "VCP-RISK payload"
    },
    "gov_data": {
      "type": "object",
      "description": "VCP-GOV payload"
    }
  }
}
```

### Appendix B: Checklists

#### Pre-PoC Checklist

- [ ] Obtain VCC API key
- [ ] Verify network connectivity (HTTPS/443)
- [ ] Set up development environment (MQL5/Python)
- [ ] Choose vcp-mql-bridge or Manager API adapter
- [ ] Build local test environment

#### Pre-Production Deployment Checklist

- [ ] Verify all mandatory event types (ORD, EXE, REJ) are logged
- [ ] Verify numeric string encoding
- [ ] Verify Heartbeat transmission
- [ ] Verify local cache behavior during disconnection
- [ ] Test verification with VCP Explorer API
- [ ] Performance test (>1,000 events/second)
- [ ] Security review (API key, pseudonymization)

### Appendix C: Related Documents

- VCP Specification v1.0
- VCP Explorer API v1.1 Reference
- VCP Developer Guide
- VC-Certified Certification Guide

---

## Change History

| Version | Date | Changes | Author |
|---------|------|---------|--------|
| 1.0 | 2025-11-25 | Initial release | VSO Technical Committee |

---

## Contact Information

**VeritasChain Standards Organization (VSO)**  
Website: https://veritaschain.org  
Email: technical@veritaschain.org  
GitHub: https://github.com/veritaschain  
Technical Support: https://support.veritaschain.org

---

*End of VCP Sidecar Integration Guide v1.0*
