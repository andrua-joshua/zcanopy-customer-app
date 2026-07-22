import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:zcanopy/services/api_service.dart';
import 'package:zcanopy/utils/colors.dart';
import 'package:zcanopy/pages/itemDetails.dart';
import 'package:zcanopy/widgets/payment_sheet.dart';

class BrokerCollectionPage extends StatefulWidget {
  final String brokerCode;
  final String brokerName;
  final String brokerPhone;

  const BrokerCollectionPage({
    super.key,
    required this.brokerCode,
    required this.brokerName,
    this.brokerPhone = '',
  });

  @override
  State<BrokerCollectionPage> createState() => _BrokerCollectionPageState();
}

class _BrokerCollectionPageState extends State<BrokerCollectionPage> {
  final _api = ApiService();
  List<Map<String, dynamic>> _properties = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
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
        if (mounted)
          setState(() {
            _properties = list;
            _loading = false;
          });
        return;
      }
    } catch (e) {
      debugPrint('Broker properties fetch failed, using local: $e');
    }
    // Fallback to locally-known properties for this broker.
    final local = _localProperties()
      ..removeWhere((p) => p['brokerCode'] != widget.brokerCode);
    if (mounted)
      setState(() {
        _properties = local;
        _loading = false;
      });
  }

  void _applyBrokerMeta(List<Map<String, dynamic>> list) {
    for (final p in list) {
      p['brokerCode'] ??= widget.brokerCode;
      p['brokerName'] ??= widget.brokerName;
      p['brokerPhone'] ??= widget.brokerPhone;
    }
  }

  // Local mirror used as fallback when the backend is unavailable.
  List<Map<String, dynamic>> _localProperties() {
    return [
      {
        'id': 'p1',
        'type': 'House',
        'name': 'Bungalow in Ntinda',
        'price': 250000000,
        'location': 'Ntinda',
        'status': 'Available',
        'images': [
          'https://picsum.photos/400/250?101',
          'https://picsum.photos/400/250?102',
          'https://picsum.photos/400/250?103',
        ],
        'brokerCode': 'BRK-MUTAASA',
        'brokerName': 'Mutaasa Brokers',
        'brokerPhone': '+256701234567',
      },
      {
        'id': 'p2',
        'type': 'Apartment',
        'name': 'Modern Apartment in Kisaasi',
        'price': 750000,
        'location': 'Kisaasi',
        'status': 'Booked',
        'images': [
          'https://picsum.photos/400/250?201',
          'https://picsum.photos/400/250?202',
        ],
        'video':
            'https://flutter.github.io/assets-for-api-docs/assets/videos/bee.mp4',
        'brokerCode': 'BRK-KISAA',
        'brokerName': 'Kisaasi Realty',
        'brokerPhone': '+256702345678',
      },
      {
        'id': 'p3',
        'type': 'Condominium',
        'name': 'Condo in Naalya',
        'price': 150000000,
        'location': 'Naalya',
        'status': 'Available',
        'images': [
          'https://picsum.photos/400/250?301',
          'https://picsum.photos/400/250?302',
          'https://picsum.photos/400/250?303',
          'https://picsum.photos/400/250?304',
        ],
        'brokerCode': 'BRK-MUTAASA',
        'brokerName': 'Mutaasa Brokers',
        'brokerPhone': '+256701234567',
      },
      {
        'id': 'p4',
        'type': 'House',
        'name': 'Rental House in Bweyogerere',
        'price': 400000,
        'location': 'Bweyogerere',
        'status': 'Available',
        'images': [
          'https://picsum.photos/400/250?401',
          'https://picsum.photos/400/250?402',
        ],
        'brokerCode': 'BRK-WAKISO',
        'brokerName': 'Wakiso Homes',
        'brokerPhone': '+256703456789',
      },
    ];
  }

  Future<void> _book(Map<String, dynamic> property) async {
    print('Code:' + widget.brokerCode+'\n');
    print('Name:' + widget.brokerName+'\n');
    print('Phone:' + widget.brokerPhone+'\n');

    await PaymentSheet.show(
      context,
      property: property,
      onSubmit: ({required phone, required email, required amount}) async {
        await Future.delayed(const Duration(seconds: 1));
        if (mounted) {
          Navigator.of(context).pop();
          await Future.delayed(const Duration(milliseconds: 300));
          if (mounted) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => PropertyDetailsPage(
                  itemID: property['id'],
                  brokerCode: widget.brokerCode,
                  brokerName: widget.brokerName,
                  brokerPhone: widget.brokerPhone,
                  revealContact: true,
                ),
              ),
            );
          }
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(widget.brokerName),
        backgroundColor: AppColors.brown,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: _properties.isEmpty
                  ? const Center(
                      child: Text('No properties from this broker yet.'),
                    )
                  : CustomScrollView(
                      slivers: [
                        SliverToBoxAdapter(
                          child: Container(
                            width: double.infinity,
                            margin: const EdgeInsets.all(16),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppColors.brown.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: AppColors.brown.withOpacity(0.25),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.brokerName,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${_properties.length} listings available',
                                  style: const TextStyle(
                                    color: Colors.grey,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                          sliver: SliverGrid(
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 1,
                                  mainAxisSpacing: 14,
                                  crossAxisSpacing: 0,
                                  childAspectRatio: 0.68,
                                ),
                            delegate: SliverChildBuilderDelegate((
                              context,
                              index,
                            ) {
                              final property = _properties[index];
                              return _CollectionTile(
                                property: property,
                                isDark: isDark,
                                onBook: () => _book(property),
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

class _CollectionTile extends StatefulWidget {
  final Map<String, dynamic> property;
  final bool isDark;
  final VoidCallback onBook;

  const _CollectionTile({
    required this.property,
    required this.isDark,
    required this.onBook,
  });

  @override
  State<_CollectionTile> createState() => _CollectionTileState();
}

class _CollectionTileState extends State<_CollectionTile> {
  int _currentImageIndex = 0;
  VideoPlayerController? _videoController;
  bool _isPlayingVideo = false;

  @override
  void initState() {
    super.initState();
    final video = widget.property['video'];
    if (video != null && video.toString().isNotEmpty) {
      _videoController = VideoPlayerController.networkUrl(Uri.parse(video.toString()));
      _videoController!.initialize().then((_) {
        if (mounted) setState(() {});
      });
      _videoController!.setLooping(true);
    }
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final status = widget.property['status']?.toString() ?? 'Available';
    final available = status.toLowerCase() == 'available';
    final price = widget.property['price'] is num
        ? (widget.property['price'] as num).toDouble()
        : 0.0;
    final imgList = widget.property['images'] as List?;
    final imageCount = imgList != null && imgList.isNotEmpty
        ? imgList.length
        : 1;
    final hasVideo =
        widget.property['video'] != null &&
        widget.property['video'].toString().isNotEmpty;

    return InkWell(
      onTap: widget.onBook,
      child: Container(
        decoration: BoxDecoration(
          color: widget.isDark ? const Color(0xFF2A2A2A) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 180,
              child: Stack(
                children: [
                  PageView.builder(
                    itemCount: imageCount,
                    onPageChanged: (index) {
                      setState(() => _currentImageIndex = index);
                    },
                    itemBuilder: (context, index) {
                      final imgUrl = (imgList != null && imgList.isNotEmpty)
                          ? imgList[index % imgList.length].toString()
                          : widget.property['image']?.toString() ?? '';
                      return Image.network(
                        imgUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: Colors.grey.shade300,
                          child: const Icon(
                            Icons.home,
                            size: 40,
                            color: Colors.grey,
                          ),
                        ),
                      );
                    },
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: available ? Colors.green : Colors.red,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        status,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ),
                  if (imageCount > 1)
                    Positioned(
                      bottom: 8,
                      left: 0,
                      right: 0,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                          imageCount,
                          (i) => AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            width: _currentImageIndex == i ? 8 : 6,
                            height: _currentImageIndex == i ? 8 : 6,
                            decoration: BoxDecoration(
                              color: _currentImageIndex == i
                                  ? Colors.white
                                  : Colors.white.withOpacity(0.5),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.property['name'] ?? '',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    widget.property['location'] ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.grey, fontSize: 11),
                  ),
                  Text(
                    'UGX ${_format(price)}',
                    style: TextStyle(
                      color: AppColors.brown,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                   if (hasVideo)
                     Column(
                       children: [
                         if (_videoController != null &&
                             _videoController!.value.isInitialized)
                           AspectRatio(
                             aspectRatio: _videoController!.value.aspectRatio,
                             child: VideoPlayer(_videoController!),
                           )
                         else
                           const SizedBox(
                             height: 150,
                             child: Center(
                               child: CircularProgressIndicator(
                                 color: AppColors.brown,
                               ),
                             ),
                           ),
                         IconButton(
                           onPressed: () {
                             setState(() {
                               if (_videoController!.value.isPlaying) {
                                 _videoController!.pause();
                                 _isPlayingVideo = false;
                               } else {
                                 _videoController!.play();
                                 _isPlayingVideo = true;
                               }
                             });
                           },
                           icon: Icon(
                             _videoController!.value.isPlaying
                                 ? Icons.pause_circle_filled
                                 : Icons.play_circle_filled,
                             size: 32,
                             color: AppColors.brown,
                           ),
                         ),
                       ],
                     )
                   else
                     Row(
                       children: [
                         Icon(
                           Icons.video_library_outlined,
                           size: 18,
                           color: Colors.grey.shade400,
                         ),
                         const SizedBox(width: 6),
                         Text(
                           'No video available',
                           style: TextStyle(
                             color: Colors.grey.shade500,
                             fontSize: 12,
                           ),
                         ),
                       ],
                     ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: widget.onBook,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.brown,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        minimumSize: const Size(0, 30),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('Book', style: TextStyle(fontSize: 12)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _format(double price) {
    final s = price.round().toString();
    return s.replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]},',
    );
  }
}
