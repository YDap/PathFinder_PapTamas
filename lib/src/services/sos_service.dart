import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class SosService {
  static Future<void> _callEmergency() async {
    final uri = Uri(scheme: 'tel', path: '112');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  static Future<Position?> _getCurrentPosition({BuildContext? context}) async {
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.deniedForever) {
        if (context != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'Location permission permanently denied. Enable it in Settings.'),
            ),
          );
        }
        return null;
      }

      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) {
        if (context != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please enable Location Services')),
          );
        }
        return null;
      }

      return Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
    } catch (_) {
      if (context != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not get current location')),
        );
      }
      return null;
    }
  }

  static Future<void> _shareMyLocation(Position pos) async {
    final url = 'https://maps.google.com/?q=${pos.latitude},${pos.longitude}';
    await Share.share('I need help. My location: $url');
  }

  static Future<void> showSosSheet(BuildContext context) async {
    final pos = await _getCurrentPosition(context: context);

    // ignore: use_build_context_synchronously
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const ListTile(
                  leading: Icon(Icons.warning_amber_rounded),
                  title: Text('Emergency options'),
                ),
                ListTile(
                  leading: const Icon(Icons.call, color: Colors.red),
                  title: const Text('Call 112'),
                  onTap: () async {
                    Navigator.pop(ctx);
                    await _callEmergency();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.share_location),
                  title: const Text('Share my current location'),
                  subtitle: Text(
                    pos == null
                        ? 'Location unavailable'
                        : '${pos.latitude.toStringAsFixed(5)}, ${pos.longitude.toStringAsFixed(5)}',
                  ),
                  enabled: pos != null,
                  onTap: pos == null
                      ? null
                      : () async {
                          Navigator.pop(ctx);
                          await _shareMyLocation(pos);
                        },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
