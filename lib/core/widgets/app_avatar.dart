import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// Shared avatar: shows photo when available, otherwise the name initial.
class AppAvatar extends StatelessWidget {
  const AppAvatar({
    super.key,
    required this.name,
    this.avatarUrl,
    this.imageBytes,
    this.radius = 20,
    this.backgroundColor,
    this.foregroundColor,
  });

  final String name;
  final String? avatarUrl;
  final Uint8List? imageBytes;
  final double radius;
  final Color? backgroundColor;
  final Color? foregroundColor;

  /// Solid mint teal — avoid alpha so the circle never blends into 2 tones.
  static Color get defaultBackground => AppColors.primaryFixed;

  static Color get defaultForeground => AppColors.primary;

  String get _initial {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '?';
    return trimmed.characters.first.toUpperCase();
  }

  ImageProvider? get _image {
    if (imageBytes != null) return MemoryImage(imageBytes!);
    final url = avatarUrl?.trim();
    if (url == null || url.isEmpty) return null;
    final uri = Uri.tryParse(url);
    if (uri == null || uri.host.isEmpty) return null;
    if (uri.scheme != 'http' && uri.scheme != 'https') return null;
    return NetworkImage(url);
  }

  @override
  Widget build(BuildContext context) {
    final image = _image;
    final bg = backgroundColor ?? defaultBackground;
    final fg = foregroundColor ?? defaultForeground;

    return CircleAvatar(
      radius: radius,
      backgroundColor: bg,
      foregroundColor: fg,
      backgroundImage: image,
      child: image == null
          ? Text(
              _initial,
              style: AppTextStyles.titleMedium.copyWith(
                color: fg,
                fontSize: radius * 0.9,
                fontWeight: FontWeight.w700,
                height: 1,
              ),
            )
          : null,
    );
  }
}
