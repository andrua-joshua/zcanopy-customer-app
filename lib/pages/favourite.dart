import 'package:flutter/material.dart';
import 'package:zcanopy/pages/welcome.dart';
import 'package:zcanopy/pages/loadIndicator.dart';
import 'package:zcanopy/pages/network.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:zcanopy/pages/session.dart';
import 'package:zcanopy/utils/theme_extensions.dart';
import 'package:zcanopy/services/api_service.dart';

class FavouritePage extends StatefulWidget {
  const FavouritePage({super.key});

  @override
  State<FavouritePage> createState() => _FavouritePageState();
}

class _FavouritePageState extends State<FavouritePage> {
  bool isLoading = true;
  bool isLoadingMore = false;
  final ScrollController _scrollController = ScrollController();
  final int itemsPerPage = 4;
  List<Map<String, dynamic>> displayedFavourites = [];
  final database = Hive.box('myStore');
  final _apiService = ApiService();
  var userID;

  List<Map<String, dynamic>> favourites = [
    {
      "id": "PROP001",
      "houseName": "Luxury Apartment",
      "location": "Banda, Kampala",
      "price": 360000,
      "houseImg": "https://picsum.photos/200/120?random=1",
      "rating": 4.7,
      "type": "Apartment",
    },
    {
      "id": "PROP002",
      "houseName": "Modern Condo",
      "location": "Kirinya, Kampala",
      "price": 280000,
      "houseImg": "https://picsum.photos/200/120?random=2",
      "rating": 4.2,
      "type": "Condo",
    },
  ];

  @override
  void initState() {
    super.initState();
    loadInitialData();
    userID = database.get('userID');

    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
              _scrollController.position.maxScrollExtent - 200 &&
          !isLoadingMore &&
          displayedFavourites.length < favourites.length) {
        loadMoreData();
      }
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

  Future<void> loadInitialData() async {
     final isSessionValid = await SessionService.validateSession();
    if (!isSessionValid) {
      if (mounted) {
        await forceLogout(context);
      }
    }

    try {
      final data = await _apiService.getFavorites(
        userId: userID,
        limit: itemsPerPage,
      );

      if (data != null && data['success'] == true) {
        setState(() {
          favourites = List<Map<String, dynamic>>.from(data['favourites'] ?? []);
          displayedFavourites = favourites.take(itemsPerPage).toList();
          isLoading = false;
          isLoadingMore = data['isLoadingMore'] ?? false;
        });
      } else {
        await Future.delayed(const Duration(seconds: 2));
        setState(() {
          displayedFavourites = favourites.take(itemsPerPage).toList();
          isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading favorites: $e');
      await Future.delayed(const Duration(seconds: 2));
      setState(() {
        displayedFavourites = favourites.take(itemsPerPage).toList();
        isLoading = false;
      });
    }
  }

  Future<void> loadMoreData() async {
    setState(() => isLoadingMore = true);

    try {
      final data = await _apiService.getFavorites(
        userId: userID,
        limit: itemsPerPage,
      );

      if (data != null && data['success'] == true) {
        setState(() {
          favourites = List<Map<String, dynamic>>.from(data['favourites'] ?? []);
          final start = displayedFavourites.length;
          final end = (start + itemsPerPage).clamp(0, favourites.length);
          displayedFavourites.addAll(favourites.sublist(start, end));
          isLoadingMore = data['isLoadingMore'] ?? false;
        });
      } else {
        await Future.delayed(const Duration(seconds: 2));
        setState(() {
          final start = displayedFavourites.length;
          final end = (start + itemsPerPage).clamp(0, favourites.length);
          displayedFavourites.addAll(favourites.sublist(start, end));
          isLoadingMore = false;
        });
      }
    } catch (e) {
      print('Error loading more favorites: $e');
      setState(() {
        final start = displayedFavourites.length;
        final end = (start + itemsPerPage).clamp(0, favourites.length);
        displayedFavourites.addAll(favourites.sublist(start, end));
        isLoadingMore = false;
      });
    }
  }

  Future<void> _removeFavorite(String propertyId, int index) async {
    try {
      final response = await _apiService.removeFromFavorites(
        userId: userID,
        propertyId: propertyId,
      );

      if (response['success'] == true) {
        setState(() {
          displayedFavourites.removeAt(index);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Removed from favorites"),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('Error removing favorite: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Failed to remove from favorites"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Favourites",
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Color.fromARGB(255, 169, 97, 14),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () async {
              setState(() {
                isLoading = true;
                displayedFavourites = [];
              });
              await loadInitialData();
            },
          ),
        ],
      ),
      body: Container(
        decoration: context.isDarkMode
            ? BoxDecoration(color: Theme.of(context).scaffoldBackgroundColor)
            : const BoxDecoration(
                image: DecorationImage(
                  image: AssetImage('assets/background.jpg'),
                  fit: BoxFit.cover,
                ),
              ),
        child: Container(
          color: context.isDarkMode
              ? Colors.transparent
              : Colors.white.withOpacity(0.85),
          child: isLoading
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Center(
                      child: ZLoadingIndicator(
                    size: 25,
                    strokeWidth: 2,
                    color: Color.fromARGB(255, 169, 97, 14),
                  )),
                )
              : displayedFavourites.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(16),
                      itemCount: displayedFavourites.length + (isLoadingMore ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index < displayedFavourites.length) {
                          return _buildFavouriteCard(displayedFavourites[index], index);
                        } else {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 20),
                            child: Center(
                                child: ZLoadingIndicator(
                              size: 22,
                              strokeWidth: 2,
                              color: Color.fromARGB(255, 169, 97, 14),
                            )),
                          );
                        }
                      }),
        ),
      ),
    );
  }

  Widget _buildFavouriteCard(Map<String, dynamic> favourite, int index) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: context.isDarkMode ? const Color(0xFF2A2A2A) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.network(
            favourite["houseImg"],
            width: 60,
            height: 60,
            fit: BoxFit.cover,
          ),
        ),
        title: Text(
          favourite["houseName"],
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: context.isDarkMode ? Colors.white : Colors.black,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              "Location: ${favourite["location"]}",
              style: TextStyle(
                fontSize: 13,
                color: context.isDarkMode ? Colors.grey.shade400 : Colors.grey[700],
              ),
            ),
            Text(
              "Price: UGX ${favourite["price"]}",
              style: TextStyle(
                fontSize: 13,
                color: context.isDarkMode ? Colors.grey.shade400 : Colors.grey[700],
              ),
            ),
            Text(
              "Rating: ${favourite["rating"]}",
              style: TextStyle(
                fontSize: 12,
                color: context.isDarkMode ? Colors.grey.shade500 : Colors.grey[500],
              ),
            ),
          ],
        ),
        trailing: IconButton(
          icon: Icon(Icons.favorite, color: Colors.red),
          onPressed: () {
            // Remove from favourites
            setState(() {
              displayedFavourites.removeAt(index);
            });
          },
        ),
        onTap: () {
          // Navigate to item details
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.favorite_border,
            size: 80,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 20),
          Text(
            "No favourites yet",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            "Add properties to your favourites to see them here",
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
