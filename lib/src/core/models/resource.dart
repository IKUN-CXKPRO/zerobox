import 'package:zerobox/src/app/generated/app_localizations.dart';

enum ResourceType { watchface, quickApp, firmware, tool, local }

enum ResourceSource { zeroBox, bandbbs, astroBox, local }

enum ResourceStatus { install, update, installed, manage }

class Resource {
  const Resource({
    required this.id,
    required this.name,
    required this.author,
    required this.version,
    required this.type,
    required this.source,
    required this.coverUrl,
    required this.supportedDevices,
    required this.description,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final String author;
  final String version;
  final ResourceType type;
  final ResourceSource source;
  final String coverUrl;
  final List<String> supportedDevices;
  final String description;
  final String updatedAt;
}

String resourceTypeLabel(ResourceType type, AppLocalizations l10n) {
  return switch (type) {
    ResourceType.watchface => l10n.watchfaces,
    ResourceType.quickApp => l10n.quickApps,
    ResourceType.firmware => l10n.firmwareTools,
    ResourceType.tool => l10n.firmwareTools,
    ResourceType.local => l10n.localResources,
  };
}

String resourceSourceLabel(ResourceSource source, AppLocalizations l10n) {
  return switch (source) {
    ResourceSource.zeroBox => l10n.zeroBox,
    ResourceSource.bandbbs => l10n.bandbbs,
    ResourceSource.astroBox => l10n.astroBox,
    ResourceSource.local => l10n.local,
  };
}
