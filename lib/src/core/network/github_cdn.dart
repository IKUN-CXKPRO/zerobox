enum GitHubCdn { raw, ghfast, ghproxy }

extension GitHubCdnExtension on GitHubCdn {
  String get displayName {
    return switch (this) {
      GitHubCdn.raw => 'Raw',
      GitHubCdn.ghfast => 'GHFast',
      GitHubCdn.ghproxy => 'GHProxy',
    };
  }
}

Uri rewriteGithubCdnUri(Uri uri, GitHubCdn cdn) {
  if (cdn == GitHubCdn.raw || !_isConvertibleGithubUri(uri)) return uri;

  final origin = uri.toString();
  return switch (cdn) {
    GitHubCdn.raw => uri,
    GitHubCdn.ghfast => Uri.parse('https://ghfast.top/$origin'),
    GitHubCdn.ghproxy => Uri.parse('https://gh-proxy.com/$origin'),
  };
}

String rewriteGithubCdnUrl(String url, GitHubCdn cdn) {
  final uri = Uri.tryParse(url);
  if (uri == null) return url;
  return rewriteGithubCdnUri(uri, cdn).toString();
}

GitHubCdn? githubCdnByName(String name) {
  try {
    return GitHubCdn.values.byName(name);
  } on ArgumentError {
    return null;
  }
}

bool _isConvertibleGithubUri(Uri uri) {
  if (uri.scheme != 'https') return false;
  if (uri.host == 'raw.githubusercontent.com' ||
      uri.host == 'gist.githubusercontent.com') {
    return true;
  }
  if (uri.host != 'github.com') return false;

  final path = uri.path;
  return path.contains('/releases/download/') ||
      path.contains('/releases/latest/download/') ||
      path.contains('/archive/');
}
