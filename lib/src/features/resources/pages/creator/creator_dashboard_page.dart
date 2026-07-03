import 'package:flutter/material.dart';
import 'package:zerobox/src/app/generated/app_localizations.dart';
import 'package:zerobox/src/app/widgets/page_container.dart';

class CreatorDashboardPage extends StatelessWidget {
  const CreatorDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return PageContainer(
      child: Center(
        child: Text(
          l10n.creatorCenter,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
      ),
    );
  }
}
