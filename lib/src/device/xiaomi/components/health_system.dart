import 'dart:async';
import 'dart:typed_data';

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

class XiaomiActivityFileSyncResult {
  const XiaomiActivityFileSyncResult({
    required this.daily,
    required this.samples,
    required this.sleep,
    required this.workouts,
    required this.filesReceived,
  });

  final List<XiaomiActivityDailyRecord> daily;
  final List<XiaomiActivitySampleRecord> samples;
  final List<XiaomiActivitySleepRecord> sleep;
  final List<XiaomiActivityWorkoutRecord> workouts;
  final int filesReceived;
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

class XiaomiActivitySleepRecord {
  const XiaomiActivitySleepRecord({
    required this.startedAt,
    required this.endedAt,
    required this.durationSeconds,
    this.averageHeartRate,
    this.averageBloodOxygen,
    this.quality,
    this.stages = const [],
  });

  final DateTime startedAt;
  final DateTime endedAt;
  final int durationSeconds;
  final int? averageHeartRate;
  final int? averageBloodOxygen;
  final int? quality;
  final List<XiaomiActivitySleepStageRecord> stages;
}

class XiaomiActivitySleepStageRecord {
  const XiaomiActivitySleepStageRecord({
    required this.timestamp,
    required this.stage,
  });

  final DateTime timestamp;

  /// Gadgetbridge's canonical stage values: 2 deep, 3 light, 4 REM, 5 awake.
  final int stage;
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

  final Logger _log;
  final _fitnessPackets = StreamController<pb_fitness.Fitness>.broadcast();
  XiaomiHealthState _state = const XiaomiHealthState();
  Completer<Uint8List>? _activityFileCompleter;
  BytesBuilder? _activityFileBuffer;
  Timer? _activityWatchdog;
  int _activityTotalChunks = 0;
  int _activityNextChunk = 1;

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
  Future<XiaomiActivityFileSyncResult> syncActivityFiles() async {
    final ids = <String, Uint8List>{};
    for (final history in [false, true]) {
      final raw = await fetchFitnessIds(history: history);
      if (raw.length % 7 != 0) {
        throw ProtocolException(
          'Invalid Xiaomi activity id list length ${raw.length}',
        );
      }
      for (var offset = 0; offset < raw.length; offset += 7) {
        final id = Uint8List.fromList(raw.sublist(offset, offset + 7));
        final timestamp = id[0] | (id[1] << 8) | (id[2] << 16) | (id[3] << 24);
        if (timestamp == 0 && id[5] == 0) {
          _log.warning('[${entity.id}] ignoring empty Xiaomi activity file id');
          continue;
        }
        ids[_activityIdKey(id)] = id;
      }
    }

    final daily = <XiaomiActivityDailyRecord>[];
    final samples = <XiaomiActivitySampleRecord>[];
    final sleep = <XiaomiActivitySleepRecord>[];
    final workouts = <XiaomiActivityWorkoutRecord>[];
    var received = 0;
    for (final id in ids.values) {
      final file = await _requestActivityFile(id);
      final parsed = _parseActivityFile(file);
      if (parsed.daily != null) daily.add(parsed.daily!);
      samples.addAll(parsed.samples);
      if (parsed.sleep != null) sleep.add(parsed.sleep!);
      workouts.addAll(parsed.workouts);
      received++;
      await confirmFitnessId(id);
    }

    return XiaomiActivityFileSyncResult(
      daily: daily,
      samples: samples,
      sleep: sleep,
      workouts: workouts,
      filesReceived: received,
    );
  }

  String _activityIdKey(Uint8List id) =>
      id.map((v) => v.toRadixString(16).padLeft(2, '0')).join();

  Future<Uint8List> _requestActivityFile(Uint8List id) async {
    if (_activityFileCompleter != null) {
      throw StateError('Xiaomi activity file request already in progress');
    }
    final completer = Completer<Uint8List>();
    _activityFileCompleter = completer;
    _activityFileBuffer = BytesBuilder(copy: false);
    _activityTotalChunks = 0;
    _activityNextChunk = 1;
    _armActivityWatchdog();
    try {
      await _sendFitness(
        // Gadgetbridge and the Xiaomi firmware use FITNESS command 3 for the
        // concrete activity-file request.  Command 4 is a different Vela
        // extension and does not trigger the file channel on these devices.
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
      _log.warning(
        '[${entity.id}] unsolicited Xiaomi activity payload '
        '(${payload.length} bytes)',
      );
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
      try {
        _validateActivityFile(data);
        completer.complete(data);
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

  void _validateActivityFile(Uint8List data) {
    if (data.length < 13) {
      throw ProtocolException('Xiaomi activity file is too short');
    }
    final view = ByteData.sublistView(data);
    final expected = view.getUint32(data.length - 4, Endian.little);
    final actual = _crc32(Uint8List.sublistView(data, 0, data.length - 4));
    if (expected != actual) {
      throw ProtocolException(
        'Xiaomi activity CRC mismatch: ${actual.toRadixString(16)} != '
        '${expected.toRadixString(16)}',
      );
    }
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

  XiaomiActivitySleepRecord? _parseSleep(
    Uint8List data,
    int timestamp,
    int version,
    int subtype,
  ) {
    if (subtype == 3 && version == 2) {
      return _parseSleepStages(data);
    }
    final limit = data.length - 4;
    if (subtype == 8) {
      return _parseSleepDetails(data, version, limit);
    }
    if (limit < 37) return null;
    final view = ByteData.sublistView(data);
    final offset = 8 + 7;
    final durationMinutes = view.getUint16(offset, Endian.little);
    final started = view.getUint32(offset + 2, Endian.little);
    final ended = view.getUint32(offset + 6, Endian.little);
    if (started == 0 || ended == 0 || durationMinutes == 0) return null;
    return XiaomiActivitySleepRecord(
      startedAt: xiaomiActivityTimestamp(started),
      endedAt: xiaomiActivityTimestamp(ended),
      durationSeconds: durationMinutes * 60,
    );
  }

  XiaomiActivitySleepRecord? _parseSleepDetails(
    Uint8List data,
    int version,
    int limit,
  ) {
    final headerSize = version >= 5 ? 2 : 1;
    if (version < 1 || version > 5 || limit < 8 + headerSize + 9) {
      return null;
    }
    final view = ByteData.sublistView(data);
    final header = data.sublist(8, 8 + headerSize);
    var offset = 8 + headerSize;
    offset += 1; // awake flag
    final started = view.getUint32(offset, Endian.little);
    offset += 4;
    final ended = view.getUint32(offset, Endian.little);
    offset += 4;
    if (started == 0 || ended <= started) return null;

    int? quality;
    var headerIndex = 3;
    if (version >= 4) {
      if (_validHeaderBit(header, headerIndex) && offset < limit) {
        quality = view.getUint8(offset);
      }
      offset += 1;
      headerIndex++;
    }

    if (version >= 5) {
      // Newer sleep-detail files include two additional timestamps after the
      // quality field: nine reserved bytes followed by bed and wake times.
      if (offset + 17 > limit) return null;
      offset += 17;
      headerIndex += 5;
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
      );
      offset = snore.offset;
    }
    final duration = ended - started;
    return XiaomiActivitySleepRecord(
      startedAt: xiaomiActivityTimestamp(started),
      endedAt: xiaomiActivityTimestamp(ended),
      durationSeconds: duration,
      averageHeartRate: heartRate.average,
      averageBloodOxygen: bloodOxygen.average,
      quality: quality,
      stages: _parseSleepStagePackets(data, offset, limit),
    );
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
      stages: stages,
    );
  }

  List<XiaomiActivitySleepStageRecord> _parseSleepStagePackets(
    Uint8List data,
    int offset,
    int limit,
  ) {
    final view = ByteData.sublistView(data);
    final stages = <XiaomiActivitySleepStageRecord>[];
    while (offset + 17 <= limit) {
      if (view.getUint32(offset, Endian.little) != 0xfffcfafb) {
        offset++;
        continue;
      }
      final type = data[offset + 13];
      final dataLength = (data[offset + 15] << 8) | data[offset + 16];
      offset += 17;
      if (type == 2 ||
          type == 3 ||
          type == 9 ||
          type == 12 ||
          type == 13 ||
          type == 14 ||
          type == 15) {
        continue;
      }
      if (offset + dataLength > limit) break;
      if (type == 17) {
        final timestamp = view.getUint64(offset - 12, Endian.little);
        var current = timestamp * 1000;
        for (var index = 0; index + 1 < dataLength; index += 2) {
          final value = view.getUint16(offset + index, Endian.big);
          final stage = _sleepStageDetailValue(value >> 12);
          if (stage >= 0) {
            stages.add(
              XiaomiActivitySleepStageRecord(
                timestamp: DateTime.fromMillisecondsSinceEpoch(current),
                stage: stage,
              ),
            );
          }
          current += (value & 0xfff) * 60 * 1000;
        }
      }
      offset += dataLength;
    }
    return stages;
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
    _ => -1,
  };

  _SleepByteSeries _readSleepByteSeries(
    ByteData view,
    Uint8List data,
    int limit,
    int offset,
    int version,
    bool valid,
  ) {
    if (offset + 4 > limit) return _SleepByteSeries(offset: limit);
    offset += 2; // sample interval
    final count = view.getUint16(offset, Endian.little);
    offset += 2;
    if (version >= 2) {
      if (offset + 4 > limit) return _SleepByteSeries(offset: limit);
      offset += 4;
    }
    final available = (limit - offset).clamp(0, count);
    if (!valid || available == 0) {
      return _SleepByteSeries(offset: offset + available);
    }
    var total = 0;
    var samples = 0;
    for (var index = 0; index < available; index++) {
      final value = data[offset + index];
      if (value == 0 || value == 255) continue;
      total += value;
      samples++;
    }
    return _SleepByteSeries(
      offset: offset + available,
      average: samples == 0 ? null : (total / samples).round(),
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
  Future<pb_fitness.SleepResult> fetchSleepResult() => _requestFitness(
    id: pb_fitness.Fitness_FitnessID.SYNC_SLEEP_RESULT,
    payload: pb_fitness.Fitness(),
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
  }) => component.requestPool.request<pb_fitness.Fitness>(
    packet: _fitnessPacket(id, payload ?? pb_fitness.Fitness()),
    timeout: timeout,
    typeMatcher: (packet) =>
        packet.whichPayload() == pb.WearPacket_Payload.fitness &&
        (responseIds ?? {id.value}).contains(packet.id),
    responseMapper: (packet) => packet.fitness,
  );

  Future<T> _requestFitness<T>({
    required pb_fitness.Fitness_FitnessID id,
    required pb_fitness.Fitness payload,
    required bool Function(pb_fitness.Fitness fitness) hasResponse,
    required T Function(pb_fitness.Fitness fitness) response,
    Set<int>? responseIds,
    Duration? timeout,
  }) => component.requestPool.request<T>(
    packet: _fitnessPacket(id, payload),
    timeout: timeout,
    typeMatcher: (packet) =>
        packet.whichPayload() == pb.WearPacket_Payload.fitness &&
        (responseIds ?? {id.value}).contains(packet.id) &&
        hasResponse(packet.fitness),
    responseMapper: (packet) => response(packet.fitness),
  );

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
  }) => component.sendPbPacket(
    _fitnessPacket(id, payload ?? pb_fitness.Fitness()),
  );

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
DateTime xiaomiActivityTimestamp(int seconds) =>
    DateTime.fromMillisecondsSinceEpoch(seconds * 1000);

class _ParsedActivityFile {
  const _ParsedActivityFile({
    this.daily,
    this.samples = const [],
    this.sleep,
    this.workouts = const [],
  });

  final XiaomiActivityDailyRecord? daily;
  final List<XiaomiActivitySampleRecord> samples;
  final XiaomiActivitySleepRecord? sleep;
  final List<XiaomiActivityWorkoutRecord> workouts;
}

class _SleepByteSeries {
  const _SleepByteSeries({required this.offset, this.average});

  final int offset;
  final int? average;
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
