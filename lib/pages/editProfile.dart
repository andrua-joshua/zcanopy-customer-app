import 'package:flutter/material.dart';
import 'package:zcanopy/pages/welcome.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:hive_flutter/hive_flutter.dart';
import 'package:zcanopy/pages/network.dart';
import 'package:zcanopy/pages/session.dart';
import 'package:zcanopy/widgets/themed_page_background.dart';
import 'package:zcanopy/utils/theme_extensions.dart';

class ProfilePageEdit extends StatefulWidget {
  const ProfilePageEdit({super.key});

  @override
  State<ProfilePageEdit> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePageEdit> {

  DateTime dateOfBirth = DateTime(1990, 1, 1);
  final database = Hive.box("myStore");

    // Sample user data - in a real app this would come from a provider or API
  String fullName ="kevin Delos";
  String userName = "delos";
  String accountType = "tenant";
  String email = "tezoschain@gmail.com.com";
  String phone = "0741882818";
  String ninNumber = "NIN1234567890";
  String country = "Uganda";

  bool isDeleting = false;
  bool _isLoading = false;
  bool isUserInDB = false;

  // Controller for phone number editing
  late TextEditingController _phoneController;

  Future<void> _fetchUserBio() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    try {
      final url =
          Uri.parse("https://my-server-url/get-user-bio-data?userID=1234");

      final response = await http.get(url);

      if (response.statusCode == 200) {
        var data = json.decode(response.body);

        setState(() {
          if (data.isNotEmpty) {
            fullName = data['fullName'];
            userName = data['username'];
            accountType = data['accountType'];
            email = data['email'];
            phone = data['phone'];
            country = data['country'];
          }
        });
      } else {
        debugPrint("Error: ${response.statusCode}");
      }
    } catch (e) {
      debugPrint("Network error: $e");
    } finally {}
  }

  @override
  void initState() {
    super.initState();
    _phoneController = TextEditingController(text: phone);
    isUserInDB = database.get('userID') != null ? true : false;

    if (!isUserInDB) {
  
    } else {
      //fullName = database.get('fullName');
      userName = database.get('username');
      accountType = database.get('accountType');
      email = database.get('email');
      phone = database.get('phoneNumber');
     // country = database.get('country');
    }
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

  postData(payload) async {
  final isSessionValid = await SessionService.validateSession();
    if (!isSessionValid) {
      if (mounted) {
        await forceLogout(context);
      }
    }

    try {
      final data = await NetworkService.post(
          'http://127.0.0.1:4000/gate-way/delete-user-account', payload);
      return data;
    } catch (e) {
      print(e);
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
   String?  photoUrl=database.get('photoURL')!=null ? database.get('photoURL') :'none';

     return Scaffold(
      appBar: AppBar(
        title: Text(
          "Profile",
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        backgroundColor: context.appPrimaryBrown,
        foregroundColor: Colors.white,
      ),
      body: ThemedPageBackground(
        lightOverlay: true,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(2),
          child: Column(
            children: [
            // Profile Avatar with edit button
            Stack(
              alignment: Alignment.bottomRight,
              children: [
                            CircleAvatar(
      radius: 60,
      backgroundColor: Colors.grey.shade400,
      backgroundImage: photoUrl != null && photoUrl.isNotEmpty
          ? NetworkImage(photoUrl) // Load from Firebase URL
          : null, // No image available
      child: (photoUrl == null || photoUrl.isEmpty)
          ? Icon(Icons.person, size: 60, color: Colors.white) // fallback
          : null,
    ),
                CircleAvatar(
                  radius: 16,
                  backgroundColor: Colors.brown,
                  child: const Icon(Icons.edit, color: Colors.white, size: 16),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // User information summary (read-only)
         //   _buildReadOnlyField("Full Name", fullName),
        //    const SizedBox(height: 2),
            _buildReadOnlyField("User Name", userName),
            const SizedBox(height: 2),
            _buildReadOnlyField("Account Type", accountType),
            const SizedBox(height: 2),
            _buildReadOnlyField("Email", email),
            const SizedBox(height: 2),
            // Phone number (editable)
           _buildReadOnlyField("Phone Number", phone),
         //   _buildEditablePhoneField(),
            const SizedBox(height: 2),
            _buildReadOnlyField("Country", country),
            //    _buildReadOnlyField("Date of Birth", "${dateOfBirth.day}/${dateOfBirth.month}/${dateOfBirth.year}"),

            const SizedBox(height: 30),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red, // Changed to red for delete
                padding:
                    const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _confirmDeleteAccount,
              child: Text("Delete Account",
                  style: GoogleFonts.poppins(
                      fontSize: 16,
                      color: Colors.white,
                      fontWeight: FontWeight.w600)),
            ),
           ],
        ),
      ),
    ));
  }

  Widget _buildReadOnlyField(String label, String value) {
    return Container(
        color: context.appCardColor,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 16,
                  color: context.appPrimaryBrown,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: context.appDividerColor),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  value,
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ],
          ),
        ));
  }

  Widget _buildEditablePhoneField() {
    return Container(
        color: context.appCardColor,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Phone Number",
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 16,
                  color: Colors.brown,
                ),
              ),
              const SizedBox(height: 4),
              TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  contentPadding: const EdgeInsets.all(12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.brown),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.brown, width: 2),
                  ),
                ),
                onChanged: (value) {
                  setState(() {
                    phone = value;
                  });
                },
              ),
            ],
          ),
        ));
  }

  void _confirmDeleteAccount() {
    final clientEmail = database.get('email');

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(5.0),
          ),
          backgroundColor: Colors.black87,
          title: const Text("Delete Account",
              style: TextStyle(color: Colors.white)),
          content: const Text(
              "Are you sure you want to delete your account? This action cannot be undone.",
              style: TextStyle(color: Colors.white)),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog
              },
              child:
                  const Text("Cancel", style: TextStyle(color: Colors.white)),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog
                database.clear();
                _deleteAccount();
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const OnBoardingScreen()),
                  (route) => false,
                );
              },
              child: const Text("Delete", style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  void _deleteAccount() {
    // In a real app, you would call your API to delete the account
    // and then navigate to the login screen or similar
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Account deleted successfully"),
        backgroundColor: Colors.red,
      ),
    );

    // Navigate to login screen or home screen
    // Navigator.pushAndRemoveUntil(
    //   context,
    //   MaterialPageRoute(builder: (context) => LoginScreen()),
    //   (route) => false,
    // );
  }
}
