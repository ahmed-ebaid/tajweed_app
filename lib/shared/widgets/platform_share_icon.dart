import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class PlatformShareIcon extends StatelessWidget {
  const PlatformShareIcon({super.key});

  @override
  Widget build(BuildContext context) {
    final platform = Theme.of(context).platform;
    final isApplePlatform =
        platform == TargetPlatform.iOS || platform == TargetPlatform.macOS;
    return Icon(
      isApplePlatform ? CupertinoIcons.share : Icons.share_rounded,
      size: 22,
    );
  }
}
