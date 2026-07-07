import 'package:dio/dio.dart';
import 'package:zerobox/src/data/astrobox/astrobox_cdn.dart';

class GithubCdnInterceptor extends Interceptor {
  GithubCdnInterceptor({required this.cdn});

  final AstroBoxCdn Function() cdn;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final rewritten = rewriteGithubCdnUri(options.uri, cdn());
    if (rewritten != options.uri) {
      options.path = rewritten.toString();
      options.queryParameters.clear();
    }
    handler.next(options);
  }
}
