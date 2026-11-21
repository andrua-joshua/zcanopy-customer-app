import 'package:flutter/material.dart';
import 'package:zcanopy/services/gateway_api.dart';
import 'package:zcanopy/widgets/tiktok_video_reel.dart';

class ReelsPage extends StatefulWidget {
  const ReelsPage({super.key});

  @override
  State<ReelsPage> createState() => _ReelsPageState();
}

class _ReelsPageState extends State<ReelsPage> {
  final _api = GatewayApi();
  List<Map<String, dynamic>> _tours = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadVideoTours();
  }

  Future<void> _loadVideoTours() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response = await _api.getVideoTours(page: 1, limit: 20);
      final list = (response['properties'] as List? ?? [])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .where((p) => (p['video'] ?? '').toString().isNotEmpty)
          .toList();
      if (!mounted) return;
      setState(() => _tours = list);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Could not load video tours.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> get _videos => _tours
      .map(
        (p) => {
          'id': p['id']?.toString() ?? '',
          'videoUrl': p['video'],
          'title': p['name']?.toString() ?? 'Property tour',
          'location': p['location']?.toString() ?? '',
          'subCounty': p['subCounty']?.toString() ?? '',
          'district': p['district']?.toString() ?? '',
          'brokerCode': p['brokerCode']?.toString() ?? '',
          'brokerName': p['brokerName']?.toString() ?? 'Broker',
          'brokerPhone': p['brokerPhone']?.toString() ?? '',
        },
      )
      .toList();

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(color: Colors.white70),
        ),
      );
    }

    if (_error != null || _videos.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _error != null ? Icons.cloud_off : Icons.play_circle_outline,
                  color: Colors.white54,
                  size: 56,
                ),
                const SizedBox(height: 12),
                Text(
                  _error ?? 'No video tours available yet.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70, fontSize: 16),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: _loadVideoTours,
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: TikTokVideoReel(videos: _videos),
    );
  }
}
