import 'package:flutter/material.dart';
import 'package:zcanopy/pages/welcome.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:zcanopy/pages/session.dart';
import 'package:zcanopy/services/gateway_api.dart';
import 'package:zcanopy/widgets/themed_page_background.dart';
import 'package:zcanopy/utils/theme_extensions.dart';

class HelpCenterPage extends StatefulWidget {
  @override
  _HelpCenterPageState createState() => _HelpCenterPageState();
}

class _HelpCenterPageState extends State<HelpCenterPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String selectedCategory = "General";
  bool isSending = false;
  final _formKey = GlobalKey<FormState>();
  final TextEditingController nameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController subjectController = TextEditingController();
  final TextEditingController messageController = TextEditingController();

  final List<String> categories = ["General", "Account", "Service", "Payment"];
  final database = Hive.box('myStore');

  final List<Map<String, String>> faqs = [
    {
      "question": "What is zcanopy?",
      "answer":
          "Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua."
    },
    {
      "question": "How to make a payment?",
      "answer": "You can make a payment through your preferred payment method."
    },
    {
      "question": "How do I cancel booking?",
      "answer": "Go to My Booking and choose Cancel option."
    },
    {
      "question": "How do I delete my account?",
      "answer": "Please contact support team to delete your account."
    },
    {
      "question": "How do I exit the app?",
      "answer": "Simply press the back button or swipe up to close."
    },
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
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

  Future<void> sendUserData() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final isSessionValid = await SessionService.validateSession();
    if (!isSessionValid) {
      if (mounted) await forceLogout(context);
      return;
    }

    setState(() => isSending = true);

    final database = Hive.box('myStore');
    final subject = subjectController.text.trim();
    final message = messageController.text.trim();
    final content = subject.isEmpty
        ? message
        : '$subject\n$message';

    try {
      await GatewayApi().submitFeedback(
        email: emailController.text.trim(),
        phone: database.get('phoneNumber')?.toString() ?? '',
        content: content,
      );
      if (!mounted) return;
      setState(() {
        isSending = false;
        nameController.clear();
        emailController.clear();
        subjectController.clear();
        messageController.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("Message sent. We'll get back to you shortly."),
        backgroundColor: Color.fromARGB(255, 169, 97, 14),
      ));
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => isSending = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (e) {
      print('Feedback error: $e');
      if (!mounted) return;
      setState(() => isSending = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Could not send. Please try again.")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Text("Help Center", style: TextStyle(color: context.appOnSurface)),
          backgroundColor: context.appSurface,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: context.appOnSurface),
            onPressed: () {},
          ),
          actions: [
            IconButton(
              icon: Icon(Icons.more_horiz, color: context.appOnSurface),
              onPressed: () {},
            )
          ],
          bottom: TabBar(
            controller: _tabController,
            indicatorColor: Color.fromARGB(255, 169, 97, 14),
            labelColor: Colors.black,
            tabs: [
              Tab(text: "FAQ"),
              Tab(text: "Contact us"),
            ],
          ),
        ),
        body: ThemedPageBackground(
          lightOverlay: true,
          child: TabBarView(
                controller: _tabController,
                children: [
                  /// FAQ Tab
                  Column(
                    children: [
                      // Category Chips
                      Container(
                        height: 50,
                        margin: EdgeInsets.only(top: 10),
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: categories.length,
                          itemBuilder: (context, index) {
                            String category = categories[index];
                            bool isSelected = selectedCategory == category;
                            return Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 8),
                              child: ChoiceChip(
                                label: Text(category),
                                selected: isSelected,
                                selectedColor: Color.fromARGB(255, 169, 97, 14)
                                    .withOpacity(0.1),
                                onSelected: (selected) {
                                  setState(() {
                                    selectedCategory = category;
                                  });
                                },
                              ),
                            );
                          },
                        ),
                      ),

                      // Search bar
                      Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: TextField(
                          style: const TextStyle(color: Colors.black),
                          decoration: InputDecoration(
                            hintText: "Search",
                            prefixIcon: Icon(Icons.search),
                            suffixIcon: Icon(Icons.tune),
                            filled: true,
                            fillColor: context.appInputFillColor,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),

                      // FAQ List
                      Expanded(
                        child: ListView.builder(
                          itemCount: faqs.length,
                          itemBuilder: (context, index) {
                            return Card(
                              color: Color.fromARGB(255, 169, 97, 14),
                              margin: EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: ExpansionTile(
                                title: Text(
                                  faqs[index]["question"]!,
                                  style: TextStyle(color: Colors.white),
                                ),
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.all(12.0),
                                    child: Text(
                                      faqs[index]["answer"]!,
                                      style: TextStyle(color: Colors.white),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),

                  /// Contact Us Tab
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: ListView(
                      children: [
                        Text(
                          "We’re here to help",
                          style: TextStyle(
                              fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 20),

                        Form(
                          key: _formKey,
                          child:Column(
                            children: [
                            // Name
                            TextFormField(
                              controller: nameController,
                              style: const TextStyle(color: Colors.black),
                              decoration: InputDecoration(
                                labelText: "Name",
                                filled: true,
                                fillColor: Colors.grey.shade100,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                              validator: (value) =>
                                  value == null || value.isEmpty
                                      ? "Enter your names"
                                      : null,
                            ),
                            SizedBox(height: 12),

                            // Email
                            TextFormField(
                              controller: emailController,
                              style: const TextStyle(color: Colors.black),
                              decoration: InputDecoration(
                                labelText: "Email",
                                filled: true,
                                fillColor: Colors.grey.shade100,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                              validator: (value) =>
                                  value == null || value.isEmpty
                                      ? "Enter email"
                                      : null,
                            ),
                            SizedBox(height: 12),

                            // Subject
                            TextFormField(
                              controller: subjectController,
                              style: const TextStyle(color: Colors.black),
                              decoration: InputDecoration(
                                labelText: "Subject",
                                filled: true,
                                fillColor: Colors.grey.shade100,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                              validator: (value) =>
                                  value == null || value.isEmpty
                                      ? "Enter subject"
                                      : null,
                            ),
                            SizedBox(height: 12),

                            // Message
                            TextFormField(
                              controller: messageController,
                              maxLines: 5,
                              style: const TextStyle(color: Colors.black),
                              decoration: InputDecoration(
                                labelText: "Message",
                                alignLabelWithHint: true,
                                filled: true,
                                fillColor: Colors.grey.shade100,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                              validator: (value) =>
                                  value == null || value.isEmpty
                                      ? "Enter a message"
                                      : null,
                            ),
                            ],
                          ) 
                          
                          ),

                        
                        SizedBox(height: 20),

                        // Send Button
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Color.fromARGB(255, 169, 97, 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: () {
                              if (_formKey.currentState!.validate()) {
                                 // handle send action
                                sendUserData();
                              }

                            },
                            child: isSending
                                ? SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                    ))
                                : Text(
                                    "Send",
                                    style: TextStyle(
                                        fontSize: 16, color: Colors.white),
                                  ),
                          ),
                        ),
                       ],
                     ),
                   ),
                 ],
               ),
               )
             );
           
  }
}
