# Tasks: 跨平台裝置電量監控工具

**Input**: 設計文件來自 `/Users/seanhung/programming/others/local-assistant/specs/001-/`
**Prerequisites**: plan.md, research.md, data-model.md, contracts/, quickstart.md
**Feature Branch**: `001-`
**Date**: 2025-10-07

---

## 執行流程概述

本任務清單基於以下設計文件生成:
1. **plan.md**: 技術棧 (Flutter + Rust FFI + 信令伺服器)
2. **research.md**: 6 個關鍵技術決策 (WebRTC, Noise Protocol, Isar 等)
3. **data-model.md**: 3 個實體 (Device, BatteryHistory, ConnectionInfo)
4. **contracts/**: 4 個服務契約 (BatteryService, CryptoService, StorageService, ConnectionService) + 信令 API
5. **quickstart.md**: 10 個端到端測試場景

---

## 任務格式說明

- **[P]**: 可並行執行 (不同檔案,無相依性)
- **[SECURITY]**: 安全相關任務 (需特別審查)
- **[TEST]**: 測試任務
- **[CORE]**: 核心功能任務
- **[SERVER]**: 伺服器任務
- **[UI]**: UI 任務

---

## Phase 3.1: 專案設置 (Setup)

### 客戶端設置

- [ ] **T001** [P] 建立 Flutter 專案結構 (lib/, test/, integration_test/)
  - 路徑: 專案根目錄
  - 執行: `flutter create --org com.localassistant --platforms windows,macos,android,ios .`

- [ ] **T002** [P] 配置 Flutter 依賴 (pubspec.yaml)
  - 新增: battery_plus, flutter_webrtc, flutter_secure_storage, isar, isar_flutter_libs
  - 開發依賴: flutter_test, integration_test, isar_generator, build_runner

- [ ] **T003** [P] 配置分析選項與格式化規則
  - 路徑: analysis_options.yaml
  - 啟用: strict mode, linter rules

### Rust 模組設置

- [ ] **T004** [P] 建立 Rust FFI 專案結構 (rust/)
  - 路徑: rust/
  - 執行: `cargo new --lib rust`
  - 子模組: crypto/, identity/, ffi/

- [ ] **T005** [P] 配置 Rust 依賴 (Cargo.toml)
  - 新增: snow, ed25519-dalek, bip39, chacha20poly1305, serde

- [ ] **T006** [P] 配置 Rust FFI 綁定 (flutter_rust_bridge)
  - 設置 FFI 介面產生器
  - 配置編譯腳本 (build.rs)

### 信令伺服器設置

- [ ] **T007** [P] 建立信令伺服器專案 (signaling-server/)
  - 路徑: signaling-server/
  - 執行: `cargo new signaling-server`

- [ ] **T008** [P] 配置信令伺服器依賴 (signaling-server/Cargo.toml)
  - 新增: tokio, tungstenite, serde, serde_json, ed25519-dalek

### TURN 伺服器設置

- [ ] **T009** 建立 coturn 配置檔 (turnserver.conf)
  - 路徑: turnserver.conf
  - 配置: STUN/TURN 端口, 認證方式, 中繼範圍

---

## Phase 3.2: 測試先行 (TDD) ⚠️ 必須在實作前完成

### 契約測試 (Contract Tests)

- [ ] **T010** [P][TEST] BatteryService 契約測試
  - 路徑: test/services/battery_service_test.dart
  - 測試: getCurrentBatteryStatus(), getBatteryStatus(), batteryStatusStream, startPeriodicReporting()
  - 預期: 測試失敗 (尚未實作)

- [ ] **T011** [P][TEST] CryptoService 契約測試
  - 路徑: test/services/crypto_service_test.dart
  - 測試: generateDeviceIdentity(), performNoiseHandshake(), encryptMessage(), decryptMessage()
  - 預期: 測試失敗

- [ ] **T012** [P][TEST] StorageService 契約測試
  - 路徑: test/services/storage_service_test.dart
  - 測試: saveDevice(), getBatteryHistory(), saveConnectionInfo()
  - 預期: 測試失敗

- [ ] **T013** [P][TEST] ConnectionService 契約測試
  - 路徑: test/services/connection_service_test.dart
  - 測試: connectToDevice(), sendMessage(), onMessageReceived(), reconnect()
  - 預期: 測試失敗

- [ ] **T014** [P][TEST] Signaling API 契約測試
  - 路徑: signaling-server/tests/signaling_api_test.rs
  - 測試: register, list_devices, offer/answer, ice_candidate, heartbeat
  - 預期: 測試失敗

### 整合測試 (Integration Tests)

- [ ] **T015** [P][TEST] 場景 1: 本地電量讀取測試
  - 路徑: integration_test/battery_reading_test.dart
  - 對應: quickstart.md 場景 1
  - 驗證: 本地電量正確顯示,AC 電源裝置顯示「AC電源」

- [ ] **T016** [P][TEST] 場景 2: 裝置初始化與金鑰生成測試
  - 路徑: integration_test/device_initialization_test.dart
  - 對應: quickstart.md 場景 2
  - 驗證: Ed25519 金鑰生成,BIP39 助記詞,私鑰存金鑰鏈

- [ ] **T017** [P][TEST] 場景 3: P2P 連線建立測試
  - 路徑: integration_test/p2p_connection_test.dart
  - 對應: quickstart.md 場景 3
  - 驗證: WebRTC Offer/Answer 交換,Noise 握手完成

- [ ] **T018** [P][TEST] 場景 4: 中繼伺服器降級測試
  - 路徑: integration_test/relay_fallback_test.dart
  - 對應: quickstart.md 場景 4
  - 驗證: P2P 失敗後自動使用 TURN 中繼

- [ ] **T019** [P][TEST] 場景 5: 電量資料傳輸測試
  - 路徑: integration_test/battery_sync_test.dart
  - 對應: quickstart.md 場景 5
  - 驗證: 每 5 分鐘同步電量,資料加密傳輸

- [ ] **T020** [P][TEST] 場景 6: 斷線重連測試
  - 路徑: integration_test/reconnection_test.dart
  - 對應: quickstart.md 場景 6
  - 驗證: 指數退避重試,自動重連成功

- [ ] **T021** [P][TEST] 場景 7: 多裝置監控測試
  - 路徑: integration_test/multi_device_test.dart
  - 對應: quickstart.md 場景 7
  - 驗證: 支援 10+ 裝置,第 11 台顯示提醒

- [ ] **T022** [P][TEST] 場景 8: 歷史記錄查詢測試
  - 路徑: integration_test/history_query_test.dart
  - 對應: quickstart.md 場景 8
  - 驗證: 30 天記錄查詢 <100ms

- [ ] **T023** [P][TEST] 場景 9: 安全性驗證測試
  - 路徑: integration_test/security_test.dart
  - 對應: quickstart.md 場景 9
  - 驗證: 私鑰不洩露,簽章驗證,網路抓包無明文

- [ ] **T024** [P][TEST] 場景 10: 平台特定測試
  - 路徑: integration_test/platform_specific_test.dart
  - 對應: quickstart.md 場景 10
  - 驗證: Windows/macOS/Android/iPadOS 正確運作

---

## Phase 3.3: 資料層實作 (Data Layer)

### Isar 資料模型

- [ ] **T025** [P][CORE] 建立 Device Isar Collection
  - 路徑: lib/models/device.dart
  - 實作 data-model.md 定義的 Device 實體
  - 包含: deviceId, deviceName, deviceType, platform, publicKey, lastSeen, isLocal

- [ ] **T026** [P][CORE] 建立 BatteryHistory Isar Collection
  - 路徑: lib/models/battery_history.dart
  - 實作 data-model.md 定義的 BatteryHistory 實體
  - 包含: deviceId, batteryLevel, chargingState, timestamp, source
  - 索引: (deviceId, timestamp) 複合索引

- [ ] **T027** [P][CORE] 建立 ConnectionInfo Isar Collection
  - 路徑: lib/models/connection_info.dart
  - 實作 data-model.md 定義的 ConnectionInfo 實體
  - 包含: deviceId, connectionState, connectionType, retryCount, noiseSessionState

- [ ] **T028** 配置 Isar 資料庫加密
  - 路徑: lib/services/storage_service_impl.dart
  - 從 flutter_secure_storage 讀取加密金鑰
  - 使用 AES-256 加密資料庫

- [ ] **T029** [SECURITY] 整合 flutter_secure_storage (金鑰鏈)
  - 路徑: lib/services/storage_service_impl.dart
  - 實作私鑰儲存 (device_private_key)
  - 實作助記詞儲存 (backup_mnemonic)
  - 實作資料庫加密金鑰儲存 (isar_encryption_key)

- [ ] **T030** 產生 Isar Schema 程式碼
  - 執行: `dart run build_runner build`
  - 驗證: *.g.dart 檔案正確生成

---

## Phase 3.4: Rust FFI 模組實作 (Crypto Core)

### 金鑰管理 (identity/)

- [ ] **T031** [P][SECURITY] Rust: Ed25519 金鑰生成
  - 路徑: rust/identity/keypair.rs
  - 實作: `generate_keypair()` 函式
  - 依賴: ed25519-dalek

- [ ] **T032** [P][SECURITY] Rust: BIP39 助記詞生成
  - 路徑: rust/identity/mnemonic.rs
  - 實作: `generate_mnemonic()` (24 個單字)
  - 實作: `mnemonic_to_seed()` (種子推導)
  - 依賴: bip39

- [ ] **T033** [SECURITY] Rust: 從助記詞恢復金鑰對
  - 路徑: rust/identity/mnemonic.rs
  - 實作: `recover_keypair_from_mnemonic()`
  - 依賴: T032

### Noise Protocol 加密 (crypto/)

- [ ] **T034** [P][SECURITY] Rust: Noise Protocol 握手
  - 路徑: rust/crypto/noise_protocol.rs
  - 實作: Noise_XX 模式握手 (發起方)
  - 實作: Noise_XX 模式握手 (接收方)
  - 依賴: snow, chacha20poly1305

- [ ] **T035** [P][SECURITY] Rust: Noise 會話加密
  - 路徑: rust/crypto/session.rs
  - 實作: `encrypt_message(data, session_key)` (ChaCha20-Poly1305)
  - 實作: `decrypt_message(encrypted, session_key)`
  - 實作: Nonce 管理 (防重放攻擊)

- [ ] **T036** [P][SECURITY] Rust: Ed25519 簽章與驗證
  - 路徑: rust/crypto/signature.rs
  - 實作: `sign_message(data, private_key)`
  - 實作: `verify_signature(data, signature, public_key)`
  - 依賴: ed25519-dalek

### Flutter FFI 綁定

- [ ] **T037** [SECURITY] Rust: FFI 介面定義
  - 路徑: rust/ffi/lib.rs
  - 定義所有 Rust 函式的 FFI 綁定 (extern "C")
  - 包含: T031-T036 的所有函式

- [ ] **T038** Dart: 生成 Rust FFI 綁定
  - 路徑: lib/rust_ffi/crypto_bindings.dart
  - 使用 flutter_rust_bridge 產生 Dart 綁定
  - 驗證: 可從 Dart 呼叫 Rust 函式

- [ ] **T039** Rust: 編譯 FFI 動態庫
  - 執行: `cd rust && cargo build --release`
  - 產生: libcrypto.dylib (macOS), crypto.dll (Windows), libcrypto.so (Linux/Android)
  - 複製至 Flutter 專案對應平台目錄

---

## Phase 3.5: 服務層實作 (Service Layer)

### BatteryService 實作

- [ ] **T040** [CORE] BatteryService: 本地電量讀取
  - 路徑: lib/services/battery_service_impl.dart
  - 實作: `getCurrentBatteryStatus()` (使用 battery_plus)
  - 處理: AC 電源裝置 (batteryLevel = -1)
  - 依賴: battery_plus package

- [ ] **T041** [CORE] BatteryService: 電量變化監聽
  - 路徑: lib/services/battery_service_impl.dart
  - 實作: `batteryStatusStream` (Stream<BatteryStatus>)
  - 依賴: T040

- [ ] **T042** [CORE] BatteryService: 定期電量回報
  - 路徑: lib/services/battery_service_impl.dart
  - 實作: `startPeriodicReporting()` (每 5 分鐘)
  - 使用: Timer.periodic
  - 儲存至 StorageService
  - 依賴: T040, T028

- [ ] **T043** [CORE] BatteryService: 電源類型偵測
  - 路徑: lib/services/battery_service_impl.dart
  - 實作: `detectPowerType()` (首次啟動時呼叫)
  - 依賴: T040

- [ ] **T044** [CORE] BatteryService: 歷史記錄查詢
  - 路徑: lib/services/battery_service_impl.dart
  - 實作: `getBatteryHistory(deviceId, startDate, endDate)`
  - 從 StorageService 查詢
  - 依賴: T028

### CryptoService 實作

- [ ] **T045** [SECURITY] CryptoService: 裝置身份生成
  - 路徑: lib/services/crypto_service_impl.dart
  - 實作: `generateDeviceIdentity()` (呼叫 Rust FFI T031, T032)
  - 儲存私鑰至金鑰鏈 (T029)
  - 依賴: T031, T032, T038

- [ ] **T046** [SECURITY] CryptoService: Noise 握手
  - 路徑: lib/services/crypto_service_impl.dart
  - 實作: `performNoiseHandshake(deviceId)` (呼叫 Rust FFI T034)
  - 依賴: T034, T038

- [ ] **T047** [SECURITY] CryptoService: 訊息加密/解密
  - 路徑: lib/services/crypto_service_impl.dart
  - 實作: `encryptMessage(data)` (呼叫 Rust FFI T035)
  - 實作: `decryptMessage(encrypted)` (呼叫 Rust FFI T035)
  - 依賴: T035, T038

- [ ] **T048** [SECURITY] CryptoService: 簽章與驗證
  - 路徑: lib/services/crypto_service_impl.dart
  - 實作: `signMessage(data)` (呼叫 Rust FFI T036)
  - 實作: `verifySignature(data, signature, publicKey)` (呼叫 Rust FFI T036)
  - 依賴: T036, T038

- [ ] **T049** [SECURITY] CryptoService: 助記詞恢復
  - 路徑: lib/services/crypto_service_impl.dart
  - 實作: `recoverFromMnemonic(mnemonic)` (呼叫 Rust FFI T033)
  - 依賴: T033, T038

### StorageService 實作

- [ ] **T050** [CORE] StorageService: 裝置資料操作
  - 路徑: lib/services/storage_service_impl.dart
  - 實作: `saveDevice(device)`, `getDevice(deviceId)`, `getAllDevices()`
  - 依賴: T025, T028

- [ ] **T051** [CORE] StorageService: 電量歷史操作
  - 路徑: lib/services/storage_service_impl.dart
  - 實作: `saveBatteryHistory(history)`, `getBatteryHistory(deviceId, dateRange)`
  - 依賴: T026, T028

- [ ] **T052** [CORE] StorageService: 連線資訊操作
  - 路徑: lib/services/storage_service_impl.dart
  - 實作: `saveConnectionInfo(info)`, `getConnectionInfo(deviceId)`, `updateRetryInfo(deviceId)`
  - 依賴: T027, T028

- [ ] **T053** StorageService: 資料完整性檢查
  - 路徑: lib/services/storage_service_impl.dart
  - 實作: `validateDataIntegrity()` (啟動時執行)
  - 檢查孤立記錄 (BatteryHistory 指向不存在的 Device)
  - 依賴: T050, T051

### ConnectionService 實作

- [ ] **T054** [CORE] ConnectionService: 信令伺服器連線
  - 路徑: lib/services/connection_service_impl.dart
  - 實作: WebSocket 連線至信令伺服器
  - 實作: `register()`, `listDevices()`, `heartbeat()`
  - 依賴: tungstenite or web_socket_channel

- [ ] **T055** [CORE] ConnectionService: WebRTC P2P 連線
  - 路徑: lib/services/connection_service_impl.dart
  - 實作: `connectToDevice(deviceId)` (發送 offer)
  - 實作: `onIncomingOffer()` (接收 offer,回覆 answer)
  - 依賴: flutter_webrtc

- [ ] **T056** [CORE] ConnectionService: ICE 候選交換
  - 路徑: lib/services/connection_service_impl.dart
  - 實作: `onIceCandidate()` (發送至信令伺服器)
  - 實作: `onIncomingIceCandidate()` (接收並加入 WebRTC)
  - 依賴: T055

- [ ] **T057** [CORE] ConnectionService: Noise 加密整合
  - 路徑: lib/services/connection_service_impl.dart
  - 在 WebRTC DataChannel 上層執行 Noise 握手 (呼叫 T046)
  - 儲存會話狀態至 ConnectionInfo (T052)
  - 依賴: T055, T046

- [ ] **T058** [CORE] ConnectionService: TURN 中繼降級
  - 路徑: lib/services/connection_service_impl.dart
  - 實作: P2P 失敗後請求 TURN 憑證
  - 使用 TURN 伺服器建立中繼連線
  - 依賴: T055

- [ ] **T059** [CORE] ConnectionService: 訊息收發
  - 路徑: lib/services/connection_service_impl.dart
  - 實作: `sendMessage(deviceId, data)` (加密後透過 DataChannel 發送)
  - 實作: `onMessageReceived(encrypted)` (解密並處理)
  - 依賴: T057, T047

- [ ] **T060** [CORE] ConnectionService: 斷線重連機制
  - 路徑: lib/services/connection_service_impl.dart
  - 實作: `reconnect(deviceId)` (指數退避)
  - 實作: 重試邏輯 (5s, 10s, 20s, 40s, 80s, 300s)
  - 依賴: T055

---

## Phase 3.6: 信令伺服器實作 (Signaling Server)

- [ ] **T061** [P][SERVER] 信令伺服器: WebSocket 伺服器
  - 路徑: signaling-server/src/main.rs
  - 實作: tokio + tungstenite WebSocket 伺服器
  - 監聽: ws://localhost:8080/signaling

- [ ] **T062** [P][SERVER] 信令伺服器: 裝置註冊邏輯
  - 路徑: signaling-server/src/device.rs
  - 實作: `register()` (儲存 device_id, public_key, 線上狀態)
  - 實作: Ed25519 簽章驗證 (呼叫 ed25519-dalek)
  - 依賴: T061

- [ ] **T063** [SERVER] 信令伺服器: SDP 交換邏輯
  - 路徑: signaling-server/src/signaling.rs
  - 實作: `handleOffer()`, `handleAnswer()` (轉發 SDP)
  - 實作: `handleIceCandidate()` (轉發 ICE 候選)
  - 依賴: T062

- [ ] **T064** [P][SERVER] 信令伺服器: 裝置查詢
  - 路徑: signaling-server/src/device.rs
  - 實作: `listDevices()` (返回已註冊裝置列表)
  - 依賴: T062

- [ ] **T065** [P][SERVER] 信令伺服器: 心跳處理
  - 路徑: signaling-server/src/signaling.rs
  - 實作: `handleHeartbeat()` (更新 last_seen)
  - 實作: 離線檢測 (60 秒未心跳視為離線)
  - 依賴: T062

- [ ] **T066** [P][SERVER] 信令伺服器: TURN 憑證生成
  - 路徑: signaling-server/src/turn.rs
  - 實作: `generateTurnCredentials()` (REST API 呼叫 coturn)
  - 有效期: 1 小時
  - 依賴: coturn (T009)

- [ ] **T067** [SERVER] 信令伺服器: 錯誤處理與速率限制
  - 路徑: signaling-server/src/auth.rs
  - 實作: 簽章驗證失敗處理
  - 實作: 速率限制 (每 IP 每分鐘 60 次)
  - 依賴: T062

- [ ] **T068** [SERVER] 信令伺服器: 資料清理
  - 路徑: signaling-server/src/device.rs
  - 實作: 離線 30 天後自動刪除裝置資訊
  - 使用: tokio::time::interval (定期清理)
  - 依賴: T062

---

## Phase 3.7: UI 層實作 (User Interface)

### 主頁面

- [ ] **T069** [P][UI] 主頁面: 裝置列表 UI
  - 路徑: lib/ui/pages/device_list_page.dart
  - 顯示: 本地裝置 + 遠端裝置列表
  - 顯示: 電量百分比、充電狀態、線上狀態
  - 依賴: T040, T050

- [ ] **T070** [UI] 主頁面: 新增裝置按鈕
  - 路徑: lib/ui/pages/device_list_page.dart
  - 功能: 掃描 QR Code 或手動輸入公鑰
  - 連線至新裝置 (T055)
  - 依賴: T069

- [ ] **T071** [P][UI] 主頁面: 裝置數量提醒
  - 路徑: lib/ui/widgets/device_count_warning.dart
  - 功能: 超過 10 台裝置時顯示提醒
  - 依賴: T069

### 電量詳情頁

- [ ] **T072** [P][UI] 電量詳情頁: 即時電量顯示
  - 路徑: lib/ui/pages/battery_detail_page.dart
  - 顯示: 電量百分比、充電狀態、電源類型
  - 依賴: T040

- [ ] **T073** [UI] 電量詳情頁: 歷史記錄圖表
  - 路徑: lib/ui/widgets/battery_chart.dart
  - 顯示: 30 天電量變化圖表
  - 依賴: T044, fl_chart package

### 設定頁面

- [ ] **T074** [P][UI] 設定頁面: 助記詞顯示/備份
  - 路徑: lib/ui/pages/settings_page.dart
  - 功能: 顯示 24 個助記詞,要求使用者抄寫
  - 功能: 從助記詞恢復 (T049)
  - 依賴: T045

- [ ] **T075** [P][UI] 設定頁面: 裝置名稱編輯
  - 路徑: lib/ui/pages/settings_page.dart
  - 功能: 編輯本地裝置名稱
  - 儲存至 Device (T050)

- [ ] **T076** [P][UI] 設定頁面: 連線狀態顯示
  - 路徑: lib/ui/pages/settings_page.dart
  - 顯示: 信令伺服器連線狀態, P2P/中繼模式
  - 依賴: T054

### UI 整合

- [ ] **T077** [UI] UI: 狀態管理整合
  - 路徑: lib/ui/state/app_state.dart
  - 使用: Provider 或 Riverpod 管理全域狀態
  - 依賴: T069-T076

- [ ] **T078** [UI] UI: 主題與樣式
  - 路徑: lib/ui/theme/app_theme.dart
  - 實作: 淺色/深色主題
  - 依賴: T077

---

## Phase 3.8: 整合與打磨 (Integration & Polish)

### 背景任務

- [ ] **T079** [CORE] 背景任務: 定期電量回報
  - 路徑: lib/background/battery_reporter.dart
  - 使用: workmanager (Android) 或 background_fetch (iOS)
  - 每 5 分鐘執行 T042
  - 依賴: T042

- [ ] **T080** [CORE] 背景任務: 自動重連
  - 路徑: lib/background/reconnection_worker.dart
  - 定期檢查 ConnectionInfo.nextRetryAt,執行重連
  - 依賴: T060

### 效能最佳化

- [ ] **T081** [P] 效能: Isar 批次寫入
  - 路徑: lib/services/storage_service_impl.dart
  - 優化: 使用 `isar.writeTxn()` 批次插入歷史記錄
  - 依賴: T051

- [ ] **T082** [P] 效能: 歷史記錄分頁查詢
  - 路徑: lib/services/storage_service_impl.dart
  - 優化: `getBatteryHistory()` 使用 offset/limit 分頁
  - 依賴: T051

### 錯誤處理

- [ ] **T083** 錯誤處理: 全域錯誤捕捉
  - 路徑: lib/main.dart
  - 實作: FlutterError.onError, PlatformDispatcher.instance.onError
  - 記錄至日誌 (不包含私鑰)

- [ ] **T084** 錯誤處理: 網路錯誤重試
  - 路徑: lib/services/connection_service_impl.dart
  - 實作: 網路斷線時自動重試邏輯
  - 依賴: T060

### 日誌與除錯

- [ ] **T085** [P] 日誌: 結構化日誌
  - 路徑: lib/utils/logger.dart
  - 使用: logger package
  - 確保: 不記錄私鑰或敏感資料

- [ ] **T086** [P] 日誌: 錯誤上報
  - 路徑: lib/utils/error_reporter.dart
  - 選用: Sentry 或 Firebase Crashlytics
  - 確保: 不上報私鑰

---

## Phase 3.9: 測試驗證 (Testing & Validation)

### 單元測試

- [ ] **T087** [P][TEST] 單元測試: Device 模型
  - 路徑: test/models/device_test.dart
  - 測試: 驗證規則 (deviceId UUID 格式, publicKey 長度)
  - 依賴: T025

- [ ] **T088** [P][TEST] 單元測試: BatteryHistory 模型
  - 路徑: test/models/battery_history_test.dart
  - 測試: batteryLevel 範圍 (-2 到 100)
  - 依賴: T026

- [ ] **T089** [P][TEST] 單元測試: Noise Protocol
  - 路徑: rust/crypto/tests/noise_test.rs
  - 測試: 握手成功,加密/解密正確
  - 依賴: T034, T035

- [ ] **T090** [P][TEST] 單元測試: Ed25519 簽章
  - 路徑: rust/crypto/tests/signature_test.rs
  - 測試: 簽章生成與驗證
  - 依賴: T036

### 契約測試驗證

- [ ] **T091** [TEST] 驗證所有契約測試通過
  - 執行: `flutter test test/services/`
  - 預期: T010-T013 測試全部通過
  - 依賴: T040-T060

- [ ] **T092** [TEST] 驗證信令 API 契約測試通過
  - 執行: `cd signaling-server && cargo test`
  - 預期: T014 測試全部通過
  - 依賴: T061-T068

### 整合測試驗證

- [ ] **T093** [TEST] 執行所有整合測試
  - 執行: `flutter test integration_test/`
  - 預期: T015-T024 測試全部通過
  - 依賴: T040-T086

### 效能測試

- [ ] **T094** [P][TEST] 效能測試: 電量顯示延遲
  - 驗證: <200ms (Performance Goals)
  - 使用: Flutter DevTools Timeline
  - 依賴: T072

- [ ] **T095** [P][TEST] 效能測試: P2P 連線建立時間
  - 驗證: <2s (Performance Goals)
  - 依賴: T055

- [ ] **T096** [P][TEST] 效能測試: 歷史記錄查詢
  - 驗證: 30 天記錄查詢 <100ms (Performance Goals)
  - 依賴: T044

- [ ] **T097** [P][TEST] 效能測試: TURN 中繼延遲
  - 驗證: <500ms (Performance Goals)
  - 依賴: T058

### 安全測試

- [ ] **T098** [TEST][SECURITY] 安全測試: 私鑰保護驗證
  - 驗證: 私鑰僅存於金鑰鏈,不在 Isar 或日誌
  - 工具: 檢查 Isar 資料庫檔案,搜尋日誌檔案
  - 依賴: T029, T085

- [ ] **T099** [TEST][SECURITY] 安全測試: 網路抓包驗證
  - 驗證: Wireshark 抓包顯示 DTLS 加密,無明文電量
  - 依賴: T055, T057

- [ ] **T100** [TEST][SECURITY] 安全測試: 簽章偽造測試
  - 驗證: 偽造簽章時信令伺服器拒絕請求
  - 依賴: T062, T067

### 平台測試

- [ ] **T101** [P][TEST] 平台測試: Windows 電量讀取
  - 執行: `flutter run -d windows`
  - 驗證: 筆電正確顯示電量,桌機顯示「AC電源」
  - 依賴: T040

- [ ] **T102** [P][TEST] 平台測試: macOS 電量讀取
  - 執行: `flutter run -d macos`
  - 驗證: MacBook 正確顯示電量,iMac 顯示「AC電源」
  - 依賴: T040

- [ ] **T103** [P][TEST] 平台測試: Android 電量讀取
  - 執行: `flutter run -d android`
  - 驗證: 手機電量正確,背景任務運作
  - 依賴: T040, T079

- [ ] **T104** [P][TEST] 平台測試: iPadOS 電量讀取
  - 執行: `flutter run -d ipad`
  - 驗證: iPad 電量正確,背景任務運作
  - 依賴: T040, T079

---

## Phase 3.10: 文件與發布 (Documentation & Release)

### 文件

- [ ] **T105** [P] 文件: API 文件產生
  - 執行: `dart doc`
  - 產生: doc/ 目錄下的 API 文件
  - 依賴: T040-T060

- [ ] **T106** [P] 文件: 使用者手冊
  - 路徑: docs/user_guide.md
  - 內容: 安裝、首次設定、新增裝置、備份助記詞

- [ ] **T107** [P] 文件: 開發者文件
  - 路徑: docs/developer_guide.md
  - 內容: 架構圖、模組說明、擴充指南

### 發布準備

- [ ] **T108** 發布: 版本號設定
  - 路徑: pubspec.yaml, Cargo.toml
  - 設定: version: 1.0.0

- [ ] **T109** 發布: 建置各平台應用
  - Windows: `flutter build windows --release`
  - macOS: `flutter build macos --release`
  - Android: `flutter build apk --release`
  - iOS: `flutter build ios --release`

- [ ] **T110** 發布: 程式碼簽章 (macOS/iOS)
  - macOS: 使用 Developer ID 簽章
  - iOS: 使用 Distribution 證書簽章

- [ ] **T111** 發布: 建置信令伺服器 Docker 映像
  - 路徑: signaling-server/Dockerfile
  - 執行: `docker build -t signaling-server:1.0.0 .`

- [ ] **T112** 發布: 部署 TURN 伺服器
  - 配置 coturn 於正式環境
  - 設定 SSL 憑證 (Let's Encrypt)

---

## 相依性圖

### 關鍵相依路徑

```
設置階段:
T001-T009 (可並行) → 所有後續任務

測試先行:
T010-T024 (可並行) → T091-T093 (驗證)

資料層:
T025-T027 (可並行) → T028 → T029 → T030

Rust FFI:
T031-T036 (部分可並行) → T037 → T038 → T039

服務層:
T040-T044 (BatteryService) 依賴 T030, T039
T045-T049 (CryptoService) 依賴 T039
T050-T053 (StorageService) 依賴 T030
T054-T060 (ConnectionService) 依賴 T039, T050

伺服器:
T061-T068 (部分可並行) 依賴 T009

UI:
T069-T078 依賴 T040-T060

整合:
T079-T086 依賴 T040-T060

驗證:
T087-T104 依賴所有實作任務
```

---

## 並行執行範例

### 設置階段 (可並行執行 T001-T009)

```bash
# 在 Claude Code 中執行:
Task: "建立 Flutter 專案結構 (T001)"
Task: "配置 Flutter 依賴 (T002)"
Task: "配置分析選項與格式化規則 (T003)"
Task: "建立 Rust FFI 專案結構 (T004)"
Task: "配置 Rust 依賴 (T005)"
Task: "配置 Rust FFI 綁定 (T006)"
Task: "建立信令伺服器專案 (T007)"
Task: "配置信令伺服器依賴 (T008)"
```

### 契約測試 (可並行執行 T010-T014)

```bash
Task: "BatteryService 契約測試 (T010)"
Task: "CryptoService 契約測試 (T011)"
Task: "StorageService 契約測試 (T012)"
Task: "ConnectionService 契約測試 (T013)"
Task: "Signaling API 契約測試 (T014)"
```

### 整合測試 (可並行執行 T015-T024)

```bash
Task: "場景 1: 本地電量讀取測試 (T015)"
Task: "場景 2: 裝置初始化與金鑰生成測試 (T016)"
Task: "場景 3: P2P 連線建立測試 (T017)"
# ... 其他場景測試
```

### 資料模型 (可並行執行 T025-T027)

```bash
Task: "建立 Device Isar Collection (T025)"
Task: "建立 BatteryHistory Isar Collection (T026)"
Task: "建立 ConnectionInfo Isar Collection (T027)"
```

### Rust FFI (可並行執行 T031-T036 中的獨立任務)

```bash
Task: "Rust: Ed25519 金鑰生成 (T031)"
Task: "Rust: BIP39 助記詞生成 (T032)"
Task: "Rust: Noise Protocol 握手 (T034)"
Task: "Rust: Noise 會話加密 (T035)"
Task: "Rust: Ed25519 簽章與驗證 (T036)"
```

---

## 驗收清單

根據 quickstart.md 的驗收標準,完成以下檢查:

- [ ] **場景 1**: 本地裝置電量正確顯示 (T015, T040, T069, T072)
- [ ] **場景 2**: 裝置身份正確生成,私鑰安全儲存 (T016, T045, T029)
- [ ] **場景 3**: P2P 連線成功建立,資料加密傳輸 (T017, T055, T057)
- [ ] **場景 4**: P2P 失敗時自動降級至中繼模式 (T018, T058)
- [ ] **場景 5**: 電量資料每 5 分鐘同步,歷史記錄儲存 (T019, T042, T051)
- [ ] **場景 6**: 斷線後自動重連,指數退避策略正確 (T020, T060)
- [ ] **場景 7**: 支援 10+ 台裝置,顯示提醒訊息 (T021, T071)
- [ ] **場景 8**: 歷史記錄查詢效能 <100ms (T022, T044, T096)
- [ ] **場景 9**: 私鑰不洩露,資料加密傳輸 (T023, T098, T099)
- [ ] **場景 10**: 四個平台正常運作 (T024, T101-T104)
- [ ] **效能**: 電量顯示 <200ms, P2P 連線 <2s, 中繼延遲 <500ms (T094-T097)
- [ ] **安全**: 簽章驗證,防重放攻擊,TURN 憑證時效 (T098-T100)
- [ ] **背景**: 定期回報與自動重連正常運作 (T079, T080)
- [ ] **憲章**: 所有安全要求符合 constitution.md (T029, T045-T049, T098-T100)

---

## 預估時程

- **Phase 3.1 設置**: 1 天 (T001-T009)
- **Phase 3.2 測試先行**: 2 天 (T010-T024)
- **Phase 3.3 資料層**: 2 天 (T025-T030)
- **Phase 3.4 Rust FFI**: 5 天 (T031-T039)
- **Phase 3.5 服務層**: 7 天 (T040-T060)
- **Phase 3.6 信令伺服器**: 4 天 (T061-T068)
- **Phase 3.7 UI 層**: 4 天 (T069-T078)
- **Phase 3.8 整合與打磨**: 3 天 (T079-T086)
- **Phase 3.9 測試驗證**: 4 天 (T087-T104)
- **Phase 3.10 文件與發布**: 2 天 (T105-T112)

**總計**: 約 34 天 (可透過並行執行縮短至 20-25 天)

---

## 執行指南

1. **嚴格遵循 TDD**: Phase 3.2 測試必須先於 Phase 3.3-3.8 實作
2. **安全任務優先審查**: 所有 [SECURITY] 標記任務需額外驗證
3. **並行任務**: 標記 [P] 的任務可使用 Task tool 並行執行
4. **依賴順序**: 嚴格遵循相依性圖,避免循環依賴
5. **憲章檢查**: 實作時持續參考 constitution.md,確保符合安全原則
6. **效能驗證**: 實作完成後執行 T094-T097 效能測試
7. **平台測試**: 每個平台都需通過 T101-T104 測試
8. **文件同步**: 實作時同步更新程式碼註解與 docs/

---

**任務清單產生時間**: 2025-10-07
**下一步**: 執行 Phase 3.1 設置任務 (T001-T009)
**快速開始**: 執行 `flutter create --org com.localassistant --platforms windows,macos,android,ios .`
