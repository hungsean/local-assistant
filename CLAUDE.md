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

## Recent Changes
- 001-: Added

<!-- MANUAL ADDITIONS START -->
<!-- MANUAL ADDITIONS END -->