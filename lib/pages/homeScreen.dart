import 'dart:async';

import 'package:flutter/material.dart';
import 'package:zcanopy/pages/welcome.dart';
import 'package:shimmer/shimmer.dart';
import 'package:zcanopy/pages/userProfile.dart';
import 'package:zcanopy/pages/explorer.dart';
import 'package:zcanopy/pages/subscriptionsPage.dart';
import 'package:zcanopy/pages/loadIndicator.dart';
import 'package:zcanopy/pages/itemDetails.dart';
import 'package:zcanopy/services/property_monitor_service.dart';
import 'package:zcanopy/pages/brokerCollection.dart';
import 'package:zcanopy/pages/notifications.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:zcanopy/pages/session.dart';
import 'package:zcanopy/theme/theme_controller.dart';
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

  String selectedType = 'All';
  double maxPrice = 200000;
  String searchQuery = '';
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

  void _rebuildReels() {
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
  }

  Future<void> loadInitialData() async {
    final isSessionValid = await SessionService.validateSession();
    if (!isSessionValid) {
      if (mounted) await forceLogout(context);
      return;
    }

    await Future.delayed(const Duration(seconds: 1));
    if (mounted) {
      setState(() {
        displayedProperties = List.from(allProperties);
        _rebuildReels();
        isLoading = false;
      });
    }
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
        final matchesSearch = (prop['name'] as String)
            .toLowerCase()
            .contains(searchQuery.toLowerCase()) ||
            (prop['brokerName'] as String?)
                ?.toLowerCase()
                .contains(searchQuery.toLowerCase()) ==
                true;
        final matchesLocation =
            selectedLocation == 'All' || prop['location'] == selectedLocation;
        final matchesSub = selectedSubCounty == 'All' ||
            (prop['subCounty'] ?? '') == selectedSubCounty;
        final matchesDistrict = selectedDistrict == 'All' ||
            (prop['district'] ?? '') == selectedDistrict;
        final matchesPrice = (minPrice == null || prop['price'] >= minPrice) &&
            (maxPriceVal == null || prop['price'] <= maxPriceVal);
        return matchesType &&
            matchesSearch &&
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
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: reels.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final reel = reels[index];
              return GestureDetector(
                onTap: () => _openReelFullscreen(initial: index),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: SizedBox(
                    width: 150,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Container(color: Colors.black),
                        const Center(
                          child: Icon(
                            Icons.play_circle_fill,
                            color: Colors.white70,
                            size: 42,
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
              right: 16,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openFeedbackDialog() {
    final contentCtrl = TextEditingController();
    bool submitting = false;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialog) {
            return AlertDialog(
              title: const Text("Send Feedback"),
              content: TextField(
                controller: contentCtrl,
                maxLines: 5,
                minLines: 3,
                decoration: const InputDecoration(
                  labelText: "Your feedback",
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: submitting ? null : () => Navigator.pop(context),
                  child: const Text("Cancel"),
                ),
                ElevatedButton(
                  onPressed: submitting
                      ? null
                      : () async {
                          final content = contentCtrl.text.trim();
                          if (content.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text("Please enter your feedback"),
                              ),
                            );
                            return;
                          }

                          setDialog(() => submitting = true);
                          try {
                            await _apiService.submitBrokerFeedback(
                              brokerCode:
                                  database.get('brokerCode')?.toString() ?? '',
                              email: database.get('email')?.toString() ?? '',
                              phone:
                                  database.get('phoneNumber')?.toString() ?? '',
                              content: content,
                            );
                            if (mounted) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text("Feedback sent. Thank you!"),
                                ),
                              );
                            }
                          } catch (e) {
                            debugPrint('Submit feedback error: $e');
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text("Failed to send feedback: $e"),
                                ),
                              );
                            }
                          } finally {
                            if (mounted) setDialog(() => submitting = false);
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        const Color.fromARGB(255, 169, 97, 14),
                  ),
                  child: submitting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text("Submit",
                          style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildPropertyCard(Map<String, dynamic> property,
      {EdgeInsetsGeometry? margin}) {
    final bookState =
        property['bookState'] as Map<String, dynamic>? ?? {};
    final isBooked = bookState['isBooked'] == true;
    final bookingCount = bookState['bookingCount'] ?? 0;
    final hasVideo =
        property['video'] != null && property['video'].toString().isNotEmpty;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark
        ? const Color(0xFF2A2A2A)
        : const Color.fromARGB(160, 254, 251, 248);

    return Card(
      color: cardColor,
      margin: margin ?? const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => BrokerCollectionPage(
                      brokerCode: property['brokerCode'] ?? '',
                      brokerName: property['brokerName'] ?? 'Broker',
                    ),
                  ),
                ),
                child: Image.network(
                  property['image'],
                  height: 200,
                  width: double.infinity,
                  fit: BoxFit.cover,
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
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    property['status'],
                    style: const TextStyle(
                        color: Colors.white, fontSize: 12),
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
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Icon(Icons.play_circle_fill,
                          color: Colors.white, size: 26),
                    ),
                  ),
                ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  property['name'],
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color.fromARGB(255, 169, 97, 14),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    property['brokerName']?.toString() ?? 'Broker',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    const Icon(Icons.location_on,
                        size: 13, color: Colors.grey),
                    const SizedBox(width: 3),
                    Expanded(
                      child: Text(
                        "${property['subCounty']}, ${property['district']}",
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  "${property['price']} UGX",
                  style: const TextStyle(
                    color: Color.fromARGB(255, 169, 97, 14),
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  property['description'],
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: Colors.grey.shade600, fontSize: 11),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Chip(
                      label: Text(
                        isBooked
                            ? "Booked ($bookingCount)"
                            : "Available",
                        style: const TextStyle(fontSize: 10),
                      ),
                      backgroundColor: isBooked
                          ? Colors.red.shade50
                          : Colors.green.shade50,
                      visualDensity: VisualDensity.compact,
                    ),
                    OutlinedButton.icon(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => BrokerCollectionPage(
                            brokerCode: property['brokerCode'] ?? '',
                            brokerName:
                                property['brokerName'] ?? 'Broker',
                          ),
                        ),
                      ),
                      icon: const Icon(Icons.visibility_outlined, size: 16),
                      label: const Text(
                        "View",
                        style: TextStyle(fontSize: 12),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color.fromARGB(255, 169, 97, 14),
                        side: const BorderSide(
                          color: Color.fromARGB(255, 169, 97, 14),
                        ),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
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
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        "Discover Properties",
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Theme.of(context).brightness == Brightness.dark
                            ? Icons.light_mode_outlined
                            : Icons.dark_mode_outlined,
                      ),
                      tooltip: 'Toggle theme',
                      onPressed: () async {
                        await themeController.toggleLightDark();
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.notifications_outlined),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => NotificationsPage(),
                          ),
                        );
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.feedback_outlined),
                      tooltip: 'Send feedback',
                      onPressed: _openFeedbackDialog,
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Search Bar
                TextField(
                  onChanged: (value) {
                    setState(() {
                      searchQuery = value;
                      applyFilters();
                    });
                  },
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search),
                    hintText: "Search by title or broker",
                    hintStyle: const TextStyle(color: Colors.black54),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.filter_list),
                      onPressed: openFilterSheet,
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  style: const TextStyle(color: Colors.black),
                ),
                const SizedBox(height: 16),

                // Horizontal Selector
                SizedBox(
                  height: 40,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      'All',
                      'House',
                      'Apartment',
                      'Condominium'
                    ].map((type) {
                      final isSelected = selectedType == type;
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            selectedType = type;
                            applyFilters();
                          });
                        },
                        child: Container(
                          margin: const EdgeInsets.only(right: 10),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color.fromARGB(255, 169, 97, 14)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            type,
                            style: TextStyle(
                              color: isSelected
                                  ? Colors.white
                                  : Colors.grey.shade800,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),

                const SizedBox(height: 20),
                const Text(
                  "Your Nearby",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),

                // Property List with Infinite Scroll
                Expanded(
                  child: isLoading
                      ? ListView.builder(
                          itemCount: 3,
                          itemBuilder: (_, __) => buildShimmerCard(),
                        )
                      : ListView(
                          controller: _scrollController,
                          children: [
                            _buildReelSection(),
                            if (reels.isNotEmpty)
                              const SizedBox(height: 16),
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
                                    color:
                                        Color.fromARGB(255, 169, 97, 14),
                                  ),
                                ),
                              ),
                          ],
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class BottomNavBar extends StatefulWidget {
  const BottomNavBar({Key? key}) : super(key: key);

  @override
  State<BottomNavBar> createState() => _BottomNavBar();
}

class _BottomNavBar extends State<BottomNavBar> {
  int _selectedIndex = 0;
  int _nearbyCount = 0;

  final List<Widget> _pages = [
    const HomeScreen(),
    ExplorePage(),
 //   const SubscriptionPage(),
    const ProfilePage(),
  ];

  @override
  void initState() {
    super.initState();
    _loadNearbyCount();
    PropertyMonitorService.onCountUpdated = _loadNearbyCount;
  }

  @override
  void dispose() {
    PropertyMonitorService.onCountUpdated = null;
    super.dispose();
  }

  Future<void> _loadNearbyCount() async {
    final count = await PropertyMonitorService().getStoredCount();
    if (mounted) {
      setState(() => _nearbyCount = count);
    }
  }

  Widget _badgeIcon(IconData icon, int count) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(icon),
        if (count > 0)
          Positioned(
            right: -6,
            top: -6,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
              child: Text(
                count > 99 ? '99+' : '$count',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }

  void _onTapped(int index) {
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    const activeColor = Color.fromARGB(255, 169, 97, 14);
    const inactiveColor = Colors.grey;

    return Scaffold(
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: _pages[_selectedIndex],
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        selectedItemColor: activeColor,
        unselectedItemColor: inactiveColor,
        showSelectedLabels: true,
        showUnselectedLabels: true,
        currentIndex: _selectedIndex,
        onTap: _onTapped,
        elevation: 8,
        items: [
          BottomNavigationBarItem(
            icon: _badgeIcon(Icons.home, _nearbyCount),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: _badgeIcon(Icons.search, _nearbyCount),
            label: 'Explore',
          ),
          BottomNavigationBarItem(
            icon: _badgeIcon(Icons.person, _nearbyCount),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
