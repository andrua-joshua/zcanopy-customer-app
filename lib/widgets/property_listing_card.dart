import 'package:flutter/material.dart';
import 'package:zcanopy/utils/currency.dart';

/// Shared property listing card — same format used across the Home and
/// Explorer screens. Renders the hero image, status chip, save bookmark,
/// optional video-tour overlay, price, location and a View action.
class PropertyListingCard extends StatelessWidget {
  final Map<String, dynamic> property;
  final bool Function(String id)? isSaved;
  final void Function(String id)? onToggleSave;
  final VoidCallback? onOpen;
  final VoidCallback? onPlayVideo;
  final EdgeInsetsGeometry? margin;
  final double imageHeight;

  const PropertyListingCard({
    super.key,
    required this.property,
    this.isSaved,
    this.onToggleSave,
    this.onOpen,
    this.onPlayVideo,
    this.margin,
    this.imageHeight = 200,
  });

  static const _brown = Color.fromARGB(255, 169, 97, 14);

  String get _imageUrl {
    final images = property['images'];
    if (images is List && images.isNotEmpty) {
      return images.first.toString();
    }
    final single = property['image'];
    if (single != null && single.toString().isNotEmpty) {
      return single.toString();
    }
    return '';
  }

  String get _location {
    final sub = property['subCounty']?.toString() ?? '';
    final dist = property['district']?.toString() ?? '';
    if (sub.isNotEmpty && dist.isNotEmpty) return '$sub, $dist';
    final loc = property['location']?.toString() ?? '';
    return loc.isNotEmpty ? loc : '';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF2A2A2A) : Colors.white;
    final status = property['status']?.toString() ?? 'Available';
    final available = !status.toLowerCase().contains('book');
    final hasVideo = property['video'] != null &&
        property['video'].toString().isNotEmpty;
    final id = property['id']?.toString();
    final saved = (id != null && isSaved != null) ? isSaved!(id) : false;

    void openDetails() => onOpen?.call();

    return Card(
      color: cardColor,
      margin: margin ?? const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      elevation: isDark ? 0 : 2,
      shadowColor: Colors.black.withValues(alpha: 0.08),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              GestureDetector(
                onTap: openDetails,
                child: _imageUrl.isEmpty
                    ? Container(
                        height: imageHeight,
                        width: double.infinity,
                        color: Colors.grey.shade200,
                        child: const Center(
                          child: Icon(Icons.home_outlined,
                              size: 40, color: Colors.grey),
                        ),
                      )
                    : Image.network(
                        _imageUrl,
                        height: imageHeight,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          height: imageHeight,
                          color: Colors.grey.shade200,
                          child: const Center(
                            child: Icon(Icons.home_outlined,
                                size: 40, color: Colors.grey),
                          ),
                        ),
                      ),
              ),
              Container(
                height: imageHeight,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black26],
                  ),
                ),
              ),
              Positioned(
                top: 10,
                right: 10,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: available ? Colors.green : Colors.red,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    status,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              if (id != null && onToggleSave != null)
                Positioned(
                  top: 10,
                  left: 10,
                  child: GestureDetector(
                    onTap: () => onToggleSave!(id),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.9),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.15),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Icon(
                        saved ? Icons.bookmark : Icons.bookmark_border,
                        color: saved ? _brown : Colors.grey.shade600,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              if (hasVideo && onPlayVideo != null)
                Positioned(
                  bottom: 10,
                  right: 10,
                  child: GestureDetector(
                    onTap: onPlayVideo,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Icon(Icons.play_circle_fill,
                          color: Colors.white, size: 24),
                    ),
                  ),
                ),
              if (hasVideo && onPlayVideo == null)
                const Positioned(
                  bottom: 10,
                  right: 10,
                  child: Icon(Icons.play_circle_fill,
                      color: Colors.white, size: 30),
                ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  property['name'],
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Text(
                  formatUgx(property['price']),
                  style: const TextStyle(
                    color: _brown,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.location_on_outlined,
                        size: 14, color: Colors.grey),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        _location,
                        style:
                            TextStyle(color: Colors.grey.shade600, fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: _brown.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          property['brokerName']?.toString() ?? 'Broker',
                          style: const TextStyle(
                            color: _brown,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    if (onOpen != null) ...[
                      const Spacer(),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: openDetails,
                        icon: const Icon(Icons.visibility_outlined, size: 16),
                        label:
                            const Text("View", style: TextStyle(fontSize: 12)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _brown,
                          side: const BorderSide(color: _brown),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 6),
                          visualDensity: VisualDensity.compact,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}