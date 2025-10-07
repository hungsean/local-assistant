# Quickstart Guide: 跨平台裝置電量監控工具

**Feature**: 001- 跨平台裝置電量監控工具
**Date**: 2025-10-07
**Purpose**: 快速驗證功能實作是否符合規格要求

---

## 概述

本文件提供端到端測試場景,用於驗證系統功能是否符合 [spec.md](./spec.md) 定義的所有功能需求與驗收標準。

**測試範圍**:
- ✅ 本地電量讀取 (FR-001, FR-002)
- ✅ 跨平台支援 (FR-003)
- ✅ P2P 連線與加密 (FR-013)
- ✅ 中繼伺服器降級 (FR-013)
- ✅ 歷史記錄儲存 (FR-015)
- ✅ 裝置身份管理 (FR-012, FR-017)
- ✅ 錯誤處理 (FR-009, FR-010)

---

## 前置準備

### 環境需求

**開發環境**:
- Flutter 3.24+
- Dart 3.5+
- Rust 1.75+ (用於 FFI 模組)
- Xcode 15+ (macOS/iOS 開發)
- Android Studio (Android 開發)

**執行環境**:
- Windows 10+ / macOS 11+ / Android 10+ / iPadOS 14+
- 網路連線 (用於測試 P2P 與中繼模式)

**信令伺服器**:
```bash
# 啟動本地測試伺服器
cd signaling-server
cargo run --release

# 預設監聽 ws://localhost:8080/signaling
```

**TURN 伺服器** (可選,測試中繼模式時需要):
```bash
# 啟動 coturn
turnserver -c turnserver.conf
```

---

## 場景 1: 本地電量讀取

**對應需求**: FR-001, FR-002, FR-003, FR-009

**步驟**:
1. 在本地裝置啟動應用
2. 檢查 UI 顯示本地裝置電量百分比
3. 檢查充電狀態顯示 (充電中/未充電/已充滿)

**預期結果**:
```dart
// 有電池的裝置 (筆電、手機、平板)
BatteryStatus {
  deviceId: "本地裝置 UUID",
  batteryLevel: 0-100,
  chargingState: ChargingState.charging/discharging/full,
  powerType: PowerType.battery,
}

// 純電源供電裝置 (桌機、虛擬機)
BatteryStatus {
  deviceId: "本地裝置 UUID",
  batteryLevel: -1, // AC_POWER
  chargingState: ChargingState.unknown,
  powerType: PowerType.acOnly,
}
```

**驗證命令**:
```bash
# Flutter 整合測試
flutter test integration_test/battery_reading_test.dart

# 預期輸出
# ✅ 本地電量讀取成功
# ✅ 充電狀態正確顯示
# ✅ AC 電源裝置顯示「AC電源」
```

**邊緣案例測試**:
- [ ] 在虛擬機上執行,驗證顯示「AC電源」
- [ ] 插拔充電器,驗證狀態即時更新
- [ ] 在 Android 上測試,確認 BatteryManager API 正常運作

---

## 場景 2: 裝置初始化與金鑰生成

**對應需求**: FR-012, FR-017

**步驟**:
1. 首次啟動應用
2. 應用自動生成 Ed25519 金鑰對
3. 顯示 24 個 BIP39 助記詞,要求使用者抄寫
4. 驗證使用者已抄寫 (輸入部分助記詞確認)
5. 金鑰儲存至平台金鑰鏈

**預期結果**:
```dart
// 生成的身份資訊
Device {
  deviceId: "UUID v4",
  deviceName: "使用者裝置名稱 (可編輯)",
  publicKey: "64 字元 hex 字串",
  platform: Platform.macos/windows/android/ipados,
  powerType: PowerType.battery/acOnly,
  isLocal: true,
}

// 私鑰儲存位置
flutter_secure_storage:
  - key: "device_private_key"
  - value: "64 字元 hex 私鑰"
  - key: "backup_mnemonic"
  - value: "24 個助記詞 (空格分隔)"
```

**驗證命令**:
```bash
# 單元測試
flutter test test/crypto_service_test.dart

# 預期輸出
# ✅ Ed25519 金鑰對生成成功
# ✅ BIP39 助記詞有效 (24 個英文單字)
# ✅ 私鑰儲存至金鑰鏈
# ✅ 從助記詞恢復金鑰對成功
```

**手動測試**:
- [ ] 在 macOS 上,使用 Keychain Access 查看私鑰
- [ ] 在 Android 上,確認私鑰儲存在 Keystore
- [ ] 重新安裝應用,測試「從助記詞恢復」功能

---

## 場景 3: P2P 連線建立

**對應需求**: FR-013, FR-004

**步驟**:
1. 啟動兩個裝置 (A 與 B),兩者在同一區域網路
2. 裝置 A 與 B 分別註冊至信令伺服器
3. 裝置 A 發送連線請求至裝置 B
4. 驗證 WebRTC Offer/Answer 交換
5. 驗證 Noise Protocol 握手完成
6. 驗證 P2P DataChannel 建立成功

**預期結果**:
```dart
// ConnectionInfo (裝置 B 在裝置 A 的資料庫)
ConnectionInfo {
  deviceId: "裝置 B UUID",
  connectionState: ConnectionState.connected,
  connectionType: ConnectionType.p2p, // P2P 直連
  lastConnectedAt: DateTime.now(),
  noiseSessionState: "序列化的 Noise 會話狀態",
}
```

**驗證命令**:
```bash
# 整合測試
flutter test integration_test/p2p_connection_test.dart

# 預期輸出
# ✅ 信令伺服器連線成功
# ✅ WebRTC Offer/Answer 交換成功
# ✅ ICE 候選交換成功
# ✅ Noise_XX 握手完成
# ✅ P2P DataChannel 狀態: open
```

**網路抓包驗證** (確認加密):
```bash
# 使用 Wireshark 抓取 WebRTC 流量
# 預期看到:
# - DTLS 加密的 WebRTC 流量 (無法解密)
# - 無明文電量資料
```

**效能驗證**:
- [ ] P2P 連線建立時間 < 2 秒 (符合 Performance Goals)
- [ ] DataChannel 延遲 < 50ms (區域網路)

---

## 場景 4: 中繼伺服器降級

**對應需求**: FR-013

**步驟**:
1. 啟動兩個裝置 (A 與 B),兩者在不同網路 (模擬 NAT 阻擋)
2. 裝置 A 嘗試 P2P 連線至裝置 B
3. P2P 直連失敗後,自動請求 TURN 憑證
4. 使用 TURN 中繼伺服器轉發流量
5. 驗證資料仍為加密狀態 (伺服器無法解密)

**預期結果**:
```dart
ConnectionInfo {
  deviceId: "裝置 B UUID",
  connectionState: ConnectionState.connected,
  connectionType: ConnectionType.relay, // 中繼模式
  lastConnectedAt: DateTime.now(),
}
```

**驗證命令**:
```bash
# 模擬 NAT 阻擋
# 在防火牆規則中阻擋 UDP 3478 端口 (WebRTC)

flutter test integration_test/relay_fallback_test.dart

# 預期輸出
# ✅ P2P 直連失敗
# ✅ 請求 TURN 憑證成功
# ✅ TURN 中繼連線建立成功
# ✅ 延遲 < 500ms (符合 Performance Goals)
```

**TURN 伺服器日誌驗證**:
```
# coturn 日誌應顯示:
# - 裝置 A 與 B 透過 TURN 轉發流量
# - 流量為加密狀態 (DTLS)
# - TURN 伺服器無法解密內容
```

---

## 場景 5: 電量資料傳輸

**對應需求**: FR-005, FR-006, FR-015

**步驟**:
1. 裝置 A 與 B 已建立 P2P 連線
2. 裝置 A 每 5 分鐘發送電量資料至裝置 B
3. 裝置 B 接收資料,解密後儲存至 Isar 資料庫
4. 驗證歷史記錄正確儲存

**傳輸資料格式** (Noise 加密前):
```json
{
  "type": "battery_update",
  "device_id": "裝置 A UUID",
  "battery_level": 85,
  "charging_state": "discharging",
  "timestamp": "2025-10-07T14:30:00Z"
}
```

**預期結果**:
```dart
// 裝置 B 的 Isar 資料庫
BatteryHistory {
  deviceId: "裝置 A UUID",
  batteryLevel: 85,
  chargingState: ChargingState.discharging,
  timestamp: DateTime.parse("2025-10-07T14:30:00Z"),
  source: DataSource.remoteP2P, // 來自 P2P
}
```

**驗證命令**:
```bash
flutter test integration_test/battery_sync_test.dart

# 預期輸出
# ✅ 每 5 分鐘發送電量資料
# ✅ 資料加密傳輸 (Noise Protocol)
# ✅ 接收方成功解密
# ✅ 歷史記錄儲存成功
# ✅ 查詢歷史記錄 < 100ms (符合 Performance Goals)
```

**資料庫驗證**:
```dart
// 查詢裝置 A 的歷史記錄
final history = await isar.batteryHistorys
  .filter()
  .deviceIdEqualTo("裝置 A UUID")
  .sortByTimestampDesc()
  .findAll();

// 預期:
// - 每 5 分鐘有一筆記錄
// - timestamp 正確排序
// - source 為 DataSource.remoteP2P
```

---

## 場景 6: 斷線重連

**對應需求**: FR-010

**步驟**:
1. 裝置 A 與 B 已建立連線
2. 模擬網路中斷 (關閉 Wi-Fi)
3. 驗證裝置 A 進入重試狀態 (指數退避)
4. 恢復網路
5. 驗證自動重連成功

**預期狀態轉換**:
```
connected → disconnected (網路中斷)
          ↓
     retrying (5s 後首次重試)
          ↓
     retrying (10s 後第二次重試)
          ↓
     connected (重連成功)
```

**預期結果**:
```dart
// 斷線後
ConnectionInfo {
  connectionState: ConnectionState.retrying,
  retryCount: 3,
  nextRetryAt: DateTime.now().add(Duration(seconds: 20)),
}

// 重連成功後
ConnectionInfo {
  connectionState: ConnectionState.connected,
  retryCount: 0, // 重置
  lastConnectedAt: DateTime.now(),
}
```

**驗證命令**:
```bash
flutter test integration_test/reconnection_test.dart

# 預期輸出
# ✅ 斷線後進入 retrying 狀態
# ✅ 重試間隔符合指數退避 (5s, 10s, 20s, ...)
# ✅ 重連成功後重置 retryCount
# ✅ 持續重試直到連線成功 (符合 FR-010)
```

---

## 場景 7: 多裝置監控

**對應需求**: FR-006, FR-007, FR-016

**步驟**:
1. 裝置 A 連線至 10 台遠端裝置 (B1-B10)
2. 驗證 UI 顯示所有裝置列表
3. 新增第 11 台裝置,驗證顯示提醒訊息
4. 查詢各裝置最新電量資訊

**預期 UI 顯示**:
```
裝置列表:
┌──────────────────────────────────────────┐
│ MacBook Pro (本機)           85% ⚡充電中 │
│ Samsung S23                  72% 🔋放電中 │
│ iPad Pro                     45% 🔋放電中 │
│ ... (共 10 台)                            │
│                                          │
│ [新增裝置] ← 新增第 11 台時顯示提醒       │
└──────────────────────────────────────────┘

⚠️ 提醒:您已監控超過 10 台裝置,可能影響效能
```

**驗證命令**:
```bash
flutter test integration_test/multi_device_test.dart

# 預期輸出
# ✅ 支援無上限裝置數 (測試 20 台)
# ✅ 第 11 台裝置新增時顯示提醒
# ✅ 查詢所有裝置電量 < 500ms
# ✅ UI 流暢度 60 FPS
```

**效能監控**:
```bash
# 使用 Flutter DevTools 監控
# - 記憶體佔用 < 100MB (10 台裝置)
# - CPU 使用率 < 10% (背景運行)
# - UI 渲染幀率 60 FPS
```

---

## 場景 8: 歷史記錄查詢

**對應需求**: FR-015

**步驟**:
1. 查詢裝置 A 最近 30 天的歷史記錄
2. 驗證記錄數量正確 (每 5 分鐘一筆 ≈ 8640 筆)
3. 驗證查詢效能 < 100ms

**查詢範例**:
```dart
final thirtyDaysAgo = DateTime.now().subtract(Duration(days: 30));
final history = await storageService.getBatteryHistory(
  deviceId: 'xxx',
  startDate: thirtyDaysAgo,
);

// 預期結果
print(history.length); // ≈ 8640 筆
print(history.first.timestamp); // 30 天前
print(history.last.timestamp); // 現在
```

**驗證命令**:
```bash
flutter test test/storage_service_test.dart

# 預期輸出
# ✅ 30 天歷史記錄查詢 < 100ms
# ✅ 記錄按時間正序排列
# ✅ 資料完整性驗證通過
```

**資料庫效能測試**:
```dart
// 插入 10000 筆測試資料
final stopwatch = Stopwatch()..start();
for (var i = 0; i < 10000; i++) {
  await isar.batteryHistorys.put(testRecord);
}
stopwatch.stop();
print('插入 10000 筆耗時: ${stopwatch.elapsedMilliseconds}ms');
// 預期 < 1000ms
```

---

## 場景 9: 安全性驗證

**對應需求**: FR-012, FR-013, FR-014

**測試項目**:

### 9.1 私鑰保護
```bash
# 驗證私鑰不存在於 Isar 資料庫
flutter test test/security_test.dart

# 預期輸出
# ✅ 私鑰僅存在於金鑰鏈
# ✅ Isar 資料庫不包含私鑰
# ✅ 日誌不包含私鑰
```

### 9.2 加密驗證
```bash
# 使用 Wireshark 抓包
# 預期看到:
# - WebRTC 流量為 DTLS 加密
# - 無明文電量資料
# - 無私鑰洩露
```

### 9.3 簽章驗證
```dart
// 測試偽造訊息
final fakeMessage = {
  'type': 'battery_update',
  'battery_level': 100,
};
final invalidSignature = 'invalid_signature';

// 預期結果
final result = await cryptoService.verifySignature(
  message: fakeMessage,
  signature: invalidSignature,
  publicKey: devicePublicKey,
);
assert(result == false); // 簽章驗證失敗
```

---

## 場景 10: 平台特定測試

### Windows 平台
```bash
# 測試 WMI 電池 API
flutter run -d windows

# 驗證:
# - 筆電正確顯示電量
# - 桌機顯示「AC電源」
# - 充電狀態正確更新
```

### macOS 平台
```bash
# 測試 IOKit 電池 API
flutter run -d macos

# 驗證:
# - MacBook 正確顯示電量
# - iMac 顯示「AC電源」
# - 金鑰儲存於 Keychain
```

### Android 平台
```bash
# 測試 BatteryManager API
flutter run -d android

# 驗證:
# - 手機電量正確顯示
# - 充電狀態正確
# - 金鑰儲存於 Keystore
# - 背景任務正常運行
```

### iPadOS 平台
```bash
# 測試 UIDevice 電池 API
flutter run -d ipad

# 驗證:
# - iPad 電量正確顯示
# - 金鑰儲存於 Keychain
# - 背景任務正常運行 (受 iOS 限制)
```

---

## 自動化測試執行

**完整測試套件**:
```bash
# 執行所有測試
./run_all_tests.sh

# 包含:
# - 單元測試 (flutter test)
# - 整合測試 (flutter test integration_test/)
# - 契約測試 (驗證 API 介面)
# - 平台測試 (Windows/macOS/Android/iPadOS)
```

**預期測試報告**:
```
✅ 單元測試: 120/120 通過
✅ 整合測試: 45/45 通過
✅ 契約測試: 15/15 通過
✅ 平台測試: 4/4 通過
✅ 總計: 184/184 通過
```

---

## 疑難排解

### 問題 1: P2P 連線失敗

**症狀**: 兩台裝置無法建立 P2P 連線

**排查步驟**:
1. 檢查防火牆是否阻擋 UDP 流量
2. 檢查信令伺服器是否正常運行
3. 檢查 ICE 候選是否交換成功
4. 檢查 STUN/TURN 伺服器是否可達

**解決方案**:
- 關閉防火牆或開放 UDP 端口
- 確認 TURN 伺服器配置正確

### 問題 2: 電量讀取失敗

**症狀**: batteryLevel 顯示 -2 (READ_FAILED)

**排查步驟**:
1. 檢查平台權限 (Android 需 BATTERY_STATS 權限)
2. 檢查 battery_plus 版本是否最新
3. 檢查裝置是否支援電池 API

**解決方案**:
- 在 AndroidManifest.xml 加入權限
- 更新 battery_plus 至最新版

---

## 驗收清單

根據 [spec.md](./spec.md) 的驗收標準,完成以下檢查:

- [ ] **場景 1**: 本地裝置電量正確顯示 (FR-001, FR-002)
- [ ] **場景 2**: 裝置身份正確生成,私鑰安全儲存 (FR-012)
- [ ] **場景 3**: P2P 連線成功建立,資料加密傳輸 (FR-013)
- [ ] **場景 4**: P2P 失敗時自動降級至中繼模式 (FR-013)
- [ ] **場景 5**: 電量資料每 5 分鐘同步,歷史記錄儲存 (FR-005, FR-015)
- [ ] **場景 6**: 斷線後自動重連,指數退避策略正確 (FR-010)
- [ ] **場景 7**: 支援 10+ 台裝置,顯示提醒訊息 (FR-016)
- [ ] **場景 8**: 歷史記錄查詢效能 < 100ms (Performance Goals)
- [ ] **場景 9**: 私鑰不洩露,資料加密傳輸 (FR-012, FR-013, FR-014)
- [ ] **場景 10**: 四個平台 (Windows/macOS/Android/iPadOS) 正常運作 (FR-003)

---

**測試完成時間**: TBD (Phase 4 實作完成後)
**測試執行者**: TBD
**測試環境**: TBD

---

**下一步**: 執行 /tasks 命令生成實作任務清單
