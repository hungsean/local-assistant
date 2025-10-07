# API Contracts Overview

**Feature**: 跨平台裝置電量監控工具
**Date**: 2025-10-07
**Version**: 1.0

---

## 契約結構

本專案包含兩類 API 契約:

### 1. 客戶端本地 API (Dart 介面)
- **用途**: 定義客戶端內部模組間的介面
- **格式**: Dart abstract class
- **檔案**:
  - `battery_service.dart` - 電量讀取介面
  - `crypto_service.dart` - 加密與金鑰管理介面
  - `storage_service.dart` - 本地儲存介面
  - `connection_service.dart` - P2P 與中繼連線介面

### 2. 信令伺服器 WebSocket API
- **用途**: 定義客戶端與信令伺服器的通訊協定
- **格式**: JSON Schema
- **檔案**:
  - `signaling_api.md` - WebSocket 訊息格式定義
  - `signaling_api.json` - JSON Schema 規範

---

## API 類別

| 契約名稱 | 類型 | 用途 | 檔案 |
|---------|------|------|------|
| BatteryService | Dart Interface | 電量讀取與監控 | battery_service.dart |
| CryptoService | Dart Interface | 加密、簽章、金鑰管理 | crypto_service.dart |
| StorageService | Dart Interface | 本地資料庫操作 | storage_service.dart |
| ConnectionService | Dart Interface | P2P/中繼連線管理 | connection_service.dart |
| Signaling API | WebSocket JSON | 裝置註冊、SDP 交換 | signaling_api.md |

---

## 測試策略

每個契約都對應一個契約測試檔案,確保實作符合介面定義:

```
contracts/
├── battery_service.dart
├── battery_service_test.dart        # 契約測試 (會失敗,實作後通過)
├── crypto_service.dart
├── crypto_service_test.dart
├── storage_service.dart
├── storage_service_test.dart
├── connection_service.dart
├── connection_service_test.dart
├── signaling_api.md
└── signaling_api_test.dart          # WebSocket 協定測試
```

---

## 依賴關係

```
┌─────────────────────────────────────────┐
│  UI Layer (Flutter Widgets)             │
└─────────────────────────────────────────┘
                  ↓
┌─────────────────────────────────────────┐
│  Service Layer                          │
│  ├─ BatteryService                      │
│  ├─ ConnectionService ←→ CryptoService  │
│  └─ StorageService                      │
└─────────────────────────────────────────┘
                  ↓
┌─────────────────────────────────────────┐
│  Platform Layer                         │
│  ├─ battery_plus (電池 API)              │
│  ├─ flutter_webrtc (P2P 連線)           │
│  ├─ Rust FFI (Noise Protocol 加密)      │
│  └─ Isar + flutter_secure_storage       │
└─────────────────────────────────────────┘
                  ↓
┌─────────────────────────────────────────┐
│  External                               │
│  └─ Signaling Server (WebSocket)        │
└─────────────────────────────────────────┘
```

---

## 加密流程 (Noise Protocol)

```
1. 裝置初始化
   ├─ CryptoService.generateDeviceIdentity()
   │   → 生成 Ed25519 靜態金鑰對
   │   → 生成 BIP39 助記詞
   │   → 儲存私鑰至金鑰鏈
   │
2. P2P 連線建立
   ├─ ConnectionService.connectToDevice(deviceId)
   │   ├─ WebRTC 建立 DataChannel (DTLS 加密)
   │   ├─ CryptoService.performNoiseHandshake()
   │   │   → Noise_XX 握手 (X25519 ECDH)
   │   │   → 建立會話金鑰 (ChaCha20-Poly1305)
   │   └─ 儲存會話狀態至 ConnectionInfo
   │
3. 資料傳輸
   ├─ BatteryService.sendBatteryUpdate()
   │   ├─ CryptoService.encryptMessage(data)
   │   │   → 使用 Noise 會話金鑰加密
   │   │   → 附加 nonce (防重放)
   │   └─ ConnectionService.send(encryptedData)
   │
4. 資料接收
   ├─ ConnectionService.onMessageReceived(encryptedData)
   │   ├─ CryptoService.decryptMessage(encryptedData)
   │   │   → 驗證 nonce
   │   │   → 解密資料
   │   └─ StorageService.saveBatteryHistory(data)
```

---

## 錯誤處理策略

所有服務方法必須返回 `Result<T, E>` 類型,明確處理錯誤:

```dart
// 成功
Result<BatteryStatus, BatteryError>.success(status);

// 失敗
Result<BatteryStatus, BatteryError>.failure(BatteryError.readFailed);
```

**錯誤類型定義**:
- `BatteryError`: 電量讀取錯誤 (無電池、讀取失敗等)
- `CryptoError`: 加密錯誤 (金鑰遺失、簽章驗證失敗等)
- `StorageError`: 儲存錯誤 (資料庫損壞、容量不足等)
- `ConnectionError`: 連線錯誤 (網路斷線、握手失敗等)

---

## 版本控制

契約變更遵循語意化版本:
- **MAJOR**: 不相容的介面變更 (移除方法、改變參數類型)
- **MINOR**: 向後相容的新增功能 (新方法、可選參數)
- **PATCH**: 向後相容的修正 (文件更新、錯誤訊息改善)

當前版本: **1.0.0**

---

## 下一步

1. 實作各服務的具體邏輯
2. 編寫契約測試 (TDD - 測試先行)
3. 執行測試確保契約符合
4. 整合測試驗證服務間互動

---

**文件產生時間**: 2025-10-07
**相關文件**: [data-model.md](../data-model.md), [research.md](../research.md)
