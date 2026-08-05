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

  XiaomiHealthState get state => _state;

  Stream<pb_fitness.Fitness> get fitnessPackets => _fitnessPackets.stream;

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
  );

  Future<Uint8List> requestFitnessIds(Uint8List ids) => _requestBytes(
    id: pb_fitness.Fitness_FitnessID.REQUEST_FITNESS_IDS,
    payload: pb_fitness.Fitness(ids: ids),
  );

  Future<Uint8List> requestFitnessId(Uint8List id) => _requestBytes(
    id: pb_fitness.Fitness_FitnessID.REQUEST_FITNESS_ID,
    payload: pb_fitness.Fitness(id: id),
  );

  Future<void> confirmFitnessId(Uint8List id) => _sendFitness(
    pb_fitness.Fitness_FitnessID.CONFIRM_FITNESS_ID,
    payload: pb_fitness.Fitness(id: id),
  );

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
  }) => _requestFitness<Uint8List>(
    id: id,
    payload: payload ?? pb_fitness.Fitness(),
    responseIds: responseIds,
    hasResponse: (fitness) => fitness.hasIds(),
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

  @override
  Future<void> dispose() async {
    await _fitnessPackets.close();
    await super.dispose();
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
