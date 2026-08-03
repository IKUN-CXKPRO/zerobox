import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oronbox/src/data/oronbox/oronbox_home_api.dart';

void main() {
  test('published blogs are included without an editor section', () async {
    final dio = Dio();
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          final data = options.path.endsWith('/api/blog')
              ? {
                  'posts': [
                    {
                      'slug': 'release-notes',
                      'type': 'announcement',
                      'title': 'Release notes',
                      'subtitle': '',
                      'author': 'OronBox',
                    },
                  ],
                }
              : {'banners': <Object?>[], 'sections': <Object?>[]};
          handler.resolve(
            Response<Object?>(
              requestOptions: options,
              statusCode: 200,
              data: data,
            ),
          );
        },
      ),
    );

    final feed = await OronBoxHomeApi(dio: dio).fetchHome();

    expect(feed.blogs.single.slug, 'release-notes');
    expect(feed.isEmpty, isFalse);
  });
}
