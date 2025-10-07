
# Implementation Plan: 跨平台裝置電量監控工具

**Branch**: `001-` | **Date**: 2025-10-07 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/Users/seanhung/programming/others/local-assistant/specs/001-/spec.md`

## Execution Flow (/plan command scope)
```
1. Load feature spec from Input path
   → If not found: ERROR "No feature spec at {path}"
2. Fill Technical Context (scan for NEEDS CLARIFICATION)
   → Detect Project Type from file system structure or context (web=frontend+backend, mobile=app+api)
   → Set Structure Decision based on project type
3. Fill the Constitution Check section based on the content of the constitution document.
4. Evaluate Constitution Check section below
   → If violations exist: Document in Complexity Tracking
   → If no justification possible: ERROR "Simplify approach first"
   → Update Progress Tracking: Initial Constitution Check
5. Execute Phase 0 → research.md
   → If NEEDS CLARIFICATION remain: ERROR "Resolve unknowns"
6. Execute Phase 1 → contracts, data-model.md, quickstart.md, agent-specific template file (e.g., `CLAUDE.md` for Claude Code, `.github/copilot-instructions.md` for GitHub Copilot, `GEMINI.md` for Gemini CLI, `QWEN.md` for Qwen Code, or `AGENTS.md` for all other agents).
7. Re-evaluate Constitution Check section
   → If new violations: Refactor design, return to Phase 1
   → Update Progress Tracking: Post-Design Constitution Check
8. Plan Phase 2 → Describe task generation approach (DO NOT create tasks.md)
9. STOP - Ready for /tasks command
```

**IMPORTANT**: The /plan command STOPS at step 7. Phases 2-4 are executed by other commands:
- Phase 2: /tasks command creates tasks.md
- Phase 3-4: Implementation execution (manual or via tools)

## Summary
實作一個跨平台裝置電量監控工具,支援 Windows、macOS、Android、iPadOS 四個平台。使用者可以查看本地裝置電量,並透過伺服器連線查看其他裝置的電量。系統採用裝置為本的身份驗證,優先使用 P2P 加密直連,無法直連時降級使用中繼伺服器。所有通訊必須端到端加密,伺服器無法讀取使用者資料。電量資訊每 5 分鐘更新一次,歷史記錄永久保存。

## Technical Context

**使用者提供的技術背景**: 這會牽扯到幾個方向,server要用什麼架構,client要怎麼顯示,core要怎麼讀取到電量,我對於這些沒有個確切的答案,請討論解決

**Language/Version**:
- 客戶端: Flutter 3.24+ / Dart 3.5+
- 加密核心 (FFI): Rust 1.75+
- 信令伺服器: Rust 1.75+ (tokio async runtime)
- TURN 伺服器: coturn (C/C++)

**Primary Dependencies**:
- Flutter: battery_plus, flutter_webrtc, flutter_secure_storage, isar
- Rust (客戶端 FFI): snow, ed25519-dalek, bip39, chacha20poly1305
- Rust (伺服器): tokio, tungstenite (WebSocket), serde

**Storage**:
- 歷史電量記錄: Isar 3.x (本地 NoSQL,AES-256 加密)
- 裝置身份資訊: Isar (公鑰、裝置 metadata)
- 私鑰: 平台金鑰鏈 (Keychain/Keystore/DPAPI)

**Testing**:
- Flutter: flutter_test (單元測試), integration_test (E2E)
- Rust: cargo test (加密模組測試)
- 契約測試: 每個 API 端點一個測試檔案

**Target Platform**: Windows 10+, macOS 11+, Android 10+, iPadOS 14+ (iOS 未來版本)

**Project Type**: mobile + server (Flutter 客戶端 + Rust 信令/TURN 伺服器)

**Performance Goals**:
- 電量資訊顯示延遲 <200ms
- P2P 連線建立 <2s
- TURN 中繼轉發延遲 <500ms
- 歷史記錄查詢 (30 天) <100ms

**Constraints**:
- 端到端加密 (伺服器無法解密)
- 離線模式支援本地電量查詢
- 背景運行時低功耗 (<5% 電量消耗/日)
- 符合憲章所有安全要求 (見 Constitution Check)

**Scale/Scope**:
- 支援單使用者無上限裝置數 (10+ 台會提醒)
- 歷史記錄永久保存 (原始記錄不刪除,30 天後降低採樣頻率:5 分鐘間隔 → 1 小時間隔,減少儲存空間)
- 預估單裝置每月資料量: ~5KB (5分鐘間隔 × 30天 ≈ 8640 筆記錄)

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

### 核心原則驗證

- [x] **裝置為本的身份驗證**: ✅ FR-012 統一要求遵循憲章安全原則
- [x] **P2P 加密優先**: ✅ FR-012 統一要求遵循憲章安全原則
- [x] **隱私保護設計**: ✅ FR-012 統一要求遵循憲章安全原則
- [x] **零知識架構**: ✅ 中繼伺服器僅轉發加密封包,無法解密內容 (需在 Phase 0 研究確認實作方案)
- [x] **最小權限原則**: ✅ 需在 Phase 1 設計時確保元件解耦,僅授予必要權限

### 安全要求驗證

- [x] 使用符合標準的加密演算法(AES-256-GCM/ChaCha20-Poly1305、Ed25519、X25519) - 需在 Phase 0 研究時選擇具體協定
- [x] 私鑰安全儲存(金鑰鏈或 HSM) - 已列入關鍵技術決策點 #6
- [x] 實作防重放攻擊與速率限制 - 需在 Phase 1 設計中規劃
- [x] 加密協定與金鑰管理已文件化 - 將在 Phase 1 contracts/ 中定義

### 開發規範驗證

- [x] 安全相關變更已規劃審查流程 - 將在 Phase 2 tasks.md 中標記安全相關任務
- [x] 測試計畫涵蓋安全功能 - 需在 Phase 1 quickstart.md 中包含加密驗證測試
- [x] 威脅模型已識別 - 主要威脅:中間人攻擊、封包重放、私鑰洩露、伺服器資料存取 (需在 Phase 0 research.md 中詳細分析)

**初步評估結果**: ✅ PASS - 功能規格符合憲章核心原則,關鍵技術細節將在 Phase 0/1 中具體化並重新驗證

---

**Phase 1 後重新評估** (2025-10-07):

### 核心原則驗證 (Phase 1 設計確認)

- [x] **裝置為本的身份驗證**: ✅ **已確認** - data-model.md 定義 Device 實體包含 Ed25519 公鑰,私鑰存於金鑰鏈 (flutter_secure_storage)
- [x] **P2P 加密優先**: ✅ **已確認** - signaling_api.md 定義 P2P 連線流程,Noise Protocol 握手在 WebRTC DataChannel 上層
- [x] **隱私保護設計**: ✅ **已確認** - data-model.md 僅儲存必要資訊,signaling_api.md 伺服器僅轉發訊息不儲存電量資料
- [x] **零知識架構**: ✅ **已確認** - signaling_api.md 明確規定伺服器不儲存私鑰、電量、Noise 會話金鑰
- [x] **最小權限原則**: ✅ **已確認** - contracts/ 定義服務層解耦 (BatteryService, CryptoService, StorageService, ConnectionService),各司其職

### 安全要求驗證 (Phase 1 設計確認)

- [x] **加密演算法**: ✅ **已確認** - research.md 選擇 Noise Protocol (X25519 + ChaCha20-Poly1305),符合憲章要求
- [x] **私鑰安全儲存**: ✅ **已確認** - data-model.md 規定私鑰僅存於平台金鑰鏈,絕不存於 Isar 資料庫
- [x] **防重放攻擊**: ✅ **已確認** - signaling_api.md 規定訊息包含 timestamp,±5 分鐘內有效;Noise Protocol 內建 nonce
- [x] **加密協定文件化**: ✅ **已確認** - research.md 詳細記錄 Noise Protocol 選擇理由,signaling_api.md 定義握手流程

### 開發規範驗證 (Phase 1 設計確認)

- [x] **安全相關審查流程**: ✅ **已確認** - quickstart.md 場景 9 規劃安全性驗證測試,contracts/README.md 定義測試策略
- [x] **測試計畫涵蓋安全**: ✅ **已確認** - quickstart.md 包含加密驗證、簽章驗證、私鑰保護驗證、網路抓包驗證
- [x] **威脅模型已識別**: ✅ **已確認** - research.md 完整記錄 7 類主要威脅與防禦措施,定義信任邊界

**Phase 1 後評估結果**: ✅ **PASS** - 所有設計文件符合憲章要求,無違規項目,可進入 Phase 2 任務規劃

## Project Structure

### Documentation (this feature)
```
specs/001-/
├── plan.md              # ✅ This file (/plan command output)
├── research.md          # ✅ Phase 0 output (技術決策研究)
├── data-model.md        # ✅ Phase 1 output (資料模型定義)
├── quickstart.md        # ✅ Phase 1 output (端到端測試場景)
├── contracts/           # ✅ Phase 1 output (API 契約)
│   ├── README.md
│   ├── battery_service.dart
│   └── signaling_api.md
└── tasks.md             # ⏳ Phase 2 output (/tasks command - NOT created by /plan)
```

### Source Code (repository root)

**Structure Decision**: Mobile + Server (Flutter 客戶端 + Rust 信令/TURN 伺服器)

```
# Flutter 客戶端
lib/
├── models/              # 資料模型 (生成自 data-model.md)
│   ├── device.dart
│   ├── battery_history.dart
│   └── connection_info.dart
├── services/            # 服務層 (契約定義於 contracts/)
│   ├── battery_service.dart
│   ├── crypto_service.dart
│   ├── storage_service.dart
│   └── connection_service.dart
├── ui/                  # UI 層
│   ├── pages/
│   ├── widgets/
│   └── theme/
├── rust_ffi/            # Rust FFI 綁定
│   └── crypto_bindings.dart
└── main.dart

# Rust 加密核心 (FFI)
rust/
├── crypto/              # Noise Protocol 實作
│   ├── noise_protocol.rs
│   └── session.rs
├── identity/            # 金鑰管理
│   ├── keypair.rs
│   └── mnemonic.rs
├── ffi/                 # Flutter FFI 介面
│   └── lib.rs
└── Cargo.toml

# Rust 信令伺服器
signaling-server/
├── src/
│   ├── main.rs
│   ├── signaling.rs     # WebSocket 信令邏輯
│   ├── device.rs        # 裝置註冊管理
│   ├── auth.rs          # Ed25519 簽章驗證
│   └── turn.rs          # TURN 憑證生成
└── Cargo.toml

# TURN 伺服器配置
turnserver.conf          # coturn 配置檔

# 測試
test/                    # Flutter 單元測試
├── services/
│   ├── battery_service_test.dart
│   ├── crypto_service_test.dart
│   ├── storage_service_test.dart
│   └── connection_service_test.dart
└── models/

integration_test/        # Flutter 整合測試 (對應 quickstart.md 場景)
├── battery_reading_test.dart        # 場景 1
├── p2p_connection_test.dart         # 場景 3
├── relay_fallback_test.dart         # 場景 4
├── battery_sync_test.dart           # 場景 5
├── reconnection_test.dart           # 場景 6
└── security_test.dart               # 場景 9

# 配置
pubspec.yaml             # Flutter 依賴
analysis_options.yaml    # Dart 分析配置
.gitignore
```

## Phase 0: Outline & Research

✅ **已完成** - 參見 [research.md](./research.md)

**研究成果總結**:

1. **Server 架構**: 選擇 WebRTC + STUN/TURN (coturn)
   - 理由: 成熟、跨平台支援良好、符合零知識架構

2. **Client 架構**: 選擇 Flutter + Rust FFI
   - 理由: 單一程式碼庫、battery_plus 支援四平台、結合 Dart 效率與 Rust 安全性

3. **Core 電量讀取**: 使用 battery_plus package
   - 理由: 官方推薦、支援 Windows/macOS/Android/iPadOS 原生 API

4. **加密實作**: Noise Protocol Framework (Noise_XX) + WebRTC
   - 理由: 符合憲章演算法要求 (X25519 + ChaCha20-Poly1305)、提供前向保密

5. **儲存方案**: Isar (資料) + flutter_secure_storage (私鑰)
   - 理由: 高效能、支援加密、私鑰存於平台金鑰鏈

6. **身份管理**: Ed25519 金鑰對 + BIP39 助記詞備份
   - 理由: 符合裝置為本原則、支援備份恢復

**威脅模型**: 已識別 7 類主要威脅並規劃防禦措施 (詳見 research.md)

**Output**: ✅ research.md (所有 NEEDS CLARIFICATION 已解決)

## Phase 1: Design & Contracts
*Prerequisites: research.md complete*

1. **Extract entities from feature spec** → `data-model.md`:
   - Entity name, fields, relationships
   - Validation rules from requirements
   - State transitions if applicable

2. **Generate API contracts** from functional requirements:
   - For each user action → endpoint
   - Use standard REST/GraphQL patterns
   - Output OpenAPI/GraphQL schema to `/contracts/`

3. **Generate contract tests** from contracts:
   - One test file per endpoint
   - Assert request/response schemas
   - Tests must fail (no implementation yet)

4. **Extract test scenarios** from user stories:
   - Each story → integration test scenario
   - Quickstart test = story validation steps

5. **Update agent file incrementally** (O(1) operation):
   - Run `.specify/scripts/bash/update-agent-context.sh claude`
     **IMPORTANT**: Execute it exactly as specified above. Do not add or remove any arguments.
   - If exists: Add only NEW tech from current plan
   - Preserve manual additions between markers
   - Update recent changes (keep last 3)
   - Keep under 150 lines for token efficiency
   - Output to repository root

**Output**: data-model.md, /contracts/*, failing tests, quickstart.md, agent-specific file

## Phase 2: Task Planning Approach
*This section describes what the /tasks command will do - DO NOT execute during /plan*

✅ **已規劃** - 以下為 /tasks 命令的執行策略

**Task Generation Strategy**:
- Load `.specify/templates/tasks-template.md` as base
- Generate tasks from Phase 1 design docs (contracts, data-model.md, quickstart.md)
- **資料層任務** (從 data-model.md 生成):
  - 每個 Entity → Isar Collection 建立任務 [P]
  - 資料庫初始化與加密配置任務
  - 金鑰鏈整合任務 (flutter_secure_storage)
- **服務層任務** (從 contracts/ 生成):
  - 每個 Service → 契約測試 + 實作任務
  - BatteryService (4 個方法 × 2 任務 = 8 任務)
  - CryptoService (Rust FFI,6 個方法 × 2 任務 = 12 任務)
  - StorageService (4 個方法 × 2 任務 = 8 任務)
  - ConnectionService (5 個方法 × 2 任務 = 10 任務)
- **伺服器任務** (從 signaling_api.md 生成):
  - 信令伺服器基礎架構 (WebSocket + tokio)
  - 裝置註冊與簽章驗證
  - SDP/ICE 交換邏輯
  - TURN 憑證生成
- **整合測試任務** (從 quickstart.md 生成):
  - 每個場景 → 整合測試任務
  - 場景 1-10,共 10 個整合測試任務
- **UI 任務**:
  - 裝置列表頁面
  - 電量詳情頁面
  - 設定頁面 (助記詞備份)

**Ordering Strategy**:
- **TDD order**: 測試先於實作 (契約測試 → 實作)
- **Dependency order**:
  1. 資料模型 (Isar Collections) [可並行]
  2. Rust FFI 模組 (CryptoService 依賴)
  3. 服務層 (依賴資料模型與 Rust FFI)
  4. 信令伺服器 (獨立,可並行)
  5. UI 層 (依賴服務層)
  6. 整合測試 (最後執行,驗證端到端流程)
- **Mark [P] for parallel execution**: 獨立檔案可並行 (如不同 Entity,不同 Service)

**Estimated Output**: 60-70 個有序任務

**任務分類**:
- **[SECURITY]**: 安全相關任務 (加密、金鑰管理、簽章驗證) - 約 15 個任務
- **[TEST]**: 測試任務 (契約測試、整合測試) - 約 25 個任務
- **[CORE]**: 核心功能任務 (資料模型、服務層) - 約 20 個任務
- **[SERVER]**: 伺服器任務 (信令伺服器、TURN) - 約 8 個任務
- **[UI]**: UI 任務 - 約 7 個任務

**示範任務順序** (前 10 個任務):
1. [CORE][P] 建立 Device Isar Collection
2. [CORE][P] 建立 BatteryHistory Isar Collection
3. [CORE][P] 建立 ConnectionInfo Isar Collection
4. [CORE] 配置 Isar 資料庫加密
5. [SECURITY] 整合 flutter_secure_storage (金鑰鏈)
6. [SECURITY][P] Rust FFI: Ed25519 金鑰生成
7. [SECURITY][P] Rust FFI: BIP39 助記詞生成
8. [SECURITY][P] Rust FFI: Noise Protocol 握手
9. [TEST] BatteryService 契約測試
10. [CORE] BatteryService 實作 (讀取本地電量)

**IMPORTANT**: This phase is executed by the /tasks command, NOT by /plan

## Phase 3+: Future Implementation
*These phases are beyond the scope of the /plan command*

**Phase 3**: Task execution (/tasks command creates tasks.md)  
**Phase 4**: Implementation (execute tasks.md following constitutional principles)  
**Phase 5**: Validation (run tests, execute quickstart.md, performance validation)

## Complexity Tracking
*Fill ONLY if Constitution Check has violations that must be justified*

**評估結果**: ✅ 無違規項目,無需填寫此表

所有設計決策符合憲章要求,無複雜度偏離需要特別說明。

---

## Progress Tracking
*This checklist is updated during execution flow*

**Phase Status**:
- [x] Phase 0: Research complete (/plan command) ✅ 2025-10-07
- [x] Phase 1: Design complete (/plan command) ✅ 2025-10-07
- [x] Phase 2: Task planning complete (/plan command - describe approach only) ✅ 2025-10-07
- [ ] Phase 3: Tasks generated (/tasks command) ⏳ 待執行
- [ ] Phase 4: Implementation complete ⏳ 待執行
- [ ] Phase 5: Validation passed ⏳ 待執行

**Gate Status**:
- [x] Initial Constitution Check: PASS ✅ 2025-10-07
- [x] Post-Design Constitution Check: PASS ✅ 2025-10-07
- [x] All NEEDS CLARIFICATION resolved ✅ 2025-10-07
- [x] Complexity deviations documented ✅ 無偏離項目

**Generated Artifacts**:
- [x] research.md (Phase 0) - 技術決策研究,6 個關鍵決策點
- [x] data-model.md (Phase 1) - 3 個 Entity,完整驗證規則與關係定義
- [x] contracts/ (Phase 1) - README.md, battery_service.dart, signaling_api.md
- [x] quickstart.md (Phase 1) - 10 個端到端測試場景
- [x] CLAUDE.md (Phase 1) - Agent 上下文檔案,包含技術棧與命令
- [ ] tasks.md (Phase 2) - 待 /tasks 命令生成

---

## 下一步行動

**執行 /tasks 命令**:
```bash
# 在 Claude Code 中執行
/tasks
```

**預期產出**:
- 生成 `specs/001-/tasks.md`,包含 60-70 個有序任務
- 任務按依賴關係排序,標記可並行執行的任務 [P]
- 包含安全相關任務 [SECURITY]、測試任務 [TEST]、核心任務 [CORE]、伺服器任務 [SERVER]、UI 任務 [UI]

**後續流程**:
1. 執行 /tasks 生成任務清單
2. 按順序執行 tasks.md 中的任務 (Phase 4)
3. 執行 quickstart.md 中的測試場景驗證 (Phase 5)
4. 所有測試通過後,功能開發完成

---

**Plan 完成時間**: 2025-10-07
**Constitution 版本**: v1.0.0 - 參見 `.specify/memory/constitution.md`
**Feature Branch**: `001-`
