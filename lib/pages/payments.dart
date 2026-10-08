import 'package:flutter/material.dart';
import 'package:zcanopy/pages/welcome.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:zcanopy/pages/loadIndicator.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:zcanopy/pages/session.dart';
import 'package:zcanopy/utils/theme_extensions.dart';
import 'package:zcanopy/services/gateway_api.dart';
import 'package:zcanopy/utils/colors.dart';
import 'package:zcanopy/utils/property_normalizer.dart';

class PaymentsPage extends StatefulWidget {
  const PaymentsPage({super.key});

  @override
  State<PaymentsPage> createState() => _PaymentsPageState();
}

class _PaymentsPageState extends State<PaymentsPage> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController numberEditCtrl = TextEditingController();
  final database = Hive.box('myStore');
  final _api = GatewayApi();
  int _page = 1;
  bool _hasMore = true;
  var userID;

  bool _isLoading = true;
  bool isLoading = false;
  bool isLoadingMore = false;
  final int TXNPerPage = 2;
  List<Map<String, dynamic>> displayedTXN = [];
  String phoneNumber = '';
  bool _isRetrieving = false;
  final TextEditingController _codeCtrl = TextEditingController();
  final TextEditingController _phoneRetrieveCtrl = TextEditingController();
  List<Map<String, dynamic>> _transactions = [];
  @override
  void initState() {
    super.initState();
    userID = database.get('userID');
    _codeCtrl.text = database.get('customerCode')?.toString() ?? '';
    _phoneRetrieveCtrl.text = database.get('phoneNumber')?.toString() ?? '';
    final storedCode = _codeCtrl.text;
    final storedPhone = _phoneRetrieveCtrl.text;
    if (storedCode.isNotEmpty && storedPhone.isNotEmpty) {
      _retrievePayments(storedCode, storedPhone);
    } else {
      loadInitialData();
    }

    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
              _scrollController.position.maxScrollExtent - 200 &&
          !isLoadingMore &&
          _hasMore) {
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
      final data = await _api.retrievePayment(
        code: code.trim(),
        phoneNumber: phone.trim(),
      );
      final dynamic raw = data['payments'] ??
          data['transactions'] ??
          data['data'] ??
          (data['id'] != null ? [data] : const []);
      final fetched = normalizeTransactions(raw);
      if (mounted) {
        setState(() {
          _transactions = fetched;
          displayedTXN = fetched.take(TXNPerPage).toList();
          _isRetrieving = false;
          _isLoading = false;
        });
      }
      if (fetched.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("No payments found for that code")),
        );
      }
    } on ApiException catch (e) {
      print('Error retrieving payments: ${e.message}');
      if (mounted) {
        setState(() {
          _transactions = [];
          displayedTXN = [];
          _isRetrieving = false;
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
    } catch (e) {
      print('Error retrieving payments: $e');
      if (mounted) {
        setState(() {
          displayedTXN = _transactions.take(TXNPerPage).toList();
          _isRetrieving = false;
          _isLoading = false;
        });
      }
    }
  }

  Future<void> loadInitialData() async {
    userID = database.get('userID');
    final isSessionValid = await SessionService.validateSession();
    if (!isSessionValid) {
      if (mounted) await forceLogout(context);
      return;
    }

    setState(() {
      isLoading = true;
      _isLoading = true;
    });
    await _fetchPage(1, replace: true);
    if (mounted) {
      setState(() {
        isLoading = false;
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchPage(int page, {bool replace = false}) async {
    try {
      final response = await _api.getTransactions(page: page, limit: TXNPerPage);
      final fetched = normalizeTransactions(
          response['transactions'] ?? response['data'] ?? response['payments']);
      if (!mounted) return;
      setState(() {
        if (replace) {
          _transactions = fetched;
          displayedTXN = fetched.take(TXNPerPage).toList();
          _page = 1;
        } else {
          _transactions.addAll(fetched);
          displayedTXN.addAll(fetched);
          _page = page;
        }
        _hasMore = fetched.length >= TXNPerPage;
      });
    } on ApiException catch (e) {
      print('Load transactions error: ${e.message}');
      if (mounted && replace) {
        setState(() {
          _transactions = [];
          displayedTXN = [];
        });
      }
    } catch (e) {
      print('Load transactions error: $e');
    }
  }

  Future<void> loadMoreData() async {
    if (!_hasMore || isLoadingMore) return;
    setState(() => isLoadingMore = true);
    await _fetchPage(_page + 1);
    if (mounted) setState(() => isLoadingMore = false);
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
      if (mounted) await forceLogout(context);
      return false;
    }

    try {
      final amount = num.tryParse(database.get('amount')?.toString() ?? '') ?? 0;
      final response = await _api.initiatePayment(
        phoneNumber: phoneNumber,
        amount: amount,
        userId: database.get('userID')?.toString() ?? '',
      );
      final ok = response['success'] == true ||
          (response['status']?.toString().toLowerCase() ?? '') == 'success';
      if (ok) {
        await database.put('amount', response['amount'] ?? amount);
        await database.put('package',
            response['package'] ?? database.get('package'));
        await database.put('status',
            response['status'] ?? database.get('status'));
        if (response['remainingDays'] != null) {
          await database.put('remainingDays', response['remainingDays']);
        }
        if (response['totalDays'] != null) {
          await database.put('totalDays', response['totalDays']);
        }
        await database.put('dataAvailable', true);
      }
      return ok;
    } on ApiException catch (e) {
      print('Initiate payment error: ${e.message}');
      return false;
    } catch (e) {
      print('Initiate payment error: $e');
      return false;
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
