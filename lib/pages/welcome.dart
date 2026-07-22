import 'package:flutter/material.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'package:zcanopy/pages/homeScreen.dart';
import 'package:zcanopy/services/api_service.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:zcanopy/widgets/themed_page_background.dart';

class OnBoardingScreen extends StatefulWidget {
  const OnBoardingScreen({super.key});

  @override
  State<OnBoardingScreen> createState() => _OnBoardingScrren();
}

class _OnBoardingScrren extends State<OnBoardingScreen> {
  final PageController _ctrl = PageController();
  bool isLastPage = false;
  bool _starting = false;
  final database = Hive.box('myStore');
  var userID;

  @override
  void initState() {
    super.initState();

    userID = database.get('userID');
  }

  Future<void> _getStarted() async {
    if (_starting) return;
    setState(() => _starting = true);

    // Customers are anonymous: ensure a tracking session exists, then go home.
    await ApiService().ensureCustomerSession();

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => BottomNavBar()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ThemedPageBackground(
        lightOverlay: true,
        child: Stack(
          alignment: Alignment.bottomCenter,
          children: [
            PageView(
              controller: _ctrl,
              onPageChanged: (index) {
                setState(() {
                  isLastPage = (index == 2);
                });
              },
              children: [
                buildPage(image: 'assets/welcome2.png'),
                buildPage(image: 'assets/info2.jpg'),
                buildPage(image: 'assets/map2.jpg'),
              ],
            ),

            //this is a page indicator
            Positioned(
              bottom: 80,
              child: SmoothIndicator(
                // controller:_ctrl,
                offset: 10.0, //not sure of this
                size: Size(20.0, 20.0),
                count: 3,
                effect: WormEffect(
                  dotHeight: 10,
                  dotWidth: 10,
                  activeDotColor: Colors.white,
                  dotColor: Colors.white54,
                ),
              ),
            ),

            //buttons
            Positioned(
              bottom: 20,
              child: SizedBox(
                width: 300,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    //        padding: const EdgeInsets.symmetric(  horizontal: 40, vertical: 12),
                    backgroundColor: Color.fromARGB(255, 169, 97, 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  onPressed: () {
                    if (isLastPage) {
                      _getStarted();
                    } else {
                      _ctrl.nextPage(
                        duration: const Duration(milliseconds: 400),
                        curve: Curves.easeInOut,
                      );
                    }
                  },
                  child: _starting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          isLastPage ? 'Get Started' : 'Next',
                          style: TextStyle(color: Colors.white),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Widget buildPage({required String image}) {
  return SizedBox(child: Image.asset(image, fit: BoxFit.cover));
}
