import 'package:flutter/material.dart';
import 'package:zcanopy/pages/welcome.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:intl_phone_field/phone_number.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:zcanopy/pages/phoneOTP.dart';
import 'package:zcanopy/pages/session.dart';
import 'package:zcanopy/services/gateway_api.dart';
import 'package:zcanopy/widgets/themed_page_background.dart';
import 'package:zcanopy/utils/theme_extensions.dart';

class ProfileFormPage extends StatefulWidget {
  const ProfileFormPage({super.key});

  @override
  State<ProfileFormPage> createState() => _ProfileFormPageState();
}

class _ProfileFormPageState extends State<ProfileFormPage> {
  final _formKey = GlobalKey<FormState>();
  final database = Hive.box('myStore');
  final _api = GatewayApi();
  String username = '';
  String email = '';
  String photoURL = '';

  // Controllers
  final TextEditingController firstNameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController ninController = TextEditingController();

  String? selectedAccountType = 'tenant';
  bool _isRegistering = false;
  String phoneNumber = '';

  @override
  void initState() {
    super.initState();
 

      setState((){
   username = database.get('username')!=null ?database.get('username'):'none';
    email = database.get('email')!=null ? database.get('email') :'none';
   
      firstNameController.text=username;
      emailController.text=email;
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

  Future<void> _updateUserProfile() async {
     final isSessionValid = await SessionService.validateSession();
    if (!isSessionValid) {
      await forceLogout(context);
    }
   
    if (_isRegistering) return;
    setState(() => _isRegistering = true);
    try {
      final phone = phoneController.text;

      // Update account type
      final response = await _api.updateAccountType(
        userId: database.get('userID'),
        accountType: selectedAccountType ?? 'tenant',
        phoneNumber: phone,
      );

      if (response['success'] == true) {
        // Save user info
        await _api.saveUserInfo(
          userId: database.get('userID'),
          username: username,
          email: email,
          phoneNumber: phone,
          photoURL: photoURL,
        );

        setState(() {
          database.put('userName', firstNameController.text);
          database.put('email', emailController.text);
          database.put('phoneNumber', phoneController.text);
          database.put('accountType', selectedAccountType);

          if (response['verificationID'] != null) {
            Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                    builder: (_) => PhoneOtpScreen(
                          phoneNumber: phone,
                          verificationId: response['verificationID'],
                        )));
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text("Profile updated successfully!")),
            );
          }
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response['message'] ?? "Failed to update profile"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      debugPrint("Network error: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Network error. Please try again."),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isRegistering = false);
    }
  }

  @override
  Widget build(BuildContext context) {
     String?  photoUrl=database.get('photoURL')!=null ? database.get('photoURL') :'none';
    

    return Scaffold(
      appBar: AppBar(
        leading: BackButton(color: context.appOnSurface),
        title: Text("Select your account Type",
            style: TextStyle(color: context.appOnSurface)),
        backgroundColor: context.appSurface,
        elevation: 0,
      ),
      body: ThemedPageBackground(
        lightOverlay: true,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                 // Profile image
                 Stack(
                   alignment: Alignment.center,
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
                    Positioned(
                      bottom: 10,
                      right: 10,
                      child: Container(
                        decoration: const BoxDecoration(
                          color: Color.fromARGB(255, 169, 97, 14),
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.edit,
                              color: Colors.white, size: 20),
                          onPressed: () {
                            // Pick image from gallery or camera
                          },
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 30),

                // First Name
                SizedBox(
                  width: 300,
                  child: TextFormField(
                    controller: firstNameController,
                    decoration: InputDecoration(
                        contentPadding:
                            EdgeInsets.symmetric(vertical: 4, horizontal: 12),
                        labelText: "${username}",
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                              color: Color.fromARGB(255, 169, 97, 14)),
                        ),
                        filled: true,
                        enabled:false,
                        fillColor: Color.fromARGB(255, 183, 183, 183),
                        labelStyle:
                            TextStyle(color: context.appPrimaryBrown),
                        floatingLabelStyle:
                            TextStyle(color: context.appPrimaryBrown),
                        focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(10)),
                            borderSide: BorderSide(
                                color: context.appPrimaryBrown,
                                width: 1.5))),
                    validator: (value) => value == null || value.isEmpty
                        ? "Enter username"
                        : null,
                  ),
                ),

                const SizedBox(height: 20),

                // Last Name
                SizedBox(
                  width: 300,
                  child: TextFormField(
                    controller: emailController,
                    decoration: InputDecoration(
                      contentPadding:
                          EdgeInsets.symmetric(vertical: 4, horizontal: 12),
                      labelText: "${email}",

                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            BorderSide(color: context.appPrimaryBrown),
                      ),
                      labelStyle:
                          TextStyle(color: context.appPrimaryBrown),
                      floatingLabelStyle:
                          TextStyle(color: context.appPrimaryBrown),
                      focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(10)),
                          borderSide: BorderSide(
                              color: context.appPrimaryBrown,
                              width: 1.5)),
                      filled: true,
                       enabled:false,
                      fillColor: context.appInputFillColor,
                    ),
                    validator: (value) => value == null || value.isEmpty
                        ? "Enter email"
                        : null,
                  ),
                ),

                const SizedBox(height: 20),

                // accoun type Dropdown
                SizedBox(
                  width: 300,
                  child: DropdownButtonFormField<String>(
                    value: selectedAccountType,
                    decoration: InputDecoration(
                      contentPadding:
                          EdgeInsets.symmetric(vertical: 4, horizontal: 12),
                      labelText: "Account Type",
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            BorderSide(color: Color.fromARGB(255, 169, 97, 14)),
                      ),
                      labelStyle: TextStyle(color: Colors.grey),
                      floatingLabelStyle:
                          TextStyle(color: Color.fromARGB(255, 169, 97, 14)),
                      focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(10)),
                          borderSide: BorderSide(
                              color: Color.fromARGB(255, 169, 97, 14),
                              width: 1.5)),
                      filled: true,
                      fillColor: context.appInputFillColor,
                    ),
                    items: ["LandLord", "tenant"]
                        .map((gender) => DropdownMenuItem(
                            value: gender, child: Text(gender)))
                        .toList(),
                    onChanged: (value) {
                      database.put('accountType', value);
                      setState(() => selectedAccountType = value);
                    },
                    validator: (value) =>
                        value == null ? "Select your account type" : null,
                  ),
                ),

                const SizedBox(height: 20),

// Phone Number with country picker
                selectedAccountType == 'LandLord'
                    ? SizedBox(
                        width: 300,
                        child: IntlPhoneField(
                          controller: phoneController,
                          decoration: InputDecoration(
                            contentPadding: EdgeInsets.symmetric(
                                vertical: 4, horizontal: 12),
                            labelText: "Phone",
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                  color: Color.fromARGB(255, 169, 97, 14)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                  color: Color.fromARGB(255, 169, 97, 14),
                                  width: 2),
                            ),
                               filled: true,
                             fillColor: context.appInputFillColor,
                          ),
                          initialCountryCode: "UG", // default country
                          onChanged: (phone) {
                            setState(() {
                            //  phoneNumber= phone;
                            });

                            print(phone
                                .completeNumber); // full number with country code
                          },
                          onSaved: (phone) {
                            print("Saved number: ${phone?.completeNumber}");
                          },
                          validator: (phone) {
                            if (phone == null || 
                            phone.number.length<10 ||
                            phone.number.length>12 ||
                                phone.number.isEmpty &&
                                    selectedAccountType == 'LandLord') {
                              return "Enter phone number";
                            }
                            return null;
                          },
                        ),
                      )
                    : Text(''),

                const SizedBox(height: 20),

                const SizedBox(height: 40),

                // Continue Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      backgroundColor: Color.fromARGB(255, 169, 97, 14),
                    ),
                    onPressed: () async {
                      if (!_formKey.currentState!.validate()) return;
                      await _updateUserProfile();
                    },
                    child: const Text(
                      "Continue",
                      style: TextStyle(fontSize: 18, color: Colors.white),
                    ),
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
