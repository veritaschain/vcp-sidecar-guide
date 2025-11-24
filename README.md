vcp-sidecar-guide

Official Sidecar Integration Guide for VCP Silver Tier — non-invasive implementation model for MT4/MT5, cTrader, and white-label environments.

This repository provides the official implementation guide for integrating the VeritasChain Protocol (VCP) into platforms that do not have server-level privileges, such as MT4/MT5 white-label servers, cTrader WL instances, and proprietary FX/CFD environments.

The Sidecar model enables tamper-evident cryptographic logging without modifying existing trading infrastructure.

📘 Purpose

The VCP Sidecar Integration Guide defines how to implement VCP logging using:

vcp-mql-bridge (MQL5 client-side hook)

Manager API integration (MT4/MT5 server-side read-only polling)

Hybrid 2-Layer Logging Architecture

VCP Explorer API v1.1 (Merkle proof & certificate verification)

It is the official technical reference for organizations aiming to deploy VCP Silver Tier and/or obtain VC-Certified compliance.

🧩 Repository Structure (recommended)
/docs
  SIDEcar_GUIDE_en.md
  SIDEcar_GUIDE_ja.md
  diagrams/

/examples
  mql5/
  python/
  c++/

/schema
  vcp-event.schema.json

LICENSE
README.md

🚀 What is the Sidecar Integration Model?

The Sidecar model is a non-invasive, parallel logging architecture that records:

SIG (Signal)

ORD (Order Sent)

ACK (Order Acknowledged)

EXE (Execution)

REJ (Rejection)

CXL (Cancel)

PRT (Partial Fill)

RISK snapshots

GOV (Algorithm governance metadata)

HBT/REC (heartbeat & recovery)

…using cryptographic primitives defined in VCP Specification v1.0:

UUID v7

RFC 8785 canonical JSON

SHA-256 hash chain

RFC 6962 Merkle trees

Ed25519 delegated signatures

The Sidecar model allows full VCP compliance without modifying platform internals, enabling deployment on:

MT4/MT5 White-Label servers

cTrader instances

Proprietary FX engines

Any environment lacking root access

🔧 Core Documents
📄 VCP Sidecar Integration Guide v1.0

The complete implementation guide (EN/JA) is available in /docs.

Includes:

Architecture diagrams

MQL5 bridge implementation

Manager API polling adapter

2-layer event correlation

Recovery & fault tolerance

Security & compliance requirements

Silver Tier technical requirements

Full JSON schema & checklists

📚 Related specs

VCP Specification v1.0

VCP Explorer API v1.1

VC-Certified Compliance Guide

🧪 Conformance & Certification

Organizations implementing Silver Tier integration can obtain:

✔ VC-Certified (Silver)

Verifies that:

All required event types are implemented

Timestamp precision meets standard

Numeric fields use string encoding

Merkle proof validation succeeds

Log integrity is cryptographically verifiable

(Full guide coming soon.)

🌐 Maintained by
VeritasChain Standards Organization (VSO)

Independent, vendor-neutral standards body defining VCP —
the global cryptographic audit standard for algorithmic trading.

Website: https://veritaschain.org

GitHub: https://github.com/veritaschain

Email: technical@veritaschain.org

📜 License

CC BY 4.0 International
