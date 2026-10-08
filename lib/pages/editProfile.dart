import 'package:flutter/material.dart';
import 'package:zcanopy/pages/welcome.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:zcanopy/services/gateway_api.dart';
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
  bool isUserInDB = false;

  // Controller for phone number editing
  late TextEditingController _phoneController;

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
              onPressed: () async {
                Navigator.of(context).pop(); // Close dialog
                final deleted = await _deleteAccount();
                if (!deleted) return;
                await database.clear();
                if (!mounted) return;
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

  /// Requests a one-time deletion code and then deletes the account on the
  /// gateway. Returns true when the account was deleted.
  Future<bool> _deleteAccount() async {
    final userId = database.get('userID')?.toString() ?? '';
    if (userId.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("No account to delete on this device")),
        );
      }
      return false;
    }

    if (mounted) setState(() => isDeleting = true);
    try {
      await GatewayApi().requestAccountDeletionOtp(userId: userId);
      final response = await GatewayApi().deleteUserAccount(userId: userId);
      final ok = response['success'] == true || response['error'] == null;
      if (mounted) {
        setState(() => isDeleting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ok
                ? "Account deleted successfully"
                : (response['message']?.toString() ?? "Account deletion failed")),
            backgroundColor: Colors.red,
          ),
        );
      }
      return ok;
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => isDeleting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
      return false;
    } catch (e) {
      print('Delete account error: $e');
      if (mounted) {
        setState(() => isDeleting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Could not delete account")),
        );
      }
      return false;
    }
  }
}
