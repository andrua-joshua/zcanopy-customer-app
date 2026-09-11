import 'dart:async';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:motion_tab_bar_v2/motion-tab-bar.dart';
import 'package:zcanopy/pages/welcome.dart';
import 'package:shimmer/shimmer.dart';
import 'package:zcanopy/pages/userProfile.dart';
import 'package:zcanopy/pages/explorer.dart';
import 'package:zcanopy/pages/itemDetails.dart';
import 'package:zcanopy/pages/loadIndicator.dart';
import 'package:zcanopy/services/api_service.dart';
import 'package:zcanopy/pages/notifications.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:zcanopy/utils/currency.dart';
import 'package:zcanopy/pages/session.dart';
import 'package:zcanopy/services/api_service.dart';
import 'package:zcanopy/widgets/tiktok_video_reel.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomePageState();
}

class _HomePageState extends State<HomeScreen> {
  final ScrollController _scrollController = ScrollController();
  final _apiService = ApiService();
  final database = Hive.box("myStore");

  static const Map<String, IconData> _categoryIcons = {
    'All': Icons.grid_view,
    'House': Icons.home,
    'Apartment': Icons.apartment,
    'Condominium': Icons.villa,
    'Office': Icons.work,
    'Shop': Icons.store,
    'Land': Icons.terrain,
    'Warehouse': Icons.warehouse,
    'Hotel': Icons.hotel,
  };

  List<Map<String, dynamic>> allProperties = [
    {
      'id': 'p1',
      'type': 'House',
      'name': 'Bungalow in Ntinda',
      'price': 250000000,
      'location': 'Ntinda',
      'subCounty': 'Ntinda',
      'district': 'Kampala Central',
      'status': 'Available',
      'image': 'https://picsum.photos/400/200?1',
      'uploadDate': '2024-05-12',
      'description':
          'Mutaasa brokers, 1 dining room, 2 toilets, spacious compound, secure gated community.',
      'mapLocation': {'lat': 0.3476, 'lng': 32.5825},
      'video': 'https://flutter.github.io/assets-for-api-docs/assets/videos/bee.mp4',
      'bookState': {'isBooked': false, 'bookingCount': 0},
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
      'subCounty': 'Kisaasi',
      'district': 'Kampala North',
      'status': 'Booked',
      'image': 'https://picsum.photos/400/200?2',
      'uploadDate': '2024-06-01',
      'description':
          'Mutaasa brokers, 2 bedrooms, 1 dining room, 2 toilets, balcony with city view.',
      'mapLocation': {'lat': 0.369, 'lng': 32.56},
      'video': 'https://flutter.github.io/assets-for-api-docs/assets/videos/butterfly.mp4',
      'bookState': {'isBooked': true, 'bookingCount': 3},
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
      'subCounty': 'Naalya',
      'district': 'Kampala North',
      'status': 'Available',
      'image': 'https://picsum.photos/400/200?3',
      'uploadDate': '2024-06-10',
      'description':
          'Mutaasa brokers, 3 bedrooms, 1 dining room, 3 toilets, swimming pool access.',
      'mapLocation': {'lat': 0.398, 'lng': 32.62},
      'video': 'https://flutter.github.io/assets-for-api-docs/assets/videos/bee.mp4',
      'bookState': {'isBooked': false, 'bookingCount': 1},
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
      'subCounty': 'Bweyogerere',
      'district': 'Wakiso',
      'status': 'Available',
      'image': 'https://picsum.photos/400/200?4',
      'uploadDate': '2024-07-02',
      'description':
          'Mutaasa brokers, 2 bedrooms, 1 dining room, 1 toilet, near main road.',
      'mapLocation': {'lat': 0.357, 'lng': 32.65},
      'video': '',
      'bookState': {'isBooked': false, 'bookingCount': 0},
      'brokerCode': 'BRK-WAKISO',
      'brokerName': 'Wakiso Homes',
      'brokerPhone': '+256703456789',
    },
  ];

  List<Map<String, dynamic>> displayedProperties = [];
  List<Map<String, dynamic>> reels = [];
  final Set<String> _savedProperties = {};

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

  final ScrollController _reelScrollController = ScrollController();
  final Map<int, VideoPlayerController> _reelControllers = {};
  int _activeReelIndex = -1;
  final Set<int> _initializedReels = {};

  String selectedType = 'All';
  double maxPrice = 200000;
  String selectedLocation = 'All';
  String selectedSubCounty = 'All';
  String selectedDistrict = 'All';

  bool isLoading = true;
  bool isLoadingMore = false;
  //bool isGridView = false;
  bool showReels = false;

  final int itemsPerPage = 2;

  @override
  void initState() {
    super.initState();
    loadInitialData();
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
              _scrollController.position.maxScrollExtent - 200 &&
          !isLoadingMore &&
          displayedProperties.length < allProperties.length) {
        loadMoreData();
      }
    });
  }

  Future<void> forceLogout(BuildContext context) async {
    await database.clear();
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const OnBoardingScreen()),
        (_) => false,
      );
    }
  }

  void _initReelControllers() {
    for (int i = 0; i < reels.length; i++) {
      if (!_initializedReels.contains(i)) {
        final url = reels[i]['videoUrl'] ?? '';
        if (url.isEmpty) continue;
        final controller = VideoPlayerController.networkUrl(Uri.parse(url));
        controller.setLooping(true);
        controller.setVolume(0);
        controller.initialize().then((_) {
          if (mounted) {
            _initializedReels.add(i);
            setState(() {});
          }
        }).catchError((e) {
          debugPrint('Reel $i init error: $e');
        });
        _reelControllers[i] = controller;
      }
    }
  }

  void _onReelScroll() {
    if (!mounted || reels.isEmpty) return;
    final controller = _reelScrollController;
    final maxScroll = controller.position.maxScrollExtent;
    if (maxScroll <= 0) return;
    final offset = controller.offset;
    final cardWidth = 150.0 + 12.0;
    final index = ((offset / cardWidth) + 0.5).floor().clamp(0, reels.length - 1);
    if (index != _activeReelIndex) {
      _pauseAllReels();
      final c = _reelControllers[index];
      if (c != null && c.value.isInitialized) {
        c.seekTo(const Duration(seconds: 0));
        c.play();
      }
      setState(() => _activeReelIndex = index);
    }
  }

  void _pauseAllReels() {
    for (final c in _reelControllers.values) {
      if (c.value.isInitialized) c.pause();
    }
  }

  void _disposeReelControllers() {
    for (final c in _reelControllers.values) {
      c.dispose();
    }
    _reelControllers.clear();
    _initializedReels.clear();
  }

  void _rebuildReels() {
    _disposeReelControllers();
    _activeReelIndex = -1;
    final list = <Map<String, dynamic>>[];
    for (final p in displayedProperties) {
      final video = p['video'];
      if (video != null && video.toString().isNotEmpty) {
        list.add({
          'id': p['id'],
          'brokerCode': p['brokerCode']?.toString() ?? '',
          'brokerName': p['brokerName']?.toString() ?? 'Broker',
          'brokerPhone': p['brokerPhone']?.toString() ?? '',
          'videoUrl': video,
          'title': p['name'],
          'location': p['location'],
          'subCounty': p['subCounty'],
          'district': p['district'],
        });
      }
    }
    reels = list;
    _initReelControllers();
  }

  Future<void> loadInitialData() async {
    final isSessionValid = await SessionService.validateSession();
    if (!isSessionValid) {
      if (mounted) await forceLogout(context);
      return;
    }

    try {
      final response = await _apiService.getCustomerProperties(
        sessionToken: _apiService.currentSessionId ?? '',
        latitude: null,
        longitude: null,
        page: 1,
        limit: 50,
      );

      if (response['success'] == true && response['properties'] is List) {
        final fetched = (response['properties'] as List)
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        if (mounted) {
          setState(() {
            allProperties = fetched;
            displayedProperties = fetched;
            _rebuildReels();
            isLoading = false;
          });
        }
        return;
      }
    } catch (e) {
      print('Load properties error: $e');
    }

    if (!mounted) return;
    await Future.delayed(const Duration(seconds: 1));
    setState(() {
      displayedProperties = List.from(allProperties);
      _rebuildReels();
      isLoading = false;
    });
  }

  Future<void> loadMoreData() async {
    setState(() => isLoadingMore = true);
    await Future.delayed(const Duration(seconds: 1));
    if (mounted) {
      setState(() => isLoadingMore = false);
    }
  }

  List<String> get _subCounties => [
        'All',
        ...{for (final p in allProperties) p['subCounty'] as String? ?? ''}
            .where((e) => e.isNotEmpty)
            .toList()
      ];

  List<String> get _districts => [
        'All',
        ...{for (final p in allProperties) p['district'] as String? ?? ''}
            .where((e) => e.isNotEmpty)
            .toList()
      ];

  void applyFilters() {
    final minPrice = double.tryParse(_minPriceCtrl.text);
    final maxPriceVal = double.tryParse(_maxPriceCtrl.text);

    setState(() {
      displayedProperties = allProperties.where((prop) {
        final matchesType =
            selectedType == 'All' || prop['type'] == selectedType;
        final matchesLocation =
            selectedLocation == 'All' || prop['location'] == selectedLocation;
        final matchesSub = selectedSubCounty == 'All' ||
            (prop['subCounty'] ?? '') == selectedSubCounty;
        final matchesDistrict = selectedDistrict == 'All' ||
            (prop['district'] ?? '') == selectedDistrict;
        final matchesPrice = (minPrice == null || prop['price'] >= minPrice) &&
            (maxPriceVal == null || prop['price'] <= maxPriceVal);
        return matchesType &&
            matchesLocation &&
            matchesSub &&
            matchesDistrict &&
            matchesPrice;
      }).toList();
      _rebuildReels();
    });
  }

  final TextEditingController _minPriceCtrl = TextEditingController();
  final TextEditingController _maxPriceCtrl = TextEditingController();

  void openFilterSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(5)),
      ),
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        "Filter Properties",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 20),
                      _filterDropdown(
                        "District",
                        selectedDistrict,
                        _districts,
                        (val) =>
                            setModalState(() => selectedDistrict = val!),
                      ),
                      const SizedBox(height: 16),
                      _filterDropdown(
                        "Sub-County",
                        selectedSubCounty,
                        _subCounties,
                        (val) =>
                            setModalState(() => selectedSubCounty = val!),
                      ),
                      const SizedBox(height: 16),
                      _filterDropdown(
                        "Location",
                        selectedLocation,
                        ['All', 'Ntinda', 'Kisaasi', 'Naalya', 'Bweyogerere'],
                        (val) => setModalState(() => selectedLocation = val!),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _minPriceCtrl,
                              keyboardType: TextInputType.number,
                              decoration: _priceDecoration('Min Price'),
                              onChanged: (_) => applyFilters(),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _maxPriceCtrl,
                              keyboardType: TextInputType.number,
                              decoration: _priceDecoration('Max Price'),
                              onChanged: (_) => applyFilters(),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context);
                            applyFilters();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                const Color.fromARGB(255, 169, 97, 14),
                          ),
                          child: const Text(
                            "Apply Filters",
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  InputDecoration _priceDecoration(String label) {
    return InputDecoration(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
      labelText: label,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(30)),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(30),
        borderSide: const BorderSide(color: Colors.brown),
      ),
      floatingLabelStyle:
          const TextStyle(color: Color.fromARGB(255, 169, 97, 14)),
    );
  }

  Widget _filterDropdown(
    String label,
    String value,
    List<String> items,
    Function(String?) onChanged,
  ) {
    return DropdownButtonFormField<String>(
      value: value,
      items: items
          .map((e) => DropdownMenuItem(value: e, child: Text(e)))
          .toList(),
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(
          borderRadius: const BorderRadius.all(Radius.circular(10)),
          borderSide: const BorderSide(
            color: Color.fromARGB(255, 169, 97, 14),
          ),
        ),
        floatingLabelStyle:
            const TextStyle(color: Color.fromARGB(255, 169, 97, 14)),
        focusedBorder: OutlineInputBorder(
          borderRadius: const BorderRadius.all(Radius.circular(10)),
          borderSide: const BorderSide(
            color: Color.fromARGB(255, 169, 97, 14),
            width: 1.5,
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _reelScrollController.dispose();
    _disposeReelControllers();
    super.dispose();
  }

  Future<void> _onRefresh() async {
    await loadInitialData();
  }

  Widget buildShimmerCard() {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300,
      highlightColor: Colors.grey.shade100,
      child: Card(
        margin: const EdgeInsets.only(bottom: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        child: Container(height: 220, color: Colors.white),
      ),
    );
  }

  Widget _buildReelSection() {
    if (reels.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              "Video Tours",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            TextButton(
              onPressed: () => _openReelFullscreen(),
              child: const Text("View all"),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 260,
          child: NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              _onReelScroll();
              return false;
            },
            child: ListView.separated(
              controller: _reelScrollController,
              scrollDirection: Axis.horizontal,
              itemCount: reels.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final reel = reels[index];
                final controller = _reelControllers[index];
                final isActive = index == _activeReelIndex;
                final isInit = controller?.value.isInitialized ?? false;
                return GestureDetector(
                  onTap: () => _openReelFullscreen(initial: index),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: SizedBox(
                      width: 150,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Container(color: Colors.black12),
                          if (isInit)
                            Center(
                              child: AspectRatio(
                                aspectRatio: controller!.value.aspectRatio,
                                child: VideoPlayer(controller),
                              ),
                            ),
                          if (!isActive)
                            Container(
                              color: Colors.black.withValues(alpha: 0.35),
                              child: const Center(
                                child: Icon(
                                  Icons.play_circle_fill,
                                  color: Colors.white,
                                  size: 38,
                                ),
                              ),
                            ),
                          Container(
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [Colors.transparent, Colors.black54],
                              ),
                            ),
                          ),
                          Positioned(
                            left: 10,
                            right: 10,
                            bottom: 10,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  reel['title'] ?? '',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                                Text(
                                  reel['subCounty'] ?? '',
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  void _openReelFullscreen({int initial = 0}) {
    if (reels.isEmpty) return;
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
              child: TikTokVideoReel(videos: reels),
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

  Widget _buildPropertyCard(Map<String, dynamic> property,
      {EdgeInsetsGeometry? margin}) {
    final bookState =
        property['bookState'] as Map<String, dynamic>? ?? {};
    final isBooked = bookState['isBooked'] == true;
    final hasVideo =
        property['video'] != null && property['video'].toString().isNotEmpty;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark
        ? const Color(0xFF2A2A2A)
        : Colors.white;

    void openDetails() => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PropertyDetailsPage(property: property),
          ),
        );

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
                child: Image.network(
                  property['image'],
                  height: 200,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    height: 200,
                    color: Colors.grey.shade200,
                    child: const Center(
                      child: Icon(Icons.home_outlined, size: 40, color: Colors.grey),
                    ),
                  ),
                ),
              ),
              Container(
                height: 200,
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
                    color: property['status'] == 'Available'
                        ? Colors.green
                        : Colors.red,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    property['status'],
                    style: const TextStyle(
                        color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              Positioned(
                top: 10,
                left: 10,
                  child: GestureDetector(
                    onTap: () => _toggleSaveProperty(property['id']),
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
                        _isSaved(property['id'])
                            ? Icons.bookmark
                            : Icons.bookmark_border,
                        color: _isSaved(property['id'])
                            ? const Color.fromARGB(255, 169, 97, 14)
                            : Colors.grey.shade600,
                        size: 20,
                      ),
                    ),
                  ),
              ),
              if (hasVideo)
                Positioned(
                  bottom: 10,
                  right: 10,
                  child: GestureDetector(
                    onTap: () => _openReelFullscreen(
                      initial: reels.indexWhere(
                          (r) => r['videoUrl'] == property['video']),
                    ),
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
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        property['name'],
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isBooked)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          "Booked",
                          style: TextStyle(
                            color: Colors.red.shade700,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  formatUgx(property['price']),
                  style: const TextStyle(
                    color: Color.fromARGB(255, 169, 97, 14),
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
                        "${property['subCounty']}, ${property['district']}",
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color.fromARGB(255, 169, 97, 14).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        property['brokerName']?.toString() ?? 'Broker',
                        style: const TextStyle(
                          color: Color.fromARGB(255, 169, 97, 14),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const Spacer(),
                    OutlinedButton.icon(
                      onPressed: openDetails,
                      icon: const Icon(Icons.visibility_outlined, size: 16),
                      label: const Text("View", style: TextStyle(fontSize: 12)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color.fromARGB(255, 169, 97, 14),
                        side: const BorderSide(
                          color: Color.fromARGB(255, 169, 97, 14),
                        ),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 6),
                        visualDensity: VisualDensity.compact,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: isDark
          ? Theme.of(context).scaffoldBackgroundColor
          : Colors.grey.shade100,
      body: Container(
        decoration: isDark
            ? BoxDecoration(color: Theme.of(context).scaffoldBackgroundColor)
            : const BoxDecoration(
                image: DecorationImage(
                  image: AssetImage('assets/background.jpg'),
                  fit: BoxFit.cover,
                ),
              ),
        child: RefreshIndicator(
          onRefresh: _onRefresh,
          color: const Color.fromARGB(255, 169, 97, 14),
          child: CustomScrollView(
            controller: _scrollController,
            slivers: [
            SliverAppBar(
              pinned: true,
              centerTitle: false,
              automaticallyImplyLeading: false,
              backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              toolbarHeight: 56,
              titleSpacing: 0,
              title: Padding(
                padding: const EdgeInsets.only(left: 12, right: 8),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.25),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(5),
                      child: ClipOval(
                        child: Image.asset(
                          'assets/midLOGO.png',
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      "ZCanopy",
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Container(
                    width: 42,
                    height: 42,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isDark
                        ? const Color(0xFF2A2A2A)
                        : Colors.grey.shade100,
                    border: Border.all(
                      color: Colors.grey.shade300,
                      width: 1,
                    ),
                    boxShadow: [
                        BoxShadow(
                          color:
                              Colors.black.withValues(alpha: 0.1),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.notifications_outlined),
                      tooltip: 'Notifications',
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => NotificationsPage(),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
            SliverPersistentHeader(
              pinned: true,
              delegate: _SearchHeaderDelegate(
                height: 106,
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.fromLTRB(12, 18, 12, 10),
                  child: SizedBox(
                    height: 74,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        'All',
                        'House',
                        'Apartment',
                        'Condominium',
                        'Office',
                        'Shop',
                        'Land',
                        'Warehouse',
                        'Hotel'
                      ].map((type) {
                        final isSelected = selectedType == type;
                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              selectedType = type;
                              applyFilters();
                            });
                          },
                          child: Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 6),
                            child: Column(
                              children: [
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: isSelected
                                        ? const Color.fromARGB(
                                            255, 169, 97, 14)
                                        : Colors.white,
                                    border: Border.all(
                                      color: isSelected
                                          ? const Color.fromARGB(
                                              255, 169, 97, 14)
                                          : Colors.grey.shade400,
                                      width: 1.5,
                                    ),
                                  ),
                                  child: Icon(
                                    _categoryIcons[type] ?? Icons.home,
                                    color: isSelected
                                        ? Colors.white
                                        : const Color.fromARGB(
                                            255, 169, 97, 14),
                                    size: 22,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  type,
                                  style: TextStyle(
                                    color: isSelected
                                        ? const Color.fromARGB(
                                            255, 169, 97, 14)
                                        : Colors.grey.shade700,
                                    fontWeight: isSelected
                                        ? FontWeight.w600
                                        : FontWeight.w400,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              sliver: isLoading
                  ? SliverList(
                      delegate: SliverChildListDelegate(
                        List.generate(3, (_) => buildShimmerCard()),
                      ),
                    )
                  : SliverList(
                      delegate: SliverChildListDelegate([
                        _buildReelSection(),
                        if (reels.isNotEmpty)
                          const SizedBox(height: 24),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                "Nearby Properties",
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              TextButton(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => ExplorePage(),
                                    ),
                                  );
                                },
                                child: const Text(
                                  "View all",
                                  style: TextStyle(fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
                          ),
                        ),
                        ...displayedProperties.map((property) {
                          return _buildPropertyCard(property);
                        }),
                        if (isLoadingMore)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 20),
                            child: Center(
                              child: ZLoadingIndicator(
                                size: 22,
                                strokeWidth: 2,
                                color: Color.fromARGB(255, 169, 97, 14),
                              ),
                            ),
                          ),
                      ]),
                    ),
            ),
           ],
         ),
       ),
     ),
    );
   }
 }

class _SearchHeaderDelegate extends SliverPersistentHeaderDelegate {
  const _SearchHeaderDelegate({required this.child, required this.height});
  final Widget child;
  final double height;

  @override
  double get minExtent => height;
  @override
  double get maxExtent => height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) =>
      SizedBox(height: maxExtent, child: child);

  @override
  bool shouldRebuild(covariant _SearchHeaderDelegate old) =>
      old.child != child || old.height != height;
}

class BottomNavBar extends StatefulWidget {
  const BottomNavBar({Key? key}) : super(key: key);

  @override
  State<BottomNavBar> createState() => _BottomNavBar();
}

class _BottomNavBar extends State<BottomNavBar> {
  int _selectedIndex = 0;

  final List<Widget> _pages = [
    const HomeScreen(),
    ExplorePage(),
    const ProfilePage(),
  ];

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  void _onTapped(int index) {
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const activeColor = Color.fromARGB(255, 169, 97, 14);
    final inactiveColor = isDark ? Colors.grey.shade300 : Colors.grey.shade700;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF5F5F5),
      body: IndexedStack(
        index: _selectedIndex,
        children: _pages,
      ),
      bottomNavigationBar: MotionTabBar(
        initialSelectedTab: 'Home',
        labels: const ['Home', 'Explore', 'Profile'],
        icons: const [Icons.home, Icons.search, Icons.person],
        onTabItemSelected: _onTapped,
        tabBarColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        tabSelectedColor: activeColor,
        tabIconSelectedColor: Colors.white,
        tabIconColor: inactiveColor,
        tabIconSize: 24,
        tabIconSelectedSize: 32,
        tabSize: 58,
        tabBarHeight: 60,
        textStyle: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: activeColor,
        ),
        useSafeArea: true,
        labelAlwaysVisible: false,
      ),
    );
  }
}
