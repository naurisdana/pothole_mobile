import 'dart:async';
import 'dart:io';
import 'offline_report_queue.dart';
import 'report_payload.dart';
import 'road_safe_api_client.dart';

class TelemetrySnapshot {
  const TelemetrySnapshot({
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    this.speed,
    this.heading,
  });

  final double latitude;
  final double longitude;
  final double accuracy;
  final double? speed;
  final double? heading;
}

class DetectionFrame {
  const DetectionFrame({
    required this.imagePath,
    required this.confidence,
    required this.l,
    required this.k,
    required this.p,
    required this.t,
    required this.telemetry,
    this.street,
  });

  final String imagePath;
  final double confidence;
  final double l;
  final double k;
  final double p;
  final double t;
  final TelemetrySnapshot telemetry;
  final String? street;
}

enum ReportDelivery { sent, duplicate, queued, heldForGps }

class ReportingController {
  ReportingController({
    required RoadSafeApiClient api,
    required this.deviceId,
    OfflineReportQueue? queue,
    this.requiredConsecutiveFrames = 3,
  }) : _api = api,
       _queue = queue ?? OfflineReportQueue();

  final RoadSafeApiClient _api;
  final String deviceId;
  final OfflineReportQueue _queue;
  final int requiredConsecutiveFrames;
  int _consecutiveFrames = 0;
  String? _detectionSignature;

  Future<ReportDelivery?> addFrame(DetectionFrame frame) async {
    final signature = _signature(frame);
    if (_detectionSignature == signature) {
      _consecutiveFrames++;
    } else {
      _detectionSignature = signature;
      _consecutiveFrames = 1;
    }
    if (_consecutiveFrames < requiredConsecutiveFrames) return null;
    _consecutiveFrames = 0;
    _detectionSignature = null;
    return submit(frame);
  }

  Future<ReportDelivery> submit(DetectionFrame frame) async {
    if (frame.telemetry.accuracy > 20) return ReportDelivery.heldForGps;
    final payload = ReportPayload(
      imagePath: frame.imagePath,
      deviceId: deviceId,
      latitude: frame.telemetry.latitude,
      longitude: frame.telemetry.longitude,
      gpsAccuracy: frame.telemetry.accuracy,
      confidence: frame.confidence,
      l: frame.l,
      k: frame.k,
      p: frame.p,
      t: frame.t,
      street: frame.street,
      speed: frame.telemetry.speed,
      heading: frame.telemetry.heading,
      timestamp: DateTime.now(),
    );
    try {
      final result = await _uploadWithRateLimitRetry(payload);
      return result.isDuplicate
          ? ReportDelivery.duplicate
          : ReportDelivery.sent;
    } on RateLimitException catch (error) {
      if (error.retryAfter != null) {
        await Future<void>.delayed(error.retryAfter!);
      }
      await _queue.enqueue(payload);
      return ReportDelivery.queued;
    } on SocketException {
      await _queue.enqueue(payload);
      return ReportDelivery.queued;
    } on TimeoutException {
      await _queue.enqueue(payload);
      return ReportDelivery.queued;
    } on ApiException catch (error) {
      if (error.statusCode >= 500) {
        await _queue.enqueue(payload);
        return ReportDelivery.queued;
      }
      rethrow;
    }
  }

  Future<int> synchronize() async {
    var sent = 0;
    for (final item in await _queue.pending()) {
      try {
        final result = await _uploadWithRateLimitRetry(item.payload);
        await _queue.remove(item);
        sent++;
        if (result.isDuplicate) continue;
      } on RateLimitException catch (error) {
        if (error.retryAfter != null) {
          await Future<void>.delayed(error.retryAfter!);
        }
        break;
      } on SocketException {
        break;
      } on TimeoutException {
        break;
      } on ApiException catch (error) {
        if (error.statusCode >= 500) break;
        rethrow;
      }
    }
    return sent;
  }

  String _signature(DetectionFrame frame) {
    return '${frame.l.round()}:${frame.k.round()}:${frame.p.round()}:${frame.t.round()}';
  }

  Future<ReportUploadResult> _uploadWithRateLimitRetry(
    ReportPayload payload,
  ) async {
    try {
      return await _api.uploadReport(payload);
    } on RateLimitException catch (error) {
      if (error.retryAfter != null) {
        await Future<void>.delayed(error.retryAfter!);
      }
      return _api.uploadReport(payload);
    }
  }
}
