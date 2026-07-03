import 'package:card_settings_ui/card_settings_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:zerobox/src/app/generated/app_localizations.dart';
import 'package:zerobox/src/app/widgets/sys_app_bar.dart';
import 'package:zerobox/src/core/constants/app_constants.dart';
import 'package:zerobox/src/core/constants/style_constants.dart';

class TeamPage extends StatelessWidget {
  const TeamPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: SysAppBar(title: Text(l10n.developmentTeam)),
      body: SettingsList(
        maxWidth: StyleConstants.pageMaxWidth,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: StyleConstants.pagePadding,
          vertical: StyleConstants.pagePadding,
        ),
        sections: [
          SettingsSection(
            title: Text('ZeroBox'),
            tiles: [
              SettingsTile.navigation(
                onPressed: (_) => _openUrl(AppConstants.githubRepoUrl),
                leading: const Icon(Icons.language_outlined),
                title: Text(l10n.settingsTeamGitHub),
                description: Text(AppConstants.githubRepoUrl),
                trailing: const Icon(Icons.open_in_new),
              ),
            ],
          ),
          SettingsSection(
            title: Text(l10n.settingsTeamMembers),
            tiles: AppConstants.teamMembers.map((member) {
              return SettingsTile.navigation(
                onPressed: (_) => _openUrl(member.githubUrl),
                leading: ClipRRect(
                  borderRadius:
                      BorderRadius.circular(StyleConstants.tileRadius),
                  child: Image.asset(
                    member.avatarAsset,
                    width: 40,
                    height: 40,
                    fit: BoxFit.cover,
                  ),
                ),
                title: Text(member.name),
                description: Text(l10n.settingsTeamRoleMain),
                trailing: SvgPicture.asset(
                  'assets/images/brands/github.svg',
                  width: 24,
                  height: 24,
                  colorFilter: ColorFilter.mode(
                    Theme.of(context).colorScheme.onSurface,
                    BlendMode.srcIn,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
