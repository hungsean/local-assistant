# Signaling Server WebSocket API

**Version**: 1.0.0
**Date**: 2025-10-07
**Protocol**: WebSocket (wss://)

---

## 概述

信令伺服器用於協助裝置間建立 P2P 連線,主要功能:
1. **裝置註冊**: 裝置上線時註冊公鑰與連線資訊
2. **SDP 交換**: WebRTC Offer/Answer 交換
3. **ICE 候選交換**: NAT 穿透資訊交換
4. **裝置查詢**: 查詢已註冊的裝置列表

**安全要求**:
- 所有訊息必須使用 Ed25519 簽章驗證裝置身份
- 伺服器僅轉發訊息,不儲存敏感資料 (電量、私鑰等)
- SDP 與 ICE 候選包含加密通道資訊,伺服器無法解密

---

## 連線流程

```
1. 客戶端連線至 wss://server.example.com/signaling
2. 伺服器返回 welcome 訊息
3. 客戶端發送 register 訊息 (包含公鑰與簽章)
4. 伺服器驗證簽章,返回 registered 或 error
5. 客戶端發送 list_devices 查詢可連線裝置
6. 客戶端發送 offer/answer 建立 P2P 連線
7. P2P 連線建立後,客戶端可選擇關閉 WebSocket (僅保留心跳)
```

---

## 訊息格式

所有訊息為 JSON 格式,包含以下通用欄位:

```json
{
  "type": "訊息類型",
  "payload": { /* 訊息內容 */ },
  "signature": "Ed25519 簽章 (Hex)",
  "timestamp": "2025-10-07T14:30:00Z"
}
```

**簽章驗證**:
- 簽章內容: `SHA256(type + payload_json + timestamp)`
- 使用裝置私鑰簽章,伺服器用公鑰驗證
- 時間戳記必須在 ±5 分鐘內,防止重放攻擊

---

## 客戶端 → 伺服器訊息

### 1. register (裝置註冊)

**用途**: 裝置上線時註冊身份

**Request**:
```json
{
  "type": "register",
  "payload": {
    "device_id": "550e8400-e29b-41d4-a716-446655440000",
    "public_key": "a1b2c3d4e5f6...(64 chars hex)",
    "device_name": "MacBook Pro",
    "platform": "macos",
    "device_type": "laptop"
  },
  "signature": "簽章內容...",
  "timestamp": "2025-10-07T14:30:00Z"
}
```

**Response (成功)**:
```json
{
  "type": "registered",
  "payload": {
    "device_id": "550e8400-e29b-41d4-a716-446655440000",
    "session_id": "隨機會話 ID",
    "expires_at": "2025-10-07T15:30:00Z"
  },
  "timestamp": "2025-10-07T14:30:01Z"
}
```

**Response (失敗)**:
```json
{
  "type": "error",
  "payload": {
    "code": "INVALID_SIGNATURE",
    "message": "簽章驗證失敗"
  },
  "timestamp": "2025-10-07T14:30:01Z"
}
```

---

### 2. list_devices (查詢裝置列表)

**用途**: 查詢已註冊的裝置 (用於顯示可連線裝置)

**Request**:
```json
{
  "type": "list_devices",
  "payload": {
    "device_id": "550e8400-e29b-41d4-a716-446655440000"
  },
  "signature": "簽章內容...",
  "timestamp": "2025-10-07T14:35:00Z"
}
```

**Response**:
```json
{
  "type": "device_list",
  "payload": {
    "devices": [
      {
        "device_id": "660e8400-e29b-41d4-a716-446655440001",
        "public_key": "b2c3d4e5f6...",
        "device_name": "Samsung Galaxy S23",
        "platform": "android",
        "device_type": "phone",
        "online": true,
        "last_seen": "2025-10-07T14:34:50Z"
      },
      {
        "device_id": "770e8400-e29b-41d4-a716-446655440002",
        "public_key": "c3d4e5f6...",
        "device_name": "iPad Pro",
        "platform": "ipados",
        "device_type": "tablet",
        "online": false,
        "last_seen": "2025-10-07T13:20:00Z"
      }
    ]
  },
  "timestamp": "2025-10-07T14:35:01Z"
}
```

---

### 3. offer (WebRTC Offer)

**用途**: 發起 P2P 連線,發送 WebRTC Offer

**Request**:
```json
{
  "type": "offer",
  "payload": {
    "from_device_id": "550e8400-e29b-41d4-a716-446655440000",
    "to_device_id": "660e8400-e29b-41d4-a716-446655440001",
    "sdp": "WebRTC SDP Offer (包含 DTLS 指紋)"
  },
  "signature": "簽章內容...",
  "timestamp": "2025-10-07T14:40:00Z"
}
```

**Response (轉發給目標裝置)**:
```json
{
  "type": "incoming_offer",
  "payload": {
    "from_device_id": "550e8400-e29b-41d4-a716-446655440000",
    "from_device_name": "MacBook Pro",
    "sdp": "WebRTC SDP Offer"
  },
  "timestamp": "2025-10-07T14:40:01Z"
}
```

---

### 4. answer (WebRTC Answer)

**用途**: 回應 Offer,建立 P2P 連線

**Request**:
```json
{
  "type": "answer",
  "payload": {
    "from_device_id": "660e8400-e29b-41d4-a716-446655440001",
    "to_device_id": "550e8400-e29b-41d4-a716-446655440000",
    "sdp": "WebRTC SDP Answer"
  },
  "signature": "簽章內容...",
  "timestamp": "2025-10-07T14:40:05Z"
}
```

**Response (轉發給原發起者)**:
```json
{
  "type": "incoming_answer",
  "payload": {
    "from_device_id": "660e8400-e29b-41d4-a716-446655440001",
    "sdp": "WebRTC SDP Answer"
  },
  "timestamp": "2025-10-07T14:40:06Z"
}
```

---

### 5. ice_candidate (ICE 候選)

**用途**: 交換 NAT 穿透資訊

**Request**:
```json
{
  "type": "ice_candidate",
  "payload": {
    "from_device_id": "550e8400-e29b-41d4-a716-446655440000",
    "to_device_id": "660e8400-e29b-41d4-a716-446655440001",
    "candidate": "ICE 候選資訊 (IP:Port)"
  },
  "signature": "簽章內容...",
  "timestamp": "2025-10-07T14:40:10Z"
}
```

**Response (轉發給目標裝置)**:
```json
{
  "type": "incoming_ice_candidate",
  "payload": {
    "from_device_id": "550e8400-e29b-41d4-a716-446655440000",
    "candidate": "ICE 候選資訊"
  },
  "timestamp": "2025-10-07T14:40:11Z"
}
```

---

### 6. heartbeat (心跳)

**用途**: 保持連線,更新 last_seen 時間

**Request**:
```json
{
  "type": "heartbeat",
  "payload": {
    "device_id": "550e8400-e29b-41d4-a716-446655440000"
  },
  "signature": "簽章內容...",
  "timestamp": "2025-10-07T14:45:00Z"
}
```

**Response**:
```json
{
  "type": "heartbeat_ack",
  "payload": {
    "server_time": "2025-10-07T14:45:01Z"
  },
  "timestamp": "2025-10-07T14:45:01Z"
}
```

**頻率**: 每 60 秒發送一次

---

### 7. unregister (取消註冊)

**用途**: 裝置下線時通知伺服器

**Request**:
```json
{
  "type": "unregister",
  "payload": {
    "device_id": "550e8400-e29b-41d4-a716-446655440000"
  },
  "signature": "簽章內容...",
  "timestamp": "2025-10-07T15:00:00Z"
}
```

**Response**:
```json
{
  "type": "unregistered",
  "payload": {
    "device_id": "550e8400-e29b-41d4-a716-446655440000"
  },
  "timestamp": "2025-10-07T15:00:01Z"
}
```

---

## 伺服器 → 客戶端訊息

### 1. welcome (歡迎訊息)

**時機**: WebSocket 連線建立時

```json
{
  "type": "welcome",
  "payload": {
    "server_version": "1.0.0",
    "protocol_version": "1.0",
    "max_devices": 1000
  },
  "timestamp": "2025-10-07T14:30:00Z"
}
```

---

### 2. error (錯誤訊息)

**時機**: 請求處理失敗時

```json
{
  "type": "error",
  "payload": {
    "code": "INVALID_SIGNATURE",
    "message": "簽章驗證失敗",
    "request_type": "register"
  },
  "timestamp": "2025-10-07T14:30:01Z"
}
```

**錯誤代碼**:
- `INVALID_SIGNATURE`: 簽章驗證失敗
- `INVALID_TIMESTAMP`: 時間戳記超出允許範圍 (±5 分鐘)
- `DEVICE_NOT_FOUND`: 裝置未註冊
- `DEVICE_OFFLINE`: 目標裝置離線
- `RATE_LIMIT_EXCEEDED`: 超過速率限制 (每分鐘 60 次請求)
- `INTERNAL_ERROR`: 伺服器內部錯誤

---

### 3. device_offline (裝置離線通知)

**時機**: 已連線的裝置斷線時通知其他裝置

```json
{
  "type": "device_offline",
  "payload": {
    "device_id": "660e8400-e29b-41d4-a716-446655440001",
    "device_name": "Samsung Galaxy S23",
    "last_seen": "2025-10-07T14:50:00Z"
  },
  "timestamp": "2025-10-07T14:50:30Z"
}
```

---

## 安全機制

### 1. 簽章驗證流程

```
1. 客戶端發送訊息:
   message = {type, payload, timestamp}
   digest = SHA256(type + JSON.stringify(payload) + timestamp)
   signature = Ed25519.sign(digest, privateKey)

2. 伺服器驗證:
   digest = SHA256(type + JSON.stringify(payload) + timestamp)
   isValid = Ed25519.verify(digest, signature, publicKey)

3. 時間戳記驗證:
   if (|server_time - timestamp| > 5 minutes):
     return error(INVALID_TIMESTAMP)
```

### 2. 速率限制

**全域限制**:
- 每個 IP 每分鐘最多 60 次請求
- 超過限制返回 `RATE_LIMIT_EXCEEDED` 錯誤
- 使用 Token Bucket 演算法

**裝置限制**:
- 每個裝置同時最多 5 個 WebSocket 連線
- 超過限制自動斷開最舊的連線

### 3. TURN 伺服器認證

**時機**: P2P 直連失敗時,客戶端請求 TURN 憑證

**Request**:
```json
{
  "type": "request_turn_credentials",
  "payload": {
    "device_id": "550e8400-e29b-41d4-a716-446655440000"
  },
  "signature": "簽章內容...",
  "timestamp": "2025-10-07T14:45:00Z"
}
```

**Response**:
```json
{
  "type": "turn_credentials",
  "payload": {
    "urls": ["turn:turn.example.com:3478"],
    "username": "臨時使用者名稱",
    "credential": "臨時密碼",
    "expires_at": "2025-10-07T15:45:00Z"
  },
  "timestamp": "2025-10-07T14:45:01Z"
}
```

**安全性**:
- TURN 憑證有效期 1 小時
- 使用 coturn 的 REST API 動態生成臨時憑證
- 憑證綁定裝置 ID,防止濫用

---

## 資料隱私保證

**伺服器不儲存的資料**:
- ❌ 裝置私鑰 (僅客戶端持有)
- ❌ 電量資訊 (僅在 P2P 通道傳輸)
- ❌ Noise Protocol 會話金鑰 (僅在客戶端)
- ❌ 使用者個人資訊 (姓名、Email 等)

**伺服器儲存的資料** (最小化):
- ✅ 裝置 ID (UUID)
- ✅ 公鑰 (Ed25519)
- ✅ 裝置名稱 (使用者可編輯,用於顯示)
- ✅ 平台類型 (windows/macos/android/ipados)
- ✅ 最後上線時間 (last_seen)
- ✅ 連線狀態 (online/offline)

**資料保存期限**:
- 裝置離線 30 天後自動刪除註冊資訊
- 裝置可主動發送 `unregister` 立即刪除

---

## 錯誤處理範例

**情境 1: 簽章驗證失敗**

```json
{
  "type": "error",
  "payload": {
    "code": "INVALID_SIGNATURE",
    "message": "Ed25519 signature verification failed",
    "request_type": "register"
  },
  "timestamp": "2025-10-07T14:30:01Z"
}
```

**客戶端處理**:
- 檢查私鑰是否正確
- 檢查簽章演算法是否正確
- 記錄錯誤並提示使用者

---

**情境 2: 目標裝置離線**

```json
{
  "type": "error",
  "payload": {
    "code": "DEVICE_OFFLINE",
    "message": "Target device is not connected",
    "device_id": "660e8400-e29b-41d4-a716-446655440001"
  },
  "timestamp": "2025-10-07T14:40:01Z"
}
```

**客戶端處理**:
- 更新 UI 顯示裝置離線狀態
- 啟動重試機制 (符合 FR-010)
- 記錄至 ConnectionInfo.connectionState = retrying

---

## 測試案例

**契約測試 (signaling_api_test.dart)** 需驗證:

1. ✅ register 訊息簽章正確
2. ✅ 時間戳記超出範圍時返回 INVALID_TIMESTAMP
3. ✅ 重複註冊相同 device_id 時覆蓋舊資訊
4. ✅ list_devices 返回所有線上裝置
5. ✅ offer/answer 正確轉發給目標裝置
6. ✅ ICE 候選正確轉發
7. ✅ 心跳更新 last_seen 時間
8. ✅ 裝置離線 30 天後自動刪除
9. ✅ 速率限制正確運作 (每分鐘 60 次)
10. ✅ TURN 憑證正確生成且有效期 1 小時

---

**版本**: 1.0.0
**下一步**: 實作信令伺服器 (Rust + tokio + tungstenite)
