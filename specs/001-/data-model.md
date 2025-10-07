# Data Model: 跨平台裝置電量監控工具

**Date**: 2025-10-07
**Feature**: 001- 跨平台裝置電量監控工具
**Based on**: spec.md Key Entities section + research.md 技術決策

---

## 概述

本文件定義系統中所有資料實體的結構、關係與驗證規則。資料模型遵循憲章的安全要求,確保私鑰與敏感資料的正確儲存與保護。

---

## 儲存架構

```
┌─────────────────────────────────────────────────────────┐
│ 平台金鑰鏈 (Keychain/Keystore/DPAPI)                      │
│  - device_private_key (Ed25519 私鑰)                     │
│  - backup_mnemonic (BIP39 助記詞,可選)                   │
│  - isar_encryption_key (資料庫加密金鑰)                   │
└─────────────────────────────────────────────────────────┘
                         ↑
                         │ flutter_secure_storage
                         ↓
┌─────────────────────────────────────────────────────────┐
│ Isar 本地資料庫 (AES-256 加密)                            │
│  ├─ Device (裝置資訊)                                    │
│  ├─ BatteryHistory (歷史電量記錄)                        │
│  └─ ConnectionInfo (連線資訊)                            │
└─────────────────────────────────────────────────────────┘
```

---

## 實體定義

### 1. Device (裝置資訊)

**用途**: 記錄本地裝置與遠端裝置的身份資訊

**Isar Collection 定義**:
```dart
import 'package:isar/isar.dart';

@Collection()
class Device {
  /// 裝置唯一識別碼 (UUID v4)
  /// 範例: "550e8400-e29b-41d4-a716-446655440000"
  @Id()
  late String deviceId;

  /// 裝置名稱 (使用者可編輯)
  /// 範例: "MacBook Pro", "Samsung Galaxy S23"
  /// 驗證: 長度 1-50 字元
  @Index()
  late String deviceName;

  /// 裝置類型
  /// 可能值: desktop, laptop, phone, tablet
  @enumerated
  late DeviceType deviceType;

  /// 作業系統平台
  /// 可能值: windows, macos, android, ipados
  @enumerated
  late Platform platform;

  /// 電源類型 (是否有電池)
  /// 可能值: battery, ac_only
  @enumerated
  late PowerType powerType;

  /// Ed25519 公鑰 (Hex 編碼, 64 字元)
  /// 範例: "a1b2c3d4e5f6..."
  /// 驗證: 必須是有效的 64 字元 hex 字串
  @Index(unique: true)
  late String publicKey;

  /// 最後上線時間
  late DateTime lastSeen;

  /// 是否為本地裝置 (true = 本機, false = 遠端裝置)
  late bool isLocal;

  /// 建立時間
  late DateTime createdAt;
}

/// 裝置類型列舉
enum DeviceType {
  desktop,   // 桌上型電腦
  laptop,    // 筆記型電腦
  phone,     // 手機
  tablet,    // 平板
}

/// 平台列舉
enum Platform {
  windows,
  macos,
  android,
  ipados,
}

/// 電源類型列舉
enum PowerType {
  battery,   // 有電池
  acOnly,    // 純電源供電
}
```

**驗證規則**:
- `deviceId`: 必須是有效的 UUID v4 格式
- `deviceName`: 長度 1-50 字元,不可為空
- `publicKey`: 必須是 64 字元的 hex 字串 (Ed25519 公鑰)
- `lastSeen`: 不可為未來時間
- `createdAt`: 不可為未來時間

**關聯**:
- 一個 Device 對應多筆 BatteryHistory (一對多)
- 一個 Device 對應一筆 ConnectionInfo (一對一,僅遠端裝置)

---

### 2. BatteryHistory (歷史電量記錄)

**用途**: 儲存裝置的歷史電量資料 (永久保存)

**Isar Collection 定義**:
```dart
import 'package:isar/isar.dart';

@Collection()
class BatteryHistory {
  /// 自動遞增 ID
  Id id = Isar.autoIncrement;

  /// 關聯的裝置 ID (外鍵)
  @Index(composite: [CompositeIndex('timestamp')])
  late String deviceId;

  /// 電量百分比
  /// -2: 無法取得 (READ_FAILED)
  /// -1: 純電源供電 (AC_POWER)
  /// 0-100: 實際電量百分比
  /// 驗證: 必須在 -2 到 100 之間
  late int batteryLevel;

  /// 充電狀態
  /// 可能值: charging, discharging, full, unknown
  @enumerated
  late ChargingState chargingState;

  /// 記錄時間戳記 (UTC)
  @Index()
  late DateTime timestamp;

  /// 資料來源
  /// local: 本地裝置讀取
  /// remote_p2p: 透過 P2P 連線取得
  /// remote_relay: 透過中繼伺服器取得
  @enumerated
  late DataSource source;
}

/// 充電狀態列舉
enum ChargingState {
  charging,     // 充電中
  discharging,  // 放電中
  full,         // 已充滿
  unknown,      // 無法判斷
}

/// 資料來源列舉
enum DataSource {
  local,        // 本地裝置
  remoteP2P,    // 遠端 P2P
  remoteRelay,  // 遠端中繼
}
```

**驗證規則**:
- `deviceId`: 必須對應到 Device.deviceId (外鍵約束)
- `batteryLevel`: 必須在 -2 到 100 之間
- `timestamp`: 不可為未來時間

**索引設計**:
- 複合索引: `(deviceId, timestamp)` - 優化查詢特定裝置的歷史記錄
- 單一索引: `timestamp` - 優化時間範圍查詢

**資料生命週期**:
- 保存期限: 永久 (符合 FR-015 要求)
- 壓縮策略: Isar 自動壓縮,舊資料讀取頻率低時佔用空間少
- 預估大小: 每筆記錄 ~50 bytes,單裝置每月 ~400KB (8640 筆 × 50 bytes)

---

### 3. ConnectionInfo (連線資訊)

**用途**: 記錄遠端裝置的連線狀態與重試資訊

**Isar Collection 定義**:
```dart
import 'package:isar/isar.dart';

@Collection()
class ConnectionInfo {
  /// 裝置 ID (外鍵,也作為主鍵)
  @Id()
  late String deviceId;

  /// 連線狀態
  /// connected: 已連線 (P2P 或中繼)
  /// disconnected: 已斷線
  /// retrying: 重試中 (背景自動重試)
  /// failed: 失敗 (已達最大重試次數)
  @enumerated
  late ConnectionState connectionState;

  /// 連線類型
  /// p2p: P2P 直連
  /// relay: 中繼伺服器
  /// none: 未連線
  @enumerated
  late ConnectionType connectionType;

  /// 最後成功連線時間
  DateTime? lastConnectedAt;

  /// 最後斷線時間
  DateTime? lastDisconnectedAt;

  /// 當前重試次數 (指數退避)
  /// 0: 未重試
  /// 1-10: 重試次數
  late int retryCount;

  /// 下次重試時間 (指數退避計算)
  /// null: 不需重試 (已連線或失敗)
  DateTime? nextRetryAt;

  /// Noise Protocol 會話狀態 (序列化為 JSON)
  /// null: 未建立會話
  /// 包含: 會話金鑰、nonce、序號等
  String? noiseSessionState;

  /// 更新時間
  late DateTime updatedAt;
}

/// 連線狀態列舉
enum ConnectionState {
  connected,
  disconnected,
  retrying,
  failed,
}

/// 連線類型列舉
enum ConnectionType {
  p2p,    // P2P 直連
  relay,  // 中繼伺服器
  none,   // 未連線
}
```

**驗證規則**:
- `deviceId`: 必須對應到 Device.deviceId (外鍵約束)
- `retryCount`: 必須 >= 0
- `nextRetryAt`: 若 connectionState == retrying,則不可為 null

**重試邏輯** (符合 FR-010):
```
重試間隔 (指數退避):
- 第 1 次: 5 秒
- 第 2 次: 10 秒
- 第 3 次: 20 秒
- 第 4 次: 40 秒
- 第 5 次: 80 秒
- 第 6 次及之後: 300 秒 (5 分鐘)

最大重試次數: 無上限 (持續重試直到連線成功)
```

---

## 資料關係圖

```
Device (1) ────────────── (*) BatteryHistory
   │                          (一個裝置有多筆歷史記錄)
   │
   └─────────────── (1) ConnectionInfo
                        (僅遠端裝置有連線資訊)
```

**關聯說明**:
- Device → BatteryHistory: 一對多 (透過 `deviceId` 關聯)
- Device → ConnectionInfo: 一對一 (僅遠端裝置,`deviceId` 相同)

---

## 狀態轉換

### Device.powerType 偵測邏輯

```
初始化時:
  ├─ 嘗試讀取 battery_plus.batteryLevel
  │   ├─ 成功 → powerType = battery
  │   └─ 異常 (PlatformException) → powerType = ac_only
  └─ 儲存到 Device.powerType (僅首次,後續不變)
```

### BatteryHistory.batteryLevel 邏輯

```
每 5 分鐘更新:
  ├─ Device.powerType == ac_only
  │   └─ batteryLevel = -1 (AC_POWER)
  │
  ├─ Device.powerType == battery
  │   ├─ battery_plus.batteryLevel 成功
  │   │   └─ batteryLevel = 0-100
  │   │
  │   └─ battery_plus.batteryLevel 失敗
  │       └─ batteryLevel = -2 (READ_FAILED)
```

### ConnectionInfo.connectionState 狀態機

```
disconnected ──[開始連線]──> retrying
     ↑                          │
     │                          ├─ P2P 成功 ─> connected (type=p2p)
     │                          ├─ Relay 成功 ─> connected (type=relay)
     │                          └─ 持續重試 (指數退避)
     │
     └───[連線中斷]─── connected
```

---

## 安全考量

### 私鑰儲存 (不存於 Isar)

```dart
// 私鑰僅存於平台金鑰鏈
final storage = FlutterSecureStorage();

// 儲存私鑰
await storage.write(
  key: 'device_private_key',
  value: privateKeyHex,
);

// 讀取私鑰 (僅用於簽章與解密)
String? privateKey = await storage.read(key: 'device_private_key');
```

**保護措施**:
- macOS/iOS: Keychain (需 Touch ID/Face ID 或密碼)
- Android: Keystore (硬體支援的安全區域)
- Windows: DPAPI (綁定使用者帳號)

### Isar 資料庫加密

```dart
// 從金鑰鏈讀取加密金鑰
final encryptionKey = await storage.read(key: 'isar_encryption_key');

// 開啟加密資料庫
final isar = await Isar.open(
  [DeviceSchema, BatteryHistorySchema, ConnectionInfoSchema],
  directory: dir.path,
  encryptionKey: encryptionKey, // AES-256
);
```

**保護措施**:
- 資料庫檔案以 AES-256 加密
- 加密金鑰存於平台金鑰鏈,不存於檔案系統
- 即使資料庫檔案被複製,無加密金鑰也無法讀取

### Noise Protocol 會話狀態

**注意**: `ConnectionInfo.noiseSessionState` 包含會話金鑰,需特別保護

```dart
// 會話狀態序列化時加密
String serializeNoiseSession(NoiseSession session) {
  final json = session.toJson();
  final encrypted = encryptWithIsarKey(json); // 使用 Isar 加密金鑰
  return base64.encode(encrypted);
}

// 反序列化時解密
NoiseSession deserializeNoiseSession(String encrypted) {
  final bytes = base64.decode(encrypted);
  final json = decryptWithIsarKey(bytes);
  return NoiseSession.fromJson(json);
}
```

---

## 查詢模式

### 常見查詢範例

**1. 查詢特定裝置最新電量**:
```dart
final latestBattery = await isar.batteryHistorys
  .filter()
  .deviceIdEqualTo(deviceId)
  .sortByTimestampDesc()
  .findFirst();
```

**2. 查詢裝置 30 天歷史記錄**:
```dart
final thirtyDaysAgo = DateTime.now().subtract(Duration(days: 30));
final history = await isar.batteryHistorys
  .filter()
  .deviceIdEqualTo(deviceId)
  .timestampGreaterThan(thirtyDaysAgo)
  .sortByTimestamp()
  .findAll();
```

**3. 查詢所有線上裝置**:
```dart
final onlineDevices = await isar.devices
  .filter()
  .isLocalEqualTo(false) // 僅遠端裝置
  .findAll();

// 過濾出 10 分鐘內有更新的裝置
final tenMinutesAgo = DateTime.now().subtract(Duration(minutes: 10));
final activeDevices = onlineDevices.where(
  (d) => d.lastSeen.isAfter(tenMinutesAgo)
).toList();
```

**4. 查詢需要重試的連線**:
```dart
final now = DateTime.now();
final toRetry = await isar.connectionInfos
  .filter()
  .connectionStateEqualTo(ConnectionState.retrying)
  .nextRetryAtLessThan(now)
  .findAll();
```

---

## 資料遷移策略

### 版本控制

**Version 1.0** (初始版本):
- Device, BatteryHistory, ConnectionInfo 基本結構

**未來擴充考量**:
- 新增欄位: 使用 `@Default()` 或 nullable 欄位避免破壞舊資料
- 刪除欄位: 保留欄位但標記為 deprecated,後續版本移除
- 結構變更: 使用 Isar migration API 進行資料轉換

### 範例:未來新增統計欄位

```dart
// Version 1.1 新增
@Collection()
class BatteryHistory {
  // ... 現有欄位 ...

  /// 電量變化率 (%/小時) - Version 1.1 新增
  @Default(0.0)
  late double chargeRatePerHour;
}
```

---

## 效能最佳化

### 索引策略
- `Device.deviceId`: 主鍵索引 (自動)
- `Device.publicKey`: 唯一索引 (防止重複)
- `BatteryHistory.deviceId + timestamp`: 複合索引 (優化歷史查詢)
- `BatteryHistory.timestamp`: 單一索引 (優化時間範圍查詢)

### 批次寫入
```dart
// 批次插入歷史記錄 (減少寫入次數)
await isar.writeTxn(() async {
  await isar.batteryHistorys.putAll(batchRecords);
});
```

### 分頁查詢 (長期歷史記錄)
```dart
// 分頁取得歷史記錄 (避免一次載入過多資料)
final page1 = await isar.batteryHistorys
  .filter()
  .deviceIdEqualTo(deviceId)
  .sortByTimestampDesc()
  .offset(0)
  .limit(100)
  .findAll();
```

---

## 資料一致性保證

### 交易保護

**範例: 新增裝置時同步建立 ConnectionInfo**:
```dart
await isar.writeTxn(() async {
  // 新增裝置
  await isar.devices.put(newDevice);

  // 若為遠端裝置,建立連線資訊
  if (!newDevice.isLocal) {
    final connectionInfo = ConnectionInfo()
      ..deviceId = newDevice.deviceId
      ..connectionState = ConnectionState.disconnected
      ..connectionType = ConnectionType.none
      ..retryCount = 0
      ..updatedAt = DateTime.now();

    await isar.connectionInfos.put(connectionInfo);
  }
});
```

### 完整性檢查

**啟動時檢查資料一致性**:
```dart
Future<void> validateDataIntegrity() async {
  // 檢查是否有 BatteryHistory 指向不存在的 Device
  final histories = await isar.batteryHistorys.where().findAll();
  for (final history in histories) {
    final device = await isar.devices.get(history.deviceId);
    if (device == null) {
      // 孤立記錄,刪除或修復
      await isar.writeTxn(() async {
        await isar.batteryHistorys.delete(history.id);
      });
    }
  }
}
```

---

## 測試資料範例

### Device 範例

```dart
final localDevice = Device()
  ..deviceId = '550e8400-e29b-41d4-a716-446655440000'
  ..deviceName = 'MacBook Pro'
  ..deviceType = DeviceType.laptop
  ..platform = Platform.macos
  ..powerType = PowerType.battery
  ..publicKey = 'a1b2c3d4e5f6...(64 chars)'
  ..lastSeen = DateTime.now()
  ..isLocal = true
  ..createdAt = DateTime.now();

final remoteDevice = Device()
  ..deviceId = '660e8400-e29b-41d4-a716-446655440001'
  ..deviceName = 'Samsung Galaxy S23'
  ..deviceType = DeviceType.phone
  ..platform = Platform.android
  ..powerType = PowerType.battery
  ..publicKey = 'b2c3d4e5f6...(64 chars)'
  ..lastSeen = DateTime.now().subtract(Duration(minutes: 3))
  ..isLocal = false
  ..createdAt = DateTime.now().subtract(Duration(days: 7));
```

### BatteryHistory 範例

```dart
// 正常電量記錄
final batteryRecord = BatteryHistory()
  ..deviceId = '550e8400-e29b-41d4-a716-446655440000'
  ..batteryLevel = 85
  ..chargingState = ChargingState.discharging
  ..timestamp = DateTime.now()
  ..source = DataSource.local;

// 純電源供電裝置
final acPowerRecord = BatteryHistory()
  ..deviceId = '770e8400-e29b-41d4-a716-446655440002'
  ..batteryLevel = -1 // AC_POWER
  ..chargingState = ChargingState.unknown
  ..timestamp = DateTime.now()
  ..source = DataSource.local;

// 讀取失敗
final failedRecord = BatteryHistory()
  ..deviceId = '550e8400-e29b-41d4-a716-446655440000'
  ..batteryLevel = -2 // READ_FAILED
  ..chargingState = ChargingState.unknown
  ..timestamp = DateTime.now()
  ..source = DataSource.local;
```

### ConnectionInfo 範例

```dart
// P2P 已連線
final p2pConnection = ConnectionInfo()
  ..deviceId = '660e8400-e29b-41d4-a716-446655440001'
  ..connectionState = ConnectionState.connected
  ..connectionType = ConnectionType.p2p
  ..lastConnectedAt = DateTime.now().subtract(Duration(minutes: 5))
  ..retryCount = 0
  ..updatedAt = DateTime.now();

// 重試中 (中繼模式)
final retryingConnection = ConnectionInfo()
  ..deviceId = '770e8400-e29b-41d4-a716-446655440002'
  ..connectionState = ConnectionState.retrying
  ..connectionType = ConnectionType.none
  ..lastDisconnectedAt = DateTime.now().subtract(Duration(minutes: 2))
  ..retryCount = 3
  ..nextRetryAt = DateTime.now().add(Duration(seconds: 20))
  ..updatedAt = DateTime.now();
```

---

**資料模型版本**: 1.0
**下一階段**: 根據此模型生成 API 契約 (contracts/)
