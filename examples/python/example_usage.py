#!/usr/bin/env python3
"""
VCP Python Sidecar Example Usage
VeritasChain Standards Organization (VSO)
https://veritaschain.org

This script demonstrates how to use the VCP Python Sidecar Adapter
to generate VCP v1.0 compliant audit trails.

Examples include:
1. Basic event creation
2. Complete order lifecycle
3. Manager API adapter usage
4. Event correlation and verification
5. Batch processing
"""

import os
import sys
import time
import json
from datetime import datetime

# Add parent directory to path for imports
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', '..', 'src', 'python'))

from vcp_sidecar_adapter_v1_0 import (
    VCPEventFactory,
    VCPEventSerializer,
    VCCClient,
    VCPManagerAdapter,
    EventCorrelator,
    VCPRiskData,
    Tier,
    EventTypeCode,
    UUIDv7Generator
)


# =============================================================================
# Configuration
# =============================================================================
VCC_ENDPOINT = os.environ.get("VCC_ENDPOINT", "https://api.veritaschain.org")
VCC_API_KEY = os.environ.get("VCC_API_KEY", "your_api_key_here")
VENUE_ID = "EXAMPLE_VENUE"


# =============================================================================
# Example 1: Basic Event Creation
# =============================================================================
def example_basic_events():
    """
    Demonstrates basic VCP event creation.
    Shows how to create SIG, ORD, and EXE events with proper structure.
    """
    print("\n" + "=" * 60)
    print("Example 1: Basic Event Creation")
    print("=" * 60)
    
    # Initialize factory
    factory = VCPEventFactory(
        venue_id=VENUE_ID,
        tier=Tier.SILVER
    )
    
    # Create a Signal event (SIG)
    signal = factory.create_signal_event(
        symbol="XAUUSD",
        account_id="demo_account_001",
        algo_id="MA_CROSSOVER_V2",
        algo_version="2.1.0",
        algo_type="HYBRID",
        confidence="0.85",
        decision_factors=[
            {"name": "EMA_FAST", "period": "10", "value": "2648.50", "weight": "0.35"},
            {"name": "EMA_SLOW", "period": "20", "value": "2645.20", "weight": "0.35"},
            {"name": "RSI", "period": "14", "value": "32.5", "weight": "0.30"},
            {"name": "SIGNAL", "value": "BUY", "weight": "1.0"}
        ]
    )
    
    print("\n--- Signal Event (SIG) ---")
    print(f"Event ID: {signal.header.event_id}")
    print(f"Trace ID: {signal.header.trace_id}")
    print(f"Event Type: {signal.header.event_type} (code: {signal.header.event_type_code})")
    print(f"Timestamp: {signal.header.timestamp_iso}")
    print(f"Hash Chain: prev={signal.security.prev_hash[:16]}... → event={signal.security.event_hash[:16]}...")
    
    # Create Order event (ORD) linked to the signal
    order = factory.create_order_event(
        symbol="XAUUSD",
        account_id="demo_account_001",
        trace_id=signal.header.trace_id,  # Same trace_id links events
        order_id="ORD_12345",
        side="BUY",
        order_type="LIMIT",
        price="2650.00",
        quantity="1.00",
        risk_data=VCPRiskData(
            max_position_size="10.00",
            exposure_utilization="0.15",
            circuit_breaker="NORMAL"
        )
    )
    
    print("\n--- Order Event (ORD) ---")
    print(f"Event ID: {order.header.event_id}")
    print(f"Trace ID: {order.header.trace_id} (same as signal)")
    print(f"Order ID: {order.payload['trade_data']['order_id']}")
    print(f"Side: {order.payload['trade_data']['side']}")
    print(f"Price: {order.payload['trade_data']['price']}")
    print(f"Hash Chain: prev={order.security.prev_hash[:16]}... → event={order.security.event_hash[:16]}...")
    
    # Create Execution event (EXE)
    execution = factory.create_execution_event(
        symbol="XAUUSD",
        account_id="demo_account_001",
        trace_id=signal.header.trace_id,
        order_id="ORD_12345",
        exchange_order_id="EXCH_98765",
        execution_price="2650.05",
        executed_qty="1.00",
        slippage="0.05",
        commission="2.50"
    )
    
    print("\n--- Execution Event (EXE) ---")
    print(f"Event ID: {execution.header.event_id}")
    print(f"Execution Price: {execution.payload['trade_data']['execution_price']}")
    print(f"Slippage: {execution.payload['trade_data']['slippage']}")
    print(f"Hash Chain: prev={execution.security.prev_hash[:16]}... → event={execution.security.event_hash[:16]}...")
    
    return [signal, order, execution]


# =============================================================================
# Example 2: JSON Serialization
# =============================================================================
def example_json_serialization(events):
    """
    Demonstrates JSON serialization of VCP events.
    Shows full JSON structure compliant with VCP v1.0 specification.
    """
    print("\n" + "=" * 60)
    print("Example 2: JSON Serialization")
    print("=" * 60)
    
    # Serialize single event to JSON
    print("\n--- Full JSON (Signal Event) ---")
    json_output = VCPEventSerializer.to_json(events[0], indent=2)
    print(json_output)
    
    # Serialize to JSONL (for batch storage)
    print("\n--- JSONL Format (for batch storage) ---")
    jsonl_output = VCPEventSerializer.to_jsonl(events)
    print(f"Generated {len(jsonl_output.splitlines())} lines of JSONL")
    print(f"First 200 chars: {jsonl_output[:200]}...")


# =============================================================================
# Example 3: Event Correlation and Verification
# =============================================================================
def example_event_correlation(events):
    """
    Demonstrates event correlation and integrity verification.
    Shows how to track order lifecycle and verify hash chain.
    """
    print("\n" + "=" * 60)
    print("Example 3: Event Correlation and Verification")
    print("=" * 60)
    
    correlator = EventCorrelator()
    
    # Add events to correlator
    for event in events:
        result = correlator.add_event(event)
        print(f"Added {event.header.event_type}: {result}")
    
    # Get event chain by trace_id
    trace_id = events[0].header.trace_id
    chain = correlator.get_chain(trace_id)
    
    print(f"\n--- Event Chain (Trace: {trace_id[:20]}...) ---")
    for i, event in enumerate(chain):
        print(f"  [{i+1}] {event.header.event_type} @ {event.header.timestamp_iso}")
    
    # Verify hash chain integrity
    integrity = correlator.verify_chain_integrity(trace_id)
    print(f"\n--- Hash Chain Integrity ---")
    print(f"Valid: {integrity['valid']}")
    print(f"Events: {integrity['events']}")


# =============================================================================
# Example 4: UUID v7 Validation
# =============================================================================
def example_uuid_validation():
    """
    Demonstrates UUID v7 generation and validation.
    UUID v7 is timestamp-ordered, critical for event sequencing.
    """
    print("\n" + "=" * 60)
    print("Example 4: UUID v7 Generation and Validation")
    print("=" * 60)
    
    # Generate multiple UUIDs
    uuids = [UUIDv7Generator.generate() for _ in range(5)]
    
    print("\n--- Generated UUID v7 Values ---")
    for i, uuid in enumerate(uuids):
        valid = UUIDv7Generator.validate(uuid)
        # Extract timestamp (first 12 hex chars = 48 bits)
        ts_hex = uuid.replace("-", "")[:12]
        ts_ms = int(ts_hex, 16)
        ts_dt = datetime.fromtimestamp(ts_ms / 1000)
        
        print(f"  [{i+1}] {uuid}")
        print(f"       Valid: {valid}, Timestamp: {ts_dt}")
    
    # Validate format components
    print("\n--- UUID v7 Format Analysis ---")
    example_uuid = uuids[0]
    parts = example_uuid.split("-")
    print(f"  Full UUID: {example_uuid}")
    print(f"  Part 1 (timestamp high): {parts[0]}")
    print(f"  Part 2 (timestamp low): {parts[1]}")
    print(f"  Part 3 (version=7 + random): {parts[2]} (starts with '7')")
    print(f"  Part 4 (variant + random): {parts[3]} (starts with 8/9/a/b)")
    print(f"  Part 5 (random): {parts[4]}")


# =============================================================================
# Example 5: Complete Trading Scenario
# =============================================================================
def example_complete_scenario():
    """
    Simulates a complete trading scenario with multiple events.
    Demonstrates realistic event flow from signal to position close.
    """
    print("\n" + "=" * 60)
    print("Example 5: Complete Trading Scenario")
    print("=" * 60)
    
    factory = VCPEventFactory(venue_id=VENUE_ID, tier=Tier.SILVER)
    correlator = EventCorrelator()
    
    # Scenario: RSI oversold → BUY signal → Order → Execution → Position Close
    
    print("\n[1] Algorithm detects oversold condition...")
    time.sleep(0.1)  # Simulate processing time
    
    # Signal
    signal = factory.create_signal_event(
        symbol="EURUSD",
        account_id="trader_42",
        algo_id="RSI_REVERSAL",
        algo_version="3.0.0",
        confidence="0.78",
        decision_factors=[
            {"name": "RSI", "value": "28.5", "threshold": "30"},
            {"name": "ATR", "value": "0.0012", "weight": "0.2"},
            {"name": "TREND", "value": "BULLISH", "weight": "0.3"}
        ]
    )
    correlator.add_event(signal)
    print(f"    SIG event logged: {signal.header.event_id[:20]}...")
    
    print("\n[2] Submitting BUY order...")
    time.sleep(0.1)
    
    # Order
    order = factory.create_order_event(
        symbol="EURUSD",
        account_id="trader_42",
        trace_id=signal.header.trace_id,
        order_id="ORD_2024_001",
        side="BUY",
        order_type="MARKET",
        price="1.08550",
        quantity="100000"
    )
    correlator.add_event(order)
    print(f"    ORD event logged: {order.header.event_id[:20]}...")
    
    print("\n[3] Order executed by broker...")
    time.sleep(0.1)
    
    # Execution
    execution = factory.create_execution_event(
        symbol="EURUSD",
        account_id="trader_42",
        trace_id=signal.header.trace_id,
        order_id="ORD_2024_001",
        exchange_order_id="BROKER_EXE_12345",
        execution_price="1.08552",
        executed_qty="100000",
        slippage="0.00002",
        commission="3.50"
    )
    correlator.add_event(execution)
    print(f"    EXE event logged: {execution.header.event_id[:20]}...")
    
    print("\n[4] Scenario complete!")
    
    # Summary
    print("\n--- Scenario Summary ---")
    chain = correlator.get_chain(signal.header.trace_id)
    print(f"Total events in chain: {len(chain)}")
    print(f"Hash chain valid: {correlator.verify_chain_integrity(signal.header.trace_id)['valid']}")
    
    # Print timeline
    print("\n--- Event Timeline ---")
    for event in chain:
        print(f"  {event.header.timestamp_iso} | {event.header.event_type:3} | {event.header.event_id[:16]}...")


# =============================================================================
# Example 6: Error Handling and Rejection
# =============================================================================
def example_error_handling():
    """
    Demonstrates handling of order rejections.
    Shows how to log REJ events properly.
    """
    print("\n" + "=" * 60)
    print("Example 6: Error Handling and Rejection")
    print("=" * 60)
    
    factory = VCPEventFactory(venue_id=VENUE_ID, tier=Tier.SILVER)
    
    # Signal
    signal = factory.create_signal_event(
        symbol="BTCUSD",
        account_id="trader_99",
        algo_id="MOMENTUM_V1",
        algo_version="1.0.0",
        confidence="0.65"
    )
    print(f"Signal generated: {signal.header.trace_id[:20]}...")
    
    # Order
    order = factory.create_order_event(
        symbol="BTCUSD",
        account_id="trader_99",
        trace_id=signal.header.trace_id,
        order_id="ORD_FAIL_001",
        side="BUY",
        order_type="LIMIT",
        price="45000.00",
        quantity="0.5"
    )
    print(f"Order submitted: {order.header.event_id[:20]}...")
    
    # Simulate rejection (insufficient margin)
    rejection = factory.create_reject_event(
        symbol="BTCUSD",
        account_id="trader_99",
        trace_id=signal.header.trace_id,
        order_id="ORD_FAIL_001",
        reject_reason="Insufficient margin: required $5000, available $2500",
        reject_code="MARGIN_INSUFFICIENT"
    )
    
    print(f"\n--- Rejection Event ---")
    print(f"Order ID: {rejection.payload['trade_data']['order_id']}")
    print(f"Reject Code: {rejection.payload['trade_data']['reject_code']}")
    print(f"Reject Reason: {rejection.payload['trade_data']['reject_reason']}")
    
    # Full JSON
    print("\n--- Full REJ Event JSON ---")
    print(VCPEventSerializer.to_json(rejection, indent=2))


# =============================================================================
# Example 7: Heartbeat Events
# =============================================================================
def example_heartbeat():
    """
    Demonstrates heartbeat event generation.
    Heartbeats prove system liveness and maintain hash chain continuity.
    """
    print("\n" + "=" * 60)
    print("Example 7: Heartbeat Events")
    print("=" * 60)
    
    factory = VCPEventFactory(venue_id=VENUE_ID, tier=Tier.SILVER)
    
    print("\nGenerating heartbeat events (simulating 3 intervals)...")
    
    for i in range(3):
        heartbeat = factory.create_heartbeat_event()
        print(f"\n  Heartbeat #{i+1}:")
        print(f"    Event ID: {heartbeat.header.event_id}")
        print(f"    Timestamp: {heartbeat.header.timestamp_iso}")
        print(f"    Event Hash: {heartbeat.security.event_hash[:32]}...")
        time.sleep(0.5)  # Simulate interval
    
    print("\n  Heartbeats maintain hash chain continuity during idle periods.")


# =============================================================================
# Main Entry Point
# =============================================================================
def main():
    """Run all examples"""
    print("\n" + "#" * 60)
    print("# VCP Python Sidecar Adapter - Usage Examples")
    print("# VeritasChain Standards Organization (VSO)")
    print("# https://veritaschain.org")
    print("#" * 60)
    
    # Run examples
    events = example_basic_events()
    example_json_serialization(events)
    example_event_correlation(events)
    example_uuid_validation()
    example_complete_scenario()
    example_error_handling()
    example_heartbeat()
    
    print("\n" + "=" * 60)
    print("All examples completed successfully!")
    print("=" * 60)
    print("\nNext steps:")
    print("  1. Set VCC_API_KEY environment variable")
    print("  2. Configure VCC_ENDPOINT if using custom server")
    print("  3. Integrate VCCClient for actual event transmission")
    print("  4. See README.md for full API documentation")
    print("\nResources:")
    print("  - VCP Specification: https://github.com/veritaschain/vcp-spec")
    print("  - VSO Website: https://veritaschain.org")
    print("  - Support: support@veritaschain.org")


if __name__ == "__main__":
    main()
