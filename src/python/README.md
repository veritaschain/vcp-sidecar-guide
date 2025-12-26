# VCP Python Sidecar Adapter

**VCP v1.0 Compliant Python Implementation**

[![License: CC BY 4.0](https://img.shields.io/badge/License-CC%20BY%204.0-lightgrey.svg)](https://creativecommons.org/licenses/by/4.0/)
[![Python 3.8+](https://img.shields.io/badge/python-3.8+-blue.svg)](https://www.python.org/downloads/)
[![VCP v1.0](https://img.shields.io/badge/VCP-v1.0-green.svg)](https://github.com/veritaschain/vcp-spec)

## Overview

This module provides a VCP v1.0 specification-compliant implementation for generating cryptographically verifiable audit trails in Python environments.

### Features

- ✅ **VCP v1.0 Compliant** - Full specification compliance
- ✅ **UUID v7 (RFC 9562)** - Timestamp-ordered unique identifiers
- ✅ **3-Layer Event Structure** - header / payload / security
- ✅ **SHA-256 Hash Chain** - Tamper-evident audit trail
- ✅ **GDPR Compliant** - Account ID pseudonymization
- ✅ **Async Queue** - Non-blocking event transmission
- ✅ **MT5 Manager API** - Server-side trade polling

## Installation

```bash
pip install -r requirements.txt
```

## Quick Start

```python
from vcp_sidecar_adapter_v1_0 import VCPEventFactory, VCPEventSerializer, Tier

# Initialize factory
factory = VCPEventFactory(
    venue_id="MY_PROP_FIRM",
    tier=Tier.SILVER
)

# Create signal event
signal = factory.create_signal_event(
    symbol="XAUUSD",
    account_id="12345",
    algo_id="MY_ALGO",
    algo_version="1.0.0",
    confidence="0.85",
    decision_factors=[
        {"name": "RSI", "weight": "0.3", "value": "72.5"}
    ]
)

# Create order event (linked via trace_id)
order = factory.create_order_event(
    symbol="XAUUSD",
    account_id="12345",
    trace_id=signal.header.trace_id,  # Same trace_id
    order_id="ORD_001",
    side="BUY",
    order_type="LIMIT",
    price="2650.50",
    quantity="1.00"
)

# Serialize to JSON
print(VCPEventSerializer.to_json(signal, indent=2))
```

## Components

### VCPEventFactory

Factory class for creating VCP-compliant events.

```python
factory = VCPEventFactory(
    venue_id="VENUE_ID",      # Your venue identifier
    tier=Tier.SILVER,         # SILVER / GOLD / PLATINUM
    hash_algo="SHA256"        # Hash algorithm
)
```

### Event Types

| Method | Event Type | Description |
|--------|------------|-------------|
| `create_signal_event()` | SIG | Algorithm signal/decision |
| `create_order_event()` | ORD | Order submission |
| `create_execution_event()` | EXE | Trade execution |
| `create_reject_event()` | REJ | Order rejection |
| `create_heartbeat_event()` | HBT | System heartbeat |

### VCCClient

Client for sending events to VeritasChain Cloud (VCC).

```python
from vcp_sidecar_adapter_v1_0 import VCCClient

client = VCCClient(
    endpoint="https://api.veritaschain.org",
    api_key="your_api_key",
    timeout=10,
    retry_count=3
)

# Send single event
result = client.send_event(signal)

# Send batch
result = client.send_batch([signal, order, execution])
```

### VCPManagerAdapter

Adapter for MT5 Manager API integration.

```python
from vcp_sidecar_adapter_v1_0 import VCPManagerAdapter

adapter = VCPManagerAdapter(
    venue_id="MY_PROP_FIRM",
    vcc_endpoint="https://api.veritaschain.org",
    vcc_api_key="your_api_key",
    tier=Tier.SILVER,
    poll_interval=1.0,
    batch_size=100
)

adapter.start()  # Start background worker
# ... your application logic ...
adapter.stop()   # Graceful shutdown
```

### EventCorrelator

Utility for validating event sequences and hash chain integrity.

```python
from vcp_sidecar_adapter_v1_0 import EventCorrelator

correlator = EventCorrelator()
correlator.add_event(signal)
correlator.add_event(order)
correlator.add_event(execution)

# Verify chain integrity
result = correlator.verify_chain_integrity(signal.header.trace_id)
print(result)  # {'valid': True, 'events': 3}
```

## Event Structure (VCP v1.0)

```json
{
  "header": {
    "event_id": "019b591b-ea7e-7507-a1cc-bb555e81345f",
    "trace_id": "019b591b-ea7e-7f6f-b130-ede86931b9d4",
    "timestamp_int": "1766726560382246912",
    "timestamp_iso": "2025-12-26T05:22:40.382Z",
    "event_type": "SIG",
    "event_type_code": 1,
    "timestamp_precision": "MILLISECOND",
    "clock_sync_status": "BEST_EFFORT",
    "hash_algo": "SHA256",
    "venue_id": "MY_PROP_FIRM",
    "symbol": "XAUUSD",
    "account_id": "acc_ca1ee1d09effaa36"
  },
  "payload": {
    "vcp_gov": {
      "algo_id": "ALGO_001",
      "algo_version": "2.1.0",
      "confidence": "0.85"
    }
  },
  "security": {
    "event_hash": "1caae2ed...",
    "prev_hash": "00000000..."
  }
}
```

## Tier Requirements

| Tier | Clock Sync | Timestamp | Signature |
|------|------------|-----------|-----------|
| Silver | BEST_EFFORT | MILLISECOND | Delegated |
| Gold | NTP_SYNCED | MICROSECOND | Required |
| Platinum | PTP_LOCKED | NANOSECOND | Required |

## License

CC BY 4.0 International

Copyright © 2025 VeritasChain Standards Organization (VSO)

## Resources

- [VCP Specification](https://github.com/veritaschain/vcp-spec)
- [Integration Guide](../VCP_SIDECAR_INTEGRATION_GUIDE_EN.md)
- [VSO Website](https://veritaschain.org)
- [Support](mailto:support@veritaschain.org)
