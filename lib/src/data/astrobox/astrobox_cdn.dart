enum AstroBoxCdn { raw, ghfast, ghproxy }

extension AstroBoxCdnExtension on AstroBoxCdn {
  String get displayName {
    return switch (this) {
      AstroBoxCdn.raw => 'Raw',
      AstroBoxCdn.ghfast => 'GHFast',
      AstroBoxCdn.ghproxy => 'GHProxy',
    };
  }
}

Uri rewriteGithubCdnUri(Uri uri, AstroBoxCdn cdn) {
  if (cdn == AstroBoxCdn.raw || !_isConvertibleGithubUri(uri)) {
    return uri;
  }

  final origin = uri.toString();
  return switch (cdn) {
    AstroBoxCdn.raw => uri,
    AstroBoxCdn.ghfast => Uri.parse('https://ghfast.top/$origin'),
    AstroBoxCdn.ghproxy => Uri.parse('https://gh-proxy.com/$origin'),
  };
}

String rewriteGithubCdnUrl(String url, AstroBoxCdn cdn) {
  final uri = Uri.tryParse(url);
  if (uri == null) return url;
  return rewriteGithubCdnUri(uri, cdn).toString();
}

AstroBoxCdn? astroBoxCdnByName(String name) {
  try {
    return AstroBoxCdn.values.byName(name);
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
