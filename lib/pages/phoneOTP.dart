import 'dart:async';
import 'package:zcanopy/pages/network.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:zcanopy/pages/profile.dart';
import 'package:pinput/pinput.dart';
import 'package:zcanopy/pages/homeScreen.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:zcanopy/services/api_service.dart';
import 'package:zcanopy/widgets/themed_page_background.dart';
import 'package:zcanopy/utils/theme_extensions.dart';

class PhoneOtpScreen extends StatefulWidget {
  final String phoneNumber;
  final String verificationId;
  final VoidCallback? onVerified;

  const PhoneOtpScreen({
    super.key,
    required this.phoneNumber,
    required this.verificationId,
    this.onVerified,
  });

  @override
  State<PhoneOtpScreen> createState() => _PhoneOtpScreenState();
}

class _PhoneOtpScreenState extends State<PhoneOtpScreen> {
  List<String> otp = ["", "", "", "", "", ""]; // 6-digit OTP
  int secondsRemaining = 60;
  bool enableResend = false;
  late String _verificationId;
  final TextEditingController otpController = TextEditingController();
  final _apiService = ApiService();

  final database = Hive.box('myStore');

  @override
  void initState() {
    super.initState();
    _verificationId = widget.verificationId;
    initOneTimeCode();
    startTimer();
  }

  void initOneTimeCode() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text("one time otp sent!"),
          backgroundColor: Color.fromARGB(255, 169, 97, 14)),
    );

    // DEV: no real OTP backend for the delinked login flow.
    if (_verificationId == 'dev-verification-id') return;

    try {
      final response = await _apiService.requestPhoneOTP(
        userId: database.get('userID'),
      );
      if (response['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("phone verification code sent!"),
            backgroundColor: Color.fromARGB(255, 169, 97, 14),
          ),
        );
      }
    } catch (e) {
      print('Error requesting phone OTP: $e');
    }
  }

  void startTimer() {
    Timer.periodic(const Duration(seconds: 1), (timer) {
      if (secondsRemaining == 0) {
        setState(() {
          enableResend = true;
        });
        timer.cancel();
      } else {
        setState(() {
          secondsRemaining--;
        });
      }
    });
  }

  void _verifyCode() async {
    String smsCode = otpController.text;

    // DEV: bypass backend when no real verification id is available.
    if (_verificationId == 'dev-verification-id') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Phone verification successful!")),
      );
      database.put('phoneNumber', widget.phoneNumber);
      if (widget.onVerified != null) {
        widget.onVerified!();
        Navigator.pop(context);
      } else {
        Navigator.pushReplacement(
            context, MaterialPageRoute(builder: (_) => BottomNavBar()));
      }
      return;
    }

    try {
      final result = await _apiService.verifyPhoneOTP(
        verificationID: _verificationId,
        userId: database.get('userID'),
        code: smsCode,
      );

      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Phone verification successful!")),
        );

        if (widget.onVerified != null) {
          widget.onVerified!();
          Navigator.pop(context);
        } else {
          Navigator.pushReplacement(
              context, MaterialPageRoute(builder: (_) => BottomNavBar()));
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message'] ?? "Verification failed")),
        );
      }
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Verification failed: ${e.message}")),
      );

      database.put('phoneNumber', 'unavailable');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Network error: $e")),
      );
    }
  }

  void _resendCode() async {
    // DEV: no real OTP backend for the delinked login flow.
    if (_verificationId == 'dev-verification-id') {
      setState(() {
        secondsRemaining = 60;
        enableResend = false;
      });
      startTimer();
      return;
    }
    try {
      final result = await _apiService.resendPhoneOTP(
        verificationID: _verificationId,
        userId: database.get('userID'),
      );
      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("OTP has been resent, check your phone")),
        );
        setState(() {
          secondsRemaining = 60;
          enableResend = false;
        });
        startTimer();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Something went wrong..retry")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to resend OTP")),
      );
    }
  }

  Widget _otpBox(int index) {
    return Container(
      width: 50,
      height: 60,
      alignment: Alignment.center,
      margin: const EdgeInsets.symmetric(horizontal: 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: otp[index].isEmpty
              ? Colors.grey
              : Color.fromARGB(255, 169, 97, 14),
          width: 2,
        ),
      ),
      child: Text(
        otp[index],
        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
      ),
    );
  }

  void _onKeyboardTap(String value) {
    setState(() {
      for (int i = 0; i < otp.length; i++) {
        if (otp[i].isEmpty) {
          otp[i] = value;
          break;
        }
      }
    });
  }

  void _onBackspace() {
    setState(() {
      for (int i = otp.length - 1; i >= 0; i--) {
        if (otp[i].isNotEmpty) {
          otp[i] = "";
          break;
        }
      }
    });
  }

  Widget _buildKeyboard() {
    List<String> keys = [
      "1",
      "2",
      "3",
      "4",
      "5",
      "6",
      "7",
      "8",
      "9",
      "*",
      "0",
      "<",
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 2,
      ),
      itemCount: keys.length,
      itemBuilder: (context, index) {
        String key = keys[index];
        return InkWell(
          onTap: () {
            if (key == "<") {
              _onBackspace();
            } else {
              _onKeyboardTap(key);
            }
          },
          child: Center(
            child: key == "<"
                ? const Icon(Icons.backspace_outlined)
                : Text(
                    key,
                    style: const TextStyle(fontSize: 22),
                  ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: const Text("OTP Code Verification"),
        ),
        body: ThemedPageBackground(
          lightOverlay: true,
          child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    const SizedBox(height: 20),
                    Text(
                      "Code has been sent to ${widget.phoneNumber}",
                      style: const TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 30),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Pinput(
                          length: 4, // number of digits
                          controller: otpController,
                          showCursor: true,
                          onCompleted: (value) {
                            print("Entered OTP: $value");
                            // TODO: verify with Firebase or your backend
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    enableResend
                        ? TextButton(
                            onPressed: _resendCode,
                            child: const Text(
                              "Resend code",
                              style: TextStyle(
                                color: Color.fromARGB(255, 169, 97, 14),
                              ),
                            ),
                          )
                        : Text(
                            "Resend code in $secondsRemaining s",
                            style: const TextStyle(
                              color: Color.fromARGB(255, 169, 97, 14),
                            ),
                          ),
                    const SizedBox(height: 30),
                    ElevatedButton(
                      onPressed: _verifyCode,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color.fromARGB(255, 169, 97, 14),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 40, vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30)),
                      ),
                      child: const Text(
                        "Verify",
                        style: TextStyle(fontSize: 18, color: Colors.white),
                      ),
                    ),
                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ));
  }
}
