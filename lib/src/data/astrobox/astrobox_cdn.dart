enum AstroBoxCdn {
  raw,
  ghfast,
  ghproxy,
}

extension AstroBoxCdnExtension on AstroBoxCdn {
  String get displayName {
    return switch (this) {
      AstroBoxCdn.raw => 'Raw',
      AstroBoxCdn.ghfast => 'GHFast',
      AstroBoxCdn.ghproxy => 'GHProxy',
    };
  }

  /// 将 raw.githubusercontent.com 等地址转换为当前 CDN 的地址。
  /// 参考 AstroBox-NG-Module-Provider/src/cdn.rs
  String convert(String rawUrl) {
    if (!rawUrl.contains('https://raw.githubusercontent.com/')) {
      return rawUrl;
    }
    final stripped = rawUrl.startsWith('https://')
        ? rawUrl.substring('https://'.length)
        : rawUrl;

    return switch (this) {
      AstroBoxCdn.raw => rawUrl,
      AstroBoxCdn.ghfast => 'https://ghfast.top/$stripped',
      AstroBoxCdn.ghproxy => 'https://gh-proxy.com/$stripped',
    };
  }
}

AstroBoxCdn? astroBoxCdnByName(String name) {
  try {
    return AstroBoxCdn.values.byName(name);
  } on ArgumentError {
    return null;
  }
}
