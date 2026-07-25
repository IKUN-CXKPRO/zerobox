import 'package:flutter_test/flutter_test.dart';
import 'package:oronbox/src/data/community/community_source.dart';
import 'package:oronbox/src/data/oronbox/oronbox_resource_provider.dart';
import 'package:oronbox/src/features/resources/domain/community_resource.dart';
import 'package:oronbox/src/features/resources/pages/resource_detail_page.dart';

void main() {
  test('parses preview media using the server sha256 field', () {
    final digest = List.filled(64, 'a').join();
    final images = parseOronBoxPreviewImages([
      {'role': 'preview', 'sha256': digest, 'width': 1200, 'height': 800},
    ], blobUri: (value) => Uri.parse('https://example.test/$value'));

    expect(images, hasLength(1));
    expect(images.single.url.pathSegments.last, digest);
    expect(images.single.width, 1200);
    expect(images.single.height, 800);
  });

  test('expands one artifact into one install choice per bound device', () {
    const file = CommunityResourceFile(
      id: 'artifact',
      fileName: 'app.rpk',
      version: '1.0.0',
      supportedDevices: {'n66', 'n67'},
    );
    const detail = CommunityResourceDetail(
      ref: ResourceRef(source: CommunitySourceId.oronBox, id: 'resource'),
      name: 'Resource',
      type: CommunityResourceType.quickApp,
      paidType: CommunityPaidType.free,
      authors: [],
      supportedDevices: {'n66', 'n67'},
      content: CommunityResourceContent(
        format: ResourceContentFormat.plainText,
        value: '',
      ),
      files: [file],
    );

    final choices = buildResourceInstallChoices(detail);

    expect(choices, hasLength(2));
    expect(choices.map((choice) => choice.codename), {'n66', 'n67'});
    expect(choices.every((choice) => !choice.label.contains('/')), isTrue);
  });
}
