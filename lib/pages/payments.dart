import 'package:flutter/material.dart';
import 'package:zcanopy/pages/welcome.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:zcanopy/pages/loadIndicator.dart';
import 'package:zcanopy/pages/network.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:zcanopy/pages/session.dart';
import 'package:zcanopy/utils/theme_extensions.dart';
import 'package:zcanopy/services/api_service.dart';
import 'package:zcanopy/utils/colors.dart';

class PaymentsPage extends StatefulWidget {
  const PaymentsPage({super.key});

  @override
  State<PaymentsPage> createState() => _PaymentsPageState();
}

class _PaymentsPageState extends State<PaymentsPage> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController numberEditCtrl = TextEditingController();
  final database = Hive.box('myStore');
  final _apiService = ApiService();
  var userID;

  // Track the selected payment method
  int _selectedPaymentMethod = 0; // 0 for MTN, 1 for Airtel
  bool _isLoading = true;
  bool _isPaying = false;
  bool isLoading = false;
  bool isLoadingMore = false;
  final int TXNPerPage = 2;
  List<Map<String, dynamic>> displayedTXN = [];
  final _formKey = GlobalKey<FormState>();
  String phoneNumber = '';
  bool _isRetrieving = false;
  final TextEditingController _codeCtrl = TextEditingController();
  final TextEditingController _phoneRetrieveCtrl = TextEditingController();
  // Sample transaction data with IDs
  List<Map<String, dynamic>> _transactions = [
    {
      'id': 'TXN001',
      'amount': 'UGX 20,000 recieved',
      'method': 'MTN Mobile Money',
      'date': '2025-08-20',
      'status': 'Success',
      'color': Colors.green,
      "type": "transaction",
      "package": "fibrous",
    },
    {
      'id': 'TXN002',
      'amount': 'UGX 35,000 recieved',
      'method': 'Airtel Money',
      'date': '2025-08-18',
      'status': 'Failed',
      'color': Colors.red,
      "type": "transaction",
      "package": "prop",
    },
    {
      'id': 'TXN003',
      'amount': 'UGX 40,000 recieved',
      'method': 'MTN Mobile Money',
      'date': '2025-08-18',
      'status': 'Success',
      'color': Colors.green,
      "type": "transaction",
      "package": "fibrous",
    },
    {
      'id': 'TXN001',
      'amount': 'UGX 20,000 recieved',
      'method': 'MTN Mobile Money',
      'date': '2025-08-20',
      'status': 'Success',
      'color': Colors.green,
      "type": "transaction",
      "package": "buttress",
    },
    {
      'id': 'TXN002',
      'amount': 'UGX 35,000 recieved',
      'method': 'Airtel Money',
      'date': '2025-08-18',
      'status': 'Failed',
      'color': Colors.red,
      "type": "transaction",
      "package": "prop",
    },
    {
      'id': 'TXN003',
      'amount': 'UGX 40,000 recieved',
      'method': 'MTN Mobile Money',
      'date': '2025-08-18',
      'status': 'Success',
      'color': Colors.green,
      "type": "transaction",
      "package": "buttress",
    },
    {
      'id': 'TXN001',
      'amount': 'UGX 20,000 recieved',
      'method': 'MTN Mobile Money',
      'date': '2025-08-20',
      'status': 'Success',
      'color': Colors.green,
      "type": "transaction",
      "package": "fibrous",
    },
    {
      'id': 'TXN002',
      'amount': 'UGX 35,000 recieved',
      'method': 'Airtel Money',
      'date': '2025-08-18',
      'status': 'Failed',
      'color': Colors.red,
      "type": "transaction",
      "package": "prop",
    },
    {
      'id': 'TXN003',
      'amount': 'UGX 40,000 recieved',
      'method': 'MTN Mobile Money',
      'date': '2025-08-18',
      'status': 'Success',
      'color': Colors.green,
      "type": "transaction",
      "package": "fibrous",
    },
  ];

  Future<void> _getTransations() async {
    //network simulation
    await Future.delayed(const Duration(seconds: 2));
    setState(() {});
  }

  Future<void> _fetchItems({bool refresh = false}) async {
    if (_isLoading) return;

    if (refresh) {
      setState(() {
        _transactions.clear();
      });
    }

    setState(() => _isLoading = true);

    try {
      final response = await _apiService.getTransactionRecords(
        userId: userID,
      );

      if (response['success'] == true) {
        setState(() {
          final data = response['data'] as List? ?? [];
          if (data.isNotEmpty) {
            _transactions.addAll(data.map((e) => Map<String, dynamic>.from(e)));
          }
        });
      } else {
        debugPrint("Error: ${response['message']}");
      }
    } catch (e) {
      debugPrint("Network error: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _initiateMobileMoneyPayment() async {
    setState(() => _isPaying = true);

    try {
      final response = await _apiService.initiateMobileMoneyPayment(
        phoneNumber: phoneNumber,
        amount: '15000',
        userId: userID,
      );

      if (response['success'] == true) {
        setState(() {
          print("payment results: ${response}");
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Payment initiated successfully!"),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response['message'] ?? "Payment failed"),
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
      setState(() => _isPaying = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _getTransations();
    // Prefill retrieval fields from locally stored values (set after payment).
    _codeCtrl.text = database.get('customerCode')?.toString() ?? '';
    _phoneRetrieveCtrl.text = database.get('phoneNumber')?.toString() ?? '';
    final storedCode = _codeCtrl.text;
    final storedPhone = _phoneRetrieveCtrl.text;
    if (storedCode.isNotEmpty && storedPhone.isNotEmpty) {
      _retrievePayments(storedCode, storedPhone);
    } else {
      loadInitialData();
    }
    userID = database.get('userID');

    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
              _scrollController.position.maxScrollExtent - 200 &&
          !isLoadingMore &&
          displayedTXN.length < _transactions.length) {
        loadMoreData();
      }
    });
  }

  /// Retrieve the customer's previous payments using the unique code issued
  /// after a successful payment plus their phone number. The payment section
  /// only needs to render these stored records.
  Future<void> _retrievePayments(String code, String phone) async {
    if (code.trim().isEmpty || phone.trim().length < 9) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Enter both your code and phone number")),
      );
      return;
    }
    setState(() {
      _isRetrieving = true;
      _isLoading = true;
    });

    try {
      final data = await _apiService.getCustomerPaymentsByCode(
        code: code.trim(),
        phoneNumber: phone.trim(),
      );

      if (data['success'] == true) {
        final fetched = List<Map<String, dynamic>>.from(data['payments'] ?? []);
        setState(() {
          _transactions = fetched;
          displayedTXN = fetched.take(TXNPerPage).toList();
          _isRetrieving = false;
          _isLoading = false;
        });
      } else {
        setState(() {
          displayedTXN = _transactions.take(TXNPerPage).toList();
          _isRetrieving = false;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error retrieving payments: $e');
      setState(() {
        displayedTXN = _transactions.take(TXNPerPage).toList();
        _isRetrieving = false;
        _isLoading = false;
      });
    }
  }

  Future<void> loadInitialData() async {
    await Future.delayed(const Duration(seconds: 2));

    setState(() {
      displayedTXN = _transactions.take(TXNPerPage).toList();
      isLoading = false;
      _isLoading = false;
    });
  }

  Future<void> loadMoreData() async {
    /*
    final data = await fetchData(userID);
    setState(() {
    _transactions = data.transactions;     
      isLoadingMore=data.isLoadingMore;
    });*/

    setState(() => isLoadingMore = true);
    await Future.delayed(const Duration(seconds: 2));
    setState(() {
      final start = displayedTXN.length;
      final end = (start + TXNPerPage).clamp(0, _transactions.length);
      displayedTXN.addAll(_transactions.sublist(start, end));
      isLoadingMore = false;
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

  Future<bool> initiatePayment() async {
    final isSessionValid = await SessionService.validateSession();
    if (!isSessionValid) {
      if (mounted) {
        await forceLogout(context);
      }
    }

    setState(() {
      _isPaying = true;
    });

    final payload = {
      "userID": database.get('userID'),
      "amount": database.get('amount'),
      "package": database.get('package'),
      "status": database.get('status'),
    };

    final response = await postData(payload);
    if (response.success) {
      database.add({"subscriptionStatus", "${response.status}"});
      database.add({"amount", response.amount});
      database.add({"package", "${response.package}"});
      database.add({"remainingDays", response.remainingDays});
      database.add({"totalDays", response.totalDays});
      database.add({
        "dataAvailable",
        true,
      }); //to retrieve instead of accessing the net again

      setState(() {
        _isPaying = false;
      });

      return true;
    } else {
      setState(() {
        _isPaying = false;
      });

      return false;
    }
  }

  fetchData(userID) async {
    try {
      final data = await NetworkService.get(
        'http://127.0.0.1:4000/payment/get-transaction-records?user_id=${userID}',
      );
      return data;
    } catch (e) {
      print(e);
    }
  }

  postData(payload) async {
    try {
      final data = await NetworkService.post(
        'http://127.0.0.1:4000/gate-way/initiate-payment',
        payload,
      );
      return data;
    } catch (e) {
      print(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          "Payments",
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: Colors.brown,
        centerTitle: true,
        elevation: 0,
      ),
      body: Container(
        decoration: context.isDarkMode
            ? BoxDecoration(color: Theme.of(context).scaffoldBackgroundColor)
            : BoxDecoration(
                image: DecorationImage(
                  image: AssetImage('assets/background.jpg'),
                  fit: BoxFit.cover,
                ),
              ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildRetrievalCard(),
              const SizedBox(height: 16),
              // Current Payment Summary
             /* Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFf6d365), Color(0xFFfda085)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8)],
                ),
                child: Row(
                  children: [
                
                /*    const Icon(
                      Icons.account_balance_wallet,
                      size: 40,
                      color: Colors.white,
                    ),*/
                    const SizedBox(width: 12),
                 /*   Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Current Payment",
                          style: GoogleFonts.poppins(
                            color: Colors.white70,
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          _selectedPaymentMethod == 0
                              ? "MTN Mobile Money"
                              : "Airtel Money",
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),*/
                  ],
                ),
              ),
              */

/*
              const SizedBox(height: 20),
              Text(
                "Select Payment Method",
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                  color: context.isDarkMode ? Colors.white : Colors.black87,
                ),
              ),

              const SizedBox(height: 12),
              // Payment Method Options
              paymentOption(
                "MTN Mobile Money",
                _selectedPaymentMethod == 0,
                Colors.yellow.shade700,
                Icons.phone_android,
                0,
              ),
              paymentOption(
                "Airtel Money",
                _selectedPaymentMethod == 1,
                Colors.red.shade600,
                Icons.phone_iphone,
                1,
              ),

              const SizedBox(height: 20),
              // Input Field
              Form(
                key: _formKey,
                child: TextFormField(
                  controller: numberEditCtrl,
                  keyboardType: TextInputType.phone,
                  style: TextStyle(
                    color: context.isDarkMode ? Colors.white : Colors.black87,
                  ),
                  decoration: InputDecoration(
                    contentPadding: EdgeInsets.all(10),
                    prefixIcon: const Icon(Icons.phone),
                    hintText: "Enter Mobile Number(075**)",
                    hintStyle: TextStyle(
                      color: context.isDarkMode
                          ? Colors.grey.shade400
                          : Colors.grey.shade600,
                    ),
                    filled: true,
                    fillColor: context.appInputFillColor,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.yellow),
                    ),
                  ),
                  onChanged: (value) => phoneNumber = value,
                  validator: (val) => val != null && val.length == 10
                      ? null
                      : '10 digits are required',
                ),
              ),

              const SizedBox(height: 20),
              // Pay Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    if (_formKey.currentState!.validate()) {
                      final response = await initiatePayment();
                      if (response) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("Your Payment was successfull"),
                            backgroundColor: Colors.green,
                          ),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              "Something went wrong,payment failed",
                            ),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    backgroundColor: Colors.brown,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: !_isPaying
                      ? Text(
                          "Pay Now",
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        )
                      : SizedBox(
                          width: 25,
                          height: 25,
                          child: CircularProgressIndicator(color: Colors.white),
                        ),
                ),
              ),
              */

              const SizedBox(height: 25),
              Text(
                "Previous Transactions",
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                  color: context.isDarkMode ? Colors.white : Colors.black87,
                ),
              ),

              const SizedBox(height: 10),
              // Display transactions with IDs
              _isLoading
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: Center(
                        child: CircularProgressIndicator(
                          color: Color.fromARGB(255, 169, 97, 14),
                        ),
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      physics: NeverScrollableScrollPhysics(),
                      controller: _scrollController,
                      padding: EdgeInsets.all(0),
                      itemCount: displayedTXN.length + (isLoadingMore ? 3 : 0),
                      itemBuilder: (context, index) {
                        if (index < displayedTXN.length) {
                          return _buildNotificationItem(
                            context,
                            displayedTXN[index],
                            index,
                          );

                          /* transactionTile(
                                displayedTXN[index]['id'],
                                displayedTXN[index]['amount'],
                                displayedTXN[index]['method'],
                                displayedTXN[index]['date'],
                                displayedTXN[index]['status'],
                                displayedTXN[index]['color'] as Color,
                              );*/
                        } else {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 20),
                            child: Center(
                              child: ZLoadingIndicator(
                                size: 22,
                                strokeWidth: 2,
                                color: Color.fromARGB(255, 169, 97, 14),
                              ),
                            ),
                          );
                        }
                      },
                    ),

              /*         }
                  }),
              )

             displayedTXN.length < 0
                  ? Column(children: [
                      ...displayedTXN
                          .map((transaction) => transactionTile(
                                transaction['id'],
                                transaction['amount'],
                                transaction['method'],
                                transaction['date'],
                                transaction['status'],
                                transaction['color'] as Color,
                              ))
                          .toList()
                    ])
                  : CardShimmer1(),*/
            ],
          ),
        ),
      ),
    );
  }

  /// Card that lets the customer retrieve their previous payment records using
  /// the unique code from their payment invoice and their phone number.
  Widget _buildRetrievalCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.isDarkMode ? const Color(0xFF2A2A2A) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 8),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Retrieve your payments",
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: context.isDarkMode ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            "Enter the code from your invoice and your phone number to view past payments.",
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _codeCtrl,
                  decoration: InputDecoration(
                    isDense: true,
                    labelText: "Payment code",
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _phoneRetrieveCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    isDense: true,
                    labelText: "Phone number",
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _isRetrieving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : IconButton(
                      onPressed: () =>
                          _retrievePayments(_codeCtrl.text, _phoneRetrieveCtrl.text),
                      icon: const Icon(Icons.search),
                      color: AppColors.primaryBrown,
                    ),
            ],
          ),
        ],
      ),
    );
  }

  Widget paymentOption(
    String text,
    bool selected,
    Color color,
    IconData icon,
    int index,
  ) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedPaymentMethod = index;
        });
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          border: Border.all(
            color: selected ? color : Colors.grey.shade300,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(14),
          color: context.isDarkMode
              ? (selected ? color.withOpacity(0.15) : const Color(0xFF2A2A2A))
              : Colors.white,
          boxShadow: selected
              ? [BoxShadow(color: color.withOpacity(0.2), blurRadius: 6)]
              : [],
        ),
        child: ListTile(
          leading: index == 0
              ? Image.asset('assets/mtnSym.png', width: 20, height: 20)
              : Image.asset('assets/airtelSym.png', width: 20, height: 20),
          title: Text(
            text,
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w500,
              color: context.isDarkMode ? Colors.white : Colors.black87,
            ),
          ),
          trailing: selected ? Icon(Icons.check_circle, color: color) : null,
        ),
      ),
    );
  }

  Widget transactionTile(
    BuildContext context,
    String transactionId,
    String amount,
    String method,
    String date,
    String status,
    Color color,
  ) {
    return Card(
      color: context.isDarkMode ? const Color(0xFF2A2A2A) : Colors.white60,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: const Icon(Icons.receipt_long, color: Colors.brown),
        title: Text(
          "$amount - $method",
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w500,
            fontSize: 12,
            color: context.isDarkMode ? Colors.white : Colors.black87,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "ID: $transactionId",
              style: GoogleFonts.poppins(color: Colors.grey, fontSize: 12),
            ),
            Text(
              date,
              style: GoogleFonts.poppins(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
        trailing: Chip(
          label: Text(
            status,
            style: const TextStyle(color: Colors.white, fontSize: 10),
          ),
          backgroundColor: color,
        ),
      ),
    );
  }
}

Widget _buildNotificationIcon(String type) {
  switch (type) {
    case 'new_property':
      return Container(
        padding: EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Color.fromARGB(255, 169, 97, 14).withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.home_outlined,
          color: Color.fromARGB(255, 169, 97, 14),
          size: 24,
        ),
      );
    case 'transaction':
      return Container(
        padding: EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.green.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.account_balance_wallet_outlined,
          color: Colors.green,
          size: 24,
        ),
      );
    case 'booking':
      return Container(
        padding: EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Color.fromARGB(255, 169, 97, 14).withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.calendar_today,
          color: Color.fromARGB(255, 169, 97, 14),
          size: 24,
        ),
      );
    default:
      return Container(
        padding: EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.grey.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(Icons.notifications_outlined, color: Colors.grey, size: 24),
      );
  }
}

Widget _buildNotificationItem(
  BuildContext context,
  Map<String, dynamic> notification,
  int index,
) {
  return Container(
    margin: EdgeInsets.symmetric(horizontal: 8, vertical: 13),
    decoration: BoxDecoration(
      color: context.isDarkMode
          ? const Color(0xFF2A2A2A)
          : const Color.fromARGB(255, 232, 227, 227),
      borderRadius: BorderRadius.circular(12),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.05),
          blurRadius: 8,
          offset: Offset(0, 2),
        ),
      ],
    ),
    child: ListTile(
      contentPadding: EdgeInsets.all(16),
      leading: _buildNotificationIcon(notification['type']),
      title: Text(
        notification['amount'],
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: context.isDarkMode ? Colors.white : Colors.black,
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: 4),
          Text(
            'Package:${notification['package']}',
            style: TextStyle(
              fontSize: 14,
              color: context.isDarkMode ? Colors.grey.shade400 : Colors.grey[700],
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Transaction Id:${notification['id']}',
            style: TextStyle(
              fontSize: 14,
              color: context.isDarkMode ? Colors.grey.shade400 : Colors.grey[700],
            ),
          ),
          SizedBox(height: 8),
          Text(
            "Status:${notification['status']}",
            style: TextStyle(
              fontSize: 12,
              color: context.isDarkMode ? Colors.grey.shade500 : Colors.grey[500],
            ),
          ),
          SizedBox(height: 8),
          Text(
            "Date:${notification['date']}",
            style: TextStyle(
              fontSize: 12,
              color: context.isDarkMode ? Colors.grey.shade500 : Colors.grey[500],
            ),
          ),
        ],
      ),
      trailing: notification['status'] == 'Success'
          ? Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: Colors.green,
                shape: BoxShape.circle,
              ),
            )
          : Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
            ),
      //      onTap: () => _onNotificationTap(index),
    ),
  );
}
