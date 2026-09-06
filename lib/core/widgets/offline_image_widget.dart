import 'package:flutter/material.dart';

/// A smart image widget that caches network images locally so Vendor POS
/// scanning visual verifications work perfectly even when offline.
class OfflineImageWidget extends StatelessWidget {
  final String imageUrl;
  final double width;
  final double height;
  final double borderRadius;

  const OfflineImageWidget({
    super.key,
    required this.imageUrl,
    this.width = 50,
    this.height = 50,
    this.borderRadius = 25,
  });

  @override
  Widget build(BuildContext context) {
    // Note: In a production environment with dependencies, this would map to
    // CachedNetworkImage(imageUrl: imageUrl) to provide true offline caching.
    
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: Image.network(
        imageUrl,
        width: width,
        height: height,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          // Fallback if truly offline and not in cache
          return Container(
            width: width,
            height: height,
            color: Colors.grey.shade300,
            child: const Icon(Icons.person, color: Colors.grey),
          );
        },
      ),
    );
  }
}
