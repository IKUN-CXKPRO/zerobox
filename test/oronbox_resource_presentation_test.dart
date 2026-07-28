import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oronbox/src/data/community/community_source.dart';
import 'package:oronbox/src/data/oronbox/oronbox_resource_provider.dart';
import 'package:oronbox/src/features/resources/domain/community_resource.dart';
import 'package:oronbox/src/features/resources/domain/resource_catalog.dart';
import 'package:oronbox/src/features/resources/pages/resource_detail_page.dart';

void main() {
  test('maps the OronBox owner BandBBS avatar from the public API', () async {
    final digest = List.filled(64, 'b').join();
    final dio = Dio();
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) => handler.resolve(
          Response<Object?>(
            requestOptions: options,
            statusCode: 200,
            data: {
              'resources': [
                {
                  'id': 'resource',
                  'name': 'Resource',
                  'kind': 'quickapp',
                  'owner': 'creator',
                  'owner_bandbbs_user_id': 12345,
                  'owner_avatar_url': 'https://bandbbs.example/avatar.png',
                  'devices': <String>[],
                  'icon_sha256': digest,
                },
              ],
              'total': 1,
            },
          ),
        ),
      ),
    );

    final page = await OronBoxResourceCatalog(
      dio: dio,
    ).getPage(const CommunityResourceQuery(page: 0, pageSize: 30));

    expect(page.items.single.authors.single.name, 'creator');
    expect(
      page.items.single.authors.single.avatarUrl,
      Uri.parse('https://bandbbs.example/avatar.png'),
    );
    expect(page.items.single.iconUrl?.queryParameters['line'], 'local');
  });

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

  test('keeps Huami App Store numeric device sources installable', () {
    const file = CommunityResourceFile(
      id: 'app:1.0.0',
      fileName: 'app.zpk',
      version: '1.0.0',
      supportedDevices: {'8519936'},
    );
    const detail = CommunityResourceDetail(
      ref: ResourceRef(
        source: CommunitySourceId.huamiAppStore,
        id: '8519936:app',
      ),
      name: 'Huami app',
      type: CommunityResourceType.miniprogram,
      paidType: CommunityPaidType.free,
      authors: [],
      supportedDevices: {'8519936'},
      content: CommunityResourceContent(
        format: ResourceContentFormat.plainText,
        value: '',
      ),
      files: [file],
      canDownload: true,
    );

    final choices = buildResourceInstallChoices(detail);

    expect(choices, hasLength(1));
    expect(choices.single.file, same(file));
    expect(choices.single.codename, isEmpty);
    expect(
      preferredResourceInstallChoice(detail, choices, 'any-current-device'),
      same(choices.single),
    );
  });
}
