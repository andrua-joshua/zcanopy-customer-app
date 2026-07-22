import 'package:flutter/material.dart';
import 'package:zcanopy/pages/welcome.dart';
import 'package:zcanopy/pages/loadIndicator.dart';
import 'package:zcanopy/widgets/filter_widget.dart';
import 'package:zcanopy/pages/itemDetails.dart';
import 'package:zcanopy/pages/brokerCollection.dart';
import 'package:http/http.dart' as http;
import 'package:zcanopy/pages/network.dart';
import 'dart:convert';
import 'package:zcanopy/pages/session.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:zcanopy/utils/colors.dart';

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
    "Office Space",
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
  final TextEditingController minPriceCtrl = TextEditingController();
  final TextEditingController maxPriceCtrl = TextEditingController();

  // Example district data
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
  //Map<String, List<Map<String, dynamic>>>
  var displayedRegions = {};

  List<String> regionsX = ["Region A", "Region B"];

  // Helper method to filter regions based on selected category
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

    print(">>>>>>>>>>>>>>${filteredRegions}");

    return filteredRegions;
  }

  Future<void> _reloadList() async {
    //network simulation
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
    await database.clear();
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
      if (mounted) {
        await forceLogout(context);
      }
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
            //      regions.addAll(data);
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
    //   _scrollController.addListener(_onScroll);

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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                onChanged: (value) {
                  setState(() {
                    searchQuery = value;
                    applyFilters();
                  });
                },
                decoration: InputDecoration(
                  hintText: "Search",
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: IconButton(
                    onPressed: openFilterSheet,
                    icon: Icon(Icons.filter_list),
                  ),
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              FilterWidget(
                categories: categories,
                onCategorySelected: (category) {
                  setState(() {
                    selectedCategory = category;
                  });
                },
                selectedCategory: selectedCategory,
              ),
              const SizedBox(height: 20),
              Expanded(
                child: ListView.builder(
                  itemCount: _districtGroups().length,
                  itemBuilder: (context, index) {
                    final entry = _districtGroups().entries.elementAt(index);
                    final district = entry.key;
                    final properties = entry.value;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(left: 4, bottom: 8),
                          child: Text(
                            district,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppColors.brown,
                            ),
                          ),
                        ),
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: properties.length,
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 1,
                            mainAxisSpacing: 12,
                            crossAxisSpacing: 0,
                            childAspectRatio: 1.15,
                          ),
                          itemBuilder: (context, i) {
                            return _buildExplorerCard(properties[i]);
                          },
                        ),
                        const SizedBox(height: 16),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> loadInitialData() async {
    //  var data = await fetchData(itemsPerPage);
    //  allProperties = data.nearByProperties;
    //  isLoadingMore=data.loadingMore;

    await Future.delayed(const Duration(seconds: 2));
    setState(() {
      displayedRegions = Map.fromEntries(regions.entries.take(itemsPerPage));
      isLoading = false;
    });

    regionsX = regions.keys.toList(); //extracting regions
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

    /*  var data = await fetchData(itemsPerPage);
    setState(() {
      regions = data.regions;
     isLoadingMore=data.loadingMore;
    });*/

    await Future.delayed(const Duration(seconds: 2));
    setState(() {
      final start = displayedRegions.length;
      final end = (start + itemsPerPage).clamp(0, regions.length);

      displayedRegions.addAll(Map.fromEntries(regions.entries
          .skip(start)
          .take(end - start))); //this is like--> regions.sublist(start, end));

      isLoadingMore = false;
    });
  }

  void applyFilters() {
    double? maxPrice = double.tryParse(maxPriceCtrl.text);
    double? minPrice = double.tryParse(minPriceCtrl.text);
    var tempX;

/*
    regions.forEach((region, valuesArray) {
      List<Map<String, dynamic>> newList = valuesArray
          .where((object) => object['location'] == searchQuery)
          .toList();

      if (newList.isNotEmpty) {
        displayedRegions[region] = newList;
      }
    });*/

    setState(() {
      regions.forEach((region, valuesArray) {
        List<Map<String, dynamic>> newList = valuesArray.where((object) {
          final matchesType =
              selectedType == 'All' || object['propertyType'] == selectedType;
          final matchesSearch =
              object['name'].toLowerCase().contains(searchQuery.toLowerCase());
          final matchesPrice =
              (minPrice == null || object['price'] >= minPrice) &&
                  (maxPrice == null || object['price'] <= maxPrice);
          final matchesLocation = selectedLocation == 'All' ||
              object['location'] == selectedLocation;

          return matchesType &&
              matchesSearch &&
              matchesPrice &&
              matchesLocation;
        }).toList();

        //        displayedRegions = newList;
        tempX = newList;
      });

      displayedRegions = {for (var item in tempX) item["id"]: item};
      
    });

/*
    setState(() {
      displayedRegions = regions.where((prop) {
        final matchesType =
            selectedType == 'All' || prop['type'] == selectedType;
        final matchesSearch =
            prop['name'].toLowerCase().contains(searchQuery.toLowerCase());
        final matchesPrice = (minPrice == null || prop['price'] >= minPrice) &&
            (maxPrice == null || prop['price'] <= maxPrice);
        final matchesLocation =
            selectedLocation == 'All' || prop['location'] == selectedLocation;

        return matchesType && matchesSearch && matchesPrice && matchesLocation;
      }).toList();
    });*/
  }

  void openFilterSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(5)),
      ),
      builder: (_) {
        return StatefulBuilder(builder: (context, setModalState) {
          return Padding(
              padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context)
                      .viewInsets
                      .bottom), //const EdgeInsets.all(16),
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text("Filter Properties",
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 20),
                    DropdownButtonFormField<String>(
                      value: selectedLocation,
                      items: [
                        'All',
                        'Ntinda',
                        'Kisaasi',
                        'Naalya',
                        'Bweyogerere'
                      ]
                          .map((e) => DropdownMenuItem(
                              value: e, child: Text(e.toString())))
                          .toList(),
                      onChanged: (val) {
                        setModalState(() => selectedLocation = val!);
                      },
                      decoration: const InputDecoration(
                          fillColor: Color.fromARGB(255, 169, 97, 14),
                          labelText: "Location",
                          border: OutlineInputBorder(
                            borderSide: BorderSide(
                                color: Color.fromARGB(255, 169, 97, 14)),
                            borderRadius: BorderRadius.all(Radius.circular(10)),
                          ),
                          labelStyle: TextStyle(color: Colors.grey),
                          floatingLabelStyle: TextStyle(
                              color: Color.fromARGB(255, 169, 97, 14)),
                          focusedBorder: OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.all(Radius.circular(10)),
                              borderSide: BorderSide(
                                  color: Color.fromARGB(255, 169, 97, 14),
                                  width: 1.5))),
                    ),
                    const SizedBox(height: 20),
                    Text("Max Price: ${maxPrice.toInt()} UGX"),
                    /*   Slider(
                  activeColor: Color.fromARGB(255, 169, 97, 14),
                  value: maxPrice,
                  min: 100000,
                  max: 3000000,
                  divisions: 13,
                  label: maxPrice.toStringAsFixed(0),
                  onChanged: (val) {
                    setModalState(() => maxPrice = val);
                  },
                ),*/

                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                            child: TextFormField(
                          controller: minPriceCtrl,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            contentPadding:
                                EdgeInsets.symmetric(horizontal: 20),
                            labelText: 'Min Price',
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(30)),
                            focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(30),
                                borderSide: BorderSide(color: Colors.brown)),
                            floatingLabelStyle: TextStyle(
                                color: Color.fromARGB(255, 169, 97, 14)),
                          ),
                          onChanged: (_) => applyFilters(),
                        )),
                        SizedBox(
                          width: 12,
                        ),
                        Expanded(
                            child: TextFormField(
                          controller: maxPriceCtrl,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            contentPadding:
                                EdgeInsets.symmetric(horizontal: 20),
                            labelText: 'Max Price',
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(30)),
                            focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(30),
                                borderSide: BorderSide(color: Colors.brown)),
                            floatingLabelStyle: TextStyle(
                                color: Color.fromARGB(255, 169, 97, 14)),
                          ),
                          onChanged: (_) => applyFilters(),
                        ))
                      ],
                    ),
                    const SizedBox(height: 10),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        applyFilters();
                      },
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Color.fromARGB(255, 169, 97, 14)),
                      child: const Text("Apply Filters",
                          style: TextStyle(color: Colors.white)),
                    ),
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

  void _navigateToBrokerCollection(Map<String, dynamic> property) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BrokerCollectionPage(
          brokerCode: property['brokerCode'] ?? '',
          brokerName: property['brokerName'] ?? 'Broker',
        ),
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

  Widget _buildExplorerCard(Map<String, dynamic> property) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark
        ? const Color(0xFF2A2A2A)
        : const Color.fromARGB(160, 254, 251, 248);
    final status = property['status']?.toString() ?? 'Available';
    final available = status.toLowerCase() == 'available';
    final price = property['price'] is num
        ? (property['price'] as num).toDouble()
        : 0.0;
    final imgList = property['images'] as List?;
    final imageCount = imgList != null && imgList.isNotEmpty ? imgList.length : 1;
    final hasVideo = property['video'] != null &&
        property['video'].toString().isNotEmpty;

    return _ExplorerCardStateful(
      property: property,
      isDark: isDark,
      cardColor: cardColor,
      status: status,
      available: available,
      price: price,
      imgList: imgList,
      imageCount: imageCount,
      hasVideo: hasVideo,
     );
   }
}

String _formatPrice(double price) {
  final s = price.round().toString();
  return s.replaceAllMapped(
    RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
    (m) => '${m[1]},',
  );
}

class _ExplorerCardStateful extends StatefulWidget {
  final Map<String, dynamic> property;
  final bool isDark;
  final Color cardColor;
  final String status;
  final bool available;
  final double price;
  final List? imgList;
  final int imageCount;
  final bool hasVideo;

  const _ExplorerCardStateful({
    required this.property,
    required this.isDark,
    required this.cardColor,
    required this.status,
    required this.available,
    required this.price,
    required this.imgList,
    required this.imageCount,
    required this.hasVideo,
  });

  @override
  State<_ExplorerCardStateful> createState() => _ExplorerCardStatefulState();
}

class _ExplorerCardStatefulState extends State<_ExplorerCardStateful> {
  int _currentImageIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: widget.cardColor,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => BrokerCollectionPage(
                brokerCode: widget.property['brokerCode'] ?? '',
                brokerName: widget.property['brokerName'] ?? 'Broker',
              ),
            ),
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 160,
              child: Stack(
                children: [
                  PageView.builder(
                    itemCount: widget.imageCount,
                    onPageChanged: (index) {
                      setState(() => _currentImageIndex = index);
                    },
                    itemBuilder: (context, index) {
                      final imgUrl = (widget.imgList != null && widget.imgList!.isNotEmpty)
                          ? widget.imgList![index % widget.imgList!.length].toString()
                          : widget.property['image']?.toString() ?? '';
                      return Image.network(
                        imgUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: Colors.grey.shade300,
                          child: const Icon(Icons.home, size: 40, color: Colors.grey),
                        ),
                      );
                    },
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: widget.available ? Colors.green : Colors.red,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        widget.status,
                        style: const TextStyle(color: Colors.white, fontSize: 11),
                      ),
                    ),
                  ),
                  if (widget.imageCount > 1)
                    Positioned(
                      bottom: 8,
                      left: 0,
                      right: 0,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                          widget.imageCount,
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
            Expanded(
              flex: 1,
              child: Padding(
                padding: const EdgeInsets.all(8),
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
                     const SizedBox(height: 3),
                     Align(
                       alignment: Alignment.centerRight,
                       child: Container(
                         padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                         decoration: BoxDecoration(
                           color: AppColors.brown,
                           borderRadius: BorderRadius.circular(6),
                         ),
                         child: Text(
                           widget.property['brokerName']?.toString() ?? 'Broker',
                           style: const TextStyle(
                             color: Colors.white,
                             fontSize: 10,
                             fontWeight: FontWeight.w600,
                           ),
                         ),
                       ),
                     ),
                     const SizedBox(height: 2),
                     Text(
                       widget.property['location'] ?? '',
                       maxLines: 1,
                       overflow: TextOverflow.ellipsis,
                       style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                     ),
                     const SizedBox(height: 4),
                     Text(
                       'UGX ${_formatPrice(widget.price)}',
                       style: TextStyle(
                         color: AppColors.brown,
                         fontWeight: FontWeight.bold,
                         fontSize: 12,
                       ),
                     ),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => BrokerCollectionPage(
                                brokerCode: widget.property['brokerCode'] ?? '',
                                brokerName: widget.property['brokerName'] ?? 'Broker',
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.visibility_outlined, size: 14),
                        label: const Text(
                          "View",
                          style: TextStyle(fontSize: 11),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.brown,
                          side: const BorderSide(color: AppColors.brown),
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          visualDensity: VisualDensity.compact,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
