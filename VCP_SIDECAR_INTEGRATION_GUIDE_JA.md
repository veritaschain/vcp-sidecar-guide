# VCP Sidecar Integration Guide
## Silver Tier 技術ガイド v1.0

**Document ID:** VSO-TECH-SIG-001  
**Status:** Production Ready  
**Category:** Implementation Guide / Silver Tier  
**Date:** 2025-11-25  
**Maintainer:** VeritasChain Standards Organization (VSO)  
**License:** CC BY 4.0 International

---

## 目次

1. [概要](#1-概要)
   - 1.1 [本ガイドの目的](#11-本ガイドの目的)
   - 1.2 [対象読者](#12-対象読者)
   - 1.3 [前提条件](#13-前提条件)
   - 1.4 [用語定義](#14-用語定義)
2. [アーキテクチャ](#2-アーキテクチャ)
   - 2.1 [サイドカー統合の基本概念](#21-サイドカー統合の基本概念)
   - 2.2 [データフロー](#22-データフロー)
   - 2.3 [なぜサイドカー統合が必要か](#23-なぜサイドカー統合が必要か)
3. [統合パターン](#3-統合パターン)
   - 3.1 [パターンA: EA/Indicator 直接統合](#31-パターンa-eaindicator-直接統合)
   - 3.2 [パターンB: Manager API 統合](#32-パターンb-manager-api-統合)
   - 3.3 [パターンC: ハイブリッド統合（推奨）](#33-パターンc-ハイブリッド統合推奨)
4. [vcp-mql-bridge 実装ガイド](#4-vcp-mql-bridge-実装ガイド)
   - 4.1 [概要](#41-概要)
   - 4.2 [インストール](#42-インストール)
   - 4.3 [初期化](#43-初期化)
   - 4.4 [シグナルイベント（SIG）の記録](#44-シグナルイベントsigの記録)
   - 4.5 [注文イベント（ORD）の記録](#45-注文イベントordの記録)
   - 4.6 [約定イベント（EXE）の記録](#46-約定イベントexeの記録)
   - 4.7 [非同期処理パターン（推奨）](#47-非同期処理パターン推奨)
   - 4.8 [DLLを使用した完全非同期実装](#48-dllを使用した完全非同期実装)
5. [Manager API 統合](#5-manager-api-統合)
   - 5.1 [概要](#51-概要)
   - 5.2 [アーキテクチャ](#52-アーキテクチャ)
   - 5.3 [Python実装例](#53-python実装例)
6. [2層ロギング構成](#6-2層ロギング構成)
   - 6.1 [概要](#61-概要)
   - 6.2 [アーキテクチャ](#62-アーキテクチャ)
   - 6.3 [TraceID による関連付け](#63-traceid-による関連付け)
   - 6.4 [Layer間の責任分担](#64-layer間の責任分担)
   - 6.5 [シーケンス図](#65-シーケンス図)
7. [VCP Explorer API 接続](#7-vcp-explorer-api-接続)
   - 7.1 [概要](#71-概要)
   - 7.2 [エンドポイント](#72-エンドポイント)
   - 7.3 [イベント検索パラメータ](#73-イベント検索パラメータ)
   - 7.4 [トレーダー向け検証機能（Verify My Trade）](#74-トレーダー向け検証機能verify-my-trade)
   - 7.5 [透明性ダッシュボード統合](#75-透明性ダッシュボード統合)
8. [切断検知と復旧](#8-切断検知と復旧)
   - 8.1 [切断検知メカニズム](#81-切断検知メカニズム)
   - 8.2 [切断時のローカルキャッシュ](#82-切断時のローカルキャッシュ)
   - 8.3 [VCP-RECOVERY イベント](#83-vcp-recovery-イベント)
9. [Silver Tier 技術要件](#9-silver-tier-技術要件)
   - 9.1 [必須要件](#91-必須要件)
   - 9.2 [オプション要件](#92-オプション要件)
   - 9.3 [数値精度要件](#93-数値精度要件)
   - 9.4 [イベントタイプコード](#94-イベントタイプコードsilver-tier必須)
10. [セキュリティ考慮事項](#10-セキュリティ考慮事項)
    - 10.1 [API キー管理](#101-api-キー管理)
    - 10.2 [データの仮名化](#102-データの仮名化)
    - 10.3 [通信セキュリティ](#103-通信セキュリティ)
    - 10.4 [ローカルキャッシュの保護](#104-ローカルキャッシュの保護)
11. [トラブルシューティング](#11-トラブルシューティング)
    - 11.1 [一般的な問題と解決策](#111-一般的な問題と解決策)
    - 11.2 [デバッグモード](#112-デバッグモード)
    - 11.3 [ヘルスチェックエンドポイント](#113-ヘルスチェックエンドポイント)
12. [付録](#12-付録)
    - 付録A [VCPイベント完全スキーマ](#付録a-vcpイベント完全スキーマ)
    - 付録B [チェックリスト](#付録b-チェックリスト)
    - 付録C [関連ドキュメント](#付録c-関連ドキュメント)

---

## 1. 概要

### 1.1 本ガイドの目的

本ガイドは、**サーバー管理者権限を持たない環境**（ホワイトラベル、MT4/MT5レンタルサーバー等）において、VeritasChain Protocol (VCP) を導入するための技術仕様を定義します。

**「サイドカー統合」**とは、既存のトレーディングインフラに変更を加えることなく、VCPロギングシステムを「並走」させる非侵襲的な統合手法です。

### 1.2 対象読者

- プロップファーム（Prop Firm）の技術責任者
- ホワイトラベルブローカーのシステム管理者
- MT4/MT5プラットフォーム運用者
- cTrader環境の管理者
- VCP Silver Tier 認証取得を目指す企業

### 1.3 前提条件

| 要件 | 詳細 |
|------|------|
| プラットフォーム | MT4/MT5, cTrader, または同等のFXプラットフォーム |
| サーバーアクセス | サーバー管理者権限は**不要** |
| ネットワーク | HTTPS/WSS でのアウトバウンド接続が可能 |
| 開発環境 | MQL5, Python 3.8+, または Node.js 18+ |

### 1.4 用語定義

| 用語 | 定義 |
|------|------|
| **サイドカー (Sidecar)** | 既存システムに並走して動作する独立したコンポーネント |
| **ホワイトラベル (WL)** | 外部プロバイダーからサーバーをレンタルして運営するモデル |
| **Manager API** | MT4/MT5のサーバー管理用API（読み取り専用アクセス可能） |
| **vcp-mql-bridge** | MQL5からVCPロギングを行うためのブリッジライブラリ |
| **VCC (VeritasChain Cloud)** | VSOが提供するクラウドベースのVCPロギング・検証インフラストラクチャ。イベントの受信、署名、マークルツリー構築、ブロックチェーンアンカーを実行する |
| **委任署名 (Delegated Signature)** | Silver Tierで使用される署名方式。導入企業は自社で鍵管理を行わず、VCCが署名処理を代行する。これにより導入障壁を大幅に低減しつつ、暗号学的な改ざん検知を実現する |
| **TraceID** | 単一の取引ライフサイクル（SIG→ORD→ACK→EXE）を一意に識別するUUID v7形式のID |

---

## 2. アーキテクチャ

### 2.1 サイドカー統合の基本概念

```
┌─────────────────────────────────────────────────────────────┐
│                     Trading Platform                         │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐          │
│  │   MT4/MT5   │  │   cTrader   │  │  Proprietary│          │
│  │   Server    │  │   Server    │  │   Platform  │          │
│  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘          │
│         │                │                │                  │
│         │    [サーバー管理権限の壁]        │                  │
│         │                │                │                  │
└─────────┼────────────────┼────────────────┼──────────────────┘
          │                │                │
          ▼                ▼                ▼
    ┌─────────────────────────────────────────────┐
    │           VCP Sidecar Layer                 │
    │  ┌───────────────────────────────────────┐  │
    │  │         vcp-mql-bridge                │  │
    │  │  • EA/Indicator からのイベント捕捉     │  │
    │  │  • Manager API からの取引データ取得   │  │
    │  │  • 非同期キューイング                 │  │
    │  └───────────────────────────────────────┘  │
    │                      │                      │
    │                      ▼                      │
    │  ┌───────────────────────────────────────┐  │
    │  │         VCP Local Logger              │  │
    │  │  • イベント生成 (VCP-CORE)            │  │
    │  │  • ハッシュチェーン構築               │  │
    │  │  • ローカルキャッシュ                 │  │
    │  └───────────────────────────────────────┘  │
    └──────────────────────┬──────────────────────┘
                           │
                           ▼
    ┌─────────────────────────────────────────────┐
    │           VeritasChain Cloud (VCC)          │
    │  ┌───────────────────────────────────────┐  │
    │  │         VCP Logging API               │  │
    │  │  • 委任署名 (Ed25519)                 │  │
    │  │  • マークルツリー構築                 │  │
    │  │  • ブロックチェーンアンカー           │  │
    │  └───────────────────────────────────────┘  │
    │                      │                      │
    │                      ▼                      │
    │  ┌───────────────────────────────────────┐  │
    │  │         VCP Explorer API              │  │
    │  │  • 検証ダッシュボード                 │  │
    │  │  • Merkle Proof 提供                  │  │
    │  │  • 証明書発行                         │  │
    │  └───────────────────────────────────────┘  │
    └─────────────────────────────────────────────┘
```

### 2.2 データフロー

```
[取引イベント発生]
        │
        ▼
┌───────────────────┐
│ 1. イベント捕捉    │ ← vcp-mql-bridge / Manager API
└─────────┬─────────┘
          │
          ▼
┌───────────────────┐
│ 2. ローカル処理    │
│ • UUID v7 生成     │
│ • タイムスタンプ   │
│ • JSON構築        │
│ • ローカルハッシュ │
└─────────┬─────────┘
          │
          ▼
┌───────────────────┐
│ 3. 非同期送信      │ ← キューイング（障害対策）
└─────────┬─────────┘
          │
          ▼
┌───────────────────┐
│ 4. VCC処理        │
│ • 署名検証/生成   │
│ • チェーン追加    │
│ • マークルツリー  │
└─────────┬─────────┘
          │
          ▼
┌───────────────────┐
│ 5. アンカー       │ ← 24時間ごと（Silver Tier）
└───────────────────┘
```

### 2.3 なぜサイドカー統合が必要か

| 課題 | サイドカー統合による解決 |
|------|------------------------|
| サーバー権限がない | プラグインインストール不要、クライアントサイドのみで動作 |
| 既存システムへの影響 | 完全に独立して動作、本番環境に変更を加えない |
| 複数プラットフォーム対応 | 統一されたAPIで異なるプラットフォームに対応 |
| 段階的な導入 | 小規模PoCから開始し、徐々に拡大可能 |
| ベンダーロックイン回避 | 標準プロトコル準拠、他システムへの移行容易 |

---

## 3. 統合パターン

Silver Tier環境では、以下の3つの統合パターンが利用可能です。

### 3.1 パターンA: EA/Indicator 直接統合

**適用シナリオ:** 自社開発のEA/Indicatorを使用している場合

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
│  │  │   (統合ライブラリ)     │  │    │
│  │  └───────────────────────┘  │    │
│  └─────────────────────────────┘    │
└─────────────────────────────────────┘
```

**メリット:**
- リアルタイムのイベント捕捉
- シグナル（SIG）から約定（EXE）までの完全なライフサイクル記録
- VCP-GOV（アルゴリズム情報）の詳細な記録が可能

**デメリット:**
- EAのソースコード修正が必要
- EAごとに統合が必要

### 3.2 パターンB: Manager API 統合

**適用シナリオ:** 既存EAに変更を加えられない場合、または複数EAを一括管理する場合

```
┌─────────────────────────────────────┐
│           MT4/MT5 Server            │
│  ┌─────────────────────────────┐    │
│  │      Trading Database       │    │
│  │   (注文・約定・残高)         │    │
│  └──────────┬──────────────────┘    │
│             │ Manager API (読み取り) │
└─────────────┼───────────────────────┘
              │
              ▼
┌─────────────────────────────────────┐
│        VCP Sidecar Service          │
│  ┌─────────────────────────────┐    │
│  │   Manager API Poller        │    │
│  │   • 取引履歴ポーリング       │    │
│  │   • 差分検出                │    │
│  │   • VCPイベント変換         │    │
│  └──────────┬──────────────────┘    │
│             │                       │
│  ┌──────────▼──────────────────┐    │
│  │   VCP Event Generator       │────┼──▶ VCC API
│  └─────────────────────────────┘    │
└─────────────────────────────────────┘
```

**メリット:**
- EAのソースコード変更不要
- 全取引を一括で捕捉
- サーバープラグインのインストール不要（Manager API経由）

**デメリット:**
- SIGイベント（シグナル生成）の捕捉不可
- ポーリング間隔による遅延
- Manager APIへのアクセス権限が必要

### 3.3 パターンC: ハイブリッド統合（推奨）

**適用シナリオ:** 最大限の監査証跡を確保したい場合

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
│  │  │   • TraceID による関連付け              │    │    │
│  │  │   • 重複排除                           │    │    │
│  │  │   • 時系列整合性チェック                │    │    │
│  │  └───────────────────┬─────────────────────┘    │    │
│  └──────────────────────┼──────────────────────────┘    │
└─────────────────────────┼──────────────────────────────┘
                          │
                          ▼
                    VeritasChain Cloud
```

**メリット:**
- 完全なイベントライフサイクルの記録
- アルゴリズム情報（VCP-GOV）と取引データ（VCP-TRADE）の両方を取得
- 冗長性による欠損防止

**デメリット:**
- 実装の複雑さ
- イベントの重複排除処理が必要

---

## 4. vcp-mql-bridge 実装ガイド

### 4.1 概要

`vcp-mql-bridge` は、MQL5からVCPイベントを生成・送信するためのブリッジライブラリです。

### 4.2 インストール

```mql5
// 1. VCP.dll をターミナルの Libraries フォルダに配置
// 2. VCP.mqh をターミナルの Include フォルダに配置
// 3. EAまたはIndicatorでインクルード

#include <VCP.mqh>
```

### 4.3 初期化

```mql5
//+------------------------------------------------------------------+
//| VCP初期化                                                         |
//+------------------------------------------------------------------+
input string VCP_ApiKey       = "";           // VCC API Key
input string VCP_ApiEndpoint  = "https://api.veritaschain.org/v1";
input string VCP_VenueID      = "MY_PROP_FIRM";
input bool   VCP_AsyncMode    = true;         // 非同期モード（推奨）

int OnInit()
{
    // VCPブリッジ初期化
    VCP_CONFIG config;
    config.api_key      = VCP_ApiKey;
    config.endpoint     = VCP_ApiEndpoint;
    config.venue_id     = VCP_VenueID;
    config.tier         = VCP_TIER_SILVER;
    config.async_mode   = VCP_AsyncMode;
    
    int result = VCP_Initialize(config);
    if(result != VCP_OK)
    {
        Print("VCP initialization failed: ", VCP_GetErrorMessage(result));
        return INIT_FAILED;
    }
    
    // 接続状態のヘルスチェック開始
    EventSetTimer(60);  // 60秒ごとにHeartbeat送信
    
    return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
    VCP_Shutdown();
    EventKillTimer();
}
```

### 4.4 シグナルイベント（SIG）の記録

```mql5
//+------------------------------------------------------------------+
//| シグナル生成時のVCPイベント記録                                    |
//+------------------------------------------------------------------+
void LogSignalEvent(
    string symbol,
    ENUM_ORDER_TYPE signal_type,
    double signal_price,
    double confidence,
    string algo_id,
    string algo_version)
{
    // VCP-CORE Header
    VCP_EVENT event;
    event.event_type        = VCP_EVENT_SIG;  // Code: 1
    event.symbol            = symbol;
    event.timestamp         = TimeCurrent() * 1000;  // ミリ秒精度
    event.timestamp_precision = VCP_PRECISION_MILLISECOND;
    event.clock_sync_status = VCP_CLOCK_BEST_EFFORT;
    
    // VCP-GOV (アルゴリズム情報)
    event.gov.algo_id       = algo_id;
    event.gov.algo_version  = algo_version;
    event.gov.algo_type     = VCP_ALGO_TYPE_HYBRID;
    event.gov.confidence    = DoubleToString(confidence, 4);
    
    // 決定要因 (DecisionFactors)
    VCP_AddFeature(event, "signal_type", EnumToString(signal_type), "0.3", "0.25");
    VCP_AddFeature(event, "signal_price", DoubleToString(signal_price, _Digits), "0.2", "0.15");
    VCP_AddFeature(event, "spread", DoubleToString(SymbolInfoInteger(symbol, SYMBOL_SPREAD), 0), "0.1", "0.05");
    
    // イベント送信
    int result = VCP_LogEvent(event);
    if(result != VCP_OK)
    {
        Print("VCP SIG event failed: ", VCP_GetErrorMessage(result));
    }
}
```

### 4.5 注文イベント（ORD）の記録

```mql5
//+------------------------------------------------------------------+
//| 注文送信時のVCPイベント記録                                        |
//+------------------------------------------------------------------+
void LogOrderEvent(
    ulong ticket,
    string symbol,
    ENUM_ORDER_TYPE order_type,
    double price,
    double volume,
    string trace_id)
{
    VCP_EVENT event;
    event.event_type        = VCP_EVENT_ORD;  // Code: 2
    event.trace_id          = trace_id;
    event.symbol            = symbol;
    event.timestamp         = TimeCurrent() * 1000;
    event.timestamp_precision = VCP_PRECISION_MILLISECOND;
    event.clock_sync_status = VCP_CLOCK_BEST_EFFORT;
    
    // VCP-TRADE
    event.trade.order_id    = IntegerToString(ticket);
    event.trade.side        = (order_type == ORDER_TYPE_BUY || order_type == ORDER_TYPE_BUY_LIMIT || order_type == ORDER_TYPE_BUY_STOP) ? "BUY" : "SELL";
    event.trade.order_type  = GetVCPOrderType(order_type);
    event.trade.price       = DoubleToString(price, _Digits);
    event.trade.quantity    = DoubleToString(volume, 2);
    event.trade.currency    = SymbolInfoString(symbol, SYMBOL_CURRENCY_BASE);
    
    // VCP-RISK (現在のリスクパラメータスナップショット)
    event.risk.max_position_size    = DoubleToString(g_MaxPositionSize, 2);
    event.risk.exposure_utilization = DoubleToString(CalculateExposure(), 4);
    event.risk.throttle_rate        = IntegerToString(g_MaxOrdersPerSecond);
    event.risk.circuit_breaker      = "NORMAL";
    
    int result = VCP_LogEvent(event);
    if(result != VCP_OK)
    {
        Print("VCP ORD event failed: ", VCP_GetErrorMessage(result));
    }
}
```

### 4.6 約定イベント（EXE）の記録

```mql5
//+------------------------------------------------------------------+
//| 約定時のVCPイベント記録                                            |
//+------------------------------------------------------------------+
void LogExecutionEvent(
    ulong ticket,
    ulong deal_ticket,
    string symbol,
    double fill_price,
    double fill_volume,
    double slippage,
    string trace_id)
{
    VCP_EVENT event;
    event.event_type        = VCP_EVENT_EXE;  // Code: 4
    event.trace_id          = trace_id;
    event.symbol            = symbol;
    event.timestamp         = TimeCurrent() * 1000;
    event.timestamp_precision = VCP_PRECISION_MILLISECOND;
    event.clock_sync_status = VCP_CLOCK_BEST_EFFORT;
    
    // VCP-TRADE
    event.trade.order_id        = IntegerToString(ticket);
    event.trade.exchange_order_id = IntegerToString(deal_ticket);
    event.trade.executed_qty    = DoubleToString(fill_volume, 2);
    event.trade.execution_price = DoubleToString(fill_price, _Digits);
    event.trade.slippage        = DoubleToString(slippage, _Digits);
    
    int result = VCP_LogEvent(event);
    if(result != VCP_OK)
    {
        Print("VCP EXE event failed: ", VCP_GetErrorMessage(result));
    }
}
```

### 4.7 非同期処理パターン（推奨）

**重要:** MQL5の `WebRequest` はブロッキング関数であり、取引執行中に呼び出すとスリッページの原因となります。以下の非同期パターンを使用してください。

```mql5
//+------------------------------------------------------------------+
//| イベントキュー（非同期送信用）                                      |
//+------------------------------------------------------------------+
class CVCPEventQueue
{
private:
    VCP_EVENT m_queue[];
    int       m_queue_size;
    int       m_max_size;
    
public:
    CVCPEventQueue(int max_size = 10000)
    {
        m_max_size = max_size;
        ArrayResize(m_queue, 0, max_size);
        m_queue_size = 0;
    }
    
    bool Enqueue(VCP_EVENT &event)
    {
        if(m_queue_size >= m_max_size)
        {
            // キューが満杯：最古のイベントを破棄（または警告）
            Print("VCP Warning: Event queue full, dropping oldest event");
            ArrayRemove(m_queue, 0, 1);
            m_queue_size--;
        }
        
        ArrayResize(m_queue, m_queue_size + 1);
        m_queue[m_queue_size] = event;
        m_queue_size++;
        return true;
    }
    
    bool Dequeue(VCP_EVENT &event)
    {
        if(m_queue_size == 0)
            return false;
            
        event = m_queue[0];
        ArrayRemove(m_queue, 0, 1);
        m_queue_size--;
        return true;
    }
    
    int Size() { return m_queue_size; }
};

// グローバルキューインスタンス
CVCPEventQueue g_EventQueue;

//+------------------------------------------------------------------+
//| タイマーイベントで非同期送信                                        |
//+------------------------------------------------------------------+
void OnTimer()
{
    // キューからイベントを取り出して送信
    VCP_EVENT event;
    int processed = 0;
    int max_per_tick = 100;  // 1回のタイマーで最大100件処理
    
    while(g_EventQueue.Dequeue(event) && processed < max_per_tick)
    {
        int result = VCP_SendEventSync(event);  // 実際のHTTP送信
        if(result != VCP_OK)
        {
            // 送信失敗時はキューに戻す（リトライ）
            g_EventQueue.Enqueue(event);
            break;
        }
        processed++;
    }
    
    // キュー状態のログ
    if(g_EventQueue.Size() > 1000)
    {
        Print("VCP Warning: Event queue backlog: ", g_EventQueue.Size());
    }
}
```

### 4.8 DLLを使用した完全非同期実装

より高性能な実装には、C++で作成したDLLを使用します。

```cpp
// VCP.dll - C++ 実装例
#include <windows.h>
#include <queue>
#include <mutex>
#include <thread>
#include <curl/curl.h>

class VCPAsyncLogger {
private:
    std::queue<std::string> event_queue;
    std::mutex queue_mutex;
    std::thread worker_thread;
    bool running = true;
    std::string api_endpoint;
    std::string api_key;
    
    void WorkerLoop() {
        while(running) {
            std::string event_json;
            {
                std::lock_guard<std::mutex> lock(queue_mutex);
                if(!event_queue.empty()) {
                    event_json = event_queue.front();
                    event_queue.pop();
                }
            }
            
            if(!event_json.empty()) {
                SendToVCC(event_json);
            } else {
                std::this_thread::sleep_for(std::chrono::milliseconds(10));
            }
        }
    }
    
    bool SendToVCC(const std::string& json) {
        CURL* curl = curl_easy_init();
        if(!curl) return false;
        
        struct curl_slist* headers = nullptr;
        headers = curl_slist_append(headers, "Content-Type: application/json");
        headers = curl_slist_append(headers, ("X-API-Key: " + api_key).c_str());
        
        curl_easy_setopt(curl, CURLOPT_URL, (api_endpoint + "/events").c_str());
        curl_easy_setopt(curl, CURLOPT_POSTFIELDS, json.c_str());
        curl_easy_setopt(curl, CURLOPT_HTTPHEADER, headers);
        curl_easy_setopt(curl, CURLOPT_TIMEOUT, 5L);  // 5秒タイムアウト
        
        CURLcode res = curl_easy_perform(curl);
        
        curl_slist_free_all(headers);
        curl_easy_cleanup(curl);
        
        return (res == CURLE_OK);
    }
    
public:
    void Initialize(const std::string& endpoint, const std::string& key) {
        api_endpoint = endpoint;
        api_key = key;
        worker_thread = std::thread(&VCPAsyncLogger::WorkerLoop, this);
    }
    
    void LogEvent(const std::string& event_json) {
        std::lock_guard<std::mutex> lock(queue_mutex);
        event_queue.push(event_json);
    }
    
    void Shutdown() {
        running = false;
        if(worker_thread.joinable()) {
            worker_thread.join();
        }
    }
};

// DLLエクスポート関数
extern "C" {
    __declspec(dllexport) int VCP_Initialize(const char* config_json);
    __declspec(dllexport) int VCP_LogEvent(const char* event_json);
    __declspec(dllexport) void VCP_Shutdown();
    __declspec(dllexport) const char* VCP_GetErrorMessage(int error_code);
}
```

---

## 5. Manager API 統合

### 5.1 概要

Manager API統合は、MT4/MT5サーバーの取引データを外部から読み取り、VCPイベントに変換するアプローチです。サーバーへのプラグインインストールが不要なため、ホワイトラベル環境で特に有効です。

### 5.2 アーキテクチャ

```
┌─────────────────────────────────────────────────────────────┐
│                  VCP Manager API Adapter                     │
│                                                             │
│  ┌───────────────────────────────────────────────────────┐  │
│  │                 Configuration                         │  │
│  │  • MT4/MT5 Manager API接続情報                        │  │
│  │  • ポーリング間隔（推奨: 1秒）                         │  │
│  │  • 対象アカウントフィルター                           │  │
│  └───────────────────────────────────────────────────────┘  │
│                                                             │
│  ┌───────────────────────────────────────────────────────┐  │
│  │                 Trade Poller                          │  │
│  │  1. HistoryDealsTotal() で新規約定を検出               │  │
│  │  2. OrdersTotal() で未決済注文を監視                   │  │
│  │  3. 前回ポーリング以降の差分を抽出                     │  │
│  └───────────────────────────────────────────────────────┘  │
│                          │                                  │
│                          ▼                                  │
│  ┌───────────────────────────────────────────────────────┐  │
│  │                 Event Transformer                     │  │
│  │  • MT4/MT5データ → VCPイベント変換                    │  │
│  │  • TraceID生成（注文ごとに一意）                       │  │
│  │  • 重複排除チェック                                   │  │
│  └───────────────────────────────────────────────────────┘  │
│                          │                                  │
│                          ▼                                  │
│  ┌───────────────────────────────────────────────────────┐  │
│  │                 VCP Logger                            │  │
│  │  • VCC APIへの送信                                    │  │
│  │  • ローカルキャッシュ（障害対策）                      │  │
│  └───────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

### 5.3 Python実装例

```python
#!/usr/bin/env python3
"""
VCP Manager API Adapter
MT4/MT5 Manager APIからの取引データをVCPイベントに変換
"""

import time
import uuid
import hashlib
import json
import logging
from datetime import datetime, timezone
from typing import Dict, List, Optional
from dataclasses import dataclass, asdict
import requests

# MT4/MT5 Manager API クライアント（サードパーティライブラリ使用）
# 例: mtapi, mql5-python-connector など
from mt5_manager import MT5ManagerClient

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("vcp_adapter")


@dataclass
class VCPEvent:
    """VCPイベント構造"""
    event_id: str
    trace_id: str
    timestamp: int
    event_type: int
    timestamp_precision: str = "MILLISECOND"
    clock_sync_status: str = "BEST_EFFORT"
    hash_algo: str = "SHA256"
    venue_id: str = ""
    symbol: str = ""
    account_id: str = ""
    trade_data: Optional[Dict] = None
    risk_data: Optional[Dict] = None
    gov_data: Optional[Dict] = None


class VCPManagerAdapter:
    """Manager API統合アダプター"""
    
    EVENT_TYPE_ORD = 2  # Order sent
    EVENT_TYPE_ACK = 3  # Order acknowledged
    EVENT_TYPE_EXE = 4  # Full execution
    EVENT_TYPE_PRT = 5  # Partial fill
    EVENT_TYPE_REJ = 6  # Order rejected
    EVENT_TYPE_CXL = 7  # Order cancelled
    EVENT_TYPE_HBT = 98 # Heartbeat
    
    def __init__(
        self,
        mt5_server: str,
        mt5_login: int,
        mt5_password: str,
        vcc_endpoint: str,
        vcc_api_key: str,
        venue_id: str,
        poll_interval: float = 1.0
    ):
        self.mt5_client = MT5ManagerClient(mt5_server, mt5_login, mt5_password)
        self.vcc_endpoint = vcc_endpoint
        self.vcc_api_key = vcc_api_key
        self.venue_id = venue_id
        self.poll_interval = poll_interval
        
        # 状態管理
        self.last_deal_time: Dict[int, datetime] = {}
        self.processed_deals: set = set()
        self.trace_id_map: Dict[int, str] = {}  # order_ticket -> trace_id
        
    def generate_event_id(self) -> str:
        """UUID v7 生成（時系列ソート可能）"""
        # 簡易実装：実際はuuid7ライブラリを使用
        timestamp_ms = int(time.time() * 1000)
        random_bits = uuid.uuid4().hex[12:]
        timestamp_hex = format(timestamp_ms, '012x')
        return f"{timestamp_hex[:8]}-{timestamp_hex[8:12]}-7{random_bits[:3]}-{random_bits[3:7]}-{random_bits[7:19]}"
    
    def get_or_create_trace_id(self, order_ticket: int) -> str:
        """注文ごとのTraceIDを取得または生成"""
        if order_ticket not in self.trace_id_map:
            self.trace_id_map[order_ticket] = self.generate_event_id()
        return self.trace_id_map[order_ticket]
    
    def transform_deal_to_event(self, deal: dict) -> VCPEvent:
        """MT5約定データをVCPイベントに変換"""
        order_ticket = deal['order']
        trace_id = self.get_or_create_trace_id(order_ticket)
        
        # イベントタイプの判定
        if deal['entry'] == 0:  # DEAL_ENTRY_IN
            event_type = self.EVENT_TYPE_EXE
        elif deal['entry'] == 1:  # DEAL_ENTRY_OUT
            event_type = self.EVENT_TYPE_EXE
        else:
            event_type = self.EVENT_TYPE_EXE
        
        event = VCPEvent(
            event_id=self.generate_event_id(),
            trace_id=trace_id,
            timestamp=int(deal['time'].timestamp() * 1000),
            event_type=event_type,
            venue_id=self.venue_id,
            symbol=deal['symbol'],
            account_id=self._pseudonymize_account(deal['login']),
            trade_data={
                "order_id": str(order_ticket),
                "exchange_order_id": str(deal['ticket']),
                "side": "BUY" if deal['type'] == 0 else "SELL",
                "executed_qty": str(deal['volume']),
                "execution_price": str(deal['price']),
                "commission": str(deal['commission']),
                "currency": deal['symbol'][:3] if len(deal['symbol']) >= 3 else "USD"
            }
        )
        
        return event
    
    def _pseudonymize_account(self, login: int) -> str:
        """アカウントIDの仮名化"""
        salt = "vcp_salt_"  # 実際は設定から読み込む
        hashed = hashlib.sha256(f"{salt}{login}".encode()).hexdigest()[:16]
        return f"acc_{hashed}"
    
    def poll_new_deals(self) -> List[VCPEvent]:
        """新規約定のポーリング"""
        events = []
        
        try:
            # 全約定履歴を取得
            deals = self.mt5_client.get_deals_history(
                from_date=datetime.now(timezone.utc).replace(hour=0, minute=0, second=0)
            )
            
            for deal in deals:
                deal_key = (deal['ticket'], deal['time'])
                
                # 重複チェック
                if deal_key in self.processed_deals:
                    continue
                
                # VCPイベントに変換
                event = self.transform_deal_to_event(deal)
                events.append(event)
                
                # 処理済みとしてマーク
                self.processed_deals.add(deal_key)
                
        except Exception as e:
            logger.error(f"Polling error: {e}")
        
        return events
    
    def send_events_to_vcc(self, events: List[VCPEvent]) -> bool:
        """VCC APIへイベント送信"""
        if not events:
            return True
        
        headers = {
            "Content-Type": "application/json",
            "X-API-Key": self.vcc_api_key
        }
        
        # バッチ送信
        payload = {
            "events": [asdict(e) for e in events]
        }
        
        try:
            response = requests.post(
                f"{self.vcc_endpoint}/v1/events/batch",
                headers=headers,
                json=payload,
                timeout=10
            )
            
            if response.status_code == 200:
                logger.info(f"Sent {len(events)} events to VCC")
                return True
            else:
                logger.error(f"VCC API error: {response.status_code} - {response.text}")
                return False
                
        except requests.RequestException as e:
            logger.error(f"Network error: {e}")
            return False
    
    def send_heartbeat(self) -> bool:
        """ヘルスチェック用Heartbeatイベント送信"""
        event = VCPEvent(
            event_id=self.generate_event_id(),
            trace_id=self.generate_event_id(),
            timestamp=int(time.time() * 1000),
            event_type=self.EVENT_TYPE_HBT,
            venue_id=self.venue_id,
            symbol="",
            account_id=""
        )
        
        return self.send_events_to_vcc([event])
    
    def run(self):
        """メインループ"""
        logger.info(f"VCP Manager Adapter started for {self.venue_id}")
        heartbeat_counter = 0
        
        while True:
            try:
                # 新規約定をポーリング
                events = self.poll_new_deals()
                
                if events:
                    self.send_events_to_vcc(events)
                
                # 60秒ごとにHeartbeat送信
                heartbeat_counter += 1
                if heartbeat_counter >= 60 / self.poll_interval:
                    self.send_heartbeat()
                    heartbeat_counter = 0
                
                time.sleep(self.poll_interval)
                
            except KeyboardInterrupt:
                logger.info("Shutting down...")
                break
            except Exception as e:
                logger.error(f"Main loop error: {e}")
                time.sleep(5)  # エラー時は5秒待機


if __name__ == "__main__":
    adapter = VCPManagerAdapter(
        mt5_server="your-mt5-server.com:443",
        mt5_login=12345,
        mt5_password="your_password",
        vcc_endpoint="https://api.veritaschain.org",
        vcc_api_key="your_api_key",
        venue_id="MY_PROP_FIRM",
        poll_interval=1.0
    )
    
    adapter.run()
```

---

## 6. 2層ロギング構成

### 6.1 概要

2層ロギング構成は、EA直接統合（Layer 1）とManager API統合（Layer 2）を組み合わせることで、最大限の監査証跡を確保する構成です。

### 6.2 アーキテクチャ

```
┌─────────────────────────────────────────────────────────────────┐
│                       2層ロギング構成                           │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │ Layer 1: EA/Indicator 直接統合                           │  │
│  │ 捕捉イベント: SIG, ORD (送信時点)                        │  │
│  │ 追加データ: VCP-GOV (アルゴリズム情報)                   │  │
│  │ タイミング: リアルタイム                                 │  │
│  └──────────────────────────────────────────────────────────┘  │
│                              │                                  │
│                              │ TraceID                          │
│                              ▼                                  │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │ Layer 2: Manager API 統合                                │  │
│  │ 捕捉イベント: ORD (確定), ACK, EXE, PRT, REJ, CXL        │  │
│  │ 追加データ: VCP-TRADE (約定詳細), VCP-RISK               │  │
│  │ タイミング: ポーリング間隔（1秒推奨）                    │  │
│  └──────────────────────────────────────────────────────────┘  │
│                              │                                  │
│                              ▼                                  │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │ Event Correlator                                         │  │
│  │ • TraceIDによる関連付け                                  │  │
│  │ • 重複排除（同一イベントの検出）                         │  │
│  │ • 時系列整合性チェック                                   │  │
│  │ • 欠損検出アラート                                       │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### 6.3 TraceID による関連付け

```python
class EventCorrelator:
    """イベント関連付けと整合性チェック"""
    
    def __init__(self):
        self.event_chains: Dict[str, List[VCPEvent]] = {}
        self.expected_sequence = {
            1: [2, 6],      # SIG -> ORD or REJ
            2: [3, 6],      # ORD -> ACK or REJ
            3: [4, 5, 7],   # ACK -> EXE, PRT, or CXL
            5: [4, 7],      # PRT -> EXE or CXL
        }
    
    def add_event(self, event: VCPEvent) -> Dict:
        """イベントを追加し、整合性をチェック"""
        trace_id = event.trace_id
        
        if trace_id not in self.event_chains:
            self.event_chains[trace_id] = []
        
        chain = self.event_chains[trace_id]
        
        # 重複チェック
        for existing in chain:
            if existing.event_id == event.event_id:
                return {"status": "duplicate", "event_id": event.event_id}
        
        # 時系列チェック
        if chain and event.timestamp < chain[-1].timestamp:
            return {
                "status": "warning",
                "message": "Out of order timestamp",
                "event_id": event.event_id
            }
        
        # シーケンスチェック
        if chain:
            last_type = chain[-1].event_type
            if last_type in self.expected_sequence:
                expected = self.expected_sequence[last_type]
                if event.event_type not in expected:
                    return {
                        "status": "warning",
                        "message": f"Unexpected event type {event.event_type} after {last_type}",
                        "event_id": event.event_id
                    }
        
        chain.append(event)
        return {"status": "ok", "event_id": event.event_id}
    
    def get_chain(self, trace_id: str) -> List[VCPEvent]:
        """TraceIDに紐づくイベントチェーンを取得"""
        return self.event_chains.get(trace_id, [])
    
    def detect_missing_events(self, trace_id: str) -> List[str]:
        """欠損イベントを検出"""
        chain = self.get_chain(trace_id)
        if not chain:
            return []
        
        missing = []
        event_types = [e.event_type for e in chain]
        
        # 完了した取引にEXEがない場合
        if 3 in event_types and 4 not in event_types and 7 not in event_types:
            missing.append("EXE or CXL expected but not found")
        
        return missing
```

### 6.4 Layer間の責任分担

| 責任領域 | Layer 1 (EA直接) | Layer 2 (Manager API) |
|---------|-----------------|---------------------|
| SIGイベント | ✓ 主担当 | ✗ 捕捉不可 |
| VCP-GOV (アルゴリズム情報) | ✓ 主担当 | ✗ 捕捉不可 |
| ORDイベント（送信時点） | ✓ 主担当 | △ ポーリング遅延あり |
| ACK/EXE/REJイベント | △ 受信確認が必要 | ✓ 主担当 |
| VCP-TRADE (約定詳細) | △ 部分的 | ✓ 主担当 |
| VCP-RISK (リスクパラメータ) | ✓ リアルタイム | △ スナップショットのみ |

### 6.5 シーケンス図

以下は2層ロギング構成における典型的なイベントフローを示すシーケンス図です。

```
┌─────────┐     ┌─────────┐     ┌─────────┐     ┌─────────┐     ┌─────────┐
│   EA    │     │ Layer 1 │     │MT Server│     │ Layer 2 │     │   VCC   │
│(Trading)│     │(EA Hook)│     │(Manager)│     │(Poller) │     │ (Cloud) │
└────┬────┘     └────┬────┘     └────┬────┘     └────┬────┘     └────┬────┘
     │               │               │               │               │
     │ Signal        │               │               │               │
     │ Generated     │               │               │               │
     │──────────────>│               │               │               │
     │               │ SIG Event     │               │               │
     │               │ (TraceID=T1)  │               │               │
     │               │───────────────────────────────────────────────>│
     │               │               │               │               │
     │ OrderSend()   │               │               │               │
     │──────────────>│               │               │               │
     │               │ ORD Event     │               │               │
     │               │ (TraceID=T1)  │               │               │
     │               │───────────────────────────────────────────────>│
     │               │               │               │               │
     │               │               │ Order Placed  │               │
     │               │               │<──────────────│               │
     │               │               │               │               │
     │               │               │               │ Poll (1s)     │
     │               │               │               │──────────────>│
     │               │               │ HistoryDeals  │               │
     │               │               │──────────────>│               │
     │               │               │               │               │
     │               │               │               │ ACK Event     │
     │               │               │               │ (TraceID=T1)  │
     │               │               │               │──────────────>│
     │               │               │               │               │
     │ OnTrade()     │               │               │               │
     │ (Execution)   │               │               │               │
     │<──────────────│               │               │               │
     │               │               │               │               │
     │               │               │               │ Poll (1s)     │
     │               │               │               │──────────────>│
     │               │               │ Deal Data     │               │
     │               │               │──────────────>│               │
     │               │               │               │               │
     │               │               │               │ EXE Event     │
     │               │               │               │ (TraceID=T1)  │
     │               │               │               │──────────────>│
     │               │               │               │               │
     │               │               │               │               │ Correlate
     │               │               │               │               │ by TraceID
     │               │               │               │               │────┐
     │               │               │               │               │    │
     │               │               │               │               │<───┘
     │               │               │               │               │
     │               │               │               │               │ Build
     │               │               │               │               │ Merkle Tree
     │               │               │               │               │────┐
     │               │               │               │               │    │
     │               │               │               │               │<───┘
     │               │               │               │               │
```

**シーケンス説明:**

1. **T+0ms**: EA がシグナルを生成し、Layer 1 が即座に SIG イベントを VCC に送信（TraceID=T1 を生成）
2. **T+1ms**: EA が OrderSend() を実行、Layer 1 が ORD イベントを送信（同一 TraceID=T1）
3. **T+100ms**: MT Server で注文が処理される
4. **T+1000ms**: Layer 2 が Manager API をポーリング、ACK イベントを検出・送信
5. **T+1500ms**: 約定完了、Layer 2 が EXE イベントを検出・送信
6. **VCC 側**: TraceID=T1 で4つのイベント（SIG→ORD→ACK→EXE）を関連付け、整合性を検証

---

## 7. VCP Explorer API 接続

### 7.1 概要

VCP Explorer APIは、記録されたイベントの検索、検証、証明書発行を行うためのRESTful APIです。

### 7.2 エンドポイント

| エンドポイント | メソッド | 説明 |
|---------------|---------|------|
| `/v1/events` | GET | イベント検索 |
| `/v1/events/:id` | GET | イベント詳細取得 |
| `/v1/events/:id/proof` | GET | Merkle Proof取得 |
| `/v1/events/:id/certificate` | GET | 証明書取得 |
| `/v1/system/status` | GET | システム状態 |

### 7.3 イベント検索パラメータ

VCP Explorer API v1.1 で利用可能な検索パラメータ一覧です。

| パラメータ | 型 | 必須 | 説明 | 例 |
|-----------|------|------|------|-----|
| `trace_id` | UUID v7 | No | 取引ライフサイクル追跡ID（SIG→ORD→ACK→EXEチェーン） | `01934e3a-6a1b-7c82-9d1b-0987654321dc` |
| `symbol` | String | No | 取引シンボル | `XAUUSD`, `EURUSD`, `BTCUSDT` |
| `event_type` | String | No | イベントタイプ名 | `ORD`, `EXE`, `REJ` |
| `event_type_code` | Integer | No | VCPイベントコード（1-255） | `2` (=ORD), `4` (=EXE) |
| `start_time` | ISO8601 | No | 時間範囲の開始（inclusive） | `2025-11-24T00:00:00Z` |
| `end_time` | ISO8601 | No | 時間範囲の終了（inclusive） | `2025-11-24T23:59:59Z` |
| `algo_id` | String | No | VCP-GOVのアルゴリズム識別子 | `neural-scalper-v1.2` |
| `venue_id` | String | No | 取引会場/ブローカー/取引所識別子 | `XNAS`, `BINANCE` |
| `order_id` | String | No | 注文ID | `12345678` |
| `account_id` | String | No | 仮名化アカウントID | `acc_a1b2c3d4e5f6` |
| `limit` | Integer | No | 最大結果数（1-500、デフォルト: 50） | `100` |
| `offset` | Integer | No | ページネーションオフセット（デフォルト: 0） | `50` |

**イベントタイプコード一覧:**

| コード | タイプ | 説明 |
|--------|--------|------|
| 1 | SIG | シグナル/決定生成 |
| 2 | ORD | 注文送信 |
| 3 | ACK | 注文確認 |
| 4 | EXE | 完全約定 |
| 5 | PRT | 部分約定 |
| 6 | REJ | 注文拒否 |
| 7 | CXL | 注文キャンセル |
| 20 | ALG | アルゴリズム更新 |
| 21 | RSK | リスクパラメータ変更 |
| 98 | HBT | ヘルスチェック |
| 99 | ERR | エラー |
| 100 | REC | 復旧 |

### 7.4 トレーダー向け検証機能（Verify My Trade）

```python
class VerifyMyTrade:
    """トレーダー向け取引検証クライアント"""
    
    def __init__(self, explorer_endpoint: str):
        self.endpoint = explorer_endpoint
    
    def verify_trade(self, order_id: str) -> Dict:
        """注文IDで取引を検証"""
        
        # 1. イベント検索
        events = self._search_events(order_id)
        if not events:
            return {"verified": False, "error": "Trade not found"}
        
        # 2. 各イベントのMerkle Proofを取得・検証
        verification_results = []
        for event in events:
            proof = self._get_merkle_proof(event['event_id'])
            verified = self._verify_proof(event, proof)
            verification_results.append({
                "event_id": event['event_id'],
                "event_type": event['type'],
                "timestamp": event['timestamp'],
                "verified": verified,
                "anchor_status": event.get('anchor_status', 'PENDING')
            })
        
        # 3. 結果サマリー
        all_verified = all(r['verified'] for r in verification_results)
        all_anchored = all(r['anchor_status'] == 'ANCHORED' for r in verification_results)
        
        return {
            "verified": all_verified,
            "anchored": all_anchored,
            "order_id": order_id,
            "events": verification_results,
            "chain_integrity": self._check_chain_integrity(events)
        }
    
    def _search_events(self, order_id: str) -> List[Dict]:
        """注文IDでイベントを検索"""
        response = requests.get(
            f"{self.endpoint}/v1/events",
            params={"order_id": order_id}
        )
        if response.status_code == 200:
            return response.json().get('events', [])
        return []
    
    def _get_merkle_proof(self, event_id: str) -> Dict:
        """Merkle Proofを取得"""
        response = requests.get(f"{self.endpoint}/v1/events/{event_id}/proof")
        if response.status_code == 200:
            return response.json()
        return {}
    
    def _verify_proof(self, event: Dict, proof: Dict) -> bool:
        """Merkle Proofを検証"""
        if not proof:
            return False
        
        # RFC 6962準拠の検証
        event_hash = proof.get('event_hash', '')
        merkle_proof = proof.get('merkle_proof', {})
        root_hash = merkle_proof.get('root_hash', '')
        audit_path = merkle_proof.get('audit_path', [])
        
        # 検証ロジック（簡略化）
        current_hash = bytes.fromhex(event_hash)
        
        for sibling_hash in audit_path:
            sibling = bytes.fromhex(sibling_hash)
            # 内部ノードのハッシュ計算（0x01プレフィックス）
            combined = b'\x01' + current_hash + sibling
            current_hash = hashlib.sha256(combined).digest()
        
        return current_hash.hex() == root_hash
    
    def _check_chain_integrity(self, events: List[Dict]) -> bool:
        """イベントチェーンの整合性をチェック"""
        if len(events) < 2:
            return True
        
        sorted_events = sorted(events, key=lambda e: e['timestamp'])
        
        for i in range(1, len(sorted_events)):
            prev = sorted_events[i-1]
            curr = sorted_events[i]
            
            # prev_hashの検証
            if curr.get('security', {}).get('prev_hash') != prev.get('security', {}).get('event_hash'):
                return False
        
        return True
```

### 7.5 透明性ダッシュボード統合

```html
<!-- トレーダー向け検証ダッシュボード例 -->
<!DOCTYPE html>
<html>
<head>
    <title>Verify My Trade - VCP Explorer</title>
    <script src="https://cdn.jsdelivr.net/npm/axios/dist/axios.min.js"></script>
</head>
<body>
    <h1>取引検証 (Verify My Trade)</h1>
    
    <div>
        <label>注文ID:</label>
        <input type="text" id="orderId" placeholder="例: 12345678">
        <button onclick="verifyTrade()">検証</button>
    </div>
    
    <div id="results"></div>
    
    <script>
        const EXPLORER_API = 'https://api-explorer.veritaschain.org/v1';
        
        async function verifyTrade() {
            const orderId = document.getElementById('orderId').value;
            const resultsDiv = document.getElementById('results');
            
            try {
                // イベント検索
                const searchRes = await axios.get(`${EXPLORER_API}/events`, {
                    params: { order_id: orderId }
                });
                
                const events = searchRes.data.events;
                
                if (!events || events.length === 0) {
                    resultsDiv.innerHTML = '<p style="color:red;">取引が見つかりません</p>';
                    return;
                }
                
                let html = '<h2>検証結果</h2><ul>';
                
                for (const event of events) {
                    // Merkle Proof取得
                    const proofRes = await axios.get(`${EXPLORER_API}/events/${event.event_id}/proof`);
                    const verified = proofRes.data.merkle_proof ? '✓ 検証済み' : '⏳ 検証待ち';
                    
                    html += `
                        <li>
                            <strong>${event.type}</strong> - ${event.timestamp}<br>
                            イベントID: ${event.event_id}<br>
                            ステータス: ${verified}<br>
                            アンカー状態: ${event.status}
                        </li>
                    `;
                }
                
                html += '</ul>';
                resultsDiv.innerHTML = html;
                
            } catch (error) {
                resultsDiv.innerHTML = `<p style="color:red;">エラー: ${error.message}</p>`;
            }
        }
    </script>
</body>
</html>
```

---

## 8. 切断検知と復旧

### 8.1 切断検知メカニズム

VCPサイドカーが切断されたことを検知するためのメカニズムを実装する必要があります。

```python
class ConnectionMonitor:
    """VCC接続監視"""
    
    def __init__(
        self,
        vcc_endpoint: str,
        heartbeat_interval: int = 60,
        max_missed_heartbeats: int = 3
    ):
        self.vcc_endpoint = vcc_endpoint
        self.heartbeat_interval = heartbeat_interval
        self.max_missed_heartbeats = max_missed_heartbeats
        
        self.last_successful_send = time.time()
        self.missed_heartbeats = 0
        self.connection_status = "CONNECTED"
        
        # アラートコールバック
        self.on_disconnected = None
        self.on_reconnected = None
    
    def send_heartbeat(self) -> bool:
        """Heartbeatを送信し、接続状態を更新"""
        try:
            response = requests.post(
                f"{self.vcc_endpoint}/v1/heartbeat",
                json={"timestamp": int(time.time() * 1000)},
                timeout=5
            )
            
            if response.status_code == 200:
                self.last_successful_send = time.time()
                self.missed_heartbeats = 0
                
                # 再接続検知
                if self.connection_status == "DISCONNECTED":
                    self.connection_status = "CONNECTED"
                    if self.on_reconnected:
                        self.on_reconnected()
                
                return True
            else:
                self._handle_failure()
                return False
                
        except requests.RequestException:
            self._handle_failure()
            return False
    
    def _handle_failure(self):
        """送信失敗時の処理"""
        self.missed_heartbeats += 1
        
        if self.missed_heartbeats >= self.max_missed_heartbeats:
            if self.connection_status == "CONNECTED":
                self.connection_status = "DISCONNECTED"
                if self.on_disconnected:
                    self.on_disconnected()
    
    def get_status(self) -> Dict:
        """現在の接続状態を取得"""
        return {
            "status": self.connection_status,
            "last_successful_send": self.last_successful_send,
            "missed_heartbeats": self.missed_heartbeats,
            "time_since_last_send": time.time() - self.last_successful_send
        }
```

### 8.2 切断時のローカルキャッシュ

```python
class LocalEventCache:
    """切断時のローカルイベントキャッシュ"""
    
    def __init__(self, cache_file: str = "vcp_event_cache.jsonl"):
        self.cache_file = cache_file
        self.max_cache_size = 100000  # 最大10万イベント
    
    def cache_event(self, event: VCPEvent) -> bool:
        """イベントをローカルにキャッシュ"""
        try:
            with open(self.cache_file, 'a') as f:
                f.write(json.dumps(asdict(event)) + '\n')
            return True
        except IOError as e:
            logger.error(f"Cache write error: {e}")
            return False
    
    def get_cached_events(self) -> List[VCPEvent]:
        """キャッシュされたイベントを取得"""
        events = []
        try:
            with open(self.cache_file, 'r') as f:
                for line in f:
                    data = json.loads(line.strip())
                    events.append(VCPEvent(**data))
        except FileNotFoundError:
            pass
        except IOError as e:
            logger.error(f"Cache read error: {e}")
        return events
    
    def clear_cache(self):
        """キャッシュをクリア"""
        try:
            open(self.cache_file, 'w').close()
        except IOError:
            pass
    
    def flush_to_vcc(self, vcc_client) -> int:
        """キャッシュをVCCにフラッシュ"""
        events = self.get_cached_events()
        if not events:
            return 0
        
        success_count = 0
        failed_events = []
        
        for event in events:
            if vcc_client.send_event(event):
                success_count += 1
            else:
                failed_events.append(event)
        
        # 失敗したイベントのみ残す
        self.clear_cache()
        for event in failed_events:
            self.cache_event(event)
        
        return success_count
```

### 8.3 VCP-RECOVERY イベント

切断からの復旧時には、VCP-RECOVERY イベントを記録して監査証跡の完全性を維持します。

```python
def create_recovery_event(
    last_valid_event_id: str,
    last_valid_hash: str,
    break_timestamp: int,
    break_reason: str,
    recovered_events: int
) -> VCPEvent:
    """チェーン復旧イベントを作成"""
    
    event = VCPEvent(
        event_id=generate_event_id(),
        trace_id=generate_event_id(),
        timestamp=int(time.time() * 1000),
        event_type=100,  # REC (Recovery)
        timestamp_precision="MILLISECOND",
        clock_sync_status="BEST_EFFORT",
        venue_id="",
        symbol="",
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

## 9. Silver Tier 技術要件

### 9.1 必須要件

| 要件カテゴリ | 要件 | 基準値 | 備考 |
|-------------|------|--------|------|
| **時刻同期** | ClockSyncStatus | BEST_EFFORT以上 | UNRELIABLE許容（ただし記録される） |
| **精度** | TimestampPrecision | MILLISECOND | ナノ秒/マイクロ秒は任意 |
| **スループット** | イベント/秒 | >1,000 | 通常のリテール取引では十分 |
| **レイテンシ** | 合計処理時間 | <1秒 | キューイング含む |
| **署名** | SignAlgo | Ed25519 (Delegated) | VCC経由の委任署名 |
| **アンカー** | 頻度 | 24時間 | Merkle Root のみ |
| **フォーマット** | シリアライズ | JSON | RFC 8785 準拠 |

**時刻同期に関する推奨事項:**

> **推奨:** NTP同期（±100ms以内）。必須ではないが、監査精度向上のため推奨。
> 
> Silver Tierでは `BEST_EFFORT` ステータスでの運用が許容されますが、NTP同期を設定することで以下のメリットがあります：
> - イベントの時系列整合性が向上
> - 監査時の証拠力が強化
> - Gold Tierへのアップグレードが容易

**委任署名について:**

> Silver Tier では鍵管理を簡素化するため、署名処理を VCC が委任方式で実行します（キー管理不要）。
> 
> これにより、導入企業は以下の負担から解放されます：
> - Ed25519 秘密鍵の生成・保管
> - 署名ライブラリの実装
> - 鍵のローテーション管理

### 9.2 オプション要件

| 要件 | 説明 | 推奨度 |
|------|------|--------|
| VCP-GOV (アルゴリズム情報) | アルゴリズムID、バージョン、決定要因の記録 | 強く推奨 |
| VCP-RISK (リスクパラメータ) | 取引時点のリスク設定スナップショット | 強く推奨 |
| Heartbeat | 60秒間隔のヘルスチェック | 推奨 |
| ローカルキャッシュ | 切断時のイベント保持 | 推奨 |
| 2層ロギング | EA直接 + Manager API | 大規模環境向け |

### 9.3 数値精度要件

**重要:** すべての金融数値は**文字列**としてエンコードする必要があります。

```json
// ✓ 正しい例
{
  "price": "123.456789",
  "quantity": "1000.00",
  "slippage": "0.00012"
}

// ✗ 誤った例（IEEE 754精度問題の原因）
{
  "price": 123.456789,
  "quantity": 1000,
  "slippage": 0.00012
}
```

### 9.4 イベントタイプコード（Silver Tier必須）

| コード | タイプ | 必須/任意 | 説明 |
|--------|--------|---------|------|
| 1 | SIG | 任意 | シグナル生成（EA直接統合で利用可能） |
| 2 | ORD | **必須** | 注文送信 |
| 3 | ACK | 推奨 | 注文確認 |
| 4 | EXE | **必須** | 約定 |
| 5 | PRT | 推奨 | 部分約定 |
| 6 | REJ | **必須** | 注文拒否 |
| 7 | CXL | 推奨 | 注文キャンセル |
| 98 | HBT | 推奨 | ヘルスチェック |
| 99 | ERR | 推奨 | エラー |
| 100 | REC | 推奨 | 復旧 |

---

## 10. セキュリティ考慮事項

### 10.1 API キー管理

```python
# 推奨: 環境変数からの読み込み
import os

VCC_API_KEY = os.environ.get('VCC_API_KEY')
if not VCC_API_KEY:
    raise ValueError("VCC_API_KEY environment variable is required")

# MQL5の場合: 入力パラメータとして設定（ただしソースコードにハードコードしない）
```

### 10.2 データの仮名化

アカウントIDや個人を特定できる情報は、VCC送信前に仮名化する必要があります。

```python
def pseudonymize_account_id(login: int, salt: str) -> str:
    """アカウントIDの仮名化（GDPR準拠）"""
    combined = f"{salt}:{login}"
    hashed = hashlib.sha256(combined.encode()).hexdigest()
    return f"acc_{hashed[:16]}"
```

### 10.3 通信セキュリティ

- すべての通信はHTTPS/TLS 1.2以上を使用
- 証明書の検証を無効化しない
- API KeyはAuthorizationヘッダーまたは専用ヘッダーで送信

### 10.4 ローカルキャッシュの保護

```python
# キャッシュファイルの暗号化（オプション）
from cryptography.fernet import Fernet

def encrypt_cache(data: bytes, key: bytes) -> bytes:
    f = Fernet(key)
    return f.encrypt(data)

def decrypt_cache(encrypted_data: bytes, key: bytes) -> bytes:
    f = Fernet(key)
    return f.decrypt(encrypted_data)
```

---

## 11. トラブルシューティング

### 11.1 一般的な問題と解決策

| 問題 | 考えられる原因 | 解決策 |
|------|---------------|--------|
| VCC接続タイムアウト | ネットワーク問題、ファイアウォール | アウトバウンドHTTPS(443)を確認 |
| イベントが記録されない | APIキー無効、認証エラー | APIキーと権限を確認 |
| 重複イベント | 2層ロギングの競合 | Event Correlatorの重複排除を確認 |
| タイムスタンプずれ | システム時刻の不正確 | NTP同期を確認 |
| ハッシュ検証失敗 | 数値精度問題 | 全数値が文字列であることを確認 |
| キュー溢れ | 送信速度 < 生成速度 | バッチサイズ増加、非同期処理確認 |

### 11.2 デバッグモード

```python
import logging

# デバッグログ有効化
logging.basicConfig(
    level=logging.DEBUG,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)

# VCPクライアントのデバッグモード
vcp_client = VCPClient(
    debug=True,
    log_requests=True,
    log_responses=True
)
```

### 11.3 ヘルスチェックエンドポイント

```python
# ローカルヘルスチェックサーバー（オプション）
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

## 12. 付録

### 付録A: VCPイベント完全スキーマ

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
      "description": "UUID v7 形式のイベント識別子"
    },
    "trace_id": {
      "type": "string",
      "pattern": "^[0-9a-f]{8}-[0-9a-f]{4}-7[0-9a-f]{3}-[0-9a-f]{4}-[0-9a-f]{12}$",
      "description": "取引ライフサイクルを追跡するID（ORD/EXE/REJでは必須、SIGでは任意）"
    },
    "timestamp": {
      "type": "integer",
      "description": "Unixエポックからのミリ秒"
    },
    "event_type": {
      "type": "integer",
      "enum": [1, 2, 3, 4, 5, 6, 7, 8, 9, 20, 21, 22, 98, 99, 100, 101],
      "description": "VCPイベントタイプコード"
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
      "description": "取引会場識別子"
    },
    "symbol": {
      "type": "string",
      "description": "取引シンボル"
    },
    "account_id": {
      "type": "string",
      "description": "仮名化されたアカウントID"
    },
    "trade_data": {
      "type": "object",
      "description": "VCP-TRADE ペイロード"
    },
    "risk_data": {
      "type": "object",
      "description": "VCP-RISK ペイロード"
    },
    "gov_data": {
      "type": "object",
      "description": "VCP-GOV ペイロード"
    }
  }
}
```

**注記:** 
- `trace_id` は Silver Tier の ORD/EXE/REJ イベントでは**必須**です
- SIG イベントでは `trace_id` を生成し、後続のイベントで同一値を使用します
- SIG イベントのみを記録する場合（Layer 1 のみ）、`trace_id` は任意ですが、2層構成では必須となります

### 付録B: チェックリスト

#### PoC開始前チェックリスト

- [ ] VCC APIキーの取得
- [ ] ネットワーク接続の確認（HTTPS/443）
- [ ] 開発環境のセットアップ（MQL5/Python）
- [ ] vcp-mql-bridgeまたはManager APIアダプターの選択
- [ ] ローカルテスト環境の構築

#### 本番デプロイ前チェックリスト

- [ ] 全必須イベントタイプ（ORD, EXE, REJ）の記録確認
- [ ] 数値の文字列エンコーディング確認
- [ ] Heartbeat送信の確認
- [ ] 切断時のローカルキャッシュ動作確認
- [ ] VCP Explorer APIでの検証テスト
- [ ] パフォーマンステスト（1,000イベント/秒以上）
- [ ] セキュリティレビュー（APIキー、仮名化）

### 付録C: 関連ドキュメント

- VCP Specification v1.0
- VCP Explorer API v1.1 Reference
- VCP Developer Guide
- VC-Certified 認証ガイド

---

## 変更履歴

| バージョン | 日付 | 変更内容 | 著者 |
|-----------|------|----------|------|
| 1.0 | 2025-11-25 | 初版リリース | VSO Technical Committee |

---

## お問い合わせ

**VeritasChain Standards Organization (VSO)**  
Website: https://veritaschain.org  
Email: technical@veritaschain.org  
GitHub: https://github.com/veritaschain  
Technical Support: https://support.veritaschain.org

---

*End of VCP Sidecar Integration Guide v1.0*
