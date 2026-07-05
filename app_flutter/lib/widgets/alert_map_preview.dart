import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class AlertMapPreview extends StatelessWidget {
  final double lat;
  final double lng;
  final bool isMissing;
  final double height;

  const AlertMapPreview({
    super.key,
    required this.lat,
    required this.lng,
    required this.isMissing,
    this.height = 140,
  });

  @override
  Widget build(BuildContext context) {
    final point = LatLng(lat, lng);
    final markerColor = isMissing ? Colors.orange.shade700 : Colors.green.shade700;

    return Container(
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: FlutterMap(
          options: MapOptions(
            initialCenter: point,
            initialZoom: 14,
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.none,
            ),
          ),
          children: [
            TileLayer(
              urlTemplate:
                  'https://api.maptiler.com/maps/streets/{z}/{x}/{y}.png?key=k2j3A7QYqy1PHIhj1lyD',
              userAgentPackageName: 'com.khaalid.missing_persons_app',
            ),
            MarkerLayer(
              markers: [
                Marker(
                  point: point,
                  width: 36,
                  height: 36,
                  child: Icon(Icons.location_on, size: 34, color: markerColor),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
