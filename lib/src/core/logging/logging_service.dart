import 'package:logging/logging.dart';

export 'package:logging/logging.dart';

Logger getLogger(String name) => Logger('zerobox.$name');

void initLogging() {
  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen((record) {
    final time = record.time.toIso8601String();
    final logger = record.loggerName;
    final level = record.level.name;
    final buffer = StringBuffer();
    buffer.write('[$time] $level $logger: ${record.message}');
    if (record.error != null) {
      buffer.write('\n  ERROR: ${record.error}');
    }
    if (record.stackTrace != null) {
      buffer.write('\n${record.stackTrace}');
    }
    // ignore: avoid_print
    print(buffer.toString());
  });
}
