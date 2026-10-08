import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:video_player/video_player.dart';
import 'package:zcanopy/pages/welcome.dart';
import 'package:zcanopy/pages/filter_wizard.dart';
import 'package:zcanopy/pages/itemDetails.dart';
import 'package:zcanopy/pages/session.dart';
import 'package:zcanopy/services/gateway_api.dart';
import 'package:zcanopy/pages/notifications.dart';
import 'package:zcanopy/utils/currency.dart';
import 'package:zcanopy/widgets/tiktok_video_reel.dart';

class ExplorePage extends StatefulWidget {
  @override
  _ExplorePageState createState() => _ExplorePageState();
}

class _ExplorePageState extends State<ExplorePage> {
  String selectedCategory = "All";
  final List<String> categories = [
    "All",
    "House",
    "Apartment",
    "Condominium",
    "Townhouse",
    "Villa",
    "Single Room",
    "Double Room",
    "Flat",
    "Bungalow",
    "Mansion",
    "Duplex",
    "Triplex",
    "Studio",
    "Loft",
    "Penthouse",
    "Cottage",
    "Cabin",
    "Farmhouse",
    "Ranch",
    "Mobile Home",
    "Tiny House",
    "Office",
    "Retail Space",
    "Warehouse",
    "Industrial Property",
    "Land",
    "Parking Space",
    "Storage Unit"
  ];

  final ScrollController _scrollController = ScrollController();
  final _api = GatewayApi();
  List<Map<String, dynamic>> _items = [];
  bool _isLoading = false;
  bool _hasMore = true;
  int _page = 1;
  final int _limit = 10;

  bool isLoading = true;
  bool isLoadingMore = false;
  final int itemsPerPage = 2;

  String selectedType = 'All';
  double maxPrice = 200000;
  String searchQuery = '';
  String selectedLocation = 'All';
  String _sortOrder = 'date';
  final TextEditingController minPriceCtrl = TextEditingController();
  final TextEditingController maxPriceCtrl = TextEditingController();
  List<Map<String, dynamic>> _displayedItems = [];

  final Map<int, VideoPlayerController> _reelControllers = {};
  final Set<int> _initializedReels = {};
  int _activeReelIndex = -1;
  final ScrollController _reelScrollController = ScrollController();
  final Set<String> _savedProperties = {};

  Map<String, List<Map<String, dynamic>>> regions = {};
  var displayedRegions = {};

  List<String> regionsX = ["Region A", "Region B"];

  Future<void> forceLogout(BuildContext context) async {
    final database = Hive.box('myStore');
    await database.clear();
    if (!context.mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const OnBoardingScreen()),
      (_) => false,
    );
  }

  Future<void> _fetchItems({bool refresh = false}) async {
    if (_isLoading) return;
    if (refresh) {
      _page = 1;
      _hasMore = true;
    }
    if (!_hasMore && !refresh) return;
    setState(() => _isLoading = true);

    final minPrice = double.tryParse(minPriceCtrl.text);
    final maxPrice = double.tryParse(maxPriceCtrl.text);

    try {
      final response = await _api.searchProperties(
        query: searchQuery.isEmpty ? null : searchQuery,
        location: selectedLocation == 'All' ? null : selectedLocation,
        propertyType: selectedCategory == 'All' ? null : selectedCategory,
        minPrice: minPrice,
        maxPrice: maxPrice,
        page: _page,
        limit: _limit,
      );

      final next = (response['properties'] as List? ?? [])
          .whereType<Map<String, dynamic>>()
          .toList();

      if (!mounted) return;
      setState(() {
        if (refresh) {
          _items = List.from(next);
        } else {
          _items.addAll(next);
        }
        if (next.length < _limit) {
          _hasMore = false;
        } else {
          _page++;
        }
        _rebuildFromItems();
        isLoading = false;
      });

      if (refresh && searchQuery.isNotEmpty) {
        _api
            .recordSearch(
              query: searchQuery,
              location: selectedLocation == 'All' ? null : selectedLocation,
              propertyType:
                  selectedCategory == 'All' ? null : selectedCategory,
              minPrice: minPrice,
              maxPrice: maxPrice,
              resultCount: next.length,
            )
            .catchError((_) => <String, dynamic>{});
      }
    } catch (e) {
      debugPrint('Explorer fetch error: $e');
      if (mounted) {
        setState(() {
          if (refresh) {
            _items = [];
            _rebuildFromItems();
          }
          isLoading = false;
        });
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _rebuildFromItems() {
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final item in _items) {
      final district = (item['district'] ?? '').toString();
      final loc = (item['location'] ?? '').toString();
      final key = district.isNotEmpty
          ? district
          : (loc.isNotEmpty ? loc : 'Other');
      grouped.putIfAbsent(key, () => []).add(item);
    }
    regions = grouped;
    displayedRegions = Map.from(grouped);
    regionsX = regions.keys.toList();
    _displayedItems = List.from(_items);
  }

  @override
  void initState() {
    super.initState();
    loadInitialData();
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
              _scrollController.position.maxScrollExtent - 200 &&
          !_isLoading &&
          _hasMore) {
        _fetchItems();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _reelScrollController.dispose();
    for (final c in _reelControllers.values) c.dispose();
    _reelControllers.clear();
    super.dispose();
  }

  Future<void> _onRefresh() async {
    await loadInitialData();
  }

  Future<void> loadInitialData() async {
    final isSessionValid = await SessionService.validateSession();
    if (!isSessionValid) {
      if (mounted) await forceLogout(context);
      return;
    }
    await _fetchItems(refresh: true);
  }

  void applyFilters() {
    double? maxPrice = double.tryParse(maxPriceCtrl.text);
    double? minPrice = double.tryParse(minPriceCtrl.text);
    
    final all = <Map<String, dynamic>>[];
    regions.forEach((_, items) {
      all.addAll(items.map((e) => Map<String, dynamic>.from(e)));
    });

    final filtered = all.where((prop) {
      final matchesType = selectedCategory == 'All' || prop['type'] == selectedCategory;
      final matchesSearch = (prop['name'] as String)
          .toLowerCase()
          .contains(searchQuery.toLowerCase());
      final matchesLocation = selectedLocation == 'All' ||
          prop['location'] == selectedLocation;
      final matchesPrice = (minPrice == null || prop['price'] >= minPrice) &&
          (maxPrice == null || prop['price'] <= maxPrice);
      return matchesType && matchesSearch && matchesLocation && matchesPrice;
    }).toList();

    // Apply sorting
    if (_sortOrder == 'price_asc') {
      filtered.sort((a, b) => (a['price'] as num).compareTo(b['price'] as num));
    } else if (_sortOrder == 'price_desc') {
      filtered.sort((a, b) => (b['price'] as num).compareTo(a['price'] as num));
    }
    // 'date' is default, keeping original order

    setState(() {
      _displayedItems = filtered;
    });

    _filterDebounce?.cancel();
    _filterDebounce =
        Timer(const Duration(milliseconds: 600), () => _fetchItems(refresh: true));
  }

  Timer? _filterDebounce;

  void openFilterSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (_) {
        return StatefulBuilder(builder: (context, setModalState) {
          return Padding(
              padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text("Sort & Filter",
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: _sortOrder,
                      items: const [
                        DropdownMenuItem(value: 'date', child: Text('Date Added')),
                        DropdownMenuItem(value: 'price_asc', child: Text('Price: Low to High')),
                        DropdownMenuItem(value: 'price_desc', child: Text('Price: High to Low')),
                      ],
                      onChanged: (val) {
                        setModalState(() => _sortOrder = val!);
                      },
                      decoration: const InputDecoration(
                          labelText: "Sort By",
                          border: OutlineInputBorder(),
                          labelStyle: TextStyle(color: Colors.grey),
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: selectedLocation,
                      items: ['All', 'Ntinda', 'Kisaasi', 'Naalya', 'Bweyogerere']
                          .map((e) => DropdownMenuItem(
                              value: e, child: Text(e.toString())))
                          .toList(),
                      onChanged: (val) {
                        setModalState(() => selectedLocation = val!);
                      },
                      decoration: const InputDecoration(
                          labelText: "Location / District",
                          border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                            child: TextFormField(
                          controller: minPriceCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            labelText: 'Min Price',
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (_) => applyFilters(),
                        )),
                        const SizedBox(width: 12),
                        Expanded(
                            child: TextFormField(
                          controller: maxPriceCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            labelText: 'Max Price',
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (_) => applyFilters(),
                        ))
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
                            backgroundColor: const Color.fromARGB(255, 169, 97, 14),
                            padding: const EdgeInsets.symmetric(vertical: 14)),
                        child: const Text("Apply",
                            style: TextStyle(color: Colors.white, fontSize: 16)),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ));
        });
      },
    );
  }

  void _openDetails(Map<String, dynamic> property) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PropertyDetailsPage(property: property),
      ),
    );
  }

  List<Map<String, dynamic>> get _videoTours => _displayedItems
      .where((p) => p['video'] != null && p['video'].toString().isNotEmpty)
      .map((p) => {
            'videoUrl': p['video'],
            'title': p['name']?.toString() ?? 'Property tour',
            'location': p['location']?.toString() ?? '',
            'subCounty': p['subCounty']?.toString() ?? '',
            'district': p['district']?.toString() ?? '',
            'brokerCode': p['brokerCode']?.toString() ?? '',
            'brokerName': p['brokerName']?.toString() ?? 'Broker',
            'brokerPhone': p['brokerPhone']?.toString() ?? '',
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final headerBg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final iconColor = isDark ? Colors.white : Colors.black87;

    return Scaffold(
      backgroundColor: isDark
          ? Theme.of(context).scaffoldBackgroundColor
          : Colors.grey.shade100,
      floatingActionButton: _videoTours.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: _openVideoTours,
              heroTag: 'explore_video_tours',
              backgroundColor: const Color.fromARGB(255, 169, 97, 14),
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
            slivers: [
            SliverAppBar(
              pinned: true,
              centerTitle: false,
              automaticallyImplyLeading: false,
              backgroundColor: headerBg,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              toolbarHeight: 56,
              titleSpacing: 0,
              title: Padding(
                padding: const EdgeInsets.only(left: 12, right: 8),
                child: Text(
                  "Explore",
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    color: iconColor,
                  ),
                ),
              ),
              actions: [
                _buildCircleAction(
                  icon: Icons.search,
                  onPressed: () => showDialog(
                    context: context,
                    builder: (ctx) => FilterWizard(
                      onComplete: (filters) {
                        setState(() {
                          selectedCategory = filters['type'] ?? 'All';
                          selectedLocation = filters['location'] ?? 'All';
                          minPriceCtrl.text = filters['minPrice'] ?? '';
                          maxPriceCtrl.text = filters['maxPrice'] ?? '';
                        });
                        applyFilters();
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                _buildCircleAction(
                  icon: Icons.filter_list,
                  onPressed: openFilterSheet,
                ),
                const SizedBox(width: 6),
                _buildCircleAction(
                  icon: Icons.notifications_outlined,
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => NotificationsPage()),
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
                    color: headerBg,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                  child: SizedBox(
                    height: 88,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: categories.take(9).map((type) {
                        final isSelected = selectedCategory == type;
                        return GestureDetector(
                          onTap: () =>
                              setState(() => selectedCategory = type),
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
                                        ? const Color.fromARGB(255, 169, 97, 14)
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
                                    _categoryIcon(type),
                                    color: isSelected
                                        ? Colors.white
                                        : const Color.fromARGB(255, 169, 97, 14),
                                    size: 22,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  type,
                                  style: TextStyle(
                                    color: isSelected
                                        ? const Color.fromARGB(255, 169, 97, 14)
                                        : Colors.grey.shade700,
                                    fontWeight: isSelected
                                        ? FontWeight.w600
                                        : FontWeight.w400,
                                    fontSize: 11,
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
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    if (index >= _displayedItems.length) return null;
                    final property = _displayedItems[index];
                    final isSaved = _savedProperties.contains(property['id']);
                    final status = property['status']?.toString() ?? 'Available';
                    final available = status.toLowerCase() == 'available';
                    return GestureDetector(
                      onTap: () => _openDetails(property),
                      child: Card(
                        color: isDark ? const Color(0xFF2A2A2A) : Colors.white,
                        margin: const EdgeInsets.only(bottom: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                        clipBehavior: Clip.antiAlias,
                        elevation: isDark ? 0 : 2,
                        shadowColor: Colors.black.withValues(alpha: 0.08),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Stack(
                              children: [
                                Image.network(
                                  property['image'],
                                  height: 200,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(
                                    height: 200,
                                    color: Colors.grey.shade200,
                                    child: const Center(
                                      child: Icon(Icons.home_outlined,
                                          size: 40, color: Colors.grey),
                                    ),
                                  ),
                                ),
                                Container(
                                  height: 200,
                                  decoration: const BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Colors.transparent,
                                        Colors.black26
                                      ],
                                    ),
                                  ),
                                ),
                                Positioned(
                                  top: 10,
                                  right: 10,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: available
                                          ? Colors.green
                                          : Colors.red,
                                      borderRadius:
                                          BorderRadius.circular(12),
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
                                Positioned(
                                  top: 10,
                                  left: 10,
                                  child: GestureDetector(
                                    onTap: () => setState(() {
                                      if (isSaved) {
                                        _savedProperties
                                            .remove(property['id']);
                                      } else {
                                        _savedProperties
                                            .add(property['id']);
                                      }
                                    }),
                                    child: Container(
                                      width: 36,
                                      height: 36,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Colors.white
                                            .withValues(alpha: 0.9),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black
                                                .withValues(alpha: 0.15),
                                            blurRadius: 6,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: Icon(
                                        isSaved
                                            ? Icons.bookmark
                                            : Icons.bookmark_border,
                                        color: isSaved
                                            ? const Color.fromARGB(
                                                255, 169, 97, 14)
                                            : Colors.grey.shade600,
                                        size: 20,
                                      ),
                                    ),
                                  ),
                                ),
                                if ((property['video'] != null &&
                                        property['video']
                                            .toString()
                                            .isNotEmpty))
                                  Positioned(
                                    bottom: 10,
                                    right: 10,
                                    child: Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: Colors.black
                                            .withValues(alpha: 0.6),
                                        borderRadius:
                                            BorderRadius.circular(20),
                                      ),
                                      child: const Icon(
                                          Icons.play_circle_fill,
                                          color: Colors.white,
                                          size: 24),
                                    ),
                                  ),
                              ],
                            ),
                            Padding(
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
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
                                    color: Color.fromARGB(
                                        255, 169, 97, 14),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      const Icon(
                                          Icons.location_on_outlined,
                                          size: 14,
                                          color: Colors.grey),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          "${property['subCounty']}, ${property['district']}",
                                          style: TextStyle(
                                              color:
                                                  Colors.grey.shade600,
                                              fontSize: 12),
                                          maxLines: 1,
                                          overflow:
                                              TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets
                                            .symmetric(
                                            horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: const Color.fromARGB(
                                                  255, 169, 97, 14)
                                              .withValues(alpha: 0.1),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          property['brokerName']
                                                  ?.toString() ??
                                              'Broker',
                                          style: const TextStyle(
                                            color: Color.fromARGB(
                                                255, 169, 97, 14),
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                      const Spacer(),
                                      OutlinedButton.icon(
                                        onPressed: () =>
                                            _openDetails(property),
                                        icon: const Icon(
                                            Icons.visibility_outlined,
                                            size: 16),
                                        label: const Text("View",
                                            style:
                                                TextStyle(fontSize: 12)),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor:
                                              const Color.fromARGB(
                                                  255, 169, 97, 14),
                                          side: const BorderSide(
                                              color: Color.fromARGB(
                                                  255, 169, 97, 14)),
                                          padding:
                                              const EdgeInsets.symmetric(
                                                  horizontal: 14,
                                                  vertical: 6),
                                          visualDensity:
                                              VisualDensity.compact,
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(
                                                    20),
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
                      ),
                    );
                  },
                  childCount: _displayedItems.length,
                ),
              ),
            ),
           ],
         ),
       ),
     ),
    );
  }

  Widget _buildCircleAction({required IconData icon, required VoidCallback onPressed}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isDark ? const Color(0xFF2A2A2A) : Colors.grey.shade100,
        border: Border.all(color: Colors.grey.shade300, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: IconButton(
        icon: Icon(icon),
        onPressed: onPressed,
      ),
    );
  }

  IconData _categoryIcon(String type) {
    switch (type) {
      case 'All':
        return Icons.grid_view;
      case 'House':
      case 'Bungalow':
      case 'Townhouse':
      case 'Villa':
      case 'Duplex':
      case 'Triplex':
      case 'Farmhouse':
      case 'Ranch':
      case 'Mobile Home':
      case 'Tiny House':
      case 'Cottage':
      case 'Cabin':
      case 'Mansion':
        return Icons.home;
      case 'Apartment':
      case 'Studio':
      case 'Loft':
      case 'Penthouse':
      case 'Flat':
      case 'Single Room':
      case 'Double Room':
        return Icons.apartment;
      case 'Condominium':
        return Icons.villa;
      case 'Office':
      case 'Office Space':
      case 'Industrial Property':
        return Icons.work;
      case 'Retail Space':
      case 'Storage Unit':
        return Icons.store;
      case 'Land':
      case 'Parking Space':
        return Icons.terrain;
      case 'Warehouse':
        return Icons.warehouse;
      case 'Hotel':
        return Icons.hotel;
      default:
        return Icons.home;
    }
  }
}

class _SearchHeaderDelegate extends SliverPersistentHeaderDelegate {
  const _SearchHeaderDelegate(
      {required this.child, required this.height});
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
