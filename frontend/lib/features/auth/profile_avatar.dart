import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({
    super.key,
    required this.photoUrl,
    required this.radius,
    this.iconSize,
  });

  final String? photoUrl;
  final double radius;
  final double? iconSize;

  @override
  Widget build(BuildContext context) {
    final url = photoUrl?.trim() ?? '';
    return CircleAvatar(
      key: ValueKey(url),
      radius: radius,
      backgroundColor: AppColors.sapphire.withValues(alpha: 0.32),
      backgroundImage: url.isEmpty ? null : NetworkImage(url),
      child: url.isEmpty
          ? Icon(
              Icons.person_rounded,
              size: iconSize ?? radius * 0.92,
              color: AppColors.shellstone.withValues(alpha: 0.86),
            )
          : null,
    );
  }
}
