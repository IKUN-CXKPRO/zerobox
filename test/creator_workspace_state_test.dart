import 'package:flutter_test/flutter_test.dart';
import 'package:oronbox/src/features/resources/domain/community_resource.dart';
import 'package:oronbox/src/features/resources/domain/creator_workspace.dart';
import 'package:oronbox/src/features/resources/pages/creator/creator_shared.dart';

void main() {
  CreatorWorkspace workspace({
    String moderationState = 'visible',
    String moderationBy = '',
    List<CreatorRevision> revisions = const [],
    List<Map<String, Object?>> publications = const [],
  }) => CreatorWorkspace(
    resource: CreatorResource(
      id: 'resource',
      slug: 'resource',
      kind: CreatorResourceKind.quickApp,
      moderationState: moderationState,
      moderationBy: moderationBy,
    ),
    revisions: revisions,
    publications: publications,
  );

  const revision = CreatorRevision(
    id: 'rev',
    number: 1,
    name: 'Name',
    summary: '',
    state: 'approved',
  );

  test('moderation states outrank review and publication states', () {
    final published = workspace(
      revisions: const [revision],
      publications: const [
        {'state': 'published'},
      ],
    );
    expect(creatorWorkspaceState(published), 'published');

    final suspended = workspace(
      moderationState: 'suspended',
      revisions: const [revision],
      publications: const [
        {'state': 'published'},
      ],
    );
    expect(creatorWorkspaceState(suspended), 'suspended');

    final frozen = workspace(
      moderationState: 'frozen',
      revisions: const [revision],
      publications: const [
        {'state': 'published'},
      ],
    );
    expect(creatorWorkspaceState(frozen), 'frozen');
  });

  test('restore is only available for owner takedowns', () {
    expect(workspace().resource.canRestore, isFalse);
    expect(
      workspace(
        moderationState: 'suspended',
        moderationBy: 'owner',
      ).resource.canRestore,
      isTrue,
    );
    expect(
      workspace(
        moderationState: 'suspended',
        moderationBy: 'admin',
      ).resource.canRestore,
      isFalse,
    );
    expect(workspace(moderationState: 'frozen').resource.canRestore, isFalse);
  });

  test('resource parses moderation fields from workspace json', () {
    final resource = CreatorResource.fromJson(const {
      'id': 'id',
      'slug': 'slug',
      'kind': 'quickapp',
      'moderation_state': 'suspended',
      'moderation_by': 'admin',
      'moderation_reason': 'policy violation',
    });
    expect(resource.isSuspended, isTrue);
    expect(resource.moderationBy, 'admin');
    expect(resource.moderationReason, 'policy violation');

    final legacy = CreatorResource.fromJson(const {
      'id': 'id',
      'slug': 'slug',
      'kind': 'quickapp',
    });
    expect(legacy.moderationState, 'visible');
  });

  test('revision parses payment metadata with a free legacy default', () {
    final revision = CreatorRevision.fromJson(const {
      'id': 'revision',
      'number': 1,
      'name': 'Resource',
      'summary': '',
      'state': 'draft',
      'paid_type': 'paid',
    });
    expect(revision.paidType, CommunityPaidType.paid);

    final legacy = CreatorRevision.fromJson(const {
      'id': 'legacy',
      'number': 1,
      'name': 'Legacy',
      'summary': '',
      'state': 'draft',
    });
    expect(legacy.paidType, CommunityPaidType.free);
  });
}
