import 'package:flutter/material.dart';

import '../report_details_models.dart';
import '../report_details_theme.dart';

class ReportDetailsHeader extends StatelessWidget {
  final ReportDetailsData data;

  const ReportDetailsHeader({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 320,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(30),
                bottomRight: Radius.circular(30),
              ),
              child: _HeaderImage(imageUrl: data.imageUrl),
            ),
          ),
          Positioned(
            top: 16,
            left: 16,
            child: _BackButton(
              onTap: () => Navigator.of(context).pop(),
            ),
          ),
          Positioned(
            left: 20,
            right: 20,
            bottom: -38,
            child: _InfoCard(data: data),
          ),
        ],
      ),
    );
  }
}

class _HeaderImage extends StatelessWidget {
  final String imageUrl;

  const _HeaderImage({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    final hasImage = imageUrl.isNotEmpty && imageUrl.startsWith('http');
    if (hasImage) {
      return Image.network(
        imageUrl,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _FallbackImage(),
      );
    }
    if (imageUrl.isNotEmpty) {
      return Image.asset(
        imageUrl,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _FallbackImage(),
      );
    }
    return const _FallbackImage();
  }
}

class _FallbackImage extends StatelessWidget {
  const _FallbackImage();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.grey.shade200,
      child: Icon(
        Icons.person,
        size: 80,
        color: Colors.grey.shade500,
      ),
    );
  }
}

class _BackButton extends StatelessWidget {
  final VoidCallback onTap;

  const _BackButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.9),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.12),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Icon(Icons.arrow_back, color: Colors.black87),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final ReportDetailsData data;

  const _InfoCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data.title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  data.subtitle,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade700,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: data.isMissing
                  ? ReportDetailsTheme.lightGold
                  : Colors.green.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              data.isMissing && data.verificationStatus == 'verified'
                  ? 'VERIFIED'
                  : data.statusLabel,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: data.isMissing && data.verificationStatus == 'verified'
                    ? Colors.green.shade700
                    : data.isMissing
                        ? ReportDetailsTheme.accentGold
                        : Colors.green.shade700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
