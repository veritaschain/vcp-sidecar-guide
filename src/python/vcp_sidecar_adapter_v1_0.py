#!/usr/bin/env python3
"""
VCP Python Sidecar Adapter v1.0 - VCP Specification Compliant
Document ID: VSO-SDK-PY-001
License: CC BY 4.0 International
Maintainer: VeritasChain Standards Organization (VSO)

This module provides a VCP v1.0 compliant implementation for:
- Manager API integration (MT4/MT5)
- Event generation with proper 3-layer structure
- UUID v7 generation (RFC 9562)
- Hash chain construction
- Async queue processing
"""

import time
import uuid
import hashlib
import json
import logging
import os
import secrets
from datetime import datetime, timezone
from typing import Dict, List, Optional, Any
from dataclasses import dataclass, field, asdict
from enum import IntEnum
import requests
from threading import Thread, Lock
from queue import Queue
import struct

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger("vcp_adapter")


# =============================================================================
# Event Type Codes (IMMUTABLE - VCP v1.0 Specification)
# =============================================================================
class EventTypeCode(IntEnum):
    """VCP Event Type Codes - These are IMMUTABLE for backward compatibility"""
    SIG = 1    # Signal/Decision generated
    ORD = 2    # Order sent
    ACK = 3    # Order acknowledged
    EXE = 4    # Full execution
    PRT = 5    # Partial fill
    REJ = 6    # Order rejected
    CXL = 7    # Order cancelled
    MOD = 8    # Order modified
    CLS = 9    # Position closed
    ALG = 20   # Algorithm update
    RSK = 21   # Risk parameter change
    AUD = 22   # Audit request
    HBT = 98   # Heartbeat
    ERR = 99   # Error
    REC = 100  # Recovery
    SNC = 101  # Clock sync status


EVENT_TYPE_NAMES = {
    EventTypeCode.SIG: "SIG",
    EventTypeCode.ORD: "ORD",
    EventTypeCode.ACK: "ACK",
    EventTypeCode.EXE: "EXE",
    EventTypeCode.PRT: "PRT",
    EventTypeCode.REJ: "REJ",
    EventTypeCode.CXL: "CXL",
    EventTypeCode.MOD: "MOD",
    EventTypeCode.CLS: "CLS",
    EventTypeCode.ALG: "ALG",
    EventTypeCode.RSK: "RSK",
    EventTypeCode.AUD: "AUD",
    EventTypeCode.HBT: "HBT",
    EventTypeCode.ERR: "ERR",
    EventTypeCode.REC: "REC",
    EventTypeCode.SNC: "SNC",
}


class TimestampPrecision:
    NANOSECOND = "NANOSECOND"
    MICROSECOND = "MICROSECOND"
    MILLISECOND = "MILLISECOND"


class ClockSyncStatus:
    PTP_LOCKED = "PTP_LOCKED"
    NTP_SYNCED = "NTP_SYNCED"
    BEST_EFFORT = "BEST_EFFORT"
    UNRELIABLE = "UNRELIABLE"


class Tier:
    PLATINUM = "PLATINUM"
    GOLD = "GOLD"
    SILVER = "SILVER"


# =============================================================================
# VCP v1.0 Data Structures
# =============================================================================
@dataclass
class VCPHeader:
    """VCP-CORE Header Structure"""
    event_id: str
    trace_id: str
    timestamp_int: str           # Nanoseconds as string
    timestamp_iso: str           # ISO 8601
    event_type: str              # String representation (SIG, ORD, etc.)
    event_type_code: int         # Integer code (1, 2, etc.)
    timestamp_precision: str
    clock_sync_status: str
    hash_algo: str
    venue_id: str
    symbol: str
    account_id: str
    operator_id: Optional[str] = None


@dataclass
class VCPTradeData:
    """VCP-TRADE Payload Structure"""
    order_id: Optional[str] = None
    exchange_order_id: Optional[str] = None
    side: Optional[str] = None              # BUY/SELL
    order_type: Optional[str] = None        # MARKET/LIMIT/STOP/STOP_LIMIT
    price: Optional[str] = None             # String for precision
    quantity: Optional[str] = None          # String for precision
    execution_price: Optional[str] = None
    executed_qty: Optional[str] = None
    commission: Optional[str] = None
    slippage: Optional[str] = None
    currency: Optional[str] = None
    reject_reason: Optional[str] = None
    reject_code: Optional[str] = None


@dataclass
class VCPRiskData:
    """VCP-RISK Payload Structure"""
    max_position_size: Optional[str] = None
    current_position: Optional[str] = None
    exposure_utilization: Optional[str] = None
    daily_loss_limit: Optional[str] = None
    current_daily_loss: Optional[str] = None
    max_drawdown: Optional[str] = None
    current_drawdown: Optional[str] = None
    throttle_rate: Optional[str] = None
    circuit_breaker: Optional[str] = None   # NORMAL/WARNING/TRIGGERED/DISABLED


@dataclass
class VCPGovData:
    """VCP-GOV Payload Structure (AI Transparency - EU AI Act Art.12-14)"""
    algo_id: Optional[str] = None
    algo_version: Optional[str] = None
    algo_type: Optional[str] = None         # RULE_BASED/ML/HYBRID/MANUAL
    confidence: Optional[str] = None
    decision_factors: Optional[List[Dict]] = None
    model_hash: Optional[str] = None
    training_date: Optional[str] = None


@dataclass
class VCPSecurity:
    """VCP Security (Hash Chain) Structure"""
    event_hash: str = ""
    prev_hash: str = "0" * 64  # Genesis: 64 zeros
    signature: Optional[str] = None
    sign_algo: Optional[str] = None  # Ed25519


@dataclass
class VCPEvent:
    """Complete VCP v1.0 Event Structure (3-layer)"""
    header: VCPHeader
    payload: Dict[str, Any] = field(default_factory=dict)
    security: VCPSecurity = field(default_factory=VCPSecurity)
    
    # Internal fields (not serialized)
    trade_data: Optional[VCPTradeData] = field(default=None, repr=False)
    risk_data: Optional[VCPRiskData] = field(default=None, repr=False)
    gov_data: Optional[VCPGovData] = field(default=None, repr=False)


# =============================================================================
# UUID v7 Generator (RFC 9562 Compliant)
# =============================================================================
class UUIDv7Generator:
    """
    UUID v7 Generator compliant with RFC 9562
    Format: xxxxxxxx-xxxx-7xxx-yxxx-xxxxxxxxxxxx
    - First 48 bits: Unix timestamp in milliseconds
    - 4 bits: Version (0111 = 7)
    - 12 bits: Random
    - 2 bits: Variant (10)
    - 62 bits: Random
    """
    
    @staticmethod
    def generate() -> str:
        """Generate a RFC 9562 compliant UUID v7"""
        # Get current timestamp in milliseconds
        timestamp_ms = int(time.time() * 1000)
        
        # Convert to bytes (48 bits = 6 bytes)
        ts_bytes = timestamp_ms.to_bytes(6, byteorder='big')
        
        # Generate random bytes
        rand_bytes = secrets.token_bytes(10)
        
        # Build UUID bytes (16 total)
        uuid_bytes = bytearray(16)
        
        # First 6 bytes: timestamp
        uuid_bytes[0:6] = ts_bytes
        
        # Bytes 6-7: version (7) and random
        uuid_bytes[6] = (7 << 4) | (rand_bytes[0] & 0x0F)
        uuid_bytes[7] = rand_bytes[1]
        
        # Byte 8: variant (10xx) and random
        uuid_bytes[8] = (0b10 << 6) | (rand_bytes[2] & 0x3F)
        
        # Remaining bytes: random
        uuid_bytes[9:16] = rand_bytes[3:10]
        
        # Format as UUID string
        hex_str = uuid_bytes.hex()
        return f"{hex_str[0:8]}-{hex_str[8:12]}-{hex_str[12:16]}-{hex_str[16:20]}-{hex_str[20:32]}"
    
    @staticmethod
    def validate(uuid_str: str) -> bool:
        """Validate UUID v7 format"""
        import re
        pattern = r'^[0-9a-f]{8}-[0-9a-f]{4}-7[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$'
        return bool(re.match(pattern, uuid_str.lower()))


# =============================================================================
# VCP Event Factory
# =============================================================================
class VCPEventFactory:
    """Factory for creating VCP-compliant events"""
    
    def __init__(
        self,
        venue_id: str,
        tier: str = Tier.SILVER,
        hash_algo: str = "SHA256"
    ):
        self.venue_id = venue_id
        self.tier = tier
        self.hash_algo = hash_algo
        self.prev_hash = "0" * 64  # Genesis hash
        self._uuid_gen = UUIDv7Generator()
        
        # Tier-specific settings
        if tier == Tier.SILVER:
            self.timestamp_precision = TimestampPrecision.MILLISECOND
            self.clock_sync_status = ClockSyncStatus.BEST_EFFORT
        elif tier == Tier.GOLD:
            self.timestamp_precision = TimestampPrecision.MICROSECOND
            self.clock_sync_status = ClockSyncStatus.NTP_SYNCED
        else:  # PLATINUM
            self.timestamp_precision = TimestampPrecision.NANOSECOND
            self.clock_sync_status = ClockSyncStatus.PTP_LOCKED
    
    def _get_timestamps(self) -> tuple:
        """Get dual-format timestamps (nanoseconds string + ISO 8601)"""
        now = datetime.now(timezone.utc)
        
        # Nanosecond timestamp as string
        timestamp_ns = int(now.timestamp() * 1_000_000_000)
        timestamp_int = str(timestamp_ns)
        
        # ISO 8601 format with milliseconds
        timestamp_iso = now.strftime("%Y-%m-%dT%H:%M:%S.") + f"{now.microsecond // 1000:03d}Z"
        
        return timestamp_int, timestamp_iso
    
    def _compute_event_hash(self, event: VCPEvent) -> str:
        """Compute SHA-256 hash of event (RFC 8785 canonical JSON)"""
        # Create canonical JSON representation
        canonical = {
            "header": {
                "event_id": event.header.event_id,
                "trace_id": event.header.trace_id,
                "timestamp_int": event.header.timestamp_int,
                "event_type_code": event.header.event_type_code,
            },
            "payload": event.payload,
            "prev_hash": event.security.prev_hash
        }
        
        # Sort keys for RFC 8785 compliance
        canonical_json = json.dumps(canonical, sort_keys=True, separators=(',', ':'))
        
        return hashlib.sha256(canonical_json.encode('utf-8')).hexdigest()
    
    def _pseudonymize_account(self, account_id: str, salt: str = "") -> str:
        """Pseudonymize account ID (GDPR compliant)"""
        if not salt:
            salt = f"vcp_{self.venue_id}_"
        combined = f"{salt}{account_id}"
        hashed = hashlib.sha256(combined.encode()).hexdigest()[:16]
        return f"acc_{hashed}"
    
    def create_header(
        self,
        event_type: EventTypeCode,
        symbol: str,
        account_id: str,
        trace_id: Optional[str] = None,
        operator_id: Optional[str] = None
    ) -> VCPHeader:
        """Create VCP-CORE compliant header"""
        timestamp_int, timestamp_iso = self._get_timestamps()
        
        return VCPHeader(
            event_id=self._uuid_gen.generate(),
            trace_id=trace_id or self._uuid_gen.generate(),
            timestamp_int=timestamp_int,
            timestamp_iso=timestamp_iso,
            event_type=EVENT_TYPE_NAMES[event_type],
            event_type_code=int(event_type),
            timestamp_precision=self.timestamp_precision,
            clock_sync_status=self.clock_sync_status,
            hash_algo=self.hash_algo,
            venue_id=self.venue_id,
            symbol=symbol,
            account_id=self._pseudonymize_account(account_id),
            operator_id=operator_id
        )
    
    def create_signal_event(
        self,
        symbol: str,
        account_id: str,
        algo_id: str,
        algo_version: str,
        algo_type: str = "HYBRID",
        confidence: str = "0.0",
        decision_factors: Optional[List[Dict]] = None
    ) -> VCPEvent:
        """Create SIG (Signal) event with VCP-GOV payload"""
        header = self.create_header(EventTypeCode.SIG, symbol, account_id)
        
        gov_data = VCPGovData(
            algo_id=algo_id,
            algo_version=algo_version,
            algo_type=algo_type,
            confidence=confidence,
            decision_factors=decision_factors or []
        )
        
        payload = {
            "vcp_gov": {
                k: v for k, v in asdict(gov_data).items() if v is not None
            }
        }
        
        event = VCPEvent(
            header=header,
            payload=payload,
            security=VCPSecurity(prev_hash=self.prev_hash),
            gov_data=gov_data
        )
        
        # Compute hash and update chain
        event.security.event_hash = self._compute_event_hash(event)
        self.prev_hash = event.security.event_hash
        
        return event
    
    def create_order_event(
        self,
        symbol: str,
        account_id: str,
        trace_id: str,
        order_id: str,
        side: str,
        order_type: str,
        price: str,
        quantity: str,
        risk_data: Optional[VCPRiskData] = None
    ) -> VCPEvent:
        """Create ORD (Order) event with VCP-TRADE and VCP-RISK payload"""
        header = self.create_header(EventTypeCode.ORD, symbol, account_id, trace_id)
        
        trade_data = VCPTradeData(
            order_id=order_id,
            side=side,
            order_type=order_type,
            price=price,
            quantity=quantity
        )
        
        payload = {
            "trade_data": {
                k: v for k, v in asdict(trade_data).items() if v is not None
            }
        }
        
        if risk_data:
            payload["vcp_risk"] = {
                k: v for k, v in asdict(risk_data).items() if v is not None
            }
        
        event = VCPEvent(
            header=header,
            payload=payload,
            security=VCPSecurity(prev_hash=self.prev_hash),
            trade_data=trade_data,
            risk_data=risk_data
        )
        
        event.security.event_hash = self._compute_event_hash(event)
        self.prev_hash = event.security.event_hash
        
        return event
    
    def create_execution_event(
        self,
        symbol: str,
        account_id: str,
        trace_id: str,
        order_id: str,
        exchange_order_id: str,
        execution_price: str,
        executed_qty: str,
        slippage: str = "0",
        commission: str = "0"
    ) -> VCPEvent:
        """Create EXE (Execution) event with VCP-TRADE payload"""
        header = self.create_header(EventTypeCode.EXE, symbol, account_id, trace_id)
        
        trade_data = VCPTradeData(
            order_id=order_id,
            exchange_order_id=exchange_order_id,
            execution_price=execution_price,
            executed_qty=executed_qty,
            slippage=slippage,
            commission=commission
        )
        
        payload = {
            "trade_data": {
                k: v for k, v in asdict(trade_data).items() if v is not None
            }
        }
        
        event = VCPEvent(
            header=header,
            payload=payload,
            security=VCPSecurity(prev_hash=self.prev_hash),
            trade_data=trade_data
        )
        
        event.security.event_hash = self._compute_event_hash(event)
        self.prev_hash = event.security.event_hash
        
        return event
    
    def create_reject_event(
        self,
        symbol: str,
        account_id: str,
        trace_id: str,
        order_id: str,
        reject_reason: str,
        reject_code: str = ""
    ) -> VCPEvent:
        """Create REJ (Reject) event with VCP-TRADE payload"""
        header = self.create_header(EventTypeCode.REJ, symbol, account_id, trace_id)
        
        trade_data = VCPTradeData(
            order_id=order_id,
            reject_reason=reject_reason,
            reject_code=reject_code
        )
        
        payload = {
            "trade_data": {
                k: v for k, v in asdict(trade_data).items() if v is not None
            }
        }
        
        event = VCPEvent(
            header=header,
            payload=payload,
            security=VCPSecurity(prev_hash=self.prev_hash),
            trade_data=trade_data
        )
        
        event.security.event_hash = self._compute_event_hash(event)
        self.prev_hash = event.security.event_hash
        
        return event
    
    def create_heartbeat_event(self) -> VCPEvent:
        """Create HBT (Heartbeat) event"""
        header = self.create_header(EventTypeCode.HBT, "", "system")
        header.trace_id = header.event_id  # Self-referential for HBT
        
        event = VCPEvent(
            header=header,
            payload={},
            security=VCPSecurity(prev_hash=self.prev_hash)
        )
        
        event.security.event_hash = self._compute_event_hash(event)
        self.prev_hash = event.security.event_hash
        
        return event


# =============================================================================
# VCP Event Serializer
# =============================================================================
class VCPEventSerializer:
    """Serialize VCP events to JSON (RFC 8785 canonical)"""
    
    @staticmethod
    def to_dict(event: VCPEvent) -> Dict:
        """Convert VCPEvent to dictionary"""
        header_dict = {
            "event_id": event.header.event_id,
            "trace_id": event.header.trace_id,
            "timestamp_int": event.header.timestamp_int,
            "timestamp_iso": event.header.timestamp_iso,
            "event_type": event.header.event_type,
            "event_type_code": event.header.event_type_code,
            "timestamp_precision": event.header.timestamp_precision,
            "clock_sync_status": event.header.clock_sync_status,
            "hash_algo": event.header.hash_algo,
            "venue_id": event.header.venue_id,
            "symbol": event.header.symbol,
            "account_id": event.header.account_id,
        }
        
        if event.header.operator_id:
            header_dict["operator_id"] = event.header.operator_id
        
        security_dict = {
            "event_hash": event.security.event_hash,
            "prev_hash": event.security.prev_hash,
        }
        
        if event.security.signature:
            security_dict["signature"] = event.security.signature
            security_dict["sign_algo"] = event.security.sign_algo
        
        return {
            "header": header_dict,
            "payload": event.payload,
            "security": security_dict
        }
    
    @staticmethod
    def to_json(event: VCPEvent, indent: Optional[int] = None) -> str:
        """Convert VCPEvent to JSON string"""
        return json.dumps(
            VCPEventSerializer.to_dict(event),
            indent=indent,
            ensure_ascii=False
        )
    
    @staticmethod
    def to_jsonl(events: List[VCPEvent]) -> str:
        """Convert list of events to JSONL format"""
        lines = [VCPEventSerializer.to_json(e) for e in events]
        return '\n'.join(lines)


# =============================================================================
# VCP Cloud Client
# =============================================================================
class VCCClient:
    """VeritasChain Cloud (VCC) API Client"""
    
    def __init__(
        self,
        endpoint: str,
        api_key: str,
        timeout: int = 10,
        retry_count: int = 3
    ):
        self.endpoint = endpoint.rstrip('/')
        self.api_key = api_key
        self.timeout = timeout
        self.retry_count = retry_count
        self._session = requests.Session()
        self._session.headers.update({
            "Content-Type": "application/json",
            "X-API-Key": api_key,
            "User-Agent": "VCP-Python-SDK/1.0.0"
        })
    
    def send_event(self, event: VCPEvent) -> Dict:
        """Send single event to VCC"""
        url = f"{self.endpoint}/v1/events"
        payload = VCPEventSerializer.to_json(event)
        
        for attempt in range(self.retry_count):
            try:
                response = self._session.post(
                    url,
                    data=payload,
                    timeout=self.timeout
                )
                
                if response.status_code in (200, 201):
                    logger.debug(f"Event sent: {event.header.event_id}")
                    return {"status": "ok", "event_id": event.header.event_id}
                else:
                    logger.warning(f"VCC error {response.status_code}: {response.text}")
                    
            except requests.RequestException as e:
                logger.error(f"Network error (attempt {attempt + 1}): {e}")
                if attempt < self.retry_count - 1:
                    time.sleep(2 ** attempt)  # Exponential backoff
        
        return {"status": "error", "event_id": event.header.event_id}
    
    def send_batch(self, events: List[VCPEvent]) -> Dict:
        """Send batch of events to VCC"""
        url = f"{self.endpoint}/v1/events/batch"
        payload = json.dumps({
            "events": [VCPEventSerializer.to_dict(e) for e in events]
        })
        
        for attempt in range(self.retry_count):
            try:
                response = self._session.post(
                    url,
                    data=payload,
                    timeout=self.timeout * 2  # Longer timeout for batch
                )
                
                if response.status_code in (200, 201):
                    logger.info(f"Batch sent: {len(events)} events")
                    return {"status": "ok", "count": len(events)}
                else:
                    logger.warning(f"VCC batch error {response.status_code}: {response.text}")
                    
            except requests.RequestException as e:
                logger.error(f"Network error (attempt {attempt + 1}): {e}")
                if attempt < self.retry_count - 1:
                    time.sleep(2 ** attempt)
        
        return {"status": "error", "count": 0}


# =============================================================================
# VCP Manager API Adapter (for MT4/MT5)
# =============================================================================
class VCPManagerAdapter:
    """
    VCP Manager API Adapter for MT4/MT5
    Polls trades from Manager API and converts to VCP events
    """
    
    def __init__(
        self,
        venue_id: str,
        vcc_endpoint: str,
        vcc_api_key: str,
        tier: str = Tier.SILVER,
        poll_interval: float = 1.0,
        batch_size: int = 100
    ):
        self.factory = VCPEventFactory(venue_id, tier)
        self.client = VCCClient(vcc_endpoint, vcc_api_key)
        self.poll_interval = poll_interval
        self.batch_size = batch_size
        
        # State management
        self.processed_deals: set = set()
        self.trace_id_map: Dict[str, str] = {}  # order_ticket -> trace_id
        self.event_queue: Queue = Queue(maxsize=10000)
        
        # Threading
        self._running = False
        self._worker_thread: Optional[Thread] = None
        self._lock = Lock()
    
    def get_or_create_trace_id(self, order_ticket: str) -> str:
        """Get or create TraceID for order"""
        with self._lock:
            if order_ticket not in self.trace_id_map:
                self.trace_id_map[order_ticket] = UUIDv7Generator.generate()
            return self.trace_id_map[order_ticket]
    
    def transform_deal_to_event(self, deal: Dict, account_id: str) -> VCPEvent:
        """Transform MT5 deal to VCP event"""
        order_ticket = str(deal.get('order', ''))
        trace_id = self.get_or_create_trace_id(order_ticket)
        
        return self.factory.create_execution_event(
            symbol=deal.get('symbol', ''),
            account_id=account_id,
            trace_id=trace_id,
            order_id=order_ticket,
            exchange_order_id=str(deal.get('ticket', '')),
            execution_price=str(deal.get('price', '0')),
            executed_qty=str(deal.get('volume', '0')),
            slippage="0",
            commission=str(deal.get('commission', '0'))
        )
    
    def process_deals(self, deals: List[Dict], account_id: str) -> List[VCPEvent]:
        """Process new deals and convert to VCP events"""
        events = []
        
        for deal in deals:
            deal_key = (deal.get('ticket'), deal.get('time'))
            
            if deal_key in self.processed_deals:
                continue
            
            event = self.transform_deal_to_event(deal, account_id)
            events.append(event)
            self.processed_deals.add(deal_key)
        
        return events
    
    def _worker_loop(self):
        """Background worker for sending queued events"""
        batch = []
        
        while self._running:
            try:
                # Collect batch
                while len(batch) < self.batch_size:
                    try:
                        event = self.event_queue.get(timeout=0.1)
                        batch.append(event)
                    except:
                        break
                
                # Send batch if we have events
                if batch:
                    result = self.client.send_batch(batch)
                    if result["status"] == "ok":
                        batch = []
                    else:
                        # Retry later
                        time.sleep(1)
                else:
                    time.sleep(0.1)
                    
            except Exception as e:
                logger.error(f"Worker error: {e}")
                time.sleep(1)
    
    def start(self):
        """Start background worker"""
        self._running = True
        self._worker_thread = Thread(target=self._worker_loop, daemon=True)
        self._worker_thread.start()
        logger.info("VCP Manager Adapter started")
    
    def stop(self):
        """Stop background worker"""
        self._running = False
        if self._worker_thread:
            self._worker_thread.join(timeout=5)
        logger.info("VCP Manager Adapter stopped")
    
    def queue_event(self, event: VCPEvent):
        """Add event to queue"""
        try:
            self.event_queue.put_nowait(event)
        except:
            logger.warning("Event queue full, dropping event")
    
    def send_heartbeat(self):
        """Send heartbeat event"""
        event = self.factory.create_heartbeat_event()
        self.queue_event(event)


# =============================================================================
# Event Correlator
# =============================================================================
class EventCorrelator:
    """
    Correlate events by TraceID and check sequence integrity
    """
    
    EXPECTED_SEQUENCE = {
        EventTypeCode.SIG: [EventTypeCode.ORD, EventTypeCode.REJ],
        EventTypeCode.ORD: [EventTypeCode.ACK, EventTypeCode.REJ],
        EventTypeCode.ACK: [EventTypeCode.EXE, EventTypeCode.PRT, EventTypeCode.CXL],
        EventTypeCode.PRT: [EventTypeCode.EXE, EventTypeCode.CXL],
    }
    
    def __init__(self):
        self.event_chains: Dict[str, List[VCPEvent]] = {}
    
    def add_event(self, event: VCPEvent) -> Dict:
        """Add event and check integrity"""
        trace_id = event.header.trace_id
        
        if trace_id not in self.event_chains:
            self.event_chains[trace_id] = []
        
        chain = self.event_chains[trace_id]
        
        # Check for duplicates
        for existing in chain:
            if existing.header.event_id == event.header.event_id:
                return {"status": "duplicate", "event_id": event.header.event_id}
        
        # Check timestamp ordering
        if chain and int(event.header.timestamp_int) < int(chain[-1].header.timestamp_int):
            return {
                "status": "warning",
                "message": "Out of order timestamp",
                "event_id": event.header.event_id
            }
        
        # Check expected sequence
        if chain:
            last_type = EventTypeCode(chain[-1].header.event_type_code)
            curr_type = EventTypeCode(event.header.event_type_code)
            
            if last_type in self.EXPECTED_SEQUENCE:
                expected = self.EXPECTED_SEQUENCE[last_type]
                if curr_type not in expected:
                    return {
                        "status": "warning",
                        "message": f"Unexpected {curr_type.name} after {last_type.name}",
                        "event_id": event.header.event_id
                    }
        
        chain.append(event)
        return {"status": "ok", "event_id": event.header.event_id}
    
    def get_chain(self, trace_id: str) -> List[VCPEvent]:
        """Get event chain by TraceID"""
        return self.event_chains.get(trace_id, [])
    
    def verify_chain_integrity(self, trace_id: str) -> Dict:
        """Verify hash chain integrity"""
        chain = self.get_chain(trace_id)
        
        if len(chain) < 2:
            return {"valid": True, "events": len(chain)}
        
        for i in range(1, len(chain)):
            prev_hash = chain[i - 1].security.event_hash
            curr_prev_hash = chain[i].security.prev_hash
            
            if prev_hash != curr_prev_hash:
                return {
                    "valid": False,
                    "error": f"Hash chain break at event {i}",
                    "expected": prev_hash,
                    "actual": curr_prev_hash
                }
        
        return {"valid": True, "events": len(chain)}


# =============================================================================
# Example Usage
# =============================================================================
if __name__ == "__main__":
    # Configuration
    VENUE_ID = "MY_PROP_FIRM"
    VCC_ENDPOINT = "https://api.veritaschain.org"
    VCC_API_KEY = os.environ.get("VCC_API_KEY", "your_api_key_here")
    
    # Create factory
    factory = VCPEventFactory(
        venue_id=VENUE_ID,
        tier=Tier.SILVER
    )
    
    # Create sample signal event
    signal = factory.create_signal_event(
        symbol="XAUUSD",
        account_id="12345",
        algo_id="ALGO_001",
        algo_version="2.1.0",
        algo_type="HYBRID",
        confidence="0.85",
        decision_factors=[
            {"name": "RSI", "weight": "0.3", "value": "72.5"},
            {"name": "MACD", "weight": "0.25", "value": "positive"},
            {"name": "Support", "weight": "0.2", "value": "2650.00"}
        ]
    )
    
    # Create sample order event
    order = factory.create_order_event(
        symbol="XAUUSD",
        account_id="12345",
        trace_id=signal.header.trace_id,
        order_id="ORD_001",
        side="BUY",
        order_type="LIMIT",
        price="2650.50",
        quantity="1.00",
        risk_data=VCPRiskData(
            max_position_size="10.00",
            exposure_utilization="0.15",
            circuit_breaker="NORMAL"
        )
    )
    
    # Create sample execution event
    execution = factory.create_execution_event(
        symbol="XAUUSD",
        account_id="12345",
        trace_id=signal.header.trace_id,
        order_id="ORD_001",
        exchange_order_id="EXE_001",
        execution_price="2650.55",
        executed_qty="1.00",
        slippage="0.05",
        commission="2.50"
    )
    
    # Print events as JSON
    print("=== VCP v1.0 Compliant Events ===\n")
    
    print("--- Signal Event (SIG) ---")
    print(VCPEventSerializer.to_json(signal, indent=2))
    print()
    
    print("--- Order Event (ORD) ---")
    print(VCPEventSerializer.to_json(order, indent=2))
    print()
    
    print("--- Execution Event (EXE) ---")
    print(VCPEventSerializer.to_json(execution, indent=2))
    print()
    
    # Verify UUID v7 format
    print("=== UUID v7 Validation ===")
    print(f"Signal event_id valid: {UUIDv7Generator.validate(signal.header.event_id)}")
    print(f"Order event_id valid: {UUIDv7Generator.validate(order.header.event_id)}")
    print(f"Execution event_id valid: {UUIDv7Generator.validate(execution.header.event_id)}")
    print()
    
    # Verify event correlation
    print("=== Event Correlation ===")
    correlator = EventCorrelator()
    print(f"Add signal: {correlator.add_event(signal)}")
    print(f"Add order: {correlator.add_event(order)}")
    print(f"Add execution: {correlator.add_event(execution)}")
    print(f"Chain integrity: {correlator.verify_chain_integrity(signal.header.trace_id)}")
