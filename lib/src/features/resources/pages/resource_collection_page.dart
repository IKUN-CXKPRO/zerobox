import 'package:flutter/material.dart';
import 'package:oronbox/src/app/generated/app_localizations.dart';
import 'package:oronbox/src/app/utils/error_localization.dart';
import 'package:oronbox/src/app/widgets/network_img_layer.dart';
import 'package:oronbox/src/app/widgets/page_container.dart';
import 'package:oronbox/src/app/widgets/sys_app_bar.dart';
import 'package:oronbox/src/core/constants/style_constants.dart';
import 'package:oronbox/src/data/oronbox/oronbox_resource_provider.dart';
import 'package:oronbox/src/features/resources/domain/community_resource.dart';
import 'package:oronbox/src/features/resources/widgets/bandbbs_resource_card.dart';

class ResourceCollectionPage extends StatefulWidget {
  const ResourceCollectionPage({super.key, required this.collection});

  final CommunityResource collection;

  @override
  State<ResourceCollectionPage> createState() => _ResourceCollectionPageState();
}

class _ResourceCollectionPageState extends State<ResourceCollectionPage> {
  late final Future<OronBoxCollectionDetail> _detail = OronBoxResourceCatalog()
      .getCollection(widget.collection.ref.id);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: SysAppBar(
        secondary: true,
        title: Text(
          widget.collection.name.isEmpty
              ? l10n.resourceCollection
              : widget.collection.name,
        ),
      ),
      body: FutureBuilder<OronBoxCollectionDetail>(
        future: _detail,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text(localizedErrorMessage(l10n, snapshot.error!)),
            );
          }
          final detail = snapshot.data;
          if (detail == null) {
            return const Center(child: CircularProgressIndicator());
          }
          return ListView(
            padding: EdgeInsets.zero,
            children: [
              PageContainer(
                padding: const EdgeInsets.all(StyleConstants.pagePadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _CollectionHeader(detail: detail),
                    const SizedBox(height: 24),
                    Text(
                      l10n.creatorResourceList,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),
                    ...detail.resources.map(
                      (resource) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: BandBbsResourceCard(item: resource),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _CollectionHeader extends StatelessWidget {
  const _CollectionHeader({required this.detail});

  final OronBoxCollectionDetail detail;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final representative = detail.resources.firstOrNull;
    final image = representative?.coverUrl ?? representative?.iconUrl;
    return Material(
      color: theme.colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final text = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  detail.owner,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
                Text(detail.name, style: theme.textTheme.headlineMedium),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 12,
                  runSpacing: 6,
                  children: [
                    Text(l10n.resourceCollectionItems(detail.resources.length)),
                    Text(l10n.resourceCollectionCoins(detail.coinCount)),
                  ],
                ),
                if (detail.summary.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(detail.summary),
                ],
              ],
            );
            if (image == null || constraints.maxWidth < 560) return text;
            return Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(child: text),
                const SizedBox(width: 24),
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: NetworkImgLayer(
                    src: image.toString(),
                    width: 180,
                    height: 120,
                    type: 'resource',
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
