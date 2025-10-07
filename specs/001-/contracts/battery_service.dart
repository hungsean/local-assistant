/// Battery Service Contract
///
/// 定義電量讀取與監控的介面契約
/// 實作必須支援 Windows、macOS、Android、iPadOS 四個平台
///
/// Version: 1.0.0
/// Date: 2025-10-07

import 'dart:async';
import '../data_model.dart'; // BatteryHistory, Device 等資料模型

/// 電量狀態
class BatteryStatus {
  /// 裝置 ID
  final String deviceId;

  /// 電量百分比
  /// -2: 讀取失敗 (READ_FAILED)
  /// -1: 純電源供電 (AC_POWER)
  /// 0-100: 實際電量百分比
  final int batteryLevel;

  /// 充電狀態
  final ChargingState chargingState;

  /// 讀取時間
  final DateTime timestamp;

  /// 電源類型
  final PowerType powerType;

  BatteryStatus({
    required this.deviceId,
    required this.batteryLevel,
    required this.chargingState,
    required this.timestamp,
    required this.powerType,
  });

  /// 是否為有效電量資訊
  bool get isValid => batteryLevel >= 0 && batteryLevel <= 100;

  /// 是否為 AC 電源
  bool get isACPower => batteryLevel == -1;

  /// 是否讀取失敗
  bool get isReadFailed => batteryLevel == -2;

  /// 轉換為 BatteryHistory 資料模型
  BatteryHistory toHistory({required DataSource source}) {
    return BatteryHistory()
      ..deviceId = deviceId
      ..batteryLevel = batteryLevel
      ..chargingState = chargingState
      ..timestamp = timestamp
      ..source = source;
  }
}

/// 電量錯誤類型
enum BatteryError {
  /// 平台不支援電池 API
  platformNotSupported,

  /// 裝置無電池 (純電源供電)
  noBattery,

  /// 讀取權限不足
  permissionDenied,

  /// 讀取失敗 (未知原因)
  readFailed,

  /// 裝置未找到
  deviceNotFound,
}

/// 結果類型 (簡化版 Result<T, E>)
class Result<T, E> {
  final T? _value;
  final E? _error;

  Result.success(T value)
      : _value = value,
        _error = null;

  Result.failure(E error)
      : _value = null,
        _error = error;

  bool get isSuccess => _value != null;
  bool get isFailure => _error != null;

  T get value => _value!;
  E get error => _error!;
}

/// 電量服務介面
///
/// 實作要求:
/// - 必須支援本地裝置電量讀取
/// - 必須支援電量變化監聽
/// - 必須正確處理 AC 電源裝置 (無電池)
/// - 必須處理讀取失敗情況
abstract class BatteryService {
  /// 取得本地裝置目前電量狀態
  ///
  /// 返回:
  /// - Success: 電量狀態
  /// - Failure: BatteryError (noBattery, readFailed 等)
  ///
  /// 範例:
  /// ```dart
  /// final result = await batteryService.getCurrentBatteryStatus();
  /// if (result.isSuccess) {
  ///   print('電量: ${result.value.batteryLevel}%');
  /// } else {
  ///   print('錯誤: ${result.error}');
  /// }
  /// ```
  Future<Result<BatteryStatus, BatteryError>> getCurrentBatteryStatus();

  /// 取得指定裝置的電量狀態
  ///
  /// 參數:
  /// - deviceId: 裝置 ID (UUID)
  ///
  /// 返回:
  /// - Success: 電量狀態
  /// - Failure: BatteryError (deviceNotFound, readFailed 等)
  ///
  /// 注意:
  /// - 本地裝置: 直接讀取
  /// - 遠端裝置: 從 StorageService 讀取最後一筆記錄
  Future<Result<BatteryStatus, BatteryError>> getBatteryStatus(
    String deviceId,
  );

  /// 監聽本地裝置電量變化
  ///
  /// 返回:
  /// - Stream<BatteryStatus>: 電量變化串流
  ///
  /// 觸發時機:
  /// - 電量百分比變化時
  /// - 充電狀態變化時 (插拔充電器)
  ///
  /// 範例:
  /// ```dart
  /// batteryService.batteryStatusStream.listen((status) {
  ///   print('電量變化: ${status.batteryLevel}%');
  /// });
  /// ```
  Stream<BatteryStatus> get batteryStatusStream;

  /// 啟動定期電量回報 (每 5 分鐘)
  ///
  /// 功能:
  /// - 每 5 分鐘讀取一次電量
  /// - 自動儲存至 StorageService
  /// - 若已連線,發送至遠端裝置
  ///
  /// 注意:
  /// - 背景運行時需正確配置平台背景任務
  /// - 低功耗模式下可能延遲執行
  Future<void> startPeriodicReporting();

  /// 停止定期電量回報
  Future<void> stopPeriodicReporting();

  /// 偵測裝置電源類型 (首次啟動時呼叫)
  ///
  /// 返回:
  /// - PowerType.battery: 有電池
  /// - PowerType.acOnly: 純電源供電
  ///
  /// 範例:
  /// ```dart
  /// final powerType = await batteryService.detectPowerType();
  /// // 儲存至 Device.powerType
  /// ```
  Future<PowerType> detectPowerType();

  /// 取得電量歷史記錄
  ///
  /// 參數:
  /// - deviceId: 裝置 ID
  /// - startDate: 開始時間 (可選,預設 30 天前)
  /// - endDate: 結束時間 (可選,預設現在)
  ///
  /// 返回:
  /// - List<BatteryHistory>: 按時間排序的歷史記錄
  ///
  /// 範例:
  /// ```dart
  /// final history = await batteryService.getBatteryHistory(
  ///   deviceId: 'xxx',
  ///   startDate: DateTime.now().subtract(Duration(days: 7)),
  /// );
  /// ```
  Future<List<BatteryHistory>> getBatteryHistory({
    required String deviceId,
    DateTime? startDate,
    DateTime? endDate,
  });

  /// 儲存電量記錄 (用於接收遠端裝置電量)
  ///
  /// 參數:
  /// - status: 電量狀態
  /// - source: 資料來源 (local, remoteP2P, remoteRelay)
  ///
  /// 返回:
  /// - Success: 已儲存的 BatteryHistory
  /// - Failure: StorageError
  Future<Result<BatteryHistory, dynamic>> saveBatteryRecord({
    required BatteryStatus status,
    required DataSource source,
  });
}

/// 電量服務實作範例 (僅用於說明契約,實際實作時刪除)
///
/// 實作要點:
/// 1. 使用 battery_plus package 讀取平台電池 API
/// 2. 捕捉 PlatformException 判斷是否為 AC 電源裝置
/// 3. 使用 Timer.periodic 實作定期回報
/// 4. 整合 StorageService 儲存歷史記錄
class BatteryServiceImpl implements BatteryService {
  // 實作細節 (Phase 3 實作時填寫)
  // ...

  @override
  Future<Result<BatteryStatus, BatteryError>> getCurrentBatteryStatus() {
    throw UnimplementedError('實作時移除此錯誤');
  }

  @override
  Future<Result<BatteryStatus, BatteryError>> getBatteryStatus(
    String deviceId,
  ) {
    throw UnimplementedError('實作時移除此錯誤');
  }

  @override
  Stream<BatteryStatus> get batteryStatusStream {
    throw UnimplementedError('實作時移除此錯誤');
  }

  @override
  Future<void> startPeriodicReporting() {
    throw UnimplementedError('實作時移除此錯誤');
  }

  @override
  Future<void> stopPeriodicReporting() {
    throw UnimplementedError('實作時移除此錯誤');
  }

  @override
  Future<PowerType> detectPowerType() {
    throw UnimplementedError('實作時移除此錯誤');
  }

  @override
  Future<List<BatteryHistory>> getBatteryHistory({
    required String deviceId,
    DateTime? startDate,
    DateTime? endDate,
  }) {
    throw UnimplementedError('實作時移除此錯誤');
  }

  @override
  Future<Result<BatteryHistory, dynamic>> saveBatteryRecord({
    required BatteryStatus status,
    required DataSource source,
  }) {
    throw UnimplementedError('實作時移除此錯誤');
  }
}
