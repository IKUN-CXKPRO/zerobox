import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:zerobox/src/app/widgets/network_img_layer.dart';
import 'package:zerobox/src/core/models/resource.dart';

class ResourceCard extends StatelessWidget {
  const ResourceCard({
    super.key,
    required this.resource,
    this.canTap = true,
    this.enableHero = true,
  });

  final Resource resource;
  final bool canTap;
  final bool enableHero;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: canTap
            ? () => context.push('/resources/detail/${resource.id}')
            : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AspectRatio(
              aspectRatio: 0.65,
              child: LayoutBuilder(
                builder: (context, boxConstraints) {
                  final maxWidth = boxConstraints.maxWidth;
                  final maxHeight = boxConstraints.maxHeight;
                  return enableHero
                      ? Hero(
                          transitionOnUserGestures: true,
                          flightShuttleBuilder:
                              NetworkImgLayer.heroFlightShuttleBuilder,
                          tag: resource.id,
                          child: NetworkImgLayer(
                            src: resource.coverUrl,
                            width: maxWidth,
                            height: maxHeight,
                          ),
                        )
                      : NetworkImgLayer(
                          src: resource.coverUrl,
                          width: maxWidth,
                          height: maxHeight,
                        );
                },
              ),
            ),
            ResourceContent(resource: resource),
          ],
        ),
      ),
    );
  }
}

class ResourceContent extends StatelessWidget {
  const ResourceContent({super.key, required this.resource});

  final Resource resource;

  @override
  Widget build(BuildContext context) {
    final textScaler = MediaQuery.textScalerOf(context);
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(5, 3, 5, 1),
        child: Text(
          resource.name,
          textAlign: TextAlign.start,
          style: const TextStyle(
            fontWeight: FontWeight.w500,
            letterSpacing: 0.3,
          ),
          textScaler: textScaler.clamp(maxScaleFactor: 1.1),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}

class ResourceListTile extends StatelessWidget {
  const ResourceListTile({
    super.key,
    required this.resource,
    this.onTap,
    this.cardHeight = 120,
    this.enableHero = true,
  });

  final Resource resource;
  final VoidCallback? onTap;
  final double cardHeight;
  final bool enableHero;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textScaler = MediaQuery.textScalerOf(context);
    final colorScheme = theme.colorScheme;
    const borderRadius = 16.0;
    const horizontalPadding = 12.0;
    const verticalPadding = 10.0;
    final contentHeight = cardHeight - (verticalPadding * 2);
    final imageWidth = contentHeight * 0.7;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      clipBehavior: Clip.antiAlias,
      color: colorScheme.surfaceContainerHigh,
      child: InkWell(
        borderRadius: BorderRadius.circular(borderRadius),
        onTap: onTap ?? () => context.push('/resources/detail/${resource.id}'),
        child: SizedBox(
          height: cardHeight,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: horizontalPadding,
              vertical: verticalPadding,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildImage(context, imageWidth, contentHeight),
                const SizedBox(width: 12),
                Expanded(child: _buildInfo(context, textScaler)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildImage(BuildContext context, double width, double height) {
    final borderRadius = BorderRadius.circular(12);
    Widget img = NetworkImgLayer(
      src: resource.coverUrl,
      width: width,
      height: height,
    );
    if (enableHero) {
      img = Hero(
        tag: resource.id,
        transitionOnUserGestures: true,
        child: ClipRRect(borderRadius: borderRadius, child: img),
      );
    } else {
      img = ClipRRect(borderRadius: borderRadius, child: img);
    }
    return img;
  }

  Widget _buildInfo(BuildContext context, TextScaler textScaler) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final nameStyle = theme.textTheme.titleSmall?.copyWith(
      color: colorScheme.onSurface,
      fontWeight: FontWeight.w600,
      height: 1.2,
    );
    final subStyle = theme.textTheme.bodySmall?.copyWith(
      color: colorScheme.onSurfaceVariant,
      height: 1.2,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          resource.name,
          style: nameStyle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textScaler: textScaler.clamp(maxScaleFactor: 1.1),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              resource.description,
              style: subStyle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textScaler: textScaler.clamp(maxScaleFactor: 1),
            ),
          ),
        ),
        const SizedBox(height: 8),
        _buildFooter(context),
      ],
    );
  }

  Widget _buildFooter(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final metricStyle = theme.textTheme.labelMedium?.copyWith(
      color: colorScheme.onSurface,
      fontWeight: FontWeight.w600,
    );

    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: [
        _buildMetric(
          context,
          icon: Icons.person_outline,
          iconColor: colorScheme.primary,
          label: resource.author,
          textStyle: metricStyle,
        ),
        _buildMetric(
          context,
          icon: Icons.devices_outlined,
          iconColor: colorScheme.secondary,
          label: '${resource.supportedDevices.length}',
          textStyle: metricStyle,
        ),
      ],
    );
  }

  Widget _buildMetric(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String label,
    required TextStyle? textStyle,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: iconColor),
        const SizedBox(width: 4),
        Text(label, style: textStyle),
      ],
    );
  }
}

class ResourceCover extends StatelessWidget {
  const ResourceCover({
    super.key,
    required this.resource,
    required this.height,
  });

  final Resource resource;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Hero(
      tag: resource.id,
      transitionOnUserGestures: true,
      flightShuttleBuilder: NetworkImgLayer.heroFlightShuttleBuilder,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: LayoutBuilder(
          builder: (context, constraints) {
            return NetworkImgLayer(
              src: resource.coverUrl,
              width: constraints.maxWidth,
              height: height,
              fadeInDuration: Duration.zero,
              fadeOutDuration: Duration.zero,
            );
          },
        ),
      ),
    );
  }
}
