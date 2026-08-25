import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:oronbox/src/core/logging/logging_service.dart';
import 'package:oronbox/src/core/models/bt_models.dart' as models;
import 'package:oronbox/src/core/models/xiaomi_health_models.dart';
import 'package:oronbox/src/device/core/event_bus.dart';
import 'package:oronbox/src/device/xiaomi/system/xiaomi_system.dart';
import 'package:oronbox/src/protocols/generated/xiaomi/wear.pb.dart' as pb;
import 'package:oronbox/src/protocols/generated/xiaomi/wear_fitness.pb.dart'
    as pb_fitness;
import 'package:oronbox/src/protocols/generated/xiaomi/wear_system.pb.dart'
    as pb_system;
import 'package:oronbox/src/protocols/common/device_protocol.dart';
import 'package:oronbox/src/protocols/xiaomi/packet/l2_packet.dart';

/// A single activity file that could not be completely synchronized.
///
/// A failed file must not discard the other files returned by the wearable.
/// The error is kept as text so callers can log or present it without making
/// the protocol exception types part of the health model API.
class XiaomiActivityFileFailure {
  const XiaomiActivityFileFailure({
    required this.id,
    required this.attempts,
    required this.error,
  });

  final String id;
  final int attempts;
  final String error;
}

class XiaomiActivityFileSyncResult {
  const XiaomiActivityFileSyncResult({
    required this.daily,
    required this.samples,
    required this.sleep,
    required this.workouts,
    required this.filesReceived,
    this.abnormalHealthRecords = const [],
    this.failedFiles = const [],
    this.filesSkipped = 0,
  });

  final List<XiaomiActivityDailyRecord> daily;
  final List<XiaomiActivitySampleRecord> samples;
  final List<XiaomiActivitySleepRecord> sleep;
  final List<XiaomiActivityWorkoutRecord> workouts;
  final List<XiaomiActivityAbnormalHealthRecord> abnormalHealthRecords;
  final int filesReceived;

  /// Files for which all transfer attempts or the final acknowledgement
  /// failed. Other files in the same sync are still usable.
  final List<XiaomiActivityFileFailure> failedFiles;

  /// Empty/placeholder files advertised by the device and intentionally
  /// ignored because they contain no health payload.
  final int filesSkipped;
}

class XiaomiActivityDailyRecord {
  const XiaomiActivityDailyRecord({
    required this.date,
    this.steps,
    this.activeCalories,
    this.calories,
    this.restingHeartRate,
    this.minHeartRate,
    this.maxHeartRate,
    this.averageHeartRate,
    this.minStress,
    this.maxStress,
    this.averageStress,
    this.standingBitmap,
    this.minBloodOxygen,
    this.maxBloodOxygen,
    this.averageBloodOxygen,
    this.vitalityIncreaseLight,
    this.vitalityIncreaseModerate,
    this.vitalityIncreaseHigh,
    this.vitalityCurrent,
  });

  final DateTime date;
  final int? steps;
  final int? activeCalories;
  final int? calories;
  final int? restingHeartRate;
  final int? minHeartRate;
  final int? maxHeartRate;
  final int? averageHeartRate;
  final int? minStress;
  final int? maxStress;
  final int? averageStress;
  final int? standingBitmap;
  final int? minBloodOxygen;
  final int? maxBloodOxygen;
  final int? averageBloodOxygen;
  final int? vitalityIncreaseLight;
  final int? vitalityIncreaseModerate;
  final int? vitalityIncreaseHigh;
  final int? vitalityCurrent;
}

class XiaomiActivitySampleRecord {
  const XiaomiActivitySampleRecord({
    required this.timestamp,
    this.steps,
    this.activeCalories,
    this.distanceMeters,
    this.heartRate,
    this.energy,
    this.bloodOxygen,
    this.stress,
  });

  final DateTime timestamp;
  final int? steps;
  final int? activeCalories;
  final int? distanceMeters;
  final int? heartRate;
  final int? energy;
  final int? bloodOxygen;
  final int? stress;
}

enum XiaomiActivityAbnormalHealthKind {
  highHeartRate,
  lowHeartRate,
  lowBloodOxygen,
  highStress,
  irregularHeartbeat,
}

/// One event from the Vela daily-type-9 abnormal-health file.
///
/// Mi Fitness maps types 1/2/3/4 to high/low heart rate, low blood oxygen,
/// and high stress. Type 5 is the separate heart-health irregular-heartbeat
/// (ABNORMAL_FIB) event and has no sample value or configured threshold.
class XiaomiActivityAbnormalHealthRecord {
  const XiaomiActivityAbnormalHealthRecord({
    required this.timestamp,
    required this.kind,
    this.value,
    this.threshold,
    this.startedAt,
    this.endedAt,
  });

  final DateTime timestamp;
  final XiaomiActivityAbnormalHealthKind kind;
  final int? value;
  final int? threshold;
  final DateTime? startedAt;
  final DateTime? endedAt;
}

/// Compatibility view for callers that only consume high/low heart-rate
/// alerts. New code should use [XiaomiActivityAbnormalHealthRecord].
enum XiaomiActivityAbnormalHeartRateKind { high, low }

/// One sample from the Vela daily-type-9 abnormal-health file.
///
/// The file contains a segment header (start/end, type, configured threshold)
/// followed by timestamp/value pairs. Keeping the segment bounds here makes it
/// possible to reproduce Mi Fitness' event list without treating every value
/// as an independently detected event.
class XiaomiActivityAbnormalHeartRateRecord {
  const XiaomiActivityAbnormalHeartRateRecord({
    required this.timestamp,
    required this.value,
    required this.kind,
    required this.threshold,
    this.startedAt,
    this.endedAt,
  });

  final DateTime timestamp;
  final int value;
  final XiaomiActivityAbnormalHeartRateKind kind;
  final int threshold;
  final DateTime? startedAt;
  final DateTime? endedAt;
}

class XiaomiActivitySleepRecord {
  const XiaomiActivitySleepRecord({
    required this.startedAt,
    required this.endedAt,
    required this.durationSeconds,
    this.averageHeartRate,
    this.averageBloodOxygen,
    this.minimumHeartRate,
    this.maximumHeartRate,
    this.minimumBloodOxygen,
    this.maximumBloodOxygen,
    this.quality,
    this.sleepEfficiency,
    this.bedDurationSeconds,
    this.goBedAt,
    this.leaveBedAt,
    this.awakeDurationSeconds,
    this.lightSleepDurationSeconds,
    this.deepSleepDurationSeconds,
    this.remSleepDurationSeconds,
    this.averageHrv,
    this.hrvMin,
    this.hrvMax,
    this.hrvBaselineMin,
    this.hrvBaselineMax,
    this.hrvStandardDeviation,
    this.hrvMedian,
    this.hrvLowerQuantile,
    this.hrvMiddleQuantile,
    this.hrvUpperQuantile,
    this.hrvTimestamp,
    this.sleepIndex,
    this.wakeCount,
    this.hasRem,
    this.hasStage,
    this.sleepScoreVersion,
    this.hrvPoints = const [],
    this.stages = const [],
  });

  final DateTime startedAt;
  final DateTime endedAt;
  final int durationSeconds;
  final int? averageHeartRate;
  final int? averageBloodOxygen;
  final int? minimumHeartRate;
  final int? maximumHeartRate;
  final int? minimumBloodOxygen;
  final int? maximumBloodOxygen;
  final int? quality;
  final int? sleepEfficiency;
  final int? bedDurationSeconds;
  final DateTime? goBedAt;
  final DateTime? leaveBedAt;
  final int? awakeDurationSeconds;
  final int? lightSleepDurationSeconds;
  final int? deepSleepDurationSeconds;
  final int? remSleepDurationSeconds;
  final int? averageHrv;
  final int? hrvMin;
  final int? hrvMax;
  final int? hrvBaselineMin;
  final int? hrvBaselineMax;
  final int? hrvStandardDeviation;
  final int? hrvMedian;
  final int? hrvLowerQuantile;
  final int? hrvMiddleQuantile;
  final int? hrvUpperQuantile;
  final DateTime? hrvTimestamp;

  /// The device-provided sleep summary index.  Mi Fitness prefers index 1 as
  /// the main night when a report contains more than one sleep segment.
  final int? sleepIndex;
  final int? wakeCount;
  final bool? hasRem;
  final bool? hasStage;
  final int? sleepScoreVersion;
  final List<XiaomiActivitySleepHrvPoint> hrvPoints;
  final List<XiaomiActivitySleepStageRecord> stages;

  XiaomiActivitySleepRecord copyWith({
    DateTime? startedAt,
    DateTime? endedAt,
    int? durationSeconds,
    int? averageHeartRate,
    int? averageBloodOxygen,
    int? minimumHeartRate,
    int? maximumHeartRate,
    int? minimumBloodOxygen,
    int? maximumBloodOxygen,
    int? quality,
    int? sleepEfficiency,
    int? bedDurationSeconds,
    DateTime? goBedAt,
    DateTime? leaveBedAt,
    int? awakeDurationSeconds,
    int? lightSleepDurationSeconds,
    int? deepSleepDurationSeconds,
    int? remSleepDurationSeconds,
    int? averageHrv,
    int? hrvMin,
    int? hrvMax,
    int? hrvBaselineMin,
    int? hrvBaselineMax,
    int? hrvStandardDeviation,
    int? hrvMedian,
    int? hrvLowerQuantile,
    int? hrvMiddleQuantile,
    int? hrvUpperQuantile,
    DateTime? hrvTimestamp,
    int? sleepIndex,
    int? wakeCount,
    bool? hasRem,
    bool? hasStage,
    int? sleepScoreVersion,
    List<XiaomiActivitySleepHrvPoint>? hrvPoints,
    List<XiaomiActivitySleepStageRecord>? stages,
  }) => XiaomiActivitySleepRecord(
    startedAt: startedAt ?? this.startedAt,
    endedAt: endedAt ?? this.endedAt,
    durationSeconds: durationSeconds ?? this.durationSeconds,
    averageHeartRate: averageHeartRate ?? this.averageHeartRate,
    averageBloodOxygen: averageBloodOxygen ?? this.averageBloodOxygen,
    minimumHeartRate: minimumHeartRate ?? this.minimumHeartRate,
    maximumHeartRate: maximumHeartRate ?? this.maximumHeartRate,
    minimumBloodOxygen: minimumBloodOxygen ?? this.minimumBloodOxygen,
    maximumBloodOxygen: maximumBloodOxygen ?? this.maximumBloodOxygen,
    quality: quality ?? this.quality,
    sleepEfficiency: sleepEfficiency ?? this.sleepEfficiency,
    bedDurationSeconds: bedDurationSeconds ?? this.bedDurationSeconds,
    goBedAt: goBedAt ?? this.goBedAt,
    leaveBedAt: leaveBedAt ?? this.leaveBedAt,
    awakeDurationSeconds: awakeDurationSeconds ?? this.awakeDurationSeconds,
    lightSleepDurationSeconds:
        lightSleepDurationSeconds ?? this.lightSleepDurationSeconds,
    deepSleepDurationSeconds:
        deepSleepDurationSeconds ?? this.deepSleepDurationSeconds,
    remSleepDurationSeconds:
        remSleepDurationSeconds ?? this.remSleepDurationSeconds,
    averageHrv: averageHrv ?? this.averageHrv,
    hrvMin: hrvMin ?? this.hrvMin,
    hrvMax: hrvMax ?? this.hrvMax,
    hrvBaselineMin: hrvBaselineMin ?? this.hrvBaselineMin,
    hrvBaselineMax: hrvBaselineMax ?? this.hrvBaselineMax,
    hrvStandardDeviation: hrvStandardDeviation ?? this.hrvStandardDeviation,
    hrvMedian: hrvMedian ?? this.hrvMedian,
    hrvLowerQuantile: hrvLowerQuantile ?? this.hrvLowerQuantile,
    hrvMiddleQuantile: hrvMiddleQuantile ?? this.hrvMiddleQuantile,
    hrvUpperQuantile: hrvUpperQuantile ?? this.hrvUpperQuantile,
    hrvTimestamp: hrvTimestamp ?? this.hrvTimestamp,
    sleepIndex: sleepIndex ?? this.sleepIndex,
    wakeCount: wakeCount ?? this.wakeCount,
    hasRem: hasRem ?? this.hasRem,
    hasStage: hasStage ?? this.hasStage,
    sleepScoreVersion: sleepScoreVersion ?? this.sleepScoreVersion,
    hrvPoints: hrvPoints ?? this.hrvPoints,
    stages: stages ?? this.stages,
  );
}

class XiaomiActivitySleepHrvPoint {
  const XiaomiActivitySleepHrvPoint({
    required this.timestamp,
    required this.value,
  });

  final DateTime timestamp;
  final int value;
}

class XiaomiActivitySleepStageRecord {
  const XiaomiActivitySleepStageRecord({
    required this.timestamp,
    required this.stage,
    this.endedAt,
  });

  final DateTime timestamp;

  /// Xiaomi's display-stage values: 2 deep, 3 light, 4 REM, 5 awake.
  ///
  /// The native packet decoder can also preserve 0/1 for undocumented or
  /// algorithm-only states; the UI intentionally omits those states.
  final int stage;

  /// The device's stage stream may provide the end of a stage as a duration.
  /// Older compact files only expose a start point and leave this null.
  final DateTime? endedAt;
}

class XiaomiActivityWorkoutRecord {
  const XiaomiActivityWorkoutRecord({
    required this.startedAt,
    required this.endedAt,
    required this.activityType,
    this.distanceMeters,
    this.calories,
  });

  final DateTime startedAt;
  final DateTime endedAt;
  final int activityType;
  final int? distanceMeters;
  final int? calories;
}

/// Xiaomi's health domain, including both real-time wearable state and the
/// historical/measurement messages carried by the FITNESS packet type.
///
/// The wire protocol puts the real-time snapshot and delta reports under
/// SYSTEM (78/79), while the rest of the health data is under FITNESS.  They
/// intentionally live in one system because this is the domain exposed by
/// XMS NodeApi, not because they share a protobuf type.
class XiaomiHealthSystem extends XiaomiPbSystem {
  XiaomiHealthSystem() : _log = getLogger('XiaomiHealthSystem');

  static const _activityFileMaxAttempts = 2;
  static const _activityFileRetryDelay = Duration(milliseconds: 150);

  final Logger _log;
  final _fitnessPackets = StreamController<pb_fitness.Fitness>.broadcast();
  XiaomiHealthState _state = const XiaomiHealthState();
  Future<XiaomiActivityFileSyncResult>? _activitySyncFuture;
  Completer<Uint8List>? _activityFileCompleter;
  BytesBuilder? _activityFileBuffer;
  Timer? _activityWatchdog;
  int _activityTotalChunks = 0;
  int _activityNextChunk = 1;
  final _pendingActivityFiles = <String, Uint8List>{};
  BytesBuilder? _pendingActivityFileBuffer;
  int _pendingActivityTotalChunks = 0;
  int _pendingActivityNextChunk = 1;

  XiaomiHealthState get state => _state;

  Stream<pb_fitness.Fitness> get fitnessPackets => _fitnessPackets.stream;

  @override
  Future<void> dispose() async {
    _activityWatchdog?.cancel();
    _activityWatchdog = null;
    final completer = _activityFileCompleter;
    if (completer != null && !completer.isCompleted) {
      completer.completeError(
        StateError('Xiaomi health system disposed during activity transfer'),
      );
    }
    _activityFileCompleter = null;
    _activityFileBuffer = null;
    _pendingActivityFiles.clear();
    _pendingActivityFileBuffer = null;
    await _fitnessPackets.close();
    await super.dispose();
  }

  Stream<pb_fitness.BasicData> get basicDataReports => fitnessPackets
      .where((packet) => packet.hasBasicData())
      .map((packet) => packet.basicData);

  Stream<pb_fitness.VitalityData_List> get vitalityReports => fitnessPackets
      .where((packet) => packet.hasVitalityDataList())
      .map((packet) => packet.vitalityDataList);

  Stream<pb_fitness.BestSportData_List> get bestSportReports => fitnessPackets
      .where((packet) => packet.hasSportDataList())
      .map((packet) => packet.sportDataList);

  Stream<pb_fitness.PhoneSportData> get phoneSportReports => fitnessPackets
      .where((packet) => packet.hasPhoneSportData())
      .map((packet) => packet.phoneSportData);

  Stream<pb_fitness.PhoneSportDataV2A> get phoneSportReportsV2a =>
      fitnessPackets
          .where((packet) => packet.hasPhoneSportDataV2a())
          .map((packet) => packet.phoneSportDataV2a);

  Stream<pb_fitness.PhoneSportDataV2D> get phoneSportLocationReports =>
      fitnessPackets
          .where((packet) => packet.hasPhoneSportDataV2d())
          .map((packet) => packet.phoneSportDataV2d);

  Stream<pb_fitness.SleepResult> get sleepResults => fitnessPackets
      .where((packet) => packet.hasSleepResult())
      .map((packet) => packet.sleepResult);

  Stream<pb_fitness.WearSportData> get sportReports => fitnessPackets
      .where((packet) => packet.hasWearSportData())
      .map((packet) => packet.wearSportData);

  Stream<pb_fitness.WearSportDataV2A> get sportReportsV2 => fitnessPackets
      .where((packet) => packet.hasWearSportDataV2a())
      .map((packet) => packet.wearSportDataV2a);

  Stream<pb_fitness.WearSensorData> get sensorReports => fitnessPackets
      .where((packet) => packet.hasWearSensorData())
      .map((packet) => packet.wearSensorData);

  Stream<pb_fitness.ECGData> get ecgReports => fitnessPackets
      .where((packet) => packet.hasEcgData())
      .map((packet) => packet.ecgData);

  Stream<pb_fitness.ECGStatus> get ecgStatusReports => fitnessPackets
      .where((packet) => packet.hasEcgStatus())
      .map((packet) => packet.ecgStatus);

  /// Heart-rate samples emitted by the aggregate, sport, and ECG payloads.
  ///
  /// The Xiaomi protocol does not define one standalone heart-rate packet
  /// type.  Keeping the extraction here means callers do not need to know
  /// which firmware-specific FITNESS payload carried the sample.
  Stream<int> get heartRateReports => fitnessPackets.expand((packet) {
    final values = <int>[];
    if (packet.hasBasicData() && packet.basicData.hasHeartRate()) {
      values.add(packet.basicData.heartRate);
    }
    if (packet.hasWearSportData() && packet.wearSportData.hasHeartRate()) {
      values.add(packet.wearSportData.heartRate);
    }
    if (packet.hasWearSportDataV2a() &&
        packet.wearSportDataV2a.hasHeartRate()) {
      values.add(packet.wearSportDataV2a.heartRate);
    }
    if (packet.hasEcgData() && packet.ecgData.hasHeartRate()) {
      values.add(packet.ecgData.heartRate);
    }
    if (packet.hasSleepResult()) {
      for (final section in packet.sleepResult.sectionList) {
        if (section.hasAverageHeartRate()) {
          values.add(section.averageHeartRate);
        }
      }
    }
    return values;
  });

  /// Blood-oxygen samples currently exposed by the device protocol.
  ///
  /// Xiaomi exposes blood oxygen measurements as part of sleep sections,
  /// rather than as a separate measurement packet.
  Stream<int> get bloodOxygenReports => sleepResults.expand(
    (result) => result.sectionList
        .where((section) => section.hasAverageBloodOxygen())
        .map((section) => section.averageBloodOxygen),
  );

  Stream<pb_fitness.WomenHealth> get womenHealthReports => fitnessPackets
      .where((packet) => packet.hasWomenHealth())
      .map((packet) => packet.womenHealth);

  Stream<pb_fitness.WomenHealth_Section_List> get womenHealthSectionReports =>
      fitnessPackets
          .where((packet) => packet.hasSectionList())
          .map((packet) => packet.sectionList);

  Stream<pb_fitness.SleepRegularity> get sleepRegularityReports =>
      fitnessPackets
          .where((packet) => packet.hasSleepRegularity())
          .map((packet) => packet.sleepRegularity);

  Stream<pb_fitness.SleepDisorder> get sleepDisorderReports => fitnessPackets
      .where((packet) => packet.hasSleepDisorder())
      .map((packet) => packet.sleepDisorder);

  Stream<pb_fitness.SportStatus> get sportStatusReports => fitnessPackets
      .where((packet) => packet.hasSportStatus())
      .map((packet) => packet.sportStatus);

  Stream<pb_fitness.SportResponse> get sportResponses => fitnessPackets
      .where((packet) => packet.hasSportResponse())
      .map((packet) => packet.sportResponse);

  /// Returns the latest basic daily aggregate reported by the device.
  Future<pb_fitness.BasicData> fetchBasicData() => _requestFitness(
    id: pb_fitness.Fitness_FitnessID.GET_BASIC_DATA,
    payload: pb_fitness.Fitness(),
    responseIds: {
      pb_fitness.Fitness_FitnessID.GET_BASIC_DATA.value,
      pb_fitness.Fitness_FitnessID.REPORT_BASIC_DATA.value,
    },
    hasResponse: (fitness) => fitness.hasBasicData(),
    response: (fitness) => fitness.basicData,
  );

  /// Returns the IDs of today's or historical fitness records.
  Future<Uint8List> fetchFitnessIds({bool history = false}) => _requestBytes(
    id: history
        ? pb_fitness.Fitness_FitnessID.GET_HISTORY_FITNESS_IDS
        : pb_fitness.Fitness_FitnessID.GET_TODAY_FITNESS_IDS,
    payload: history
        ? pb_fitness.Fitness()
        : pb_fitness.Fitness(syncParam: pb_fitness.SyncParam(reason: 0)),
    timeout: const Duration(seconds: 30),
    hasResponse: (_) => true,
  );

  Future<Uint8List> requestFitnessIds(Uint8List ids) => _requestBytes(
    id: pb_fitness.Fitness_FitnessID.REQUEST_FITNESS_IDS,
    payload: pb_fitness.Fitness(ids: ids),
  );

  Future<Uint8List> requestFitnessId(Uint8List id) => _requestBytes(
    id: pb_fitness.Fitness_FitnessID.REQUEST_FITNESS_IDS,
    // Xiaomi's activity-file request uses the repeated-id wire slot (field 2)
    // even when it contains exactly one seven-byte file id.
    payload: pb_fitness.Fitness(ids: id),
  );

  Future<void> confirmFitnessId(Uint8List id) => _sendFitness(
    pb_fitness.Fitness_FitnessID.CONFIRM_FITNESS_ID,
    payload: pb_fitness.Fitness(id: id),
  );

  /// Synchronizes the activity files used by Xiaomi's stable health protocol.
  ///
  /// The newer aggregate requests (41/44) are not implemented by all Vela
  /// firmwares.  Activity files are the compatible path used by Gadgetbridge:
  /// request ids, request each seven-byte file, receive a separate fitness
  /// channel stream, then acknowledge the file.
  ///
  /// Health synchronization can be started by the device page, the health
  /// page, or the command bus.  All three entry points share the same
  /// protocol system, so concurrent calls must join the active transfer
  /// instead of interleaving request IDs and file chunks.
  Future<XiaomiActivityFileSyncResult> syncActivityFiles() {
    final active = _activitySyncFuture;
    if (active != null) {
      _log.fine('[${entity.id}] joining active Xiaomi health file sync');
      return active;
    }

    _log.info('[${entity.id}] Xiaomi health file sync started');
    final sync = _syncActivityFiles();
    _activitySyncFuture = sync;
    sync.then<void>(
      (result) {
        _log.info(
          '[${entity.id}] Xiaomi health file sync completed: '
          'files=${result.filesReceived}, skipped=${result.filesSkipped}, '
          'failed=${result.failedFiles.length}',
        );
        if (identical(_activitySyncFuture, sync)) _activitySyncFuture = null;
      },
      onError: (Object error, StackTrace stackTrace) {
        _log.warning(
          '[${entity.id}] Xiaomi health file sync failed',
          error,
          stackTrace,
        );
        if (identical(_activitySyncFuture, sync)) _activitySyncFuture = null;
      },
    );
    return sync;
  }

  Future<XiaomiActivityFileSyncResult> _syncActivityFiles() async {
    final daily = <XiaomiActivityDailyRecord>[];
    final samples = <XiaomiActivitySampleRecord>[];
    final sleep = <XiaomiActivitySleepRecord>[];
    final workouts = <XiaomiActivityWorkoutRecord>[];
    final abnormalHealthRecords = <XiaomiActivityAbnormalHealthRecord>[];
    final failedFiles = <XiaomiActivityFileFailure>[];
    var received = 0;
    var skipped = 0;

    // Mi Fitness/Gadgetbridge starts the file queue as soon as today's IDs
    // arrive and requests the historical IDs in parallel. Waiting for both
    // ID responses before requesting the first file creates a window in which
    // the wearable can emit the first activity chunk without a receiver.
    final requested = <String>{};

    Future<Uint8List?> fetchIds({required bool history}) async {
      try {
        final ids = await fetchFitnessIds(history: history);
        _log.fine(
          '[${entity.id}] Xiaomi ${history ? 'history' : 'today'} '
          'activity id list received: ${ids.length} bytes',
        );
        return ids;
      } catch (error, stackTrace) {
        _log.warning(
          '[${entity.id}] Xiaomi ${history ? 'history' : 'today'} activity '
          'id list unavailable; continuing with the other source',
          error,
          stackTrace,
        );
        return null;
      }
    }

    List<Uint8List> decodeIds(Uint8List raw) {
      if (raw.length % 7 != 0) {
        throw ProtocolException(
          'Invalid Xiaomi activity id list length ${raw.length}',
        );
      }
      final result = <Uint8List>[];
      for (var offset = 0; offset < raw.length; offset += 7) {
        final id = Uint8List.fromList(raw.sublist(offset, offset + 7));
        final timestamp = id[0] | (id[1] << 8) | (id[2] << 16) | (id[3] << 24);
        if (timestamp == 0 && id[5] == 0) {
          skipped++;
          _log.warning('[${entity.id}] ignoring empty Xiaomi activity file id');
          continue;
        }
        result.add(id);
      }
      return result;
    }

    Future<void> fetchFiles(Uint8List raw) async {
      late final List<Uint8List> ids;
      try {
        ids = decodeIds(raw);
      } catch (error, stackTrace) {
        _log.warning(
          '[${entity.id}] invalid Xiaomi activity id list; skipping this '
          'source',
          error,
          stackTrace,
        );
        return;
      }

      for (final id in ids) {
        final key = _activityIdKey(id);
        if (!requested.add(key)) continue;

        Uint8List? file;
        Object? requestError;
        StackTrace? requestStackTrace;
        var attempts = 0;
        var emptyFile = false;
        for (var attempt = 1; attempt <= _activityFileMaxAttempts; attempt++) {
          attempts = attempt;
          try {
            file = await _requestActivityFile(id);
            break;
          } catch (error, stackTrace) {
            requestError = error;
            requestStackTrace = stackTrace;
            // Xiaomi periodically advertises an empty/placeholder activity
            // file. It is a valid skip, not a transfer failure, and retrying
            // it only changes the protocol sequence without adding data.
            if (_isEmptyActivityFileError(error)) {
              emptyFile = true;
              break;
            }
            if (attempt >= _activityFileMaxAttempts) break;
            _log.warning(
              '[${entity.id}] Xiaomi activity file $key failed on attempt '
              '$attempt/$_activityFileMaxAttempts; retrying',
              error,
              stackTrace,
            );
            await Future<void>.delayed(_activityFileRetryDelay);
          }
        }

        if (emptyFile) {
          skipped++;
          _log.warning(
            '[${entity.id}] skipping empty Xiaomi activity file $key',
          );
          continue;
        }
        if (file == null) {
          final error =
              requestError ??
              StateError('Xiaomi activity file request returned no data');
          failedFiles.add(
            XiaomiActivityFileFailure(
              id: key,
              attempts: attempts,
              error: error.toString(),
            ),
          );
          _log.warning(
            '[${entity.id}] giving up Xiaomi activity file $key after '
            '$attempts attempts; continuing with the next file',
            error,
            requestStackTrace,
          );
          continue;
        }

        late final _ParsedActivityFile parsed;
        try {
          parsed = _parseActivityFile(file);
        } catch (error, stackTrace) {
          failedFiles.add(
            XiaomiActivityFileFailure(
              id: key,
              attempts: attempts,
              error: 'parse failed: $error',
            ),
          );
          _log.warning(
            '[${entity.id}] could not parse Xiaomi activity file $key; '
            'continuing with the next file',
            error,
            stackTrace,
          );
          continue;
        }
        if (parsed.daily != null) daily.add(parsed.daily!);
        samples.addAll(parsed.samples);
        sleep.addAll(parsed.sleep);
        workouts.addAll(parsed.workouts);
        abnormalHealthRecords.addAll(parsed.abnormalHealthRecords);
        received++;
        try {
          await confirmFitnessId(id);
        } catch (error, stackTrace) {
          // The payload is already validated and parsed. Keep it even if the
          // acknowledgement is lost; the device can advertise it again on a
          // later sync, whereas discarding valid data would be worse.
          failedFiles.add(
            XiaomiActivityFileFailure(
              id: key,
              attempts: attempts,
              error: 'confirmation failed: $error',
            ),
          );
          _log.warning(
            '[${entity.id}] Xiaomi activity file $key was received but could '
            'not be confirmed; continuing',
            error,
            stackTrace,
          );
        }
      }
    }

    // Start the first file request before asking for the historical IDs. The
    // device may begin emitting the file immediately after this request, so
    // the completer must already be installed when the history request is
    // put on the wire.
    final todayRaw = await fetchIds(history: false);
    final todayFilesFuture = todayRaw == null ? null : fetchFiles(todayRaw);
    final historyFuture = fetchIds(history: true);
    if (todayFilesFuture != null) await todayFilesFuture;
    final historyRaw = await historyFuture;
    if (historyRaw != null) await fetchFiles(historyRaw);

    return XiaomiActivityFileSyncResult(
      daily: daily,
      samples: samples,
      sleep: sleep,
      workouts: workouts,
      abnormalHealthRecords: abnormalHealthRecords,
      filesReceived: received,
      failedFiles: List.unmodifiable(failedFiles),
      filesSkipped: skipped,
    );
  }

  bool _isEmptyActivityFileError(Object error) =>
      error is ProtocolException &&
      error.message == 'Xiaomi activity file is too short';

  String _activityIdKey(Uint8List id) =>
      id.map((v) => v.toRadixString(16).padLeft(2, '0')).join();

  Future<Uint8List> _requestActivityFile(Uint8List id) async {
    if (_activityFileCompleter != null) {
      throw StateError('Xiaomi activity file request already in progress');
    }
    final pending = _pendingActivityFiles.remove(_activityIdKey(id));
    if (pending != null) {
      _log.fine(
        '[${entity.id}] consuming buffered Xiaomi activity file '
        '${_activityIdKey(id)}',
      );
      return pending;
    }
    final completer = Completer<Uint8List>();
    final key = _activityIdKey(id);
    _log.fine('[${entity.id}] requesting Xiaomi activity file $key');
    _activityFileCompleter = completer;
    _activityFileBuffer = BytesBuilder(copy: false);
    _activityTotalChunks = 0;
    _activityNextChunk = 1;
    _armActivityWatchdog();
    try {
      await _sendFitness(
        pb_fitness.Fitness_FitnessID.REQUEST_FITNESS_IDS,
        payload: pb_fitness.Fitness(ids: id),
      );
      return await completer.future;
    } finally {
      _activityWatchdog?.cancel();
      _activityWatchdog = null;
      _activityFileCompleter = null;
      _activityFileBuffer = null;
    }
  }

  void _armActivityWatchdog() {
    _activityWatchdog?.cancel();
    final waitingForFirstChunk = _activityNextChunk == 1;
    _activityWatchdog = Timer(
      waitingForFirstChunk
          ? const Duration(seconds: 45)
          : const Duration(seconds: 10),
      () {
        final completer = _activityFileCompleter;
        if (completer == null || completer.isCompleted) return;
        _log.warning(
          '[${entity.id}] Xiaomi activity file transfer timed out: '
          'chunk=${_activityNextChunk - 1}/$_activityTotalChunks',
        );
        completer.completeError(
          ProtocolException(
            waitingForFirstChunk
                ? 'Xiaomi activity file preparation timed out before the first chunk'
                : 'Xiaomi activity file transfer stalled at chunk '
                      '${_activityNextChunk - 1}/$_activityTotalChunks',
          ),
        );
      },
    );
  }

  /// Receives one raw activity-file chunk from SPP activity or L2 fileFitness.
  void onActivityPayload(Uint8List payload) {
    final completer = _activityFileCompleter;
    if (completer == null || completer.isCompleted) {
      _bufferUnsolicitedActivityPayload(payload);
      return;
    }
    if (payload.length < 4) {
      _log.warning(
        '[${entity.id}] dropping Xiaomi activity chunk shorter than header '
        '(${payload.length} bytes)',
      );
      completer.completeError(
        ProtocolException('Xiaomi activity chunk too short'),
      );
      return;
    }
    final view = ByteData.sublistView(payload);
    final total = view.getUint16(0, Endian.little);
    final number = view.getUint16(2, Endian.little);
    if (total == 0 || number == 0 || number > total) {
      _log.warning(
        '[${entity.id}] dropping invalid Xiaomi activity chunk '
        '$number/$total',
      );
      completer.completeError(
        ProtocolException('Invalid Xiaomi activity chunk $number/$total'),
      );
      return;
    }
    if (number == 1) {
      _activityFileBuffer = BytesBuilder(copy: false);
      _activityTotalChunks = total;
      _activityNextChunk = 1;
    }
    if (total != _activityTotalChunks || number != _activityNextChunk) {
      _log.warning(
        '[${entity.id}] unexpected Xiaomi activity chunk '
        '$number/$total, expected $_activityNextChunk/$_activityTotalChunks',
      );
      completer.completeError(
        ProtocolException(
          'Unexpected Xiaomi activity chunk $number/$total '
          '(expected $_activityNextChunk/$_activityTotalChunks)',
        ),
      );
      return;
    }
    _activityFileBuffer!.add(payload.sublist(4));
    _activityNextChunk++;
    _armActivityWatchdog();
    _log.fine(
      '[${entity.id}] Xiaomi activity chunk $number/$total '
      '(${payload.length - 4} bytes)',
    );
    if (number == total) {
      final data = _activityFileBuffer!.toBytes();
      _log.fine(
        '[${entity.id}] Xiaomi activity file transfer completed: '
        '$number/$total chunks, ${data.length} bytes',
      );
      try {
        completer.complete(_normalizeActivityFile(data));
      } catch (error, stackTrace) {
        _log.warning(
          '[${entity.id}] Xiaomi activity file validation failed',
          error,
          stackTrace,
        );
        completer.completeError(error, stackTrace);
      }
    }
  }

  /// Xiaomi can emit the first file chunk in the interval between the file
  /// request and the next request. Mi Fitness/Gadgetbridge keep an assembler
  /// alive for that stream; dropping it here made the first health sync depend
  /// on a retry. A completed file is retained only after header and CRC
  /// validation, then bounded by the number of pending files.
  void _bufferUnsolicitedActivityPayload(Uint8List payload) {
    if (payload.length < 4) {
      _log.fine(
        '[${entity.id}] dropping unsolicited Xiaomi activity payload '
        'shorter than header (${payload.length} bytes)',
      );
      return;
    }
    final view = ByteData.sublistView(payload);
    final total = view.getUint16(0, Endian.little);
    final number = view.getUint16(2, Endian.little);
    if (total == 0 || number == 0 || number > total) {
      _pendingActivityFileBuffer = null;
      _pendingActivityTotalChunks = 0;
      _pendingActivityNextChunk = 1;
      _log.fine(
        '[${entity.id}] dropping invalid unsolicited Xiaomi activity '
        'chunk $number/$total',
      );
      return;
    }
    if (number == 1) {
      _pendingActivityFileBuffer = BytesBuilder(copy: false);
      _pendingActivityTotalChunks = total;
      _pendingActivityNextChunk = 1;
    }
    if (_pendingActivityFileBuffer == null ||
        total != _pendingActivityTotalChunks ||
        number != _pendingActivityNextChunk) {
      _pendingActivityFileBuffer = null;
      _pendingActivityTotalChunks = 0;
      _pendingActivityNextChunk = 1;
      _log.fine(
        '[${entity.id}] dropping out-of-order unsolicited Xiaomi activity '
        'chunk $number/$total',
      );
      return;
    }
    _pendingActivityFileBuffer!.add(payload.sublist(4));
    _pendingActivityNextChunk++;
    if (number != total) return;

    final data = _pendingActivityFileBuffer!.toBytes();
    _pendingActivityFileBuffer = null;
    _pendingActivityTotalChunks = 0;
    _pendingActivityNextChunk = 1;
    try {
      final normalized = _normalizeActivityFile(data);
      final key = _activityIdKey(Uint8List.sublistView(normalized, 0, 7));
      _pendingActivityFiles[key] = normalized;
      while (_pendingActivityFiles.length > 8) {
        _pendingActivityFiles.remove(_pendingActivityFiles.keys.first);
      }
      _log.fine(
        '[${entity.id}] buffered unsolicited Xiaomi activity file '
        '$key (${normalized.length} bytes)',
      );
    } catch (error, stackTrace) {
      _log.fine(
        '[${entity.id}] dropping invalid unsolicited Xiaomi activity file',
        error,
        stackTrace,
      );
    }
  }

  /// Validates the raw file emitted on the Xiaomi activity-file channel.
  ///
  /// Mi Fitness removes the trailing CRC and the seven-byte
  /// FitnessDataId before handing the buffer to its generated server-data
  /// parser. OronBox parses the device file directly, so this method keeps
  /// both the raw file ID and its CRC-validated contents intact.
  Uint8List _normalizeActivityFile(Uint8List data) {
    if (data.length < 13) {
      throw ProtocolException('Xiaomi activity file is too short');
    }
    final view = ByteData.sublistView(data);
    final expected = view.getUint32(data.length - 4, Endian.little);
    final actual = _crc32(Uint8List.sublistView(data, 0, data.length - 4));
    if (expected == actual) return data;
    throw ProtocolException(
      'Xiaomi activity CRC mismatch: ${actual.toRadixString(16)} != '
      '${expected.toRadixString(16)}',
    );
  }

  /// Parses a sleep activity file for protocol tests and diagnostics.
  @visibleForTesting
  XiaomiActivitySleepRecord? parseActivitySleepFileForTesting(Uint8List data) {
    return _primarySleepRecord(parseActivitySleepFilesForTesting(data));
  }

  /// Parses every sleep summary in a device activity file. This is kept
  /// public for protocol tests and diagnostics; normal sync uses the same list
  /// through [XiaomiActivityFileSyncResult.sleep].
  @visibleForTesting
  List<XiaomiActivitySleepRecord> parseActivitySleepFilesForTesting(
    Uint8List data,
  ) {
    final parsed = _parseActivityFile(_normalizeActivityFile(data));
    return parsed.sleep;
  }

  /// Parses Vela's historical daily-type-9 abnormal heart-rate file.
  @visibleForTesting
  List<XiaomiActivityAbnormalHealthRecord>
  parseActivityAbnormalHealthFileForTesting(Uint8List data) {
    return _parseActivityFile(_normalizeActivityFile(data))
        .abnormalHealthRecords;
  }

  List<XiaomiActivityAbnormalHeartRateRecord>
  parseActivityAbnormalHeartRateFileForTesting(Uint8List data) {
    return parseActivityAbnormalHealthFileForTesting(data)
        .where(
          (record) =>
              record.kind == XiaomiActivityAbnormalHealthKind.highHeartRate ||
              record.kind == XiaomiActivityAbnormalHealthKind.lowHeartRate,
        )
        .where((record) => record.value != null && record.threshold != null)
        .map(
          (record) => XiaomiActivityAbnormalHeartRateRecord(
            timestamp: record.timestamp,
            value: record.value!,
            kind: record.kind == XiaomiActivityAbnormalHealthKind.highHeartRate
                ? XiaomiActivityAbnormalHeartRateKind.high
                : XiaomiActivityAbnormalHeartRateKind.low,
            threshold: record.threshold!,
            startedAt: record.startedAt,
            endedAt: record.endedAt,
          ),
        )
        .toList(growable: false);
  }

  XiaomiActivitySleepRecord? _primarySleepRecord(
    List<XiaomiActivitySleepRecord> records,
  ) {
    if (records.isEmpty) return null;
    final indexed = records.where((value) => value.sleepIndex == 1);
    final candidates = indexed.isEmpty ? records : indexed;
    return candidates.reduce(
      (left, right) =>
          left.durationSeconds >= right.durationSeconds ? left : right,
    );
  }

  _ParsedActivityFile _parseActivityFile(Uint8List data) {
    final view = ByteData.sublistView(data);
    final timestamp = view.getUint32(0, Endian.little);
    final version = data[5];
    final flags = data[6];
    final type = (flags >> 7) & 1;
    final subtype = (flags & 0x7f) >> 2;
    final detail = flags & 3;
    if (type == 0 && subtype == 0 && detail == 1) {
      return _ParsedActivityFile(daily: _parseDaily(data, timestamp, version));
    }
    if (type == 0 && subtype == 0 && detail == 0) {
      return _ParsedActivityFile(
        samples: _parseDailyDetails(data, timestamp, version),
      );
    }
    if (type == 0 && (subtype == 3 || subtype == 8)) {
      return _ParsedActivityFile(
        sleep: _parseSleep(data, timestamp, version, subtype),
      );
    }
    if (type == 0 && subtype == 9) {
      return _ParsedActivityFile(
        abnormalHealthRecords: _parseAbnormalHealth(data, version),
      );
    }
    if (type == 1 && detail == 1) {
      final workout = _parseWorkoutSummary(data, timestamp, subtype, version);
      return _ParsedActivityFile(
        workouts: workout == null ? const [] : [workout],
      );
    }
    _log.fine(
      '[${entity.id}] unsupported Xiaomi activity file '
      'type=$type subtype=$subtype detail=$detail version=$version',
    );
    return const _ParsedActivityFile();
  }

  List<XiaomiActivityAbnormalHealthRecord> _parseAbnormalHealth(
    Uint8List data,
    int version,
  ) {
    // Mi Fitness' native AbnormalRecordParser supports only v1/v2 here. The
    // validity header is zero bytes for this daily type, so the binary body
    // starts immediately after the seven-byte FitnessDataId.
    if (version != 1 && version != 2) return const [];
    final limit = data.length - 4;
    const headerSize = 7;
    if (limit < headerSize + 13) return const [];

    final view = ByteData.sublistView(data);
    var offset = headerSize;
    final records = <XiaomiActivityAbnormalHealthRecord>[];
    while (offset + 13 <= limit) {
      final startedSeconds = view.getUint32(offset, Endian.little);
      final endedSeconds = view.getUint32(offset + 4, Endian.little);
      final type = data[offset + 8];
      final threshold = view.getUint16(offset + 9, Endian.little);
      final count = view.getUint16(offset + 11, Endian.little);
      offset += 13;

      if (offset + count * 5 > limit) break;
      final kind = switch (type) {
        1 => XiaomiActivityAbnormalHealthKind.highHeartRate,
        2 => XiaomiActivityAbnormalHealthKind.lowHeartRate,
        3 => XiaomiActivityAbnormalHealthKind.lowBloodOxygen,
        4 => XiaomiActivityAbnormalHealthKind.highStress,
        5 => XiaomiActivityAbnormalHealthKind.irregularHeartbeat,
        _ => null,
      };
      final startedAt = startedSeconds == 0
          ? null
          : xiaomiActivityTimestamp(startedSeconds);
      final endedAt = endedSeconds == 0
          ? null
          : xiaomiActivityTimestamp(endedSeconds);
      if (count == 0) {
        if (kind == XiaomiActivityAbnormalHealthKind.irregularHeartbeat) {
          final eventStart = startedAt ?? endedAt;
          if (eventStart != null) {
            records.add(
              XiaomiActivityAbnormalHealthRecord(
                timestamp: eventStart,
                kind: XiaomiActivityAbnormalHealthKind.irregularHeartbeat,
                startedAt: eventStart,
                endedAt: endedAt ?? startedAt,
              ),
            );
          }
        }
        continue;
      }
      DateTime? firstSampleAt;
      DateTime? lastSampleAt;
      for (var index = 0; index < count; index++) {
        final timestampSeconds = view.getUint32(offset, Endian.little);
        final value = data[offset + 4];
        offset += 5;
        if (timestampSeconds == 0) continue;
        final sampleAt = xiaomiActivityTimestamp(timestampSeconds);
        firstSampleAt ??= sampleAt;
        lastSampleAt = sampleAt;
        if (kind == null ||
            kind == XiaomiActivityAbnormalHealthKind.irregularHeartbeat) {
          continue;
        }
        records.add(
          XiaomiActivityAbnormalHealthRecord(
            timestamp: sampleAt,
            value: value,
            kind: kind,
            threshold: threshold,
            startedAt: startedAt,
            endedAt: endedAt,
          ),
        );
      }
      if (kind == XiaomiActivityAbnormalHealthKind.irregularHeartbeat) {
        final eventStart = startedAt ?? firstSampleAt ?? endedAt;
        final eventEnd = endedAt ?? lastSampleAt ?? startedAt;
        if (eventStart != null) {
          records.add(
            XiaomiActivityAbnormalHealthRecord(
              timestamp: eventStart,
              kind: XiaomiActivityAbnormalHealthKind.irregularHeartbeat,
              startedAt: eventStart,
              endedAt: eventEnd,
            ),
          );
        }
      }
    }
    return records;
  }

  XiaomiActivityDailyRecord? _parseDaily(
    Uint8List data,
    int timestamp,
    int version,
  ) {
    final headerSize = switch (version) {
      3 || 4 => 3,
      5 => 4,
      _ => 0,
    };
    final slots = switch (version) {
      3 || 4 => 21,
      5 => 32,
      _ => 0,
    };
    final limit = data.length - 4;
    if (headerSize == 0 || limit < 8 + headerSize) return null;
    final view = ByteData.sublistView(data);
    var offset = 8 + headerSize;
    int? steps;
    int? activeCalories;
    int? calories;
    int? restingHeartRate;
    int? minHeartRate;
    int? maxHeartRate;
    int? averageHeartRate;
    int? minStress;
    int? maxStress;
    int? averageStress;
    int? standingBitmap;
    int? minBloodOxygen;
    int? maxBloodOxygen;
    int? averageBloodOxygen;
    int? vitalityIncreaseLight;
    int? vitalityIncreaseModerate;
    int? vitalityIncreaseHigh;
    int? vitalityCurrent;
    bool valid(int slot) => (data[8 + slot ~/ 8] & (1 << (7 - slot % 8))) != 0;
    for (var slot = 0; slot < slots; slot++) {
      switch (slot) {
        case 0:
          if (offset + 4 > limit) return null;
          final value = view.getInt32(offset, Endian.little);
          if (valid(slot)) steps = value;
          offset += 4;
        case 1:
          if (offset + 2 > limit) return null;
          final value = view.getUint16(offset, Endian.little);
          if (valid(slot)) activeCalories = value;
          offset += 2;
        case 2:
          offset += 1;
        case 3:
          if (offset >= limit) return null;
          if (valid(slot)) restingHeartRate = data[offset];
          offset += 1;
        case 4:
          if (offset >= limit) return null;
          if (valid(slot)) maxHeartRate = data[offset];
          offset += 1;
        case 5:
          if (offset + 4 > limit) return null;
          offset += 4;
        case 6:
          if (offset >= limit) return null;
          if (valid(slot)) minHeartRate = data[offset];
          offset += 1;
        case 7:
          if (offset + 4 > limit) return null;
          offset += 4;
        case 8:
          if (offset >= limit) return null;
          if (valid(slot)) averageHeartRate = data[offset];
          offset += 1;
        case 9:
          if (offset >= limit) return null;
          if (valid(slot)) averageStress = data[offset];
          offset += 1;
        case 10:
          if (offset >= limit) return null;
          if (valid(slot)) maxStress = data[offset];
          offset += 1;
        case 11:
          if (offset >= limit) return null;
          if (valid(slot)) minStress = data[offset];
          offset += 1;
        case 12:
          if (offset + 3 > limit) return null;
          if (valid(slot)) {
            standingBitmap =
                data[offset] |
                (data[offset + 1] << 8) |
                (data[offset + 2] << 16);
          }
          offset += 3;
        case 13:
          if (offset + 2 > limit) return null;
          final value = view.getUint16(offset, Endian.little);
          if (valid(slot)) calories = value;
          offset += 2;
        case 14:
          offset += 2;
        case 15:
          offset += 1;
        case 16:
          if (offset >= limit) return null;
          if (valid(slot)) maxBloodOxygen = data[offset];
          offset += 1;
        case 17:
          if (offset + 4 > limit) return null;
          offset += 4;
        case 18:
          if (offset >= limit) return null;
          if (valid(slot)) minBloodOxygen = data[offset];
          offset += 1;
        case 19:
          if (offset + 4 > limit) return null;
          offset += 4;
        case 20:
          if (offset >= limit) return null;
          if (valid(slot)) averageBloodOxygen = data[offset];
          offset += 1;
        case 21 || 22:
          offset += 2;
        case 23:
          offset += 1;
        case 24:
          if (offset >= limit) return null;
          if (valid(slot)) vitalityIncreaseLight = data[offset];
          offset += 1;
        case 25:
          if (offset >= limit) return null;
          if (valid(slot)) vitalityIncreaseModerate = data[offset];
          offset += 1;
        case 26:
          if (offset >= limit) return null;
          if (valid(slot)) vitalityIncreaseHigh = data[offset];
          offset += 1;
        case 27:
          if (offset + 2 > limit) return null;
          if (valid(slot)) {
            vitalityCurrent = view.getUint16(offset, Endian.little);
          }
          offset += 2;
        case 28 || 29:
          offset += 1;
        case 30 || 31:
          offset += 2;
      }
      if (offset > limit) return null;
    }
    return XiaomiActivityDailyRecord(
      date: xiaomiActivityTimestamp(timestamp),
      steps: steps,
      activeCalories: activeCalories,
      calories: calories,
      restingHeartRate: restingHeartRate,
      minHeartRate: minHeartRate,
      maxHeartRate: maxHeartRate,
      averageHeartRate: averageHeartRate,
      minStress: minStress,
      maxStress: maxStress,
      averageStress: averageStress,
      standingBitmap: standingBitmap,
      minBloodOxygen: minBloodOxygen,
      maxBloodOxygen: maxBloodOxygen,
      averageBloodOxygen: averageBloodOxygen,
      vitalityIncreaseLight: vitalityIncreaseLight,
      vitalityIncreaseModerate: vitalityIncreaseModerate,
      vitalityIncreaseHigh: vitalityIncreaseHigh,
      vitalityCurrent: vitalityCurrent,
    );
  }

  List<XiaomiActivitySampleRecord> _parseDailyDetails(
    Uint8List data,
    int timestamp,
    int version,
  ) {
    final headerSize = switch (version) {
      1 || 2 => 4,
      3 => 5,
      4 => 6,
      _ => 0,
    };
    final limit = data.length - 4;
    if (headerSize == 0 || limit < 8 + headerSize) return const [];

    final parser = _XiaomiComplexActivityParser(
      data: data,
      offset: 8 + headerSize,
      limit: limit,
      header: data.sublist(8, 8 + headerSize),
    );
    final samples = <XiaomiActivitySampleRecord>[];
    var sampleTimestamp = timestamp;
    while (parser.hasRemaining) {
      parser.reset();
      int? steps;
      int? activeCalories;
      int? distanceMeters;
      int? heartRate;
      int? energy;
      int? bloodOxygen;
      int? stress;
      var includeExtraEntry = false;

      if (parser.nextGroup(16)) {
        if (parser.hasSecond) includeExtraEntry = parser.get(1, 1) == 1;
        if (parser.hasThird) steps = parser.get(2, 14);
      }
      if (parser.nextGroup(8) && parser.hasSecond) {
        // The value occupies the low six bits of this group. This matches
        // Gadgetbridge's XiaomiComplexActivityParser.get(2, 6).
        activeCalories = parser.get(2, 6);
      }
      parser.nextGroup(8);
      if (parser.nextGroup(16) && parser.hasFirst) {
        distanceMeters = (parser.get(0, 16) / 100).round();
      }
      if (parser.nextGroup(8) && parser.hasFirst) {
        final value = parser.get(0, 8);
        if (value != 255) heartRate = value;
      }
      if (parser.nextGroup(8) && parser.hasFirst) {
        energy = parser.get(0, 8);
      }
      parser.nextGroup(16);
      if (version >= 3) {
        if (parser.nextGroup(8) && parser.hasFirst) {
          final value = parser.get(0, 8);
          if (value != 255) bloodOxygen = value;
        }
        if (parser.nextGroup(8) && parser.hasFirst) {
          final value = parser.get(0, 8);
          if (value != 255) stress = value;
        }
      }
      if (includeExtraEntry) parser.consumeByte();
      if (version >= 4) {
        parser.nextGroup(16);
        parser.nextGroup(16);
      }
      if (!parser.progressed) break;
      samples.add(
        XiaomiActivitySampleRecord(
          timestamp: xiaomiActivityTimestamp(sampleTimestamp),
          steps: steps,
          activeCalories: activeCalories,
          distanceMeters: distanceMeters,
          heartRate: heartRate,
          energy: energy,
          bloodOxygen: bloodOxygen,
          stress: stress,
        ),
      );
      sampleTimestamp += 60;
    }
    return samples;
  }

  XiaomiActivityWorkoutRecord? _parseWorkoutSummary(
    Uint8List data,
    int timestamp,
    int subtype,
    int version,
  ) {
    final headerSize = _workoutHeaderSize(subtype, version);
    final limit = data.length - 4;
    if (headerSize == 0 || limit < 8 + headerSize + 8) return null;
    final view = ByteData.sublistView(data);
    var offset = 8 + headerSize;
    if (subtype == 0x16 || subtype == 0x17) {
      if (offset + 2 > limit) return null;
      offset += 2;
    }
    if (offset + 8 > limit) return null;
    final started = view.getUint32(offset, Endian.little);
    final ended = view.getUint32(offset + 4, Endian.little);
    if (started == 0 || ended <= started) return null;

    int? distanceMeters;
    int? calories;
    final commonOffset = offset + 8;
    if (subtype == 0x16 || subtype == 0x17) {
      if (commonOffset + 14 <= limit) {
        distanceMeters = view.getUint32(commonOffset + 8, Endian.little);
        calories = view.getUint16(commonOffset + 12, Endian.little);
      }
    } else if (commonOffset + 6 <= limit) {
      if (subtype == 0x01 || subtype == 0x02) {
        if (commonOffset + 8 <= limit) {
          distanceMeters = view.getUint32(commonOffset + 4, Endian.little);
        }
        if (commonOffset + 10 <= limit) {
          calories = view.getUint16(commonOffset + 8, Endian.little);
        }
      } else {
        calories = view.getUint16(commonOffset + 4, Endian.little);
      }
    }
    return XiaomiActivityWorkoutRecord(
      startedAt: xiaomiActivityTimestamp(started),
      endedAt: xiaomiActivityTimestamp(ended),
      activityType: subtype,
      distanceMeters: distanceMeters,
      calories: calories,
    );
  }

  int _workoutHeaderSize(int subtype, int version) => switch (subtype) {
    0x01 || 0x02 => version == 4 ? 4 : 0,
    0x03 => switch (version) {
      5 => 4,
      9 => 6,
      10 => 8,
      11 => 9,
      _ => 0,
    },
    0x06 || 0x07 => switch (version) {
      8 => 7,
      9 => 8,
      _ => 0,
    },
    0x08 => switch (version) {
      5 => 3,
      7 => 5,
      8 || 9 || 10 => 6,
      _ => 0,
    },
    0x09 => switch (version) {
      6 => 4,
      7 => 5,
      8 => 8,
      _ => 0,
    },
    0x0b => version >= 3 && version <= 6 ? 4 : 0,
    0x0d => switch (version) {
      4 => 4,
      6 || 7 => 5,
      _ => 0,
    },
    0x0e => version == 3 || version == 5 ? 5 : 0,
    0x10 => version == 5 ? 4 : 0,
    0x16 => switch (version) {
      1 => 5,
      4 => 7,
      5 || 6 => 9,
      9 => 13,
      _ => 0,
    },
    0x17 => version == 4 ? 5 : 0,
    _ => 0,
  };

  List<XiaomiActivitySleepRecord> _parseSleep(
    Uint8List data,
    int timestamp,
    int version,
    int subtype,
  ) {
    if (subtype == 3 && version == 2) {
      final record = _parseSleepStages(data);
      return record == null ? const [] : [record];
    }
    final limit = data.length - 4;
    if (subtype == 8) {
      return _parseSleepDetails(data, version, limit);
    }
    if (limit < 37) return const [];
    final view = ByteData.sublistView(data);
    final offset = 8 + 7;
    final durationMinutes = view.getUint16(offset, Endian.little);
    final started = view.getUint32(offset + 2, Endian.little);
    final ended = view.getUint32(offset + 6, Endian.little);
    if (started == 0 || ended == 0 || durationMinutes == 0) return const [];
    return [
      XiaomiActivitySleepRecord(
        startedAt: xiaomiActivityTimestamp(started),
        endedAt: xiaomiActivityTimestamp(ended),
        durationSeconds: durationMinutes * 60,
      ),
    ];
  }

  List<XiaomiActivitySleepRecord> _parseSleepDetails(
    Uint8List data,
    int version,
    int limit,
  ) {
    // Versions 1–4 use the older compact all-day-sleep layout.  The schema
    // files shipped by Mi Fitness define the report layout used by versions 5
    // and 6; do not apply that layout to the compact files.
    if (version < 5) {
      return _parseLegacySleepDetails(data, version, limit);
    }
    if (version > 6) return const [];
    final validityLength = _sleepValidityLength(version);
    // sleepFull(1) + start/end(8) + quality/efficiency(2) + four u32
    // duration/time fields(16). v6 appends eleven HRV summary fields:
    // six u16 values, one u32 timestamp, and four more u16 values.
    const fixedRecordLength = 27;
    const hrvSummaryLength = 24;
    final minimumRecordLength =
        fixedRecordLength + (version == 6 ? hrvSummaryLength : 0);
    if (validityLength == 0 ||
        limit < 8 + validityLength + minimumRecordLength) {
      return const [];
    }
    final view = ByteData.sublistView(data);
    final validity = data.sublist(8, 8 + validityLength);
    var offset = 8 + validityLength;

    // Mi Fitness's schema parser consumes the fixed record in this order. The
    // validity bits only mark a value as usable; they do not remove the value
    // from the body.
    int? readUint8() {
      if (offset + 1 > limit) return null;
      return data[offset++];
    }

    int? readUint32() {
      if (offset + 4 > limit) return null;
      final value = view.getUint32(offset, Endian.little);
      offset += 4;
      return value;
    }

    int? readUint16() {
      if (offset + 2 > limit) return null;
      final value = view.getUint16(offset, Endian.little);
      offset += 2;
      return value;
    }

    final sleepFullRaw = readUint8();
    final startedRaw = readUint32();
    final endedRaw = readUint32();
    final qualityRaw = readUint8();
    final efficiencyRaw = readUint8();
    final asleepDurationRaw = readUint32();
    final bedDurationRaw = readUint32();
    final goBedRaw = readUint32();
    final leaveBedRaw = readUint32();
    if ([
      sleepFullRaw,
      startedRaw,
      endedRaw,
      qualityRaw,
      efficiencyRaw,
      asleepDurationRaw,
      bedDurationRaw,
      goBedRaw,
      leaveBedRaw,
    ].any((value) => value == null)) {
      return const [];
    }

    int? hrvAverageRaw;
    int? hrvStandardDeviationRaw;
    int? hrvMedianRaw;
    int? hrvLowerQuantileRaw;
    int? hrvUpperQuantileRaw;
    int? hrvMiddleQuantileRaw;
    int? hrvTimestampRaw;
    int? hrvMaximumRaw;
    int? hrvMinimumRaw;
    int? hrvBaselineMaximumRaw;
    int? hrvBaselineMinimumRaw;
    if (version == 6) {
      hrvAverageRaw = readUint16();
      hrvStandardDeviationRaw = readUint16();
      hrvMedianRaw = readUint16();
      hrvLowerQuantileRaw = readUint16();
      hrvUpperQuantileRaw = readUint16();
      hrvMiddleQuantileRaw = readUint16();
      hrvTimestampRaw = readUint32();
      hrvMaximumRaw = readUint16();
      hrvMinimumRaw = readUint16();
      hrvBaselineMaximumRaw = readUint16();
      hrvBaselineMinimumRaw = readUint16();
      if ([
        hrvAverageRaw,
        hrvStandardDeviationRaw,
        hrvMedianRaw,
        hrvLowerQuantileRaw,
        hrvUpperQuantileRaw,
        hrvMiddleQuantileRaw,
        hrvTimestampRaw,
        hrvMaximumRaw,
        hrvMinimumRaw,
        hrvBaselineMaximumRaw,
        hrvBaselineMinimumRaw,
      ].any((value) => value == null)) {
        return const [];
      }
    }

    final heartRate = _readSleepRecordSeries(
      view: view,
      limit: limit,
      offset: offset,
      version: version,
      valid: _sleepValidity(validity, version, _SleepValidityField.heartRate),
    );
    offset = heartRate.offset;
    final bloodOxygen = _readSleepRecordSeries(
      view: view,
      limit: limit,
      offset: offset,
      version: version,
      valid: _sleepValidity(validity, version, _SleepValidityField.bloodOxygen),
    );
    offset = bloodOxygen.offset;

    final hrv = _readSleepRecordSeries(
      view: view,
      limit: limit,
      offset: offset,
      version: version,
      valid:
          version == 6 &&
          _sleepValidity(validity, version, _SleepValidityField.hrvSeries),
      sampleWidth: 2,
    );
    offset = hrv.offset;

    final snore = _readSleepRecordSeries(
      view: view,
      limit: limit,
      offset: offset,
      version: version,
      valid: _sleepValidity(validity, version, _SleepValidityField.snore),
      sampleWidth: 4,
    );
    offset = snore.offset;

    // Mi Fitness calls the remaining bytes featureData and passes them to its
    // native sleep algorithm. The known packet stream is decoded when
    // present; other feature-data records remain opaque.
    final stagePackets = _parseSleepStagePackets(data, offset, limit);
    final packetSummary = stagePackets.summary;
    final startedValue =
        _sleepValidity(validity, version, _SleepValidityField.start) &&
            startedRaw! > 0
        ? startedRaw
        : null;
    final endedValue =
        _sleepValidity(validity, version, _SleepValidityField.end) &&
            endedRaw! > 0
        ? endedRaw
        : null;
    final goBedValue =
        _sleepValidity(validity, version, _SleepValidityField.goBed) &&
            goBedRaw! > 0
        ? goBedRaw
        : null;
    final leaveBedValue =
        _sleepValidity(validity, version, _SleepValidityField.leaveBed) &&
            leaveBedRaw! > 0
        ? leaveBedRaw
        : null;

    var resolvedStarted = startedValue ?? goBedValue;
    var resolvedEnded = endedValue ?? leaveBedValue;
    final reportedDuration =
        _sleepValidity(validity, version, _SleepValidityField.asleepDuration) &&
            asleepDurationRaw! > 0
        ? asleepDurationRaw
        : null;
    if (resolvedStarted == null &&
        resolvedEnded != null &&
        reportedDuration != null) {
      resolvedStarted = resolvedEnded - reportedDuration;
    }
    if (resolvedEnded == null &&
        resolvedStarted != null &&
        reportedDuration != null) {
      resolvedEnded = resolvedStarted + reportedDuration;
    }
    // For device-provided type-16 summaries, Mi Fitness uses the packet
    // timestamps as the authoritative sleep interval. Wake duration is part
    // of the interval end but not part of sleepDuration.
    if (packetSummary != null &&
        packetSummary.startedAtSeconds > 0 &&
        packetSummary.endedAtSeconds > packetSummary.startedAtSeconds) {
      resolvedStarted = packetSummary.startedAtSeconds;
      resolvedEnded = packetSummary.endedAtSeconds;
    }
    if (resolvedStarted == null || resolvedEnded == null) return const [];
    if (resolvedEnded <= resolvedStarted) return const [];
    final heartRateStats = heartRate.statsBetween(
      resolvedStarted,
      resolvedEnded,
    );
    final bloodOxygenStats = bloodOxygen.statsBetween(
      resolvedStarted,
      resolvedEnded,
    );
    final hrvPoints = hrv.firstRecordTimeSeconds <= 0
        ? const <XiaomiActivitySleepHrvPoint>[]
        : hrv.values
              .asMap()
              .entries
              .where((entry) => entry.value != null)
              .map(
                (entry) => XiaomiActivitySleepHrvPoint(
                  timestamp: xiaomiActivityTimestamp(
                    hrv.firstRecordTimeSeconds +
                        entry.key * hrv.intervalSeconds,
                  ),
                  value: entry.value!,
                ),
              )
              .toList(growable: false);
    final packetDuration = packetSummary?.durationMinutes;
    final duration = packetDuration != null && packetDuration > 0
        ? packetDuration * 60
        : reportedDuration ?? resolvedEnded - resolvedStarted;
    final base = XiaomiActivitySleepRecord(
      startedAt: xiaomiActivityTimestamp(resolvedStarted),
      endedAt: xiaomiActivityTimestamp(resolvedEnded),
      durationSeconds: duration,
      averageHeartRate: heartRateStats?.average ?? heartRate.average,
      averageBloodOxygen: bloodOxygenStats?.average ?? bloodOxygen.average,
      minimumHeartRate: heartRateStats?.minimum ?? heartRate.minimum,
      maximumHeartRate: heartRateStats?.maximum ?? heartRate.maximum,
      minimumBloodOxygen: bloodOxygenStats?.minimum ?? bloodOxygen.minimum,
      maximumBloodOxygen: bloodOxygenStats?.maximum ?? bloodOxygen.maximum,
      quality:
          _sleepValidity(validity, version, _SleepValidityField.quality) &&
              qualityRaw! >= 0
          ? qualityRaw
          : null,
      sleepEfficiency:
          _sleepValidity(validity, version, _SleepValidityField.efficiency) &&
              efficiencyRaw! >= 0
          ? efficiencyRaw
          : null,
      bedDurationSeconds:
          _sleepValidity(validity, version, _SleepValidityField.bedDuration) &&
              bedDurationRaw! > 0
          ? bedDurationRaw
          : null,
      goBedAt: goBedValue == null ? null : xiaomiActivityTimestamp(goBedValue),
      leaveBedAt: leaveBedValue == null
          ? null
          : xiaomiActivityTimestamp(leaveBedValue),
      awakeDurationSeconds: packetSummary == null
          ? null
          : packetSummary.awakeDurationMinutes * 60,
      lightSleepDurationSeconds: packetSummary == null
          ? null
          : packetSummary.lightDurationMinutes * 60,
      deepSleepDurationSeconds: packetSummary == null
          ? null
          : packetSummary.deepDurationMinutes * 60,
      remSleepDurationSeconds: packetSummary == null
          ? null
          : packetSummary.remDurationMinutes * 60,
      sleepIndex: packetSummary?.sleepIndex,
      wakeCount: packetSummary?.wakeCount,
      hasRem: packetSummary?.hasRem,
      hasStage:
          packetSummary?.hasStage ??
          (stagePackets.stages.isEmpty ? null : true),
      sleepScoreVersion: packetSummary?.sleepScoreVersion,
      averageHrv:
          version == 6 &&
              _sleepValidity(validity, version, _SleepValidityField.hrvAverage)
          ? hrvAverageRaw
          : null,
      hrvStandardDeviation:
          version == 6 &&
              _sleepValidity(
                validity,
                version,
                _SleepValidityField.hrvStandardDeviation,
              )
          ? hrvStandardDeviationRaw
          : null,
      hrvMedian:
          version == 6 &&
              _sleepValidity(validity, version, _SleepValidityField.hrvMedian)
          ? hrvMedianRaw
          : null,
      hrvLowerQuantile:
          version == 6 &&
              _sleepValidity(
                validity,
                version,
                _SleepValidityField.hrvLowerQuantile,
              )
          ? hrvLowerQuantileRaw
          : null,
      hrvUpperQuantile:
          version == 6 &&
              _sleepValidity(
                validity,
                version,
                _SleepValidityField.hrvUpperQuantile,
              )
          ? hrvUpperQuantileRaw
          : null,
      hrvMiddleQuantile:
          version == 6 &&
              _sleepValidity(
                validity,
                version,
                _SleepValidityField.hrvMiddleQuantile,
              )
          ? hrvMiddleQuantileRaw
          : null,
      hrvTimestamp:
          version == 6 &&
              _sleepValidity(
                validity,
                version,
                _SleepValidityField.hrvTimestamp,
              ) &&
              hrvTimestampRaw! > 0
          ? xiaomiActivityTimestamp(hrvTimestampRaw)
          : null,
      hrvMax:
          version == 6 &&
              _sleepValidity(validity, version, _SleepValidityField.hrvMaximum)
          ? hrvMaximumRaw
          : null,
      hrvMin:
          version == 6 &&
              _sleepValidity(validity, version, _SleepValidityField.hrvMinimum)
          ? hrvMinimumRaw
          : null,
      hrvBaselineMax:
          version == 6 &&
              _sleepValidity(
                validity,
                version,
                _SleepValidityField.hrvBaselineMaximum,
              )
          ? hrvBaselineMaximumRaw
          : null,
      hrvBaselineMin:
          version == 6 &&
              _sleepValidity(
                validity,
                version,
                _SleepValidityField.hrvBaselineMinimum,
              )
          ? hrvBaselineMinimumRaw
          : null,
      hrvPoints: hrvPoints,
      stages: stagePackets.stages,
    );
    return _expandSleepPacketSummaries(
      base: base,
      packets: stagePackets,
      heartRate: heartRate,
      bloodOxygen: bloodOxygen,
    );
  }

  List<XiaomiActivitySleepRecord> _parseLegacySleepDetails(
    Uint8List data,
    int version,
    int limit,
  ) {
    final headerSize = version >= 5 ? 2 : 1;
    if (version < 1 || version > 4 || limit < 8 + headerSize + 9) {
      return const [];
    }
    final view = ByteData.sublistView(data);
    final header = data.sublist(8, 8 + headerSize);
    var offset = 8 + headerSize;
    if (offset >= limit) return const [];
    offset++; // compact sleep-finished/awake flag
    if (offset + 8 > limit) return const [];
    final started = view.getUint32(offset, Endian.little);
    final ended = view.getUint32(offset + 4, Endian.little);
    offset += 8;
    if (started == 0 || ended <= started) return const [];

    int? quality;
    var headerIndex = 3;
    if (version >= 4) {
      if (offset >= limit) return const [];
      if (_validHeaderBit(header, headerIndex)) {
        quality = view.getUint8(offset);
      }
      offset++;
      headerIndex++;
    }

    final heartRate = _readSleepByteSeries(
      view,
      data,
      limit,
      offset,
      version,
      _validHeaderBit(header, headerIndex),
    );
    offset = heartRate.offset;
    headerIndex++;
    final bloodOxygen = _readSleepByteSeries(
      view,
      data,
      limit,
      offset,
      version,
      _validHeaderBit(header, headerIndex),
    );
    offset = bloodOxygen.offset;
    headerIndex++;
    if (version >= 3) {
      final snore = _readSleepByteSeries(
        view,
        data,
        limit,
        offset,
        version,
        _validHeaderBit(header, headerIndex),
        sampleWidth: 4,
      );
      offset = snore.offset;
    }
    final stagePackets = _parseSleepStagePackets(data, offset, limit);
    final packetSummary = stagePackets.summary;
    var resolvedStarted = started;
    var resolvedEnded = ended;
    if (packetSummary != null &&
        packetSummary.startedAtSeconds > 0 &&
        packetSummary.endedAtSeconds > packetSummary.startedAtSeconds) {
      resolvedStarted = packetSummary.startedAtSeconds;
      resolvedEnded = packetSummary.endedAtSeconds;
    }
    final heartRateStats = heartRate.statsBetween(
      resolvedStarted,
      resolvedEnded,
    );
    final bloodOxygenStats = bloodOxygen.statsBetween(
      resolvedStarted,
      resolvedEnded,
    );
    final durationSeconds =
        packetSummary != null && packetSummary.durationMinutes > 0
        ? packetSummary.durationMinutes * 60
        : resolvedEnded - resolvedStarted;
    final base = XiaomiActivitySleepRecord(
      startedAt: xiaomiActivityTimestamp(resolvedStarted),
      endedAt: xiaomiActivityTimestamp(resolvedEnded),
      durationSeconds: durationSeconds,
      averageHeartRate: heartRateStats?.average ?? heartRate.average,
      averageBloodOxygen: bloodOxygenStats?.average ?? bloodOxygen.average,
      minimumHeartRate: heartRateStats?.minimum ?? heartRate.minimum,
      maximumHeartRate: heartRateStats?.maximum ?? heartRate.maximum,
      minimumBloodOxygen: bloodOxygenStats?.minimum ?? bloodOxygen.minimum,
      maximumBloodOxygen: bloodOxygenStats?.maximum ?? bloodOxygen.maximum,
      quality: quality,
      awakeDurationSeconds: packetSummary == null
          ? null
          : packetSummary.awakeDurationMinutes * 60,
      lightSleepDurationSeconds: packetSummary == null
          ? null
          : packetSummary.lightDurationMinutes * 60,
      deepSleepDurationSeconds: packetSummary == null
          ? null
          : packetSummary.deepDurationMinutes * 60,
      remSleepDurationSeconds: packetSummary == null
          ? null
          : packetSummary.remDurationMinutes * 60,
      sleepIndex: packetSummary?.sleepIndex,
      wakeCount: packetSummary?.wakeCount,
      hasRem: packetSummary?.hasRem,
      hasStage:
          packetSummary?.hasStage ??
          (stagePackets.stages.isEmpty ? null : true),
      sleepScoreVersion: packetSummary?.sleepScoreVersion,
      stages: stagePackets.stages,
    );
    return _expandSleepPacketSummaries(
      base: base,
      packets: stagePackets,
      heartRate: heartRate,
      bloodOxygen: bloodOxygen,
    );
  }

  /// Expands the device summaries instead of collapsing the packet stream to
  /// the main night. Mi Fitness's native parser returns every
  /// [SleepStageSummary]; index 1 is only the preferred summary when a caller
  /// needs one representative night.
  List<XiaomiActivitySleepRecord> _expandSleepPacketSummaries({
    required XiaomiActivitySleepRecord base,
    required _SleepPacketParseResult packets,
    required _SleepByteSeries heartRate,
    required _SleepByteSeries bloodOxygen,
  }) {
    if (packets.summaries.length <= 1) return [base];
    return packets.summaries
        .where(
          (summary) =>
              summary.startedAtSeconds > 0 &&
              summary.endedAtSeconds > summary.startedAtSeconds,
        )
        .map((summary) {
          final startedAt = xiaomiActivityTimestamp(summary.startedAtSeconds);
          final endedAt = xiaomiActivityTimestamp(summary.endedAtSeconds);
          final heartRateStats = heartRate.statsBetween(
            summary.startedAtSeconds,
            summary.endedAtSeconds,
          );
          final bloodOxygenStats = bloodOxygen.statsBetween(
            summary.startedAtSeconds,
            summary.endedAtSeconds,
          );
          final hrvPoints = base.hrvPoints
              .where(
                (point) =>
                    !point.timestamp.isBefore(startedAt) &&
                    point.timestamp.isBefore(endedAt),
              )
              .toList(growable: false);
          final stages = packets.stages
              .where(
                (stage) =>
                    !stage.timestamp.isBefore(startedAt) &&
                    stage.timestamp.isBefore(endedAt),
              )
              .toList(growable: false);
          return base.copyWith(
            startedAt: startedAt,
            endedAt: endedAt,
            durationSeconds: summary.durationMinutes * 60,
            averageHeartRate: heartRateStats?.average ?? base.averageHeartRate,
            minimumHeartRate: heartRateStats?.minimum ?? base.minimumHeartRate,
            maximumHeartRate: heartRateStats?.maximum ?? base.maximumHeartRate,
            averageBloodOxygen:
                bloodOxygenStats?.average ?? base.averageBloodOxygen,
            minimumBloodOxygen:
                bloodOxygenStats?.minimum ?? base.minimumBloodOxygen,
            maximumBloodOxygen:
                bloodOxygenStats?.maximum ?? base.maximumBloodOxygen,
            awakeDurationSeconds: summary.awakeDurationMinutes * 60,
            lightSleepDurationSeconds: summary.lightDurationMinutes * 60,
            deepSleepDurationSeconds: summary.deepDurationMinutes * 60,
            remSleepDurationSeconds: summary.remDurationMinutes * 60,
            sleepIndex: summary.sleepIndex,
            wakeCount: summary.wakeCount,
            hasRem: summary.hasRem,
            hasStage: summary.hasStage,
            sleepScoreVersion: summary.sleepScoreVersion,
            hrvPoints: hrvPoints,
            stages: stages,
          );
        })
        .toList(growable: false);
  }

  XiaomiActivitySleepRecord? _parseSleepStages(Uint8List data) {
    final limit = data.length - 4;
    if (limit < 37) return null;
    final view = ByteData.sublistView(data);
    var offset = 8 + 7;
    final durationMinutes = view.getUint16(offset, Endian.little);
    final started = view.getUint32(offset + 2, Endian.little);
    final ended = view.getUint32(offset + 6, Endian.little);
    offset += 10;
    if (started == 0 || ended <= started || durationMinutes == 0) return null;
    final totalsOffset = offset + 3;
    if (totalsOffset + 8 > limit) return null;
    final deepDurationMinutes = view.getUint16(totalsOffset, Endian.little);
    final lightDurationMinutes = view.getUint16(
      totalsOffset + 2,
      Endian.little,
    );
    final remDurationMinutes = view.getUint16(totalsOffset + 4, Endian.little);
    final awakeDurationMinutes = view.getUint16(
      totalsOffset + 6,
      Endian.little,
    );
    // Three reserved bytes, four stage totals, then one trailing reserved
    // byte precede the five-byte stage records.
    offset += 3 + 8 + 1;
    final stages = <XiaomiActivitySleepStageRecord>[];
    while (offset + 5 <= limit) {
      final timestamp = view.getUint32(offset, Endian.little);
      final stage = _sleepStageFileValue(data[offset + 4]);
      if (timestamp != 0 && stage >= 0) {
        stages.add(
          XiaomiActivitySleepStageRecord(
            timestamp: xiaomiActivityTimestamp(timestamp),
            stage: stage,
          ),
        );
      }
      offset += 5;
    }
    return XiaomiActivitySleepRecord(
      startedAt: xiaomiActivityTimestamp(started),
      endedAt: xiaomiActivityTimestamp(ended),
      durationSeconds: durationMinutes * 60,
      awakeDurationSeconds: awakeDurationMinutes * 60,
      lightSleepDurationSeconds: lightDurationMinutes * 60,
      deepSleepDurationSeconds: deepDurationMinutes * 60,
      remSleepDurationSeconds: remDurationMinutes * 60,
      hasRem: remDurationMinutes > 0,
      hasStage: stages.isNotEmpty,
      stages: stages,
    );
  }

  _SleepPacketParseResult _parseSleepStagePackets(
    Uint8List data,
    int offset,
    int limit,
  ) {
    // The feature-data tail uses the packet stream consumed by Mi Fitness:
    // magic 0xfb 0xfa 0xfc 0xff, a five-byte header prefix, a little-endian
    // timestamp, parity, type, and a big-endian payload length. Type 16 is a
    // compact summary record; type 17 contains big-endian stage/duration
    // points. The device has already performed stage classification before
    // this stream is sent, so this parser only decodes the wire records.
    final view = ByteData.sublistView(data);
    final stages = <XiaomiActivitySleepStageRecord>[];
    final summaries = <_SleepPacketSummary>[];
    var sleepScoreVersion = 0;
    while (offset + 17 <= limit) {
      if (view.getUint32(offset, Endian.little) != 0xfffcfafb) {
        offset++;
        continue;
      }
      final type = data[offset + 14];
      final dataLength = (data[offset + 15] << 8) | data[offset + 16];
      final timestamp = view.getUint64(offset + 5, Endian.little);
      final payloadOffset = offset + 17;
      if (type == 2 ||
          type == 3 ||
          type == 9 ||
          type == 12 ||
          type == 13 ||
          type == 14 ||
          type == 15) {
        // These packet types carry flags in the two bytes that otherwise look
        // like a length. They have no payload in the sleep stream.
        offset = payloadOffset;
        continue;
      }
      if (payloadOffset + dataLength > limit) break;
      offset = payloadOffset;
      if (type == 19) {
        // Mi Fitness's native parser marks device-provided summaries as
        // score-version 1 when this marker is present.
        sleepScoreVersion = 1;
      } else if (type == 16 && dataLength >= 13) {
        // Native Mi Fitness accepts N consecutive 13-byte summaries in one
        // type-16 payload. The first starts at the packet timestamp; each
        // following summary starts after the previous interval plus its
        // trailing one-byte gap.
        var currentTimestamp = timestamp;
        final payloadEnd = offset + dataLength;
        for (
          var recordOffset = offset;
          recordOffset + 13 <= payloadEnd;
          recordOffset += 13
        ) {
          final sleepIndexAndWakeCount = data[recordOffset];
          final sleepIndex = sleepIndexAndWakeCount >> 4;
          final wakeCount = sleepIndexAndWakeCount & 0x0f;
          final durationMinutes = view.getUint16(recordOffset + 1, Endian.big);
          final awakeDurationMinutes = view.getUint16(
            recordOffset + 3,
            Endian.big,
          );
          final lightDurationMinutes = view.getUint16(
            recordOffset + 5,
            Endian.big,
          );
          final remDurationMinutes = view.getUint16(
            recordOffset + 7,
            Endian.big,
          );
          final deepDurationMinutes = view.getUint16(
            recordOffset + 9,
            Endian.big,
          );
          final flags = data[recordOffset + 11];
          final remState = (flags >> 4) & 0x03;
          final stageState = (flags >> 2) & 0x03;
          final unknownDurationMinutes = data[recordOffset + 12];
          final endedTimestamp =
              currentTimestamp + (durationMinutes + awakeDurationMinutes) * 60;
          summaries.add(
            _SleepPacketSummary(
              startedAtSeconds: currentTimestamp,
              endedAtSeconds: endedTimestamp,
              durationMinutes: durationMinutes,
              awakeDurationMinutes: awakeDurationMinutes,
              lightDurationMinutes: lightDurationMinutes,
              remDurationMinutes: remDurationMinutes,
              deepDurationMinutes: deepDurationMinutes,
              sleepIndex: sleepIndex,
              wakeCount: wakeCount,
              hasRem: remState == 1,
              hasStage: stageState == 1,
              unknownDurationMinutes: unknownDurationMinutes,
              sleepScoreVersion: sleepScoreVersion == 0
                  ? null
                  : sleepScoreVersion,
            ),
          );
          currentTimestamp = endedTimestamp + unknownDurationMinutes * 60;
        }
      } else if (type == 17) {
        var current = timestamp * 1000;
        for (var index = 0; index + 1 < dataLength; index += 2) {
          final value = view.getUint16(offset + index, Endian.big);
          final durationMinutes = value & 0xfff;
          final stage = _sleepStageDetailValue(value >> 12);
          if (stage >= 0) {
            stages.add(
              XiaomiActivitySleepStageRecord(
                timestamp: xiaomiActivityTimestamp(current ~/ 1000),
                stage: stage,
                endedAt: durationMinutes == 0
                    ? null
                    : xiaomiActivityTimestamp(
                        current ~/ 1000 + durationMinutes * 60,
                      ),
              ),
            );
          }
          current += durationMinutes * 60 * 1000;
        }
      }
      offset += dataLength;
    }
    final finalSummaries = sleepScoreVersion == 0
        ? summaries
        : summaries
              .map(
                (summary) =>
                    summary.copyWith(sleepScoreVersion: sleepScoreVersion),
              )
              .toList(growable: false);
    return _SleepPacketParseResult(stages: stages, summaries: finalSummaries);
  }

  int _sleepValidityLength(int version) => switch (version) {
    5 => 2,
    6 => 3,
    _ => 0,
  };

  bool _sleepValidity(
    Uint8List validity,
    int version,
    _SleepValidityField field,
  ) {
    final index = switch (version) {
      5 => switch (field) {
        _SleepValidityField.start => 0,
        _SleepValidityField.end => 1,
        _SleepValidityField.quality => 2,
        _SleepValidityField.efficiency => 3,
        _SleepValidityField.asleepDuration => 4,
        _SleepValidityField.bedDuration => 5,
        _SleepValidityField.goBed => 6,
        _SleepValidityField.leaveBed => 7,
        _SleepValidityField.heartRate => 8,
        _SleepValidityField.bloodOxygen => 9,
        _SleepValidityField.snore => 10,
        _ => -1,
      },
      6 => switch (field) {
        _SleepValidityField.start => 0,
        _SleepValidityField.end => 1,
        _SleepValidityField.quality => 2,
        _SleepValidityField.efficiency => 3,
        _SleepValidityField.asleepDuration => 4,
        _SleepValidityField.bedDuration => 5,
        _SleepValidityField.goBed => 6,
        _SleepValidityField.leaveBed => 7,
        _SleepValidityField.hrvAverage => 8,
        _SleepValidityField.hrvStandardDeviation => 9,
        _SleepValidityField.hrvMedian => 10,
        _SleepValidityField.hrvLowerQuantile => 11,
        _SleepValidityField.hrvUpperQuantile => 12,
        _SleepValidityField.hrvMiddleQuantile => 13,
        _SleepValidityField.hrvTimestamp => 14,
        _SleepValidityField.hrvMaximum => 15,
        _SleepValidityField.hrvMinimum => 16,
        _SleepValidityField.hrvBaselineMaximum => 17,
        _SleepValidityField.hrvBaselineMinimum => 18,
        _SleepValidityField.heartRate => 19,
        _SleepValidityField.bloodOxygen => 20,
        _SleepValidityField.hrvSeries => 21,
        _SleepValidityField.snore => 22,
      },
      _ => -1,
    };
    return _validHeaderBit(validity, index);
  }

  _SleepByteSeries _readSleepRecordSeries({
    required ByteData view,
    required int limit,
    required int offset,
    required int version,
    required bool valid,
    int sampleWidth = 1,
    int validMinimum = 1,
    int validMaximum = 254,
  }) {
    // The record block is conditional on its validity bit in the official
    // v5/v6 schema.  Do not consume bytes for an absent block.
    if (!valid) return _SleepByteSeries(offset: offset);
    if (offset + 4 > limit) return _SleepByteSeries(offset: limit);
    final interval = view.getUint16(offset, Endian.little);
    final count = view.getUint16(offset + 2, Endian.little);
    offset += 4;
    if (count == 0) return _SleepByteSeries(offset: offset);
    var firstRecordTime = 0;
    if (version >= 2) {
      if (offset + 4 > limit) return _SleepByteSeries(offset: limit);
      firstRecordTime = view.getUint32(offset, Endian.little);
      offset += 4;
    }
    final remaining = limit - offset;
    if (sampleWidth <= 0 || count > remaining ~/ sampleWidth) {
      return _SleepByteSeries(offset: limit);
    }
    final end = offset + count * sampleWidth;
    final values = <int?>[];
    for (var index = 0; index < count; index++) {
      final value = switch (sampleWidth) {
        1 => view.getUint8(offset + index),
        2 => view.getUint16(offset + index * 2, Endian.little),
        4 => view.getUint32(offset + index * 4, Endian.little),
        _ => null,
      };
      if (value == null) {
        values.add(null);
      } else if (sampleWidth == 1 &&
          (value < validMinimum || value > validMaximum)) {
        values.add(null);
      } else {
        values.add(value);
      }
    }
    // Keep the read of interval and firstRecordTime explicit: both are part
    // of the wire format even though the summary model only needs averages.
    if (interval < 0 || firstRecordTime < 0) {
      return _SleepByteSeries(offset: end);
    }
    return _SleepByteSeries(
      offset: end,
      average: _SleepByteSeries._stats(values)?.average,
      minimum: _SleepByteSeries._stats(values)?.minimum,
      maximum: _SleepByteSeries._stats(values)?.maximum,
      intervalSeconds: interval,
      firstRecordTimeSeconds: firstRecordTime,
      values: values,
    );
  }

  int _sleepStageFileValue(int raw) => switch (raw) {
    2 || 3 || 4 || 5 => raw,
    _ => -1,
  };

  int _sleepStageDetailValue(int raw) => switch (raw) {
    0 => 5,
    1 => 3,
    2 => 2,
    3 => 4,
    4 => 0,
    _ => 1,
  };

  _SleepByteSeries _readSleepByteSeries(
    ByteData view,
    Uint8List data,
    int limit,
    int offset,
    int version,
    bool valid, {
    int sampleWidth = 1,
  }) {
    if (!valid) return _SleepByteSeries(offset: offset);
    if (offset + 4 > limit) return _SleepByteSeries(offset: limit);
    final interval = view.getUint16(offset, Endian.little);
    offset += 2;
    final count = view.getUint16(offset, Endian.little);
    offset += 2;
    var firstRecordTime = 0;
    if (version >= 2) {
      if (offset + 4 > limit) return _SleepByteSeries(offset: limit);
      firstRecordTime = view.getUint32(offset, Endian.little);
      offset += 4;
    }
    final available = (limit - offset) ~/ sampleWidth;
    final samplesToRead = available.clamp(0, count);
    if (samplesToRead == 0) {
      return _SleepByteSeries(offset: offset + available * sampleWidth);
    }
    final values = <int?>[];
    for (var index = 0; index < samplesToRead; index++) {
      if (sampleWidth == 1) {
        final value = data[offset + index];
        values.add(value == 0 || value == 255 ? null : value);
      }
    }
    final end = offset + samplesToRead * sampleWidth;
    final stats = _SleepByteSeries._stats(values);
    return _SleepByteSeries(
      offset: end,
      average: stats?.average,
      minimum: stats?.minimum,
      maximum: stats?.maximum,
      intervalSeconds: interval,
      firstRecordTimeSeconds: firstRecordTime,
      values: values,
    );
  }

  bool _validHeaderBit(Uint8List header, int index) =>
      index >= 0 && index < header.length * 8
      ? (header[index ~/ 8] & (1 << (7 - index % 8))) != 0
      : false;

  int _crc32(Uint8List data) {
    var crc = 0xffffffff;
    for (final byte in data) {
      crc ^= byte;
      for (var bit = 0; bit < 8; bit++) {
        crc = (crc & 1) != 0 ? (crc >> 1) ^ 0xedb88320 : crc >> 1;
      }
    }
    return (crc ^ 0xffffffff) & 0xffffffff;
  }

  Future<pb_fitness.RemainingSportData_List> fetchRemainingSportData() =>
      _requestFitness(
        id: pb_fitness.Fitness_FitnessID.GET_REMAINING_SPORT_DATA,
        payload: pb_fitness.Fitness(),
        hasResponse: (fitness) => fitness.hasRemainingSportDataList(),
        response: (fitness) => fitness.remainingSportDataList,
      );

  Future<void> registerBasicDataReports() =>
      _sendFitness(pb_fitness.Fitness_FitnessID.REGISTER_BASIC_DATA_REPORT);

  Future<void> unregisterBasicDataReports() =>
      _sendFitness(pb_fitness.Fitness_FitnessID.UNREGISTER_BASIC_DATA_REPORT);

  Future<pb_fitness.UserProfile> fetchUserProfile() => _requestFitness(
    id: pb_fitness.Fitness_FitnessID.REQUEST_USER_PROFILE,
    payload: pb_fitness.Fitness(),
    hasResponse: (fitness) => fitness.hasUserProfile(),
    response: (fitness) => fitness.userProfile,
  );

  Future<void> setUserProfile(pb_fitness.UserProfile profile) => _sendFitness(
    pb_fitness.Fitness_FitnessID.SET_USER_PROFILE,
    payload: pb_fitness.Fitness(userProfile: profile),
  );

  Future<pb_fitness.SedentaryReminder> fetchSedentaryReminder() =>
      _requestFitness(
        id: pb_fitness.Fitness_FitnessID.GET_SEDENTARY_REMINDER,
        payload: pb_fitness.Fitness(),
        hasResponse: (fitness) => fitness.hasSedentaryReminder(),
        response: (fitness) => fitness.sedentaryReminder,
      );

  Future<void> setSedentaryReminder(pb_fitness.SedentaryReminder reminder) =>
      _sendFitness(
        pb_fitness.Fitness_FitnessID.SET_SEDENTARY_REMINDER,
        payload: pb_fitness.Fitness(sedentaryReminder: reminder),
      );

  Future<pb_fitness.PressureMonitor> fetchPressureMonitor() => _requestFitness(
    id: pb_fitness.Fitness_FitnessID.GET_PRESSURE_MONITOR,
    payload: pb_fitness.Fitness(),
    hasResponse: (fitness) => fitness.hasPressureMonitor(),
    response: (fitness) => fitness.pressureMonitor,
  );

  Future<void> setPressureMonitor(pb_fitness.PressureMonitor monitor) =>
      _sendFitness(
        pb_fitness.Fitness_FitnessID.SET_PRESSURE_MONITOR,
        payload: pb_fitness.Fitness(pressureMonitor: monitor),
      );

  Future<pb_fitness.MeasureReminder> fetchBloodPressureReminder() =>
      _requestMeasureReminder(
        pb_fitness.Fitness_FitnessID.GET_BLOOD_PRESSURE_REMINDER,
      );

  Future<void> setBloodPressureReminder(pb_fitness.MeasureReminder reminder) =>
      _sendMeasureReminder(
        pb_fitness.Fitness_FitnessID.SET_BLOOD_PRESSURE_REMINDER,
        reminder,
      );

  Future<pb_fitness.MeasureReminder> fetchEcgReminder() =>
      _requestMeasureReminder(pb_fitness.Fitness_FitnessID.GET_ECG_REMINDER);

  Future<void> setEcgReminder(pb_fitness.MeasureReminder reminder) =>
      _sendMeasureReminder(
        pb_fitness.Fitness_FitnessID.SET_ECG_REMINDER,
        reminder,
      );

  Future<pb_fitness.VitalityReminder> fetchVitalityReminder() =>
      _requestFitness(
        id: pb_fitness.Fitness_FitnessID.GET_VITALITY_REMINDER,
        payload: pb_fitness.Fitness(),
        hasResponse: (fitness) => fitness.hasVitalityReminder(),
        response: (fitness) => fitness.vitalityReminder,
      );

  Future<void> setVitalityReminder(pb_fitness.VitalityReminder reminder) =>
      _sendFitness(
        pb_fitness.Fitness_FitnessID.SET_VITALITY_REMINDER,
        payload: pb_fitness.Fitness(vitalityReminder: reminder),
      );

  Future<pb_fitness.ActivityReminder> fetchActivityReminder() =>
      _requestFitness(
        id: pb_fitness.Fitness_FitnessID.GET_ACTIVITY_REMINDER,
        payload: pb_fitness.Fitness(),
        hasResponse: (fitness) => fitness.hasActivityReminder(),
        response: (fitness) => fitness.activityReminder,
      );

  Future<void> setActivityReminder(pb_fitness.ActivityReminder reminder) =>
      _sendFitness(
        pb_fitness.Fitness_FitnessID.SET_ACTIVITY_REMINDER,
        payload: pb_fitness.Fitness(activityReminder: reminder),
      );

  /// Returns the latest sleep summary, including sleep sections and averages.
  Future<pb_fitness.SleepResult> fetchSleepResult({Duration? timeout}) =>
      _requestFitness(
        id: pb_fitness.Fitness_FitnessID.SYNC_SLEEP_RESULT,
        payload: pb_fitness.Fitness(),
        timeout: timeout,
        hasResponse: (fitness) => fitness.hasSleepResult(),
        response: (fitness) => fitness.sleepResult,
      );

  Future<pb_fitness.HeartRateMonitor> fetchHeartRateMonitor() =>
      _requestFitness(
        id: pb_fitness.Fitness_FitnessID.GET_HEART_RATE_MONITOR,
        payload: pb_fitness.Fitness(),
        hasResponse: (fitness) => fitness.hasHeartRateMonitor(),
        response: (fitness) => fitness.heartRateMonitor,
      );

  Future<void> setHeartRateMonitor(pb_fitness.HeartRateMonitor monitor) =>
      _sendFitness(
        pb_fitness.Fitness_FitnessID.SET_HEART_RATE_MONITOR,
        payload: pb_fitness.Fitness(heartRateMonitor: monitor),
      );

  Future<pb_fitness.BloodOxygenMonitor> fetchBloodOxygenMonitor() =>
      _requestFitness(
        id: pb_fitness.Fitness_FitnessID.GET_BLOOD_OXYGEN_MONITOR,
        payload: pb_fitness.Fitness(),
        hasResponse: (fitness) => fitness.hasBloodOxygenMonitor(),
        response: (fitness) => fitness.bloodOxygenMonitor,
      );

  Future<void> setBloodOxygenMonitor(pb_fitness.BloodOxygenMonitor monitor) =>
      _sendFitness(
        pb_fitness.Fitness_FitnessID.SET_BLOOD_OXYGEN_MONITOR,
        payload: pb_fitness.Fitness(bloodOxygenMonitor: monitor),
      );

  Future<pb_fitness.ECGResponse> requestEcg(pb_fitness.ECGRequest request) =>
      _requestFitness(
        id: pb_fitness.Fitness_FitnessID.ECG_REQUEST,
        payload: pb_fitness.Fitness(ecgRequest: request),
        hasResponse: (fitness) => fitness.hasEcgResponse(),
        response: (fitness) => fitness.ecgResponse,
      );

  Future<pb_fitness.ECGActivation> fetchEcgActivation() => _requestFitness(
    id: pb_fitness.Fitness_FitnessID.CHECK_ECG_ACTIVATION,
    payload: pb_fitness.Fitness(),
    hasResponse: (fitness) => fitness.hasEcgActivation(),
    response: (fitness) => fitness.ecgActivation,
  );

  Future<void> setEcgActivation(bool enabled) => _sendFitness(
    enabled
        ? pb_fitness.Fitness_FitnessID.ACTIVATE_ECG
        : pb_fitness.Fitness_FitnessID.DEACTIVATE_ECG,
    payload: pb_fitness.Fitness(
      ecgActivation: pb_fitness.ECGActivation(status: enabled),
    ),
  );

  Future<void> setWomenHealthReminder(
    pb_fitness.WomenHealth_Reminder_List reminders,
  ) => _sendFitness(
    pb_fitness.Fitness_FitnessID.SET_WOMEN_HEALTH_REMINDER,
    payload: pb_fitness.Fitness(reminderList: reminders),
  );

  Future<pb_fitness.Goal_Status> fetchGoalStatus() => _requestFitness(
    id: pb_fitness.Fitness_FitnessID.GET_GOAL_STATUS,
    payload: pb_fitness.Fitness(),
    hasResponse: (fitness) => fitness.hasGoalStatus(),
    response: (fitness) => fitness.goalStatus,
  );

  Future<void> setGoalStatus(pb_fitness.Goal_Status status) => _sendFitness(
    pb_fitness.Fitness_FitnessID.SET_GOAL_STATUS,
    payload: pb_fitness.Fitness(goalStatus: status),
  );

  Future<pb_fitness.VitalityData_List> fetchVitalityData() => _requestFitness(
    id: pb_fitness.Fitness_FitnessID.SYNC_VITALITY_DATA,
    payload: pb_fitness.Fitness(),
    hasResponse: (fitness) => fitness.hasVitalityDataList(),
    response: (fitness) => fitness.vitalityDataList,
  );

  Future<void> syncVitalityData(pb_fitness.VitalityData_List data) =>
      _sendFitness(
        pb_fitness.Fitness_FitnessID.SYNC_VITALITY_DATA,
        payload: pb_fitness.Fitness(vitalityDataList: data),
      );

  Future<pb_fitness.BestSportData_List> fetchBestSportData() => _requestFitness(
    id: pb_fitness.Fitness_FitnessID.SYNC_BEST_SPORT_DATA,
    payload: pb_fitness.Fitness(),
    hasResponse: (fitness) => fitness.hasSportDataList(),
    response: (fitness) => fitness.sportDataList,
  );

  Future<void> syncBestSportData(pb_fitness.BestSportData_List data) =>
      _sendFitness(
        pb_fitness.Fitness_FitnessID.SYNC_BEST_SPORT_DATA,
        payload: pb_fitness.Fitness(sportDataList: data),
      );

  Future<pb_fitness.SportStatus> fetchSportStatus() => _requestFitness(
    id: pb_fitness.Fitness_FitnessID.GET_SPORT_STATUS,
    payload: pb_fitness.Fitness(),
    hasResponse: (fitness) => fitness.hasSportStatus(),
    response: (fitness) => fitness.sportStatus,
  );

  Future<pb_fitness.SportPreResponse> prepareSport(
    pb_fitness.SportPreRequest request,
  ) => _requestFitness(
    id: pb_fitness.Fitness_FitnessID.SPORT_PRE_REQUEST,
    payload: pb_fitness.Fitness(sportPreRequest: request),
    hasResponse: (fitness) => fitness.hasSportPreResponse(),
    response: (fitness) => fitness.sportPreResponse,
  );

  Future<pb_fitness.SportResponse> requestSport(
    pb_fitness.SportRequest request,
  ) => _requestFitness(
    id: pb_fitness.Fitness_FitnessID.SPORT_REQUEST,
    payload: pb_fitness.Fitness(sportRequest: request),
    hasResponse: (fitness) => fitness.hasSportResponse(),
    response: (fitness) => fitness.sportResponse,
  );

  Future<pb_fitness.SleepRegularity> fetchSleepRegularity() => _requestFitness(
    id: pb_fitness.Fitness_FitnessID.GET_SLEEP_REGULARITY,
    payload: pb_fitness.Fitness(),
    hasResponse: (fitness) => fitness.hasSleepRegularity(),
    response: (fitness) => fitness.sleepRegularity,
  );

  Future<void> setSleepRegularity(pb_fitness.SleepRegularity setting) =>
      _sendFitness(
        pb_fitness.Fitness_FitnessID.SET_SLEEP_REGULARITY,
        payload: pb_fitness.Fitness(sleepRegularity: setting),
      );

  Future<pb_fitness.SleepDisorder> fetchSleepDisorder() => _requestFitness(
    id: pb_fitness.Fitness_FitnessID.GET_SLEEP_DISORDER,
    payload: pb_fitness.Fitness(),
    hasResponse: (fitness) => fitness.hasSleepDisorder(),
    response: (fitness) => fitness.sleepDisorder,
  );

  Future<void> setSleepDisorder(pb_fitness.SleepDisorder setting) =>
      _sendFitness(
        pb_fitness.Fitness_FitnessID.SET_SLEEP_DISORDER,
        payload: pb_fitness.Fitness(sleepDisorder: setting),
      );

  Future<pb_fitness.WomenHealth> fetchWomenHealth() => _requestFitness(
    id: pb_fitness.Fitness_FitnessID.GET_WOMEN_HEALTH,
    payload: pb_fitness.Fitness(),
    hasResponse: (fitness) => fitness.hasWomenHealth(),
    response: (fitness) => fitness.womenHealth,
  );

  Future<pb_fitness.WomenHealth_Section_List> fetchWomenHealthSections() =>
      _requestFitness(
        id: pb_fitness.Fitness_FitnessID.REQUEST_WOMEN_HEALTH,
        payload: pb_fitness.Fitness(),
        hasResponse: (fitness) => fitness.hasSectionList(),
        response: (fitness) => fitness.sectionList,
      );

  Future<void> syncWomenHealth(pb_fitness.WomenHealth health) => _sendFitness(
    pb_fitness.Fitness_FitnessID.SYNC_WOMEN_HEALTH,
    payload: pb_fitness.Fitness(womenHealth: health),
  );

  Future<void> setWomenHealthForecast(bool enabled) => _sendFitness(
    pb_fitness.Fitness_FitnessID.SET_WOMEN_HEALTH_FORCAST,
    payload: pb_fitness.Fitness(forcastOn: enabled),
  );

  /// Sends a raw FITNESS command for protocol capabilities not yet wrapped by
  /// a convenience method. The packet remains observable through
  /// [fitnessPackets] when the device reports a result.
  Future<void> sendFitnessCommand(
    pb_fitness.Fitness_FitnessID id, {
    pb_fitness.Fitness? payload,
  }) => _sendFitness(id, payload: payload);

  /// Requests a raw FITNESS response matched by packet id.
  Future<pb_fitness.Fitness> requestFitnessCommand(
    pb_fitness.Fitness_FitnessID id, {
    pb_fitness.Fitness? payload,
    Set<int>? responseIds,
    Duration? timeout,
  }) {
    final acceptedIds = responseIds ?? {id.value};
    _log.fine(
      '[${entity.id}] requesting Xiaomi FITNESS id=${id.value}, '
      'responses=${acceptedIds.join(',')}',
    );
    return component.requestPool.request<pb_fitness.Fitness>(
      packet: _fitnessPacket(id, payload ?? pb_fitness.Fitness()),
      timeout: timeout,
      typeMatcher: (packet) =>
          packet.whichPayload() == pb.WearPacket_Payload.fitness &&
          acceptedIds.contains(packet.id),
      responseMapper: (packet) => packet.fitness,
    );
  }

  Future<T> _requestFitness<T>({
    required pb_fitness.Fitness_FitnessID id,
    required pb_fitness.Fitness payload,
    required bool Function(pb_fitness.Fitness fitness) hasResponse,
    required T Function(pb_fitness.Fitness fitness) response,
    Set<int>? responseIds,
    Duration? timeout,
  }) {
    final acceptedIds = responseIds ?? {id.value};
    _log.fine(
      '[${entity.id}] requesting Xiaomi FITNESS id=${id.value}, '
      'responses=${acceptedIds.join(',')}',
    );
    return component.requestPool.request<T>(
      packet: _fitnessPacket(id, payload),
      timeout: timeout,
      typeMatcher: (packet) =>
          packet.whichPayload() == pb.WearPacket_Payload.fitness &&
          acceptedIds.contains(packet.id) &&
          hasResponse(packet.fitness),
      responseMapper: (packet) => response(packet.fitness),
    );
  }

  Future<Uint8List> _requestBytes({
    required pb_fitness.Fitness_FitnessID id,
    pb_fitness.Fitness? payload,
    Set<int>? responseIds,
    Duration? timeout,
    bool Function(pb_fitness.Fitness fitness)? hasResponse,
  }) => _requestFitness<Uint8List>(
    id: id,
    payload: payload ?? pb_fitness.Fitness(),
    responseIds: responseIds,
    hasResponse: hasResponse ?? (fitness) => fitness.hasIds(),
    response: (fitness) => Uint8List.fromList(fitness.ids),
    timeout: timeout,
  );

  Future<pb_fitness.MeasureReminder> _requestMeasureReminder(
    pb_fitness.Fitness_FitnessID id,
  ) => _requestFitness(
    id: id,
    payload: pb_fitness.Fitness(),
    hasResponse: (fitness) => fitness.hasMeasureReminder(),
    response: (fitness) => fitness.measureReminder,
  );

  Future<void> _sendMeasureReminder(
    pb_fitness.Fitness_FitnessID id,
    pb_fitness.MeasureReminder reminder,
  ) => _sendFitness(id, payload: pb_fitness.Fitness(measureReminder: reminder));

  Future<void> _sendFitness(
    pb_fitness.Fitness_FitnessID id, {
    pb_fitness.Fitness? payload,
  }) {
    _log.fine('[${entity.id}] sending Xiaomi FITNESS id=${id.value}');
    return component.sendPbPacket(
      _fitnessPacket(id, payload ?? pb_fitness.Fitness()),
    );
  }

  @override
  void onLayer2Packet(L2Channel channel, L2OpCode opcode, Uint8List payload) {
    if (channel == L2Channel.fileFitness) {
      onActivityPayload(payload);
      return;
    }
    super.onLayer2Packet(channel, opcode, payload);
  }

  @override
  void onWearPacket(pb.WearPacket packet) {
    if (packet.whichPayload() == pb.WearPacket_Payload.system) {
      final system = packet.system;
      if (system.hasPresentBasicStatus()) {
        _applyPresentStatus(system.presentBasicStatus);
      }
      if (system.hasReportBasicStatus()) {
        _applyReportStatus(system.reportBasicStatus);
      }
      if (system.hasWearStatus()) {
        _applyWearingStatus(system.wearStatus.value);
      }
      return;
    }

    if (packet.whichPayload() != pb.WearPacket_Payload.fitness) return;
    final knownId = pb_fitness.Fitness_FitnessID.values.any(
      (value) => value.value == packet.id,
    );
    if (!knownId) {
      _log.warning(
        '[${entity.id}] unsupported Xiaomi FITNESS packet id=${packet.id} '
        'payload=${packet.fitness.whichPayload()}',
      );
    } else {
      _log.fine(
        '[${entity.id}] received Xiaomi FITNESS packet id=${packet.id} '
        'payload=${packet.fitness.whichPayload()}',
      );
    }
    _fitnessPackets.add(packet.fitness);
  }

  void _applyPresentStatus(pb_system.BasicStatus_Present present) {
    final next = XiaomiHealthState(
      isCharging: present.isCharging,
      isWearing: present.isWearing,
      isSleeping: present.isSleeping,
      battery: present.hasBattery() ? present.battery : null,
      chargingStatus: present.isCharging ? 1 : 2,
      wearingStatus: present.isWearing ? 1 : 2,
      sleepingStatus: present.isSleeping ? 1 : 2,
      sportType: present.hasSport() ? present.sport.sportType.value : null,
      sportState: present.hasSport() && present.sport.hasSportState()
          ? present.sport.sportState.value
          : null,
    );
    _commitState(next, battery: present.hasBattery() ? present.battery : null);
  }

  void _applyReportStatus(pb_system.BasicStatus_Report report) {
    var next = _state;
    if (report.hasCharging()) {
      final value = report.charging.value;
      final charging = switch (value) {
        1 => true,
        2 || 3 => false,
        _ => null,
      };
      if (charging == null) {
        _log.warning('[${entity.id}] unknown charging status $value');
      } else {
        next = next.copyWith(isCharging: charging, chargingStatus: value);
      }
    }
    if (report.hasWearing()) {
      final value = report.wearing.value;
      if (value == 1 || value == 2) {
        next = next.copyWith(isWearing: value == 1, wearingStatus: value);
      } else {
        _log.warning('[${entity.id}] unknown wearing status $value');
      }
    }
    if (report.hasSleeping()) {
      final value = report.sleeping.value;
      if (value == 1 || value == 2) {
        next = next.copyWith(isSleeping: value == 1, sleepingStatus: value);
      } else {
        _log.warning('[${entity.id}] unknown sleeping status $value');
      }
    }
    if (report.hasWaring()) {
      next = next.copyWith(warningStatus: report.waring.value);
    }
    if (report.hasSport()) {
      next = next.copyWith(
        sportType: report.sport.sportType.value,
        sportState: report.sport.hasSportState()
            ? report.sport.sportState.value
            : null,
      );
    }
    _commitState(next);
  }

  void _applyWearingStatus(int value) {
    if (value != 1 && value != 2) {
      _log.warning('[${entity.id}] unknown wearing status $value');
      return;
    }
    _commitState(_state.copyWith(isWearing: value == 1, wearingStatus: value));
  }

  void _commitState(XiaomiHealthState next, {int? battery}) {
    if (_sameState(_state, next) && battery == null) return;
    _state = next;
    entity.emit(XiaomiHealthStateUpdated(deviceId: entity.id, health: next));
    if (battery != null) {
      entity.emit(
        BatteryUpdated(
          deviceId: entity.id,
          battery: models.BatteryStatus(
            capacity: battery,
            chargeStatus: next.isCharging == true
                ? models.ChargeStatus.charging
                : models.ChargeStatus.notCharging,
          ),
        ),
      );
    }
  }

  bool _sameState(XiaomiHealthState left, XiaomiHealthState right) =>
      left.isCharging == right.isCharging &&
      left.isWearing == right.isWearing &&
      left.isSleeping == right.isSleeping &&
      left.battery == right.battery &&
      left.chargingStatus == right.chargingStatus &&
      left.wearingStatus == right.wearingStatus &&
      left.sleepingStatus == right.sleepingStatus &&
      left.warningStatus == right.warningStatus &&
      left.sportType == right.sportType &&
      left.sportState == right.sportState;
}

/// Converts a timestamp from Xiaomi's activity-file protocol.
///
/// These fields are encoded as the device's local wall-clock epoch. They are
/// not UTC instants, even though the wire representation looks like a Unix
/// timestamp. Constructing a UTC [DateTime] here and calling [DateTime.toLocal]
/// later adds the host timezone offset a second time (UTC+8 on the affected
/// devices).
DateTime xiaomiActivityTimestamp(int seconds) {
  final wallClock = DateTime.fromMillisecondsSinceEpoch(
    seconds * 1000,
    isUtc: true,
  );
  return DateTime(
    wallClock.year,
    wallClock.month,
    wallClock.day,
    wallClock.hour,
    wallClock.minute,
    wallClock.second,
    wallClock.millisecond,
    wallClock.microsecond,
  );
}

class _ParsedActivityFile {
  const _ParsedActivityFile({
    this.daily,
    this.samples = const [],
    this.sleep = const [],
    this.workouts = const [],
    this.abnormalHealthRecords = const [],
  });

  final XiaomiActivityDailyRecord? daily;
  final List<XiaomiActivitySampleRecord> samples;
  final List<XiaomiActivitySleepRecord> sleep;
  final List<XiaomiActivityWorkoutRecord> workouts;
  final List<XiaomiActivityAbnormalHealthRecord> abnormalHealthRecords;
}

class _SleepByteSeries {
  const _SleepByteSeries({
    required this.offset,
    this.average,
    this.minimum,
    this.maximum,
    this.intervalSeconds = 0,
    this.firstRecordTimeSeconds = 0,
    this.values = const [],
  });

  final int offset;
  final int? average;
  final int? minimum;
  final int? maximum;
  final int intervalSeconds;
  final int firstRecordTimeSeconds;
  final List<int?> values;

  _SleepSeriesStats? statsBetween(int startedAt, int endedAt) {
    if (values.isEmpty) {
      if (average == null || minimum == null || maximum == null) return null;
      return _SleepSeriesStats(
        average: average!,
        minimum: minimum!,
        maximum: maximum!,
      );
    }
    if (intervalSeconds <= 0 || firstRecordTimeSeconds <= 0) {
      return _stats(values);
    }
    final selected = <int?>[];
    for (var index = 0; index < values.length; index++) {
      final timestamp = firstRecordTimeSeconds + index * intervalSeconds;
      if (timestamp >= startedAt && timestamp <= endedAt) {
        selected.add(values[index]);
      }
    }
    return _stats(selected) ?? _stats(values);
  }

  static _SleepSeriesStats? _stats(Iterable<int?> input) {
    var count = 0;
    var total = 0;
    int? minimum;
    int? maximum;
    for (final value in input) {
      if (value == null) continue;
      count++;
      total += value;
      minimum = minimum == null || value < minimum ? value : minimum;
      maximum = maximum == null || value > maximum ? value : maximum;
    }
    if (count == 0 || minimum == null || maximum == null) return null;
    return _SleepSeriesStats(
      average: (total / count).round(),
      minimum: minimum,
      maximum: maximum,
    );
  }
}

class _SleepSeriesStats {
  const _SleepSeriesStats({
    required this.average,
    required this.minimum,
    required this.maximum,
  });

  final int average;
  final int minimum;
  final int maximum;
}

enum _SleepValidityField {
  start,
  end,
  quality,
  efficiency,
  asleepDuration,
  bedDuration,
  goBed,
  leaveBed,
  hrvAverage,
  hrvStandardDeviation,
  hrvMedian,
  hrvLowerQuantile,
  hrvUpperQuantile,
  hrvMiddleQuantile,
  hrvTimestamp,
  hrvMaximum,
  hrvMinimum,
  hrvBaselineMaximum,
  hrvBaselineMinimum,
  heartRate,
  bloodOxygen,
  hrvSeries,
  snore,
}

class _SleepPacketParseResult {
  const _SleepPacketParseResult({
    required this.stages,
    this.summaries = const [],
  });

  final List<XiaomiActivitySleepStageRecord> stages;
  final List<_SleepPacketSummary> summaries;

  /// Mi Fitness keeps the night with sleepIndex 1 when several summaries are
  /// present. If no indexed night exists, use the longest device summary.
  _SleepPacketSummary? get summary {
    if (summaries.isEmpty) return null;
    final indexed = summaries.where((value) => value.sleepIndex == 1);
    final candidates = indexed.isEmpty ? summaries : indexed;
    return candidates.reduce(
      (left, right) =>
          left.durationMinutes >= right.durationMinutes ? left : right,
    );
  }
}

class _SleepPacketSummary {
  const _SleepPacketSummary({
    required this.startedAtSeconds,
    required this.endedAtSeconds,
    required this.durationMinutes,
    required this.awakeDurationMinutes,
    required this.lightDurationMinutes,
    required this.remDurationMinutes,
    required this.deepDurationMinutes,
    required this.sleepIndex,
    required this.wakeCount,
    required this.hasRem,
    required this.hasStage,
    required this.unknownDurationMinutes,
    required this.sleepScoreVersion,
  });

  final int startedAtSeconds;
  final int endedAtSeconds;
  final int durationMinutes;
  final int awakeDurationMinutes;
  final int lightDurationMinutes;
  final int remDurationMinutes;
  final int deepDurationMinutes;
  final int sleepIndex;
  final int wakeCount;
  final bool hasRem;
  final bool hasStage;
  final int unknownDurationMinutes;
  final int? sleepScoreVersion;

  _SleepPacketSummary copyWith({int? sleepScoreVersion}) => _SleepPacketSummary(
    startedAtSeconds: startedAtSeconds,
    endedAtSeconds: endedAtSeconds,
    durationMinutes: durationMinutes,
    awakeDurationMinutes: awakeDurationMinutes,
    lightDurationMinutes: lightDurationMinutes,
    remDurationMinutes: remDurationMinutes,
    deepDurationMinutes: deepDurationMinutes,
    sleepIndex: sleepIndex,
    wakeCount: wakeCount,
    hasRem: hasRem,
    hasStage: hasStage,
    unknownDurationMinutes: unknownDurationMinutes,
    sleepScoreVersion: sleepScoreVersion ?? this.sleepScoreVersion,
  );
}

/// Bit-packed daily detail reader matching Gadgetbridge's
/// XiaomiComplexActivityParser semantics.
class _XiaomiComplexActivityParser {
  _XiaomiComplexActivityParser({
    required this.data,
    required this.offset,
    required this.limit,
    required this.header,
  });

  final Uint8List data;
  final int limit;
  final Uint8List header;
  int offset;
  int _group = -1;
  int _groupBits = 0;
  int _value = 0;
  int _startOffset = 0;

  bool get hasRemaining => offset < limit;
  bool get progressed => offset > _startOffset;
  bool get hasFirst => _isValid(0);
  bool get hasSecond => _isValid(1);
  bool get hasThird => _isValid(2);

  void reset() {
    _startOffset = offset;
    _group = -1;
    _groupBits = 0;
    _value = 0;
  }

  bool nextGroup(int bits) {
    _group++;
    if (_group >= header.length * 2) {
      consume(bits);
      return false;
    }
    if ((_currentNibble & 8) == 0) return false;
    _groupBits = bits;
    _value = consume(bits);
    return (_currentNibble & 8) != 0;
  }

  int get(int index, int bits) {
    final shift = _groupBits - index - bits;
    return (_value & (((1 << bits) - 1) << shift)) >> shift;
  }

  void consumeByte() => consume(8);

  int consume(int bits) {
    if (offset + bits ~/ 8 > limit) {
      offset = limit;
      return 0;
    }
    final view = ByteData.sublistView(data);
    final result = switch (bits) {
      8 => view.getUint8(offset),
      16 => view.getUint16(offset, Endian.little),
      32 => view.getUint32(offset, Endian.little),
      _ => throw ArgumentError.value(bits, 'bits'),
    };
    offset += bits ~/ 8;
    return result;
  }

  bool _isValid(int index) {
    if (index < 0 || index > 2) return false;
    return (_currentNibble & (1 << (2 - index))) != 0;
  }

  int get _currentNibble {
    final byte = header[_group ~/ 2];
    return _group.isEven ? (byte & 0xf0) >> 4 : byte & 0x0f;
  }
}

pb.WearPacket _fitnessPacket(
  pb_fitness.Fitness_FitnessID id,
  pb_fitness.Fitness payload,
) {
  return pb.WearPacket(
    type: pb.WearPacket_Type.FITNESS,
    id: id.value,
    fitness: payload,
  );
}
