import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:video_player/video_player.dart';
import 'package:zcanopy/pages/welcome.dart';
import 'package:zcanopy/pages/filter_wizard.dart';
import 'package:zcanopy/pages/loadIndicator.dart';
import 'package:zcanopy/pages/itemDetails.dart';
import 'package:http/http.dart' as http;
import 'package:zcanopy/pages/network.dart';
import 'dart:convert';
import 'package:zcanopy/pages/session.dart';
import 'package:zcanopy/services/api_service.dart';
import 'package:zcanopy/pages/notifications.dart';
import 'package:zcanopy/utils/colors.dart';
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
  List<dynamic> _items = [];
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

  Map<String, List<Map<String, dynamic>>> regions = {
    "Kampala": [
      {
        'id': 'e1',
        'type': 'House',
        'name': 'Bungalow in Ntinda',
        'price': 250000000,
        'location': 'Ntinda',
        'subCounty': 'Ntinda',
        'district': 'Kampala Central',
        'status': 'Available',
        'image': 'https://picsum.photos/400/200?10',
        'description': 'Mutaasa brokers, 1 dining room, 2 toilets, spacious compound, secure gated community.',
        'mapLocation': {'lat': 0.3476, 'lng': 32.5825},
        'video': '',
        'bookState': {'isBooked': false, 'bookingCount': 0},
        'brokerCode': 'BRK-MUTAASA',
        'brokerName': 'Mutaasa Brokers',
        'brokerPhone': '+256701234567',
      },
      {
        'id': 'e2',
        'type': 'Apartment',
        'name': 'Modern Apartment in Kisaasi',
        'price': 750000,
        'location': 'Kisaasi',
        'subCounty': 'Kisaasi',
        'district': 'Kampala North',
        'status': 'Available',
        'image': 'https://picsum.photos/400/200?11',
        'description': 'Mutaasa brokers, 2 bedrooms, 1 dining room, 2 toilets, balcony with city view.',
        'mapLocation': {'lat': 0.369, 'lng': 32.56},
        'video': '',
        'bookState': {'isBooked': false, 'bookingCount': 0},
        'brokerCode': 'BRK-KISAA',
        'brokerName': 'Kisaasi Realty',
        'brokerPhone': '+256702345678',
      },
    ],
    "Wakiso": [
      {
        'id': 'e3',
        'type': 'House',
        'name': 'Rental House in Bweyogerere',
        'price': 400000,
        'location': 'Bweyogerere',
        'subCounty': 'Bweyogerere',
        'district': 'Wakiso',
        'status': 'Available',
        'image': 'https://picsum.photos/400/200?12',
        'description': '2 bedrooms, 1 dining room, 1 toilet, near main road.',
        'mapLocation': {'lat': 0.357, 'lng': 32.65},
        'video': '',
        'bookState': {'isBooked': false, 'bookingCount': 0},
        'brokerCode': 'BRK-WAKISO',
        'brokerName': 'Wakiso Homes',
        'brokerPhone': '+256703456789',
      },
    ],
    "Entebbe": [
      {
        'id': 'e4',
        'type': 'Condominium',
        'name': 'Luxury Condo',
        'price': 250000,
        'location': 'Entebbe',
        'subCounty': 'Entebbe',
        'district': 'Entebbe',
        'status': 'Available',
        'image': 'https://picsum.photos/400/200?13',
        'description': '4 bedrooms, 3 bathrooms, living room, kitchen.',
        'mapLocation': {'lat': 0.054, 'lng': 32.463},
        'video': '',
        'bookState': {'isBooked': false, 'bookingCount': 0},
        'brokerCode': 'BRK-MUTAASA',
        'brokerName': 'Mutaasa Brokers',
        'brokerPhone': '+256701234567',
      },
    ],
    "Jinja": [
      {
        'id': 'e5',
        'type': 'Flat',
        'name': 'Cozy Flat',
        'price': 800000,
        'location': 'Jinja',
        'subCounty': 'Jinja',
        'district': 'Jinja',
        'status': 'Available',
        'image': 'https://picsum.photos/400/200?14',
        'description': '2 bedrooms, 1 bathroom, living room, no kitchen.',
        'mapLocation': {'lat': 0.424, 'lng': 33.204},
        'video': '',
        'bookState': {'isBooked': false, 'bookingCount': 0},
        'brokerCode': 'BRK-KISAA',
        'brokerName': 'Kisaasi Realty',
        'brokerPhone': '+256702345678',
      },
    ],
  };
  var displayedRegions = {};

  List<String> regionsX = ["Region A", "Region B"];

  Map<String, List<Map<String, dynamic>>> _filterRegions() {
    if (selectedCategory == "All") {
      return regions;
    }
    Map<String, List<Map<String, dynamic>>> filteredRegions = {};
    displayedRegions.forEach((regionName, items) {
      List<Map<String, dynamic>> filteredItems = items
          .where((item) => item['propertyType'] == selectedCategory)
          .toList();
      if (filteredItems.isNotEmpty) {
        filteredRegions[regionName] = filteredItems;
      }
    });
    return filteredRegions;
  }

  Future<void> _reloadList() async {
    await Future.delayed(const Duration(seconds: 2));
    setState(() {
      regions = {
        "Region A": [
          {
            "name": "Modern Apartment",
            "location": "Kampala",
            "price": 120000,
            "bedrooms": 3,
            "bathrooms": 2,
            "livingRoom": true,
            "kitchen": true,
            "image": "https://picsum.photos/200/120?random=1",
            "propertyType": "Apartment"
          },
          {
            "name": "Luxury Condo",
            "location": "Entebbe",
            "price": 250000,
            "bedrooms": 4,
            "bathrooms": 3,
            "livingRoom": true,
            "kitchen": true,
            "image": "https://picsum.photos/200/120?random=2",
            "propertyType": "Condominium"
          },
        ],
        "Region B": [
          {
            "name": "Cozy Flat",
            "location": "Jinja",
            "price": 800000,
            "bedrooms": 2,
            "bathrooms": 1,
            "livingRoom": true,
            "kitchen": false,
            "image": "https://picsum.photos/200/120?random=3",
            "propertyType": "Flat"
          },
          {
            "name": "Family House",
            "location": "Gulu",
            "price": 180000,
            "bedrooms": 5,
            "bathrooms": 3,
            "livingRoom": true,
            "kitchen": true,
            "image": "https://picsum.photos/200/120?random=4",
            "propertyType": "House"
          },
        ],
      };
    });
  }

  Future<void> forceLogout(BuildContext context) async {
    final database = Hive.box('myStore');
    await database.clear();
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const OnBoardingScreen()),
      (_) => false,
    );
  }

  Future<void> _fetchItems({bool refresh = false}) async {
    if (_isLoading) return;
    if (refresh) {
      setState(() {
        _page = 1;
        _items.clear();
        _hasMore = true;
      });
    }
    setState(() => _isLoading = true);
    final isSessionValid = await SessionService.validateSession();
    if (!isSessionValid) {
      if (mounted) await forceLogout(context);
    }
    try {
      final url = Uri.parse(
          "https://my-server-url/get-all-properties?region=wakiso&_limit=$_limit&_page=$_page");
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          if (data.isNotEmpty) {
            _items.addAll(data);
            _page++;
          } else {
            _hasMore = false;
          }
        });
      } else {
        debugPrint("Error: ${response.statusCode}");
      }
    } catch (e) {
      debugPrint("Network error: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_isLoading &&
        _hasMore) {
      _fetchItems();
    }
  }

  Future<void> _refresh() async {
    await _fetchItems(refresh: true);
  }

  @override
  void initState() {
    super.initState();
    _fetchItems();
    loadInitialData();
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
              _scrollController.position.maxScrollExtent - 200 &&
          !isLoadingMore &&
          displayedRegions.length < regions.length) {
        loadMoreData();
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
    try {
      final url = Uri.parse(
          "https://my-server-url/get-all-properties?region=wakiso&_limit=50&_page=1");
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        if (data.isNotEmpty) {
          final fetchedRegions = <String, List<Map<String, dynamic>>>{};
          for (final item in data) {
            final loc = item['location']?.toString() ?? 'Unknown';
            fetchedRegions.putIfAbsent(loc, () => [])
                .add(Map<String, dynamic>.from(item));
          }
          if (fetchedRegions.isNotEmpty) {
            if (mounted) {
              setState(() {
                regions = fetchedRegions;
                _displayedItems = [];
                regions.forEach((_, items) {
                  _displayedItems.addAll(items.map((e) => Map<String, dynamic>.from(e)));
                });
                isLoading = false;
              });
            }
            regionsX = regions.keys.toList();
            return;
          }
        }
      }
    } catch (e) {
      debugPrint("Network error: $e");
    }
    await Future.delayed(const Duration(seconds: 2));
    setState(() {
      _displayedItems = [];
      regions.forEach((_, items) {
        _displayedItems.addAll(items.map((e) => Map<String, dynamic>.from(e)));
      });
      isLoading = false;
    });
    regionsX = regions.keys.toList();
  }

  fetchData(itemsPerPage) async {
    try {
      final data = await NetworkService.get(
          'http://127.0.0.1:4000/listings/get-nearby-properties?itemPerPage=${itemsPerPage}');
      return data;
    } catch (e) {
      print(e);
    }
  }

  Future<void> loadMoreData() async {
    setState(() => isLoadingMore = true);
    await Future.delayed(const Duration(seconds: 2));
    setState(() {
      final start = displayedRegions.length;
      final end = (start + itemsPerPage).clamp(0, regions.length);
      displayedRegions.addAll(Map.fromEntries(regions.entries
          .skip(start)
          .take(end - start)));
      isLoadingMore = false;
    });
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
  }

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

  List<Map<String, dynamic>> _getDisplayedProperties() {
    final all = <Map<String, dynamic>>[];
    regions.forEach((_, items) {
      all.addAll(items.map((e) => Map<String, dynamic>.from(e)));
    });
    final minPrice = double.tryParse(maxPriceCtrl.text);
    final maxPrice = double.tryParse(maxPriceCtrl.text);
    return all.where((prop) {
      final matchesType = selectedType == 'All' || prop['type'] == selectedType;
      final matchesSearch = (prop['name'] as String)
          .toLowerCase()
          .contains(searchQuery.toLowerCase());
      final matchesLocation = selectedLocation == 'All' ||
          prop['location'] == selectedLocation;
      final matchesPrice = (minPrice == null || prop['price'] >= minPrice) &&
          (maxPrice == null || prop['price'] <= maxPrice);
      return matchesType && matchesSearch && matchesLocation && matchesPrice;
    }).toList();
  }

  void _openDetails(Map<String, dynamic> property) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PropertyDetailsPage(property: property),
      ),
    );
  }

  Map<String, List<Map<String, dynamic>>> _districtGroups() {
    final displayed = _getDisplayedProperties();
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final prop in displayed) {
      final district = prop['district']?.toString() ?? prop['location']?.toString() ?? 'Other';
      grouped.putIfAbsent(district, () => []).add(prop);
    }
    return grouped;
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
