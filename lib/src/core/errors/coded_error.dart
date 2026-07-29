/// Stable machine-readable error exposed across feature and process boundaries.
///
/// UI code should localize [code] instead of parsing [message]. The message is
/// retained for diagnostics and as a fallback for unknown server errors.
abstract interface class CodedError implements Exception {
  String get code;
  String get message;
  Object? get details;
}
