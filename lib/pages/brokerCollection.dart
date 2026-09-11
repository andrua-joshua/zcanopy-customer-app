import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:zcanopy/data/sample_catalog.dart';
import 'package:zcanopy/services/api_service.dart';
import 'package:zcanopy/pages/itemDetails.dart';
import 'package:zcanopy/utils/theme_extensions.dart';
import 'package:zcanopy/widgets/property_listing_card.dart';
import 'package:zcanopy/widgets/tiktok_video_reel.dart';
import 'package:zcanopy/widgets/video_tour_player.dart';

const _primary = Color(0xFFA9710E);

class BrokerCollectionPage extends StatefulWidget {
  final String brokerCode;
  final String brokerName;
  final String brokerPhone;
  final num? brokerRating;

  const BrokerCollectionPage({
    super.key,
    required this.brokerCode,
    required this.brokerName,
    this.brokerPhone = '',
    this.brokerRating,
  });

  @override
  State<BrokerCollectionPage> createState() => _BrokerCollectionPageState();
}

class _BrokerCollectionPageState extends State<BrokerCollectionPage> {
  final _api = ApiService();
  List<Map<String, dynamic>> _properties = [];
  bool _loading = true;
  final Set<String> _savedProperties = {};

  @override
  void initState() {
    super.initState();
    _savedProperties.addAll((Hive.box('myStore')
            .get('savedProperties', defaultValue: []) as List)
        .map((e) => e.toString()));
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await _api.getBrokerPropertiesForCustomer(
        sessionToken: _api.currentSessionId ?? '',
        brokerCode: widget.brokerCode,
      );
      if (res['success'] == true && res['properties'] is List) {
        final list = (res['properties'] as List)
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        _applyBrokerMeta(list);
        if (mounted) {
          setState(() {
            _properties = list;
            _loading = false;
          });
        }
        return;
      }
    } catch (e) {
      debugPrint('Broker properties fetch failed, using local: $e');
    }
    final local = kSampleProperties
        .where((p) => p['brokerCode']?.toString() == widget.brokerCode)
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    _applyBrokerMeta(local);
    if (mounted) {
      setState(() {
        _properties = local;
        _loading = false;
      });
    }
  }

  void _applyBrokerMeta(List<Map<String, dynamic>> list) {
    for (final p in list) {
      p['brokerCode'] ??= widget.brokerCode;
      p['brokerName'] ??= widget.brokerName;
      p['brokerPhone'] ??= widget.brokerPhone;
    }
  }

  void _toggleSaveProperty(String id) {
    final prefs = Hive.box('myStore');
    if (_savedProperties.contains(id)) {
      _savedProperties.remove(id);
    } else {
      _savedProperties.add(id);
    }
    prefs.put('savedProperties', _savedProperties.toList());
    setState(() {});
  }

  bool _isSaved(String id) => _savedProperties.contains(id);

  Future<void> _launch(Uri uri) async {
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _openDetails(Map<String, dynamic> property) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PropertyDetailsPage(property: property),
      ),
    );
  }

  void _openVideoTour(Map<String, dynamic> property) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VideoTourPlayer(property: property),
      ),
    );
  }

  List<Map<String, dynamic>> get _videoTours => _properties
      .where((p) =>
          p['video'] != null && p['video'].toString().isNotEmpty)
      .map((p) => {
            'videoUrl': p['video'],
            'title': p['name']?.toString() ?? 'Property tour',
            'location': p['location']?.toString() ?? '',
            'subCounty': p['subCounty']?.toString() ?? '',
            'district': p['district']?.toString() ?? '',
            'brokerCode': widget.brokerCode,
            'brokerName': widget.brokerName,
            'brokerPhone': widget.brokerPhone,
          })
      .toList();

  void _openVideoTours() {
    final videos = _videoTours;
    if (videos.isEmpty) return;
    showDialog(
      context: context,
      barrierColor: Colors.black,
      builder: (_) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          children: [
            SizedBox(
              height: MediaQuery.of(context).size.height,
              width: MediaQuery.of(context).size.width,
              child: TikTokVideoReel(videos: videos),
            ),
            Positioned(
              top: 40,
              left: 16,
              child: IconButton(
                icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String get _initials {
    final parts = widget.brokerName.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts[1][0]}'.toUpperCase();
    }
    return widget.brokerName.isNotEmpty
        ? widget.brokerName[0].toUpperCase()
        : 'B';
  }

  @override
  Widget build(BuildContext context) {
    final hasTours = _videoTours.isNotEmpty;
    return Scaffold(
      backgroundColor: context.appScaffoldColor,
      floatingActionButton: hasTours
          ? FloatingActionButton.extended(
              onPressed: _openVideoTours,
              heroTag: 'broker_video_tours',
              backgroundColor: _primary,
              foregroundColor: Colors.white,
              elevation: 6,
              icon: const Icon(Icons.play_circle_fill, size: 22),
              label: const Text(
                'Video Tours',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: _load,
        color: _primary,
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              pinned: true,
              expandedHeight: 190,
              backgroundColor: _primary,
              foregroundColor: Colors.white,
              elevation: 0,
              flexibleSpace: FlexibleSpaceBar(
                collapseMode: CollapseMode.parallax,
                background: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF6B4A1F), _primary, Color(0xFF8A5A1E)],
                    ),
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: _BrokerHeader(
                name: widget.brokerName,
                initials: _initials,
                rating: widget.brokerRating,
                listingCount: _properties.length,
                onWhatsApp: () => _launch(
                  Uri.parse(
                    'https://wa.me/${widget.brokerPhone.replaceAll(RegExp(r'[^0-9+]'), '')}',
                  ),
                ),
                onCall: () => _launch(Uri.parse('tel:${widget.brokerPhone}')),
              ),
            ),
            if (_loading)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 80),
                  child: Center(
                    child: CircularProgressIndicator(color: _primary),
                  ),
                ),
              )
            else if (_properties.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Text(
                    'No properties from this broker yet.',
                    style: TextStyle(color: context.appMutedTextColor),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final property = _properties[index];
                    return PropertyListingCard(
                      property: property,
                      isSaved: _isSaved,
                      onToggleSave: _toggleSaveProperty,
                      onOpen: () => _openDetails(property),
                      onPlayVideo: () => _openVideoTour(property),
                    );
                  }, childCount: _properties.length),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _BrokerHeader extends StatelessWidget {
  final String name;
  final String initials;
  final num? rating;
  final int listingCount;
  final VoidCallback onWhatsApp;
  final VoidCallback onCall;

  const _BrokerHeader({
    required this.name,
    required this.initials,
    required this.rating,
    required this.listingCount,
    required this.onWhatsApp,
    required this.onCall,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;
    final muted = context.appMutedTextColor;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
      decoration: BoxDecoration(
        color: context.appCardColor,
        borderRadius: BorderRadius.circular(20),
        border: isDark ? Border.all(color: Colors.white12) : null,
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF6B4A1F), _primary],
                  ),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: Text(
                  initials,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            name,
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.verified,
                            color: Color(0xFF1B9E48), size: 18),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.pin_drop_outlined,
                            size: 15, color: _primary),
                        const SizedBox(width: 4),
                        Text(
                          '$listingCount listings available',
                          style: TextStyle(fontSize: 12, color: muted),
                        ),
                      ],
                    ),
                    if (rating != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          for (var i = 1; i <= 5; i++)
                            Icon(
                              i <= rating!.round()
                                  ? Icons.star_rate_rounded
                                  : Icons.star_outline_rounded,
                              color: Colors.amber,
                              size: 16,
                            ),
                          const SizedBox(width: 6),
                          Text(
                            rating!.toStringAsFixed(1),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: muted,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onWhatsApp,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF128C7E),
                    side: const BorderSide(color: Color(0xFF128C7E)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.chat_outlined, size: 18),
                  label: const Text('WhatsApp'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onCall,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _primary,
                    side: const BorderSide(color: _primary),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.phone_outlined, size: 18),
                  label: const Text('Call'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}