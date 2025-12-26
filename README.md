# vcp-sidecar-guide

[![License: CC BY 4.0](https://img.shields.io/badge/License-CC%20BY%204.0-lightgrey.svg)](https://creativecommons.org/licenses/by/4.0/)
[![VCP v1.0](https://img.shields.io/badge/VCP-v1.0-green.svg)](https://github.com/veritaschain/vcp-spec)
[![VC-Certified](https://img.shields.io/badge/VC--Certified-Silver-blue.svg)](https://veritaschain.org/certified/)

**Official Sidecar Integration Guide for VCP Silver Tier — non-invasive implementation for MT4/MT5, cTrader, and white-label environments.**

This repository provides the official implementation guide and **production-ready code** for integrating the **VeritasChain Protocol (VCP)** into platforms that **do not have server-level privileges**.

---

## 🚀 Quick Start

### Python

```bash
pip install requests
```

```python
from src.python.vcp_sidecar_adapter_v1_0 import VCPEventFactory, VCPEventSerializer, Tier

factory = VCPEventFactory(venue_id="MY_PROP_FIRM", tier=Tier.SILVER)

# Create signal event
signal = factory.create_signal_event(
    symbol="XAUUSD",
    account_id="12345",
    algo_id="MY_ALGO",
    algo_version="1.0.0",
    confidence="0.85"
)

print(VCPEventSerializer.to_json(signal, indent=2))
```

### MQL5

```mql5
#include <VCP/vcp_mql_bridge_v1_0.mqh>

int OnInit()
{
    VCP_CONFIG config;
    config.api_key = InpVCPApiKey;
    config.endpoint = "https://api.veritaschain.org";
    config.venue_id = "MY_PROP_FIRM";
    config.tier = VCP_TIER_SILVER;
    config.async_mode = true;
    
    VCP_Initialize(config);
    return INIT_SUCCEEDED;
}
```

---

## 📁 Repository Structure

```
vcp-sidecar-guide/
├── README.md
├── LICENSE
├── VCP_SIDECAR_INTEGRATION_GUIDE_EN.md    # Full guide (English)
├── VCP_SIDECAR_INTEGRATION_GUIDE_JA.md    # Full guide (Japanese)
│
├── src/                                    # Production-ready implementations
│   ├── mql5/
│   │   ├── vcp_mql_bridge_v1_0.mqh        # MQL5 bridge library
│   │   └── README.md                       # MQL5 documentation
│   └── python/
│       ├── vcp_sidecar_adapter_v1_0.py    # Python adapter
│       ├── requirements.txt                # Dependencies
│       └── README.md                       # Python documentation
│
└── examples/                               # Usage examples
    ├── mql5/
    │   └── ExampleEA.mq5                  # Complete EA example
    └── python/
        └── example_usage.py               # Python usage examples
```

---

## 📘 What is the Sidecar Integration Model?

The Sidecar model is a **non-invasive, parallel logging architecture** that records trading events without modifying existing infrastructure:

| Event Type | Code | Description |
|------------|------|-------------|
| SIG | 1 | Signal/Decision generated |
| ORD | 2 | Order sent |
| ACK | 3 | Order acknowledged |
| EXE | 4 | Full execution |
| PRT | 5 | Partial fill |
| REJ | 6 | Order rejected |
| CXL | 7 | Order cancelled |
| HBT | 98 | Heartbeat |

### Cryptographic Primitives (VCP v1.0)

- **UUID v7** (RFC 9562) — Timestamp-ordered identifiers
- **RFC 8785** — Canonical JSON serialization
- **SHA-256** — Hash chain integrity
- **RFC 6962** — Merkle tree anchoring
- **Ed25519** — Delegated signatures (optional for Silver)

---

## 🎯 Target Environments

The Sidecar model enables VCP compliance **without server modification**:

| Platform | Integration Method |
|----------|-------------------|
| MT4/MT5 White-Label | vcp-mql-bridge + Manager API |
| cTrader WL | Manager API polling |
| Proprietary FX engines | Python adapter |
| Any read-only environment | Hybrid 2-layer logging |

---

## 📦 Components

### src/mql5/vcp_mql_bridge_v1_0.mqh

Full-featured MQL5 library for VCP event logging:

- ✅ VCP v1.0 specification compliant
- ✅ UUID v7 generation (RFC 9562)
- ✅ 3-layer event structure (header/payload/security)
- ✅ SHA-256 hash chain
- ✅ Async queue with batch processing
- ✅ GDPR-compliant account pseudonymization

### src/python/vcp_sidecar_adapter_v1_0.py

Python implementation for server-side integration:

- ✅ VCPEventFactory — Event creation
- ✅ VCPEventSerializer — JSON serialization
- ✅ VCCClient — API communication
- ✅ VCPManagerAdapter — MT5 Manager API polling
- ✅ EventCorrelator — Chain validation

---

## 🧪 Running Examples

### Python

```bash
cd vcp-sidecar-guide
pip install -r src/python/requirements.txt
python examples/python/example_usage.py
```

### MQL5

1. Copy `src/mql5/vcp_mql_bridge_v1_0.mqh` to `MQL5/Include/VCP/`
2. Copy `examples/mql5/ExampleEA.mq5` to `MQL5/Experts/`
3. Compile and attach to chart
4. Add `https://api.veritaschain.org` to WebRequest allowed URLs

---

## ✅ VC-Certified (Silver) Requirements

| Requirement | Status |
|-------------|--------|
| All event types implemented | ✅ |
| UUID v7 format (RFC 9562) | ✅ |
| Dual timestamp format | ✅ |
| 3-layer structure | ✅ |
| SHA-256 hash chain | ✅ |
| Numeric fields as strings | ✅ |
| Account pseudonymization | ✅ |

---

## 📚 Documentation

| Document | Description |
|----------|-------------|
| [Integration Guide (EN)](VCP_SIDECAR_INTEGRATION_GUIDE_EN.md) | Complete implementation guide |
| [Integration Guide (JA)](VCP_SIDECAR_INTEGRATION_GUIDE_JA.md) | 日本語版実装ガイド |
| [src/mql5/README.md](src/mql5/README.md) | MQL5 API reference |
| [src/python/README.md](src/python/README.md) | Python API reference |

---

## 🔗 Related Repositories

| Repository | Description |
|------------|-------------|
| [vcp-spec](https://github.com/veritaschain/vcp-spec) | VCP Specification v1.0 |
| [vcp-conformance-guide](https://github.com/veritaschain/vcp-conformance-guide) | Conformance tests & example payloads |
| [vcp-sdk-spec](https://github.com/veritaschain/vcp-sdk-spec) | SDK interface specification |
| [vcp-explorer-api](https://github.com/veritaschain/vcp-explorer-api) | Explorer API reference |

---

## 🌐 Maintained by

### VeritasChain Standards Organization (VSO)

Independent, vendor-neutral standards body defining VCP — the global cryptographic audit standard for algorithmic trading.

- **Website:** [https://veritaschain.org](https://veritaschain.org)
- **GitHub:** [https://github.com/veritaschain](https://github.com/veritaschain)
- **Email:** [technical@veritaschain.org](mailto:technical@veritaschain.org)

---

## 📜 License

CC BY 4.0 International

Copyright © 2025 VeritasChain Standards Organization (VSO)

---

<p align="center">
  <strong>"Verify, Don't Trust"</strong><br>
  <em>Encoding Trust in the Algorithmic Age</em>
</p>
