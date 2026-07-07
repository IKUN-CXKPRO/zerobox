class TeamMember {
  const TeamMember({
    required this.name,
    required this.role,
    required this.avatarAsset,
    required this.githubUrl,
  });

  final String name;
  final TeamRole role;
  final String avatarAsset;
  final String githubUrl;
}

enum TeamRole { mainDeveloperDesigner, zeppOSImplementation }

abstract final class AppConstants {
  static const String githubRepoUrl = 'https://github.com/zxor-org/zerobox';

  static const List<TeamMember> teamMembers = [
    TeamMember(
      name: 'OrPudding',
      role: TeamRole.mainDeveloperDesigner,
      avatarAsset: 'assets/images/team/orpudding.jpg',
      githubUrl: 'https://github.com/orpudding',
    ),
    TeamMember(
      name: 'zxxhcj',
      role: TeamRole.zeppOSImplementation,
      avatarAsset: 'assets/images/team/zxxhcj.jpg',
      githubUrl: 'https://github.com/zxxhcj',
    ),
  ];
}
