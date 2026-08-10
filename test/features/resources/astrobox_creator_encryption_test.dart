import 'package:flutter_test/flutter_test.dart';
import 'package:oronbox/src/data/astrobox/astrobox_repo_resource_provider.dart';
import 'package:oronbox/src/data/astrobox/models/astrobox_models.dart';
import 'package:oronbox/src/data/community/community_source.dart';
import 'package:oronbox/src/features/resources/domain/community_resource.dart';
import 'package:oronbox/src/features/resources/domain/community_resource_codec.dart';

void main() {
  group('AstroBox Creator Console encryption marker', () {
    test('requires the exact boolean manifest extension', () {
      expect(
        astroBoxManifestUsesCreatorEncryption(
          _manifest({'enableAstroBoxCreatorFeatures': true}),
        ),
        isTrue,
      );
      expect(
        astroBoxManifestUsesCreatorEncryption(
          _manifest({'enableAstroBoxCreatorFeatures': false}),
        ),
        isFalse,
      );
      expect(
        astroBoxManifestUsesCreatorEncryption(
          _manifest({'enableAstroBoxCreatorFeatures': 'true'}),
        ),
        isFalse,
      );
      expect(
        astroBoxManifestUsesCreatorEncryption(
          _manifest({
            'trialDownloads': {'watch': 'trial.rpk'},
          }),
        ),
        isFalse,
      );
    });
  });

  test(
    'preserves the unsupported download restriction in the detail codec',
    () {
      const detail = CommunityResourceDetail(
        ref: ResourceRef(source: CommunitySourceId.astroboxRepo, id: 'sample'),
        name: 'Sample',
        type: CommunityResourceType.quickApp,
        paidType: CommunityPaidType.paid,
        authors: [CommunityResourceAuthor(name: 'Author')],
        supportedDevices: {},
        content: CommunityResourceContent(
          format: ResourceContentFormat.plainText,
          value: 'Description',
        ),
        files: [],
        canDownload: false,
        downloadRestriction:
            CommunityResourceDownloadRestriction.astroBoxCreatorEncrypted,
      );

      final json = communityResourceDetailToJson(detail);
      expect(json['downloadRestriction'], 'astrobox_creator_encrypted');

      final decoded = communityResourceDetailFromJson(json);
      expect(
        decoded.downloadRestriction,
        CommunityResourceDownloadRestriction.astroBoxCreatorEncrypted,
      );
      expect(decoded.canDownload, isFalse);
    },
  );
}

AstroBoxManifest _manifest(Map<String, dynamic> ext) => AstroBoxManifest(
  item: const AstroBoxManifestItem(
    id: 'sample',
    restype: AstroBoxResourceType.quickApp,
    name: 'Sample',
    description: 'Description',
    icon: 'icon.png',
    cover: 'cover.png',
  ),
  ext: ext,
);
