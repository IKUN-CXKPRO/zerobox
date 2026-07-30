import 'package:dio/dio.dart';
import 'package:oronbox/src/core/network/github_cdn.dart';
import 'package:oronbox/src/core/network/github_cdn_interceptor.dart';
import 'package:oronbox/src/core/network/http_observability_interceptor.dart';

typedef GithubCdnResolver = GitHubCdn Function();

/// Creates the shared application HTTP transport.
///
/// Upstream modules still own their base URL, timeouts and authentication.
/// Cross-cutting transport behavior belongs here so default clients cannot
/// silently bypass observability or the optional GitHub CDN policy.
Dio createAppHttpTransport({
  BaseOptions? options,
  GithubCdnResolver? githubCdn,
}) {
  final dio = Dio(options);
  if (githubCdn != null) {
    dio.interceptors.add(GithubCdnInterceptor(cdn: githubCdn));
  }
  installHttpObservability(dio);
  return dio;
}
