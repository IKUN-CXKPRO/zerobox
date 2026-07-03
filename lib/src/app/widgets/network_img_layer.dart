import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:zerobox/src/core/constants/style_constants.dart' as style;

class NetworkImgLayer extends StatelessWidget {
  const NetworkImgLayer({
    super.key,
    this.src,
    required this.width,
    required this.height,
    this.type,
    this.fadeOutDuration,
    this.fadeInDuration,
    this.filterQuality = FilterQuality.high,
    this.color,
    this.colorBlendMode,
  });

  final String? src;
  final double width;
  final double height;
  final String? type;
  final Duration? fadeOutDuration;
  final Duration? fadeInDuration;
  final FilterQuality filterQuality;
  final Color? color;
  final BlendMode? colorBlendMode;

  static Widget heroFlightShuttleBuilder(
    BuildContext flightContext,
    Animation<double> animation,
    HeroFlightDirection flightDirection,
    BuildContext fromHeroContext,
    BuildContext toHeroContext,
  ) {
    final fromHero = fromHeroContext.widget as Hero;
    final heroContext = flightDirection == HeroFlightDirection.push
        ? fromHeroContext
        : toHeroContext;

    return InheritedTheme.captureAll(
      heroContext,
      Material(
        type: MaterialType.transparency,
        child: fromHero.child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final imageUrl = src ?? '';

    return imageUrl.isNotEmpty
        ? ClipRRect(
            clipBehavior: Clip.antiAlias,
            borderRadius: BorderRadius.circular(
              type == 'avatar'
                  ? 50
                  : type == 'emote'
                      ? 0
                      : style.StyleConstants.imgRadius.x,
            ),
            child: CachedNetworkImage(
              imageUrl: imageUrl,
              width: width,
              height: height,
              fit: BoxFit.cover,
              fadeOutDuration:
                  fadeOutDuration ?? const Duration(milliseconds: 120),
              fadeInDuration:
                  fadeInDuration ?? const Duration(milliseconds: 120),
              filterQuality: filterQuality,
              color: color,
              colorBlendMode: colorBlendMode,
              errorWidget: (context, url, error) => _placeholder(context),
              placeholder: (context, url) => _placeholder(context),
            ),
          )
        : _placeholder(context);
  }

  Widget _placeholder(BuildContext context) {
    return Container(
      width: width,
      height: height,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .onInverseSurface
            .withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(
          type == 'avatar'
              ? 50
              : type == 'emote'
                  ? 0
                  : style.StyleConstants.imgRadius.x,
        ),
      ),
      child: const Center(
        child: Icon(Icons.image_outlined),
      ),
    );
  }
}
