# local-assistant Development Guidelines

Auto-generated from all feature plans. Last updated: 2025-10-07

## Active Technologies

### Feature 001- (跨平台裝置電量監控工具)
- **客戶端**: Flutter 3.24+ / Dart 3.5+
- **加密核心 (FFI)**: Rust 1.75+ (snow, ed25519-dalek, bip39, chacha20poly1305)
- **伺服器**: Rust 1.75+ (tokio, tungstenite, serde), coturn (TURN 伺服器)
- **主要套件**: battery_plus, flutter_webrtc, flutter_secure_storage, isar
- **平台支援**: Windows 10+, macOS 11+, Android 10+, iPadOS 14+
- **加密協定**: Noise Protocol Framework (Noise_XX), WebRTC (DTLS-SRTP)

## Project Structure

```
# 客戶端 (Flutter)
lib/
├── models/          # 資料模型 (Device, BatteryHistory, ConnectionInfo)
├── services/        # 服務層 (BatteryService, CryptoService, StorageService, ConnectionService)
├── ui/              # UI 層 (Flutter Widgets)
└── rust_ffi/        # Rust FFI 綁定

# Rust 加密核心
rust/
├── crypto/          # Noise Protocol 實作
├── identity/        # 金鑰管理與 BIP39
└── ffi/             # Flutter FFI 介面

# 信令伺服器 (Rust)
signaling-server/
├── src/
│   ├── signaling.rs # WebSocket 信令邏輯
│   ├── device.rs    # 裝置註冊管理
│   └── auth.rs      # Ed25519 簽章驗證
└── Cargo.toml

# 測試
test/                # Flutter 單元測試
integration_test/    # Flutter 整合測試
```

## Commands

```bash
# 客戶端開發
flutter pub get                    # 安裝依賴
flutter run -d macos              # 執行 (macOS)
flutter run -d windows            # 執行 (Windows)
flutter run -d android            # 執行 (Android)
flutter test                      # 單元測試
flutter test integration_test/    # 整合測試

# Rust FFI 模組
cd rust
cargo build --release             # 編譯 Rust 模組
cargo test                        # Rust 測試

# 信令伺服器
cd signaling-server
cargo run --release               # 啟動伺服器 (ws://localhost:8080/signaling)
cargo test                        # 伺服器測試

# TURN 伺服器
turnserver -c turnserver.conf     # 啟動 coturn
```

## Code Style

### Dart (Flutter)
- 使用 `flutter analyze` 檢查程式碼
- 遵循 [Effective Dart](https://dart.dev/guides/language/effective-dart) 規範
- 使用 Result<T, E> 類型處理錯誤 (不使用 throw)
- 服務層方法必須為 async,返回 Future 或 Stream

### Rust
- 使用 `cargo fmt` 格式化程式碼
- 使用 `cargo clippy` 檢查警告
- FFI 介面必須使用 #[no_mangle] 和 extern "C"
- 錯誤處理使用 Result<T, anyhow::Error>

### 安全要求 (憲章)
- ❌ 私鑰絕不離開裝置,不得寫入日誌或資料庫
- ✅ 所有加密使用憲章指定演算法 (Ed25519, X25519, ChaCha20-Poly1305)
- ✅ 資料傳輸必須端到端加密 (Noise Protocol)
- ✅ Isar 資料庫使用 AES-256 加密,金鑰存於平台金鑰鏈

## 術語表 (Glossary)

| 術語 (Term) | 英文 (English) | 說明 (Description) |
| --- | --- | --- |
| 裝置 | Device | 代表一個實體裝置，擁有唯一的身份和金鑰。 |
| 電量狀態 | Battery Status | 裝置的即時電量資訊，包含百分比和充電狀態。 |
| 連線資訊 | Connection Info | 儲存裝置間連線狀態的資訊，包含 P2P、中繼等。 |
| 點對點 | P2P (Peer-to-Peer) | 裝置間直接通訊，不透過中央伺服器轉發。 |
| 中繼 | Relay | 當 P2P 連線失敗時，透過 TURN 伺服器轉發加密資料。 |
| 信令伺服器 | Signaling Server | 協助裝置交換連線資訊 (IP位址、公鑰) 以建立 P2P 連線的伺服器。 |
| TURN 伺服器 | TURN Server | 提供中繼 (Relay) 功能的伺服器，通常使用 coturn 實作。 |
| Noise 協定 | Noise Protocol | 用於建立端到端加密通道的密碼學協定框架。 |
| 外部函式介面 | FFI (Foreign Function Interface) | 允許一個程式語言呼叫另一個語言的函式，此專案用於 Dart 呼叫 Rust。 |

## Recent Changes
- 001-: Added

<!-- MANUAL ADDITIONS START -->
目前是我單人開發，請按照只有我開發的狀況下思考
<!-- MANUAL ADDITIONS END -->