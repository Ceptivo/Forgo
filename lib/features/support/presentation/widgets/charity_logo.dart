import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

/// Renders a charity's logo, or a placeholder icon when none is set yet.
/// [logoUrl] can be a bundled asset path (rendered via [Image.asset]) or a
/// plain http(s) URL (rendered via [Image.network]) — whichever the
/// developer set on the charities row.
class CharityLogo extends StatelessWidget {
  const CharityLogo({super.key, required this.logoUrl, this.size = 44});

  final String? logoUrl;
  final double size;

  @override
  Widget build(BuildContext context) {
    final url = logoUrl;
    return ClipOval(
      child: Container(
        width: size,
        height: size,
        color: AppColors.accentDim,
        alignment: Alignment.center,
        child: url == null || url.isEmpty
            ? Icon(
                Icons.volunteer_activism_rounded,
                color: AppColors.accentDeep,
                size: size * 0.55,
              )
            : url.startsWith('http')
            ? Image.network(
                url,
                width: size,
                height: size,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Icon(
                  Icons.volunteer_activism_rounded,
                  color: AppColors.accentDeep,
                  size: size * 0.55,
                ),
              )
            : Image.asset(
                url,
                width: size,
                height: size,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Icon(
                  Icons.volunteer_activism_rounded,
                  color: AppColors.accentDeep,
                  size: size * 0.55,
                ),
              ),
      ),
    );
  }
}
