import 'package:flutter/material.dart';
import 'package:zcanopy/pages/welcome.dart';
import 'package:zcanopy/pages/loadIndicator.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:zcanopy/pages/itemDetails.dart';
import 'package:zcanopy/pages/session.dart';
import 'package:zcanopy/utils/currency.dart';
import 'package:zcanopy/utils/theme_extensions.dart';
import 'package:zcanopy/services/gateway_api.dart';

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
  final _api = GatewayApi();
  int _page = 1;
  bool _hasMore = true;
  var userID;

  List<Map<String, dynamic>> favourites = [];

  /// Maps a normalised gateway property onto the keys the card renders.
  Map<String, dynamic> _toCard(Map<String, dynamic> property) {
    final images = property['images'];
    final image = images is List && images.isNotEmpty
        ? images.first.toString()
        : (property['image'] ?? '').toString();
    return {
      ...property,
      'id': (property['id'] ?? '').toString(),
      'houseName': (property['name'] ?? property['houseName'] ?? 'Property')
          .toString(),
      'location': (property['location'] ?? '').toString(),
      'price': property['price'] ?? 0,
      'houseImg': image,
      'rating': property['rating'] ?? 0,
      'type': (property['type'] ?? '').toString(),
    };
  }

  @override
  void initState() {
    super.initState();
    loadInitialData();
    userID = database.get('userID');

    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
              _scrollController.position.maxScrollExtent - 200 &&
          !isLoadingMore &&
          _hasMore) {
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
      if (mounted) await forceLogout(context);
      return;
    }

    setState(() => isLoading = true);
    try {
      final data = await _api.getFavorites(page: 1, limit: itemsPerPage);
      final list = _extract(data);
      if (mounted) {
        setState(() {
          favourites = list;
          displayedFavourites = list.take(itemsPerPage).toList();
          _page = 1;
          _hasMore = list.length >= itemsPerPage;
          isLoading = false;
        });
      }
    } on ApiException catch (e) {
      print('Error loading favorites: ${e.message}');
      if (mounted) {
        setState(() {
          favourites = [];
          displayedFavourites = [];
          isLoading = false;
          isLoadingMore = false;
        });
      }
    } catch (e) {
      print('Error loading favorites: $e');
      if (mounted) {
        setState(() {
          displayedFavourites = favourites.take(itemsPerPage).toList();
          isLoading = false;
          isLoadingMore = false;
        });
      }
    }
  }

  List<Map<String, dynamic>> _extract(Map<String, dynamic> data) {
    final raw = data['favourites'] ?? data['favorites'] ?? data['properties'];
    if (raw is! List) return [];
    return raw
        .whereType<Map>()
        .map((e) => _toCard(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<void> loadMoreData() async {
    if (!_hasMore || isLoadingMore) return;
    setState(() => isLoadingMore = true);
    try {
      final data =
          await _api.getFavorites(page: _page + 1, limit: itemsPerPage);
      final list = _extract(data);
      if (mounted) {
        setState(() {
          _page++;
          favourites.addAll(list);
          displayedFavourites.addAll(list);
          _hasMore = list.length >= itemsPerPage;
          isLoadingMore = false;
        });
      }
    } catch (e) {
      print('Error loading more favorites: $e');
      if (mounted) setState(() => isLoadingMore = false);
    }
  }

  Future<void> _removeFavorite(String propertyId, int index) async {
    setState(() {
      if (index < displayedFavourites.length) {
        displayedFavourites.removeAt(index);
      }
      favourites.removeWhere((f) => f['id'] == propertyId);
    });
    try {
      await _api.toggleFavorite(propertyId: propertyId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Removed from favorites"),
          backgroundColor: Colors.green,
        ),
      );
    } on ApiException catch (e) {
      print('Error removing favorite: ${e.message}');
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
            favourite["houseImg"]?.toString() ?? '',
            errorBuilder: (_, __, ___) => Container(
              width: 60,
              height: 60,
              color: Colors.grey.shade200,
              child: const Icon(Icons.home_outlined, color: Colors.grey),
            ),
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
              "Price: ${formatUgx(favourite["price"])}",
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
          onPressed: () =>
              _removeFavorite(favourite['id'].toString(), index),
        ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PropertyDetailsPage(property: favourite),
            ),
          );
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
