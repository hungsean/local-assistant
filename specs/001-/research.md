# Technical Research: 跨平台裝置電量監控工具

**Date**: 2025-10-07
**Feature**: 001- 跨平台裝置電量監控工具
**Purpose**: 解決 Technical Context 中的關鍵技術決策點

---

## 研究概述

本文件記錄針對 6 個關鍵技術決策點的研究結果,用於指導後續設計與實作。

---

## 1. Server 架構:中繼伺服器技術選型

### 需求分析
- 支援 P2P 打洞 (STUN/TURN)
- 轉發加密封包 (無法解密內容)
- 裝置註冊與身份管理
- 低延遲轉發 (<500ms)
- 符合零知識架構原則

### 技術選項

#### 選項 A: 自建 WebRTC + STUN/TURN 伺服器
- **技術棧**: coturn (TURN server) + 自訂信令伺服器
- **優點**: 完全掌控、符合零知識架構、WebRTC 成熟且跨平台支援良好
- **缺點**: 需自行實作信令邏輯、維護複雜度高
- **加密**: WebRTC 內建 DTLS-SRTP 加密

#### 選項 B: libp2p (IPFS 使用的 P2P 框架)
- **技術棧**: libp2p (Rust/Go 實作)
- **優點**: 內建 NAT 穿透、多種傳輸協定、成熟的 P2P 框架
- **缺點**: 學習曲線陡峭、可能過度設計
- **加密**: 內建 Noise Protocol 或 TLS 1.3

#### 選項 C: WireGuard 協定 + 自訂中繼
- **技術棧**: wireguard-go / boringtun (Rust)
- **優點**: 極簡設計、效能優異、安全性經過驗證
- **缺點**: 需自行實作中繼邏輯、較適合 VPN 場景
- **加密**: Noise_IK 握手 + ChaCha20-Poly1305

### 決策

**選擇方案 A: 自建 WebRTC + STUN/TURN**

**理由**:
1. WebRTC 對四個目標平台 (Windows/macOS/Android/iPadOS) 都有成熟的原生支援
2. STUN/TURN 標準成熟,開源實作穩定 (coturn)
3. 可完全掌控信令邏輯,確保零知識架構 (伺服器僅轉發 SDP,不保存敏感資訊)
4. 內建加密 (DTLS-SRTP) 符合憲章要求

**實作計畫**:
- 使用 coturn 作為 TURN 伺服器 (僅轉發加密流量)
- 自訂信令伺服器 (WebSocket) 用於 SDP 交換與裝置註冊
- 信令伺服器僅儲存裝置公鑰與線上狀態,不儲存私鑰或電量資料

**替代方案**:
- 選項 B (libp2p) 功能強大但過於複雜,不符合最小權限原則
- 選項 C (WireGuard) 效能最佳但需大量客製化,開發成本高

---

## 2. Client 架構:跨平台開發方案

### 需求分析
- 支援 Windows、macOS、Android、iPadOS 四個平台
- 需要存取平台原生電池 API
- 需要整合平台金鑰鏈 (Keychain/Keystore)
- 需要背景運行支援
- 低功耗要求 (<5% 電量消耗/日)

### 技術選項

#### 選項 A: Rust + Tauri (桌面) + Capacitor (行動)
- **技術棧**: Rust (核心邏輯) + Tauri (Windows/macOS) + Capacitor (Android/iPadOS)
- **優點**: Rust 安全性高、效能優異、可共用核心邏輯
- **缺點**: 需維護兩套 UI 框架、行動平台 Capacitor 較重
- **電池 API**: 需透過 Tauri plugin + Capacitor plugin

#### 選項 B: Flutter
- **技術棧**: Dart + Flutter
- **優點**: 單一程式碼庫、跨平台 UI 一致性高、原生效能佳
- **缺點**: 加密庫選擇較少 (需使用 FFI 呼叫 Rust)
- **電池 API**: battery_plus package (支援四平台)

#### 選項 C: 原生開發
- **技術棧**: C++/Swift (Windows/macOS) + Kotlin/Swift (Android/iPadOS)
- **優點**: 最佳效能、完全掌控平台特性、最低功耗
- **缺點**: 開發成本最高、需維護四套程式碼

### 決策

**選擇方案 B: Flutter + Rust FFI (加密模組)**

**理由**:
1. **跨平台效率**: 單一程式碼庫大幅降低維護成本
2. **電池 API 支援**: battery_plus package 已支援四平台,省去自行整合成本
3. **安全性**: 關鍵加密邏輯用 Rust 實作 (透過 FFI),結合 Dart 開發效率與 Rust 安全性
4. **背景任務**: 支援平台背景插件 (workmanager、background_fetch)
5. **金鑰儲存**: 使用 flutter_secure_storage (底層呼叫平台金鑰鏈)

**架構設計**:
```
Flutter (UI + 業務邏輯)
    ↓ FFI
Rust 核心模組 (加密、P2P 連線、WebRTC)
    ↓ 平台 API
Windows/macOS/Android/iPadOS 原生層
```

**替代方案**:
- 選項 A (Rust + Tauri + Capacitor) 需維護兩套 UI,增加複雜度
- 選項 C (原生開發) 成本過高,不符合快速開發目標

---

## 3. Core 電量讀取:各平台電池 API 整合

### 決策

**使用 Flutter battery_plus package**

**理由**:
已選擇 Flutter 作為客戶端框架,battery_plus 是官方推薦的電池資訊獲取套件,支援:
- **Windows**: 透過 WMI (Windows Management Instrumentation)
- **macOS**: 透過 IOKit framework
- **Android**: 透過 BatteryManager API
- **iOS/iPadOS**: 透過 UIDevice.current.batteryState/batteryLevel

**實作細節**:
```dart
import 'package:battery_plus/battery_plus.dart';

final battery = Battery();

// 取得電量百分比
int batteryLevel = await battery.batteryLevel;

// 取得充電狀態
BatteryState state = await battery.batteryState;
// BatteryState.charging / .discharging / .full / .connectedNotCharging

// 監聽電量變化
battery.onBatteryStateChanged.listen((BatteryState state) {
  // 處理電量更新
});
```

**邊緣案例處理**:
- **純電源供電裝置** (如桌機): battery_plus 在無電池裝置上會回傳錯誤,需捕捉並顯示「AC電源」
- **讀取失敗**: 捕捉異常後顯示「無法取得」
- **虛擬機**: 部分虛擬機可能回傳 0% 或 100%,需額外驗證

---

## 4. 加密實作:P2P 加密協定選擇

### 需求分析
- 端到端加密 (E2EE)
- 支援憲章要求的演算法 (Ed25519、X25519、ChaCha20-Poly1305)
- 防重放攻擊
- 前向保密 (Forward Secrecy)

### 技術選項

#### 選項 A: WebRTC 內建加密 (DTLS-SRTP)
- **優點**: 已整合在 WebRTC 中,無需額外實作
- **缺點**: 使用 RSA 或 ECDSA 證書,不符合憲章要求的 Ed25519

#### 選項 B: Noise Protocol Framework
- **技術棧**: Noise_XX 或 Noise_IK 模式
- **優點**: 現代化設計、支援 X25519 + ChaCha20-Poly1305、前向保密
- **缺點**: 需自行整合到 WebRTC DataChannel 上層

#### 選項 C: Signal Protocol (Double Ratchet)
- **優點**: 經過實戰驗證 (WhatsApp/Signal 使用)、最強安全性
- **缺點**: 複雜度高、需儲存大量狀態

### 決策

**選擇方案 B: Noise Protocol Framework (Noise_XX 模式) + WebRTC**

**理由**:
1. **符合憲章**: 使用 X25519 (ECDH) + ChaCha20-Poly1305 (AEAD)
2. **前向保密**: Noise_XX 模式提供雙向認證與前向保密
3. **簡潔性**: 相比 Signal Protocol 更簡單,符合最小權限原則
4. **整合方式**: WebRTC DataChannel 建立後,在應用層加密訊息

**實作計畫**:
```
1. 裝置初始化時生成 Ed25519 靜態金鑰對 (身份)
2. P2P 連線建立時:
   a. WebRTC 建立 DataChannel (傳輸層加密 DTLS)
   b. 在 DataChannel 上執行 Noise_XX 握手 (應用層加密)
   c. 握手完成後使用 Noise 會話金鑰加密電量資料
3. 防重放攻擊: Noise 協定內建 nonce,每個訊息有唯一序號
```

**Rust 實作庫**: `snow` crate (Noise Protocol 的 Rust 實作)

**替代方案**:
- 選項 A (DTLS-SRTP) 雖簡單但不符合憲章演算法要求
- 選項 C (Signal Protocol) 過度設計,不適合電量監控場景

---

## 5. 儲存方案:本地資料庫選擇

### 需求分析
- 儲存歷史電量記錄 (無時間限制)
- 儲存裝置身份資訊
- 跨平台支援 (Windows/macOS/Android/iPadOS)
- 支援加密儲存 (保護私鑰)

### 技術選項

#### 選項 A: SQLite
- **優點**: 輕量、跨平台、Flutter 支援良好 (sqflite package)
- **缺點**: 需手動管理 schema、加密需額外套件 (sqlcipher)

#### 選項 B: Hive (Flutter NoSQL)
- **優點**: 純 Dart 實作、效能優異、內建加密支援
- **缺點**: 無 SQL 查詢、較適合簡單資料結構

#### 選項 C: Isar (Flutter NoSQL)
- **優點**: 高效能、支援索引與查詢、內建加密
- **缺點**: 較新的專案,生態系統較小

### 決策

**混合方案: Isar (一般資料) + flutter_secure_storage (私鑰)**

**理由**:
1. **歷史電量記錄**: 使用 Isar 儲存 (支援時間範圍查詢、自動索引)
2. **裝置身份**: 使用 Isar 儲存公鑰與裝置 metadata
3. **私鑰儲存**: 使用 flutter_secure_storage (底層呼叫平台金鑰鏈)
   - macOS: Keychain
   - Windows: DPAPI (Data Protection API)
   - Android: Keystore
   - iOS: Keychain

**資料結構設計** (Phase 1 詳細定義):
```dart
// Isar Collection
@Collection()
class BatteryHistory {
  Id id; // 自動遞增
  @Index()
  String deviceId; // 裝置識別碼
  int batteryLevel; // 0-100 或 -1 (AC電源) 或 -2 (無法取得)
  String chargingState; // charging/discharging/full
  @Index()
  DateTime timestamp; // 記錄時間
}

@Collection()
class Device {
  @Id()
  String deviceId; // UUID
  String deviceName;
  String platform; // windows/macos/android/ipados
  String publicKey; // Ed25519 公鑰 (Hex)
  DateTime lastSeen;
}
```

**加密策略**:
- **私鑰**: 絕不儲存在 Isar,僅存於平台金鑰鏈
- **資料庫加密**: Isar 支援 AES-256 加密整個資料庫 (加密金鑰存於 flutter_secure_storage)

**替代方案**:
- 選項 A (SQLite) 功能強大但過於傳統,不符合 Flutter 生態
- 選項 B (Hive) 簡單但缺乏查詢能力,不適合歷史記錄場景

---

## 6. 身份管理:裝置金鑰生成與儲存

### 需求分析
- 符合憲章「裝置為本的身份驗證」原則
- 私鑰安全儲存 (金鑰鏈或 HSM)
- 支援備份與恢復 (助記詞或紙本備份)
- 防止私鑰洩露

### 決策

**金鑰生成方案: Ed25519 靜態金鑰對 + BIP39 助記詞備份**

**實作細節**:

1. **金鑰生成** (首次啟動):
   ```rust
   // Rust FFI 模組
   use ed25519_dalek::{Keypair, PublicKey, SecretKey};
   use bip39::{Mnemonic, Language, MnemonicType};

   // 生成 24 個助記詞
   let mnemonic = Mnemonic::new(MnemonicType::Words24, Language::English);

   // 從助記詞推導種子
   let seed = mnemonic.to_seed("");

   // 從種子生成 Ed25519 金鑰對
   let keypair = Keypair::from_bytes(&seed[..32])?;
   ```

2. **私鑰儲存**:
   ```dart
   // Flutter 端
   import 'package:flutter_secure_storage/flutter_secure_storage.dart';

   final storage = FlutterSecureStorage();

   // 儲存私鑰 (平台金鑰鏈)
   await storage.write(key: 'device_private_key', value: privateKeyHex);

   // 儲存助記詞 (僅供備份,使用者可選擇匯出後刪除)
   await storage.write(key: 'backup_mnemonic', value: mnemonic);
   ```

3. **備份與恢復**:
   - **備份**: 首次啟動時顯示 24 個助記詞,要求使用者抄寫並確認
   - **恢復**: 提供「從助記詞恢復」選項,重新生成相同金鑰對
   - **安全性**: 助記詞匯出後可選擇從金鑰鏈中刪除 (降低洩露風險)

4. **身份恢復選擇** (FR-017):
   ```
   重新安裝偵測流程:
   1. 檢查本地是否有私鑰
   2. 若無,詢問使用者:
      [ ] 建立新裝置身份
      [ ] 從助記詞恢復舊身份
   3. 若選擇恢復:
      - 輸入 24 個助記詞
      - 重新生成金鑰對
      - 向伺服器註冊 (公鑰相同,視為同一裝置)
   ```

**安全考量**:
- **私鑰絕不離開裝置**: 僅公鑰上傳至伺服器
- **金鑰鏈保護**:
  - macOS/iOS: Keychain (需 Touch ID/Face ID 或密碼)
  - Android: Keystore (硬體支援的安全區域)
  - Windows: DPAPI (綁定使用者帳號)
- **助記詞顯示警告**: 「請勿截圖或數位化保存,建議手寫紙本備份」

**替代方案**:
- **不使用助記詞**: 簡化實作但無法備份,裝置遺失即永久失去身份
- **使用密碼推導**: 增加複雜度且使用者體驗差

---

## 技術棧總結

基於以上研究,確定技術棧如下:

| 元件 | 技術選擇 | 主要依賴 |
|------|---------|---------|
| **客戶端框架** | Flutter 3.x | Dart 3.x |
| **加密核心** | Rust (FFI) | `snow` (Noise Protocol), `ed25519-dalek`, `bip39` |
| **電池 API** | battery_plus | 平台原生 API (WMI/IOKit/BatteryManager/UIDevice) |
| **本地儲存** | Isar 3.x | - |
| **私鑰儲存** | flutter_secure_storage | 平台金鑰鏈 |
| **P2P 連線** | flutter_webrtc | libwebrtc (C++) |
| **信令伺服器** | Rust + tokio + tungstenite | WebSocket |
| **TURN 伺服器** | coturn | - |

---

## 更新 Technical Context

基於研究結果,更新 plan.md 的 Technical Context:

**Language/Version**:
- 客戶端: Flutter 3.24+ / Dart 3.5+
- 加密核心: Rust 1.75+
- 信令伺服器: Rust 1.75+ (tokio async runtime)

**Primary Dependencies**:
- Flutter: battery_plus, flutter_webrtc, flutter_secure_storage, isar
- Rust (客戶端 FFI): snow, ed25519-dalek, bip39, chacha20poly1305
- Rust (伺服器): tokio, tungstenite (WebSocket), serde

**Storage**:
- 歷史電量記錄: Isar (本地 NoSQL,支援加密)
- 裝置身份資訊: Isar (公鑰、裝置 metadata)
- 私鑰: 平台金鑰鏈 (Keychain/Keystore/DPAPI)

**Testing**:
- Flutter: flutter_test (單元測試)
- Rust: cargo test (加密模組測試)
- E2E: integration_test (Flutter 整合測試)

---

## 威脅模型分析

### 主要威脅與防禦措施

| 威脅 | 攻擊向量 | 防禦措施 | 優先級 |
|------|---------|---------|--------|
| **中間人攻擊 (MITM)** | 攔截 P2P 連線 | Noise Protocol 雙向認證 + WebRTC DTLS | 高 |
| **封包重放** | 重發舊電量資料 | Noise 內建 nonce + timestamp 驗證 | 中 |
| **私鑰洩露** | 裝置被盜或惡意軟體 | 平台金鑰鏈保護 + 生物辨識鎖定 | 高 |
| **伺服器資料存取** | 中繼伺服器被入侵 | 端到端加密,伺服器僅存公鑰與加密封包 | 高 |
| **裝置冒充** | 偽造裝置身份 | Ed25519 簽章驗證 | 高 |
| **DoS 攻擊** | 大量連線請求 | 速率限制 (每 IP 每分鐘 10 次握手) | 中 |
| **歷史記錄竄改** | 修改本地資料庫 | Isar 資料庫加密 + 完整性校驗 | 低 |

### 信任邊界

```
[ 客戶端 A ]
    ↕ (Noise 加密)
[ WebRTC DataChannel ]
    ↕ (DTLS 加密)
[ TURN 伺服器 ] ← 信任邊界 (伺服器僅轉發,無法解密)
    ↕ (DTLS 加密)
[ WebRTC DataChannel ]
    ↕ (Noise 加密)
[ 客戶端 B ]
```

**零知識驗證**:
- TURN 伺服器僅知道: IP 位址、連線時間、流量大小
- TURN 伺服器不知道: 裝置身份、電量資料、訊息內容

---

## 相依性與風險

### 技術相依性
- **Flutter 生態**: 依賴 battery_plus、flutter_webrtc 維護狀態
- **Rust FFI**: 需確保 Flutter-Rust bridge 穩定性
- **coturn**: 開源專案,需關注安全更新

### 已知風險
1. **iOS 限制**: iPadOS 支援良好,但 iOS 背景運行受限 (未來版本需處理)
2. **虛擬機偵測**: battery_plus 在虛擬機上可能回傳不正確資料
3. **P2P 成功率**: 企業防火牆可能阻擋 WebRTC,降級到 TURN 會增加延遲

---

## 後續行動

Phase 1 將基於本研究結果執行以下任務:
1. 定義資料模型 (data-model.md)
2. 設計 API 契約 (contracts/)
3. 編寫快速開始指南 (quickstart.md)
4. 更新 agent 檔案 (CLAUDE.md)

---

**研究完成時間**: 2025-10-07
**下一階段**: Phase 1 - Design & Contracts
