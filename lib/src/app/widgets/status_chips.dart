import 'package:flutter/material.dart';
import 'package:zerobox/src/app/generated/app_localizations.dart';
import 'package:zerobox/src/core/models/device.dart';
import 'package:zerobox/src/core/models/resource.dart';

class StatusChip extends StatelessWidget {
  const StatusChip({
    super.key,
    required this.label,
    this.color,
    this.icon,
  });

  final String label;
  final Color? color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final effectiveColor = color ?? colorScheme.primary;

    return Chip(
      avatar: icon != null
          ? Icon(icon, size: 16, color: effectiveColor)
          : null,
      label: Text(
        label,
        style: TextStyle(
          color: effectiveColor,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
      backgroundColor: effectiveColor.withValues(alpha: 0.12),
      side: BorderSide.none,
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
    );
  }
}

class ResourceTypeChip extends StatelessWidget {
  const ResourceTypeChip({super.key, required this.type, required this.l10n});

  final ResourceType type;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return StatusChip(
      label: resourceTypeLabel(type, l10n),
      color: colorScheme.secondary,
    );
  }
}

class ResourceSourceChip extends StatelessWidget {
  const ResourceSourceChip({super.key, required this.source, required this.l10n});

  final ResourceSource source;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final color = switch (source) {
      ResourceSource.zeroBox => colorScheme.primary,
      ResourceSource.bandbbs => colorScheme.tertiary,
      ResourceSource.astroBox => colorScheme.secondary,
      ResourceSource.local => colorScheme.outline,
    };
    return StatusChip(
      label: resourceSourceLabel(source, l10n),
      color: color,
    );
  }
}

class DevicePlatformChip extends StatelessWidget {
  const DevicePlatformChip({super.key, required this.platform});

  final DevicePlatform platform;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return StatusChip(
      label: devicePlatformLabel(platform),
      color: platform == DevicePlatform.velaOS
          ? colorScheme.tertiary
          : colorScheme.primary,
    );
  }
}

class ConnectionStatusChip extends StatelessWidget {
  const ConnectionStatusChip({super.key, required this.status});

  final ConnectionStatus status;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final color = switch (status) {
      ConnectionStatus.ready => Colors.green,
      ConnectionStatus.connected => colorScheme.primary,
      ConnectionStatus.connecting || ConnectionStatus.scanning => colorScheme.tertiary,
      ConnectionStatus.error => colorScheme.error,
      ConnectionStatus.disconnected => colorScheme.outline,
    };
    return StatusChip(
      label: connectionStatusLabel(status),
      color: color,
    );
  }
}
