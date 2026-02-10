import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

class MapPickerWidget extends StatefulWidget {
  final LatLng? initialLocation;
  final ValueChanged<LatLng> onLocationPicked;
  final bool showCurrentLocationButton;
  final double height;

  const MapPickerWidget({
    super.key,
    this.initialLocation,
    required this.onLocationPicked,
    this.showCurrentLocationButton = true,
    this.height = 220,
  });

  @override
  State<MapPickerWidget> createState() => _MapPickerWidgetState();
}

class _MapPickerWidgetState extends State<MapPickerWidget> {
  late final MapController _mapController;
  late LatLng _selected;
  bool _hasPicked = false;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _selected = widget.initialLocation ?? const LatLng(2.0469, 45.3182);
    _hasPicked = widget.initialLocation != null;
  }

  Future<void> _useCurrentLocation() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _showMessage('Please enable location services.');
      return;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      _showMessage('Location permission denied.');
      return;
    }

    final position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
    final latLng = LatLng(position.latitude, position.longitude);
    setState(() {
      _selected = latLng;
      _hasPicked = true;
    });
    widget.onLocationPicked(latLng);
    _mapController.move(latLng, 15);
  }

  void _showMessage(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _selected,
                initialZoom: 13,
                onTap: (tapPosition, latLng) {
                  setState(() {
                    _selected = latLng;
                    _hasPicked = true;
                  });
                  widget.onLocationPicked(latLng);
                },
              ),
              children: [
                // Using MapTiler's free tiles with an API key (replace with your own key if needed)
                TileLayer(
                  urlTemplate:
                      'https://api.maptiler.com/maps/streets/{z}/{x}/{y}.png?key=k2j3A7QYqy1PHIhj1lyD',
                  userAgentPackageName: 'com.khaalid.missing_persons_app',
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _selected,
                      width: 40,
                      height: 40,
                      child: Icon(
                        Icons.location_on,
                        size: 36,
                        color: _hasPicked ? Colors.redAccent : Colors.grey,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _hasPicked
                  ? 'Lat: ${_selected.latitude.toStringAsFixed(4)}  Lng: ${_selected.longitude.toStringAsFixed(4)}'
                  : 'No location selected',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            if (widget.showCurrentLocationButton)
              TextButton.icon(
                onPressed: _useCurrentLocation,
                icon: const Icon(Icons.my_location, size: 16),
                label: const Text('Use Current'),
              ),
          ],
        ),
      ],
    );
  }
}
