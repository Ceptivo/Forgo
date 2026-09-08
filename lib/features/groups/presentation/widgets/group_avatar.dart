import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

/// Renders a group's photo, or a placeholder icon when none is set.
/// [imageUrl] can be a plain http(s) URL (uploaded via the group settings
/// picker, rendered with [Image.network]) or a bundled Flutter asset path
/// (rendered with [Image.asset]) — the Forgo Community group uses the
/// latter, pointing straight at the app's own logo rather than a copy
/// uploaded to storage. Told apart by an "http" prefix, same convention
/// as CharityLogo.
class GroupAvatar extends StatelessWidget {
  const GroupAvatar({super.key, required this.imageUrl, this.size = 44});

  final String? imageUrl;
  final double size;

  @override
  Widget build(BuildContext context) {
    final url = imageUrl;
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: AppColors.accentDim,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      clipBehavior: Clip.antiAlias,
      child: url == null || url.isEmpty
          ? Icon(
              Icons.groups_rounded,
              color: AppColors.accentDeep,
              size: size * 0.55,
            )
          : ClipOval(
              child: url.startsWith('http')
                  ? Image.network(
                      url,
                      width: size,
                      height: size,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Icon(
                        Icons.groups_rounded,
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
                        Icons.groups_rounded,
                        color: AppColors.accentDeep,
                        size: size * 0.55,
                      ),
                    ),
            ),
    );
  }
}
