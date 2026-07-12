import 'package:flutter_test/flutter_test.dart';
import 'package:zerobox/src/cli/cli_models.dart';
import 'package:zerobox/src/cli/cli_parser.dart';

void main() {
  test('GUI mode leaves arguments untouched', () {
    final result = parseCliInvocation(['zerobox://open?id=1']);
    expect(result.noGui, isFalse);
    expect(result.arguments, ['zerobox://open?id=1']);
  });

  test('parses explicit local install type and path', () {
    final result = parseCliInvocation([
      '--nogui',
      '--json',
      'install',
      'quickapp',
      '/tmp/demo.rpk',
      '--device',
      'AA:BB',
    ]);
    expect(result.command, ['install', 'quickapp']);
    expect(result.arguments, ['/tmp/demo.rpk']);
    expect(result.options['device'], 'AA:BB');
    expect(result.json, isTrue);
  });

  test('requires a command in no-GUI mode', () {
    expect(
      () => parseCliInvocation(['--nogui']),
      throwsA(isA<CliUsageException>()),
    );
  });

  test('boolean options do not consume the command', () {
    final result = parseCliInvocation([
      '--nogui',
      '--no-autostart',
      'device',
      'status',
    ]);
    expect(result.command, ['device', 'status']);
    expect(result.options, containsPair('no-autostart', null));
  });

  test('supports global help and version in no-GUI mode', () {
    expect(parseCliInvocation(const ['--nogui', '--help']).command, const [
      'help',
    ]);
    expect(parseCliInvocation(const ['--nogui', '--version']).command, const [
      'version',
    ]);
    expect(
      parseCliInvocation(const ['--nogui', '--json', '--version']).json,
      isTrue,
    );
  });
}
