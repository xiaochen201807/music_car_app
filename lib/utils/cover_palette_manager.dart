import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../theme/design_tokens.dart';

/// 管理当前歌曲封面的主色采样提取，并为网络 URL 提供内存缓存。
/// 采用 1x1 像素缩放算法，高效提取背景渐变所需的克制色彩。
class CoverPaletteManager {
  CoverPaletteManager._privateConstructor();

  static final CoverPaletteManager instance =
      CoverPaletteManager._privateConstructor();

  // 内存中缓存已采样过封面的 URL -> Color 的映射
  final Map<String, Color> _paletteCache = <String, Color>{};

  /// 获取指定封面 URL 的采样主色。如果包含缓存，立即同步返回；
  /// 否则触发异步分析。
  Future<Color> getColor(String imageUrl) async {
    final String cleanUrl = imageUrl.trim();
    if (cleanUrl.isEmpty) {
      return AppColor.accentSteelStart;
    }

    if (_paletteCache.containsKey(cleanUrl)) {
      return _paletteCache[cleanUrl]!;
    }

    try {
      final Color color = await _extractColorFromUrl(cleanUrl);
      // 分析成功，存入缓存
      _paletteCache[cleanUrl] = color;
      return color;
    } catch (_) {
      // 失败则不写入缓存，下一次仍可重试，但本次返回安全 fallback 颜色
      return AppColor.accentSteelStart;
    }
  }

  /// 物理清空全部色值缓存
  void clearCache() {
    _paletteCache.clear();
  }

  /// 核心 1x1 像素缩放采样主色，并限制饱和度与亮度
  Future<Color> _extractColorFromUrl(String imageUrl) async {
    final ImageProvider provider = CachedNetworkImageProvider(imageUrl);
    final ImageStream stream = provider.resolve(ImageConfiguration.empty);
    final Completer<ui.Image> completer = Completer<ui.Image>();
    ImageStreamListener? listener;

    listener = ImageStreamListener(
      (ImageInfo info, bool synchronousCall) {
        if (!completer.isCompleted) {
          completer.complete(info.image);
        }
        if (listener != null) {
          stream.removeListener(listener);
        }
      },
      onError: (Object exception, StackTrace? stackTrace) {
        if (!completer.isCompleted) {
          completer.completeError(exception);
        }
        if (listener != null) {
          stream.removeListener(listener);
        }
      },
    );
    stream.addListener(listener);

    try {
      final ui.Image image = await completer.future.timeout(
        const Duration(milliseconds: 3500),
      );

      final ui.PictureRecorder recorder = ui.PictureRecorder();
      final Canvas canvas = Canvas(recorder);
      canvas.drawImageRect(
        image,
        Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
        const Rect.fromLTWH(0, 0, 1, 1),
        Paint()..filterQuality = FilterQuality.medium,
      );
      final ui.Picture picture = recorder.endRecording();
      final ui.Image smallImage = await picture.toImage(1, 1);
      final ByteData? byteData = await smallImage.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      );

      if (byteData == null || byteData.lengthInBytes < 4) {
        return AppColor.accentSteelStart;
      }

      final int r = byteData.getUint8(0);
      final int g = byteData.getUint8(1);
      final int b = byteData.getUint8(2);

      final HSLColor hsl = HSLColor.fromColor(Color.fromARGB(255, r, g, b));
      final double s = hsl.saturation.clamp(0.12, 0.34);
      final double l = hsl.lightness.clamp(0.28, 0.56);
      return hsl.withSaturation(s).withLightness(l).toColor();
    } finally {
      stream.removeListener(listener);
    }
  }
}
