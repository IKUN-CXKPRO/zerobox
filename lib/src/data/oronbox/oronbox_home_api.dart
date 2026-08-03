import 'package:dio/dio.dart';
import 'package:oronbox/src/core/constants/oronbox_server.dart';
import 'package:oronbox/src/core/network/app_http_transport.dart';

enum HomeBannerType { resource, blog, link }

class HomeBanner {
  const HomeBanner({
    required this.id,
    required this.type,
    required this.title,
    required this.subtitle,
    this.coverUrl,
    this.resourceId = '',
    this.blogSlug = '',
    this.linkUrl,
  });

  final String id;
  final HomeBannerType type;
  final String title;
  final String subtitle;
  final Uri? coverUrl;
  final String resourceId;
  final String blogSlug;
  final Uri? linkUrl;
}

class HomeResourceCard {
  const HomeResourceCard({
    required this.id,
    required this.slug,
    required this.name,
    required this.summary,
    required this.kind,
    required this.owner,
    this.iconUrl,
    this.coverUrl,
    this.previews = const [],
  });

  final String id;
  final String slug;
  final String name;
  final String summary;
  final String kind;
  final String owner;
  final Uri? iconUrl;
  final Uri? coverUrl;
  final List<Uri> previews;
}

class BlogCard {
  const BlogCard({
    required this.slug,
    required this.type,
    required this.title,
    required this.subtitle,
    required this.author,
    this.coverUrl,
    this.publishedAt,
  });

  final String slug;
  final String type;
  final String title;
  final String subtitle;
  final String author;
  final Uri? coverUrl;
  final DateTime? publishedAt;
}

class BlogPost extends BlogCard {
  const BlogPost({
    required super.slug,
    required super.type,
    required super.title,
    required super.subtitle,
    required super.author,
    required this.body,
    super.coverUrl,
    super.publishedAt,
  });

  final String body;
}

class HomeSectionCard {
  const HomeSectionCard({required this.id, this.resource, this.blog});

  final String id;
  final HomeResourceCard? resource;
  final BlogCard? blog;
}

class HomeSection {
  const HomeSection({
    required this.id,
    required this.name,
    required this.description,
    required this.cards,
  });

  final String id;
  final String name;
  final String description;
  final List<HomeSectionCard> cards;
}

class HomeFeed {
  const HomeFeed({
    required this.banners,
    required this.blogs,
    required this.sections,
  });

  final List<HomeBanner> banners;
  final List<BlogCard> blogs;
  final List<HomeSection> sections;

  bool get isEmpty =>
      banners.isEmpty &&
      blogs.isEmpty &&
      sections.every((section) => section.cards.isEmpty);
}

class OronBoxHomeApi {
  OronBoxHomeApi({Dio? dio}) : _dio = dio ?? createAppHttpTransport();

  final Dio _dio;

  Future<HomeFeed> fetchHome() async {
    final responses = await Future.wait([
      _dio.get<Object?>('$oronBoxServerBaseUrl/api/home'),
      _dio.get<Object?>('$oronBoxServerBaseUrl/api/blog'),
    ]);
    final root = _map(responses[0].data);
    final blogRoot = _map(responses[1].data);
    return HomeFeed(
      banners: (root['banners'] as List? ?? const [])
          .whereType<Map>()
          .map((value) => _banner(value.cast<String, Object?>()))
          .toList(),
      blogs: (blogRoot['posts'] as List? ?? const [])
          .whereType<Map>()
          .map((value) => _blogCard(value.cast<String, Object?>()))
          .toList(),
      sections: (root['sections'] as List? ?? const [])
          .whereType<Map>()
          .map((value) => _section(value.cast<String, Object?>()))
          .toList(),
    );
  }

  Future<BlogPost> fetchBlogPost(String slug) async {
    final response = await _dio.get<Object?>(
      '$oronBoxServerBaseUrl/api/blog/${Uri.encodeComponent(slug)}',
    );
    final json = _map(response.data);
    return BlogPost(
      slug: json['slug']?.toString() ?? slug,
      type: json['type']?.toString() ?? 'announcement',
      title: json['title']?.toString() ?? '',
      subtitle: json['subtitle']?.toString() ?? '',
      author: json['author']?.toString() ?? '',
      body: json['body']?.toString() ?? '',
      coverUrl: _blobUri(json['cover_sha256']?.toString() ?? ''),
      publishedAt: DateTime.tryParse(json['published_at']?.toString() ?? ''),
    );
  }

  HomeBanner _banner(Map<String, Object?> json) {
    final link = Uri.tryParse(json['link_url']?.toString() ?? '');
    return HomeBanner(
      id: json['id']?.toString() ?? '',
      type: switch (json['type']?.toString()) {
        'blog' => HomeBannerType.blog,
        'link' => HomeBannerType.link,
        _ => HomeBannerType.resource,
      },
      title: json['title']?.toString() ?? '',
      subtitle: json['subtitle']?.toString() ?? '',
      coverUrl: _blobUri(json['cover_sha256']?.toString() ?? ''),
      resourceId: json['resource_id']?.toString() ?? '',
      blogSlug: json['blog_slug']?.toString() ?? '',
      linkUrl: link?.hasScheme == true ? link : null,
    );
  }

  HomeSection _section(Map<String, Object?> json) {
    return HomeSection(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      cards: (json['cards'] as List? ?? const [])
          .whereType<Map>()
          .map((value) => _card(value.cast<String, Object?>()))
          .whereType<HomeSectionCard>()
          .toList(),
    );
  }

  HomeSectionCard? _card(Map<String, Object?> json) {
    final id = json['id']?.toString() ?? '';
    if (json['resource'] is Map) {
      final resource = (json['resource']! as Map).cast<String, Object?>();
      return HomeSectionCard(
        id: id,
        resource: HomeResourceCard(
          id: resource['id']?.toString() ?? '',
          slug: resource['slug']?.toString() ?? '',
          name: resource['name']?.toString() ?? '',
          summary: resource['summary']?.toString() ?? '',
          kind: resource['kind']?.toString() ?? '',
          owner: resource['owner']?.toString() ?? '',
          iconUrl: _blobUri(resource['icon_sha256']?.toString() ?? ''),
          coverUrl: _blobUri(resource['cover_sha256']?.toString() ?? ''),
          previews: (resource['previews'] as List? ?? const [])
              .map((value) => _blobUri(value.toString()))
              .whereType<Uri>()
              .toList(),
        ),
      );
    }
    if (json['blog'] is Map) {
      return HomeSectionCard(
        id: id,
        blog: _blogCard((json['blog']! as Map).cast<String, Object?>()),
      );
    }
    return null;
  }

  BlogCard _blogCard(Map<String, Object?> json) => BlogCard(
    slug: json['slug']?.toString() ?? '',
    type: json['type']?.toString() ?? 'announcement',
    title: json['title']?.toString() ?? '',
    subtitle: json['subtitle']?.toString() ?? '',
    author: json['author']?.toString() ?? '',
    coverUrl: _blobUri(json['cover_sha256']?.toString() ?? ''),
    publishedAt: DateTime.tryParse(json['published_at']?.toString() ?? ''),
  );

  Uri? _blobUri(String digest) => digest.length == 64
      ? Uri.parse('$oronBoxServerBaseUrl/api/blobs/$digest?line=local')
      : null;

  Map<String, Object?> _map(Object? value) => value is Map
      ? value.cast<String, Object?>()
      : throw FormatException('OronBox server returned ${value.runtimeType}');
}
