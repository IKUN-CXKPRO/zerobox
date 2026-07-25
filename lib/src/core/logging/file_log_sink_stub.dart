Future<void> initializeFileLogSink({List<String> arguments = const []}) async {}
void writeFileLogLine(String line) {}
Future<void> closeFileLogSink() async {}
Future<bool> openLogDirectory() async => false;
Future<String?> getLogDirectoryPath() async => null;
Future<int> logDirectorySize() async => 0;
Future<int> clearLogFiles() async => 0;
Future<String?> exportLogsZip() async => null;
