import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class PropertyDetailsShimmer extends StatelessWidget {
  const PropertyDetailsShimmer({super.key});

  Widget _shimmerBox({
    double? height,
    double? width,
    BorderRadiusGeometry borderRadius = BorderRadius.zero,
  }) {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300,
      highlightColor: Colors.grey.shade100,
      child: Container(
        height: height,
        width: width,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: borderRadius,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F8),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _shimmerBox(height: 300, width: double.infinity),
            Transform.translate(
              offset: const Offset(0, -20),
              child: Column(
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _shimmerBox(height: 24, width: 220, borderRadius: BorderRadius.circular(8)),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            _shimmerBox(height: 26, width: 80, borderRadius: BorderRadius.circular(8)),
                            const SizedBox(width: 12),
                            _shimmerBox(height: 18, width: 120, borderRadius: BorderRadius.circular(6)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 88,
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      scrollDirection: Axis.horizontal,
                      itemCount: 4,
                      separatorBuilder: (_, __) => const SizedBox(width: 10),
                      itemBuilder: (_, __) => _shimmerBox(
                        height: 88,
                        width: 88,
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _shimmerBox(
                      height: 100,
                      width: double.infinity,
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _shimmerBox(
                      height: 140,
                      width: double.infinity,
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: SizedBox(
                      height: 96,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: 4,
                        separatorBuilder: (_, __) => const SizedBox(width: 10),
                        itemBuilder: (_, __) => _shimmerBox(
                          height: 96,
                          width: 120,
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _shimmerBox(
                      height: 200,
                      width: double.infinity,
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 12,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _shimmerBox(height: 12, width: 70, borderRadius: BorderRadius.circular(4)),
                  const SizedBox(height: 6),
                  _shimmerBox(height: 24, width: 110, borderRadius: BorderRadius.circular(6)),
                ],
              ),
              const Spacer(),
              _shimmerBox(height: 48, width: 130, borderRadius: BorderRadius.circular(14)),
            ],
          ),
        ),
      ),
    );
  }
}
