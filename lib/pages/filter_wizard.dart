import 'package:flutter/material.dart';

class FilterWizard extends StatefulWidget {
  final Function(Map<String, dynamic>) onComplete;
  const FilterWizard({super.key, required this.onComplete});

  @override
  State<FilterWizard> createState() => _FilterWizardState();
}

class _FilterWizardState extends State<FilterWizard>
    with TickerProviderStateMixin {
  int _step = 0;
  late PageController _pageController;
  late AnimationController _progressController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    _progressController.dispose();
    super.dispose();
  }

  // Filter State
  String _selectedType = 'All';
  String _minPrice = '';
  String _maxPrice = '';
  String _selectedLocation = 'All';

  final List<String> _propertyTypes = [
    'House',
    'Apartment',
    'Condominium',
    'Office',
    'Land',
    'Warehouse',
    'Hotel',
    'Shop',
  ];

  final List<String> _locations = [
    'All',
    'Ntinda',
    'Kisaasi',
    'Naalya',
    'Bweyogerere',
    'Wakiso',
    'Kampala',
    'Entebbe',
    'Jinja',
  ];

  void _nextStep() {
    if (_step < 3) {
      setState(() {
        _step++;
        _pageController.animateToPage(
          _step,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOutCubic,
        );
        _progressController.forward(from: 0.0);
      });
    }
  }

  void _prevStep() {
    if (_step > 0) {
      setState(() {
        _step--;
        _pageController.animateToPage(
          _step,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOutCubic,
        );
        _progressController.reverse();
      });
    }
  }

  void _applyFilters() {
    widget.onComplete({
      'type': _selectedType,
      'minPrice': _minPrice,
      'maxPrice': _maxPrice,
      'location': _selectedLocation,
    });
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = const Color.fromARGB(255, 169, 97, 14);
    final textColor = isDark ? Colors.white : Colors.black87;

    return Dialog(
      insetPadding: EdgeInsets.zero,
      backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Column(
            children: [
              // Header with Progress
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                child: Row(
                  children: [
                    if (_step > 0)
                      IconButton(
                        icon: Icon(Icons.arrow_back, color: textColor),
                        onPressed: _prevStep,
                      ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Filter Wizard',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: (_step + 1) / 4,
                              backgroundColor: Colors.grey.shade200,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(primaryColor),
                              minHeight: 6,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${_step + 1}/4',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: primaryColor,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Content Area
              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _buildStepContent(context, 0, _buildTypeStep(textColor)),
                    _buildStepContent(context, 1, _buildPriceStep(textColor)),
                    _buildStepContent(context, 2, _buildLocationStep(textColor)),
                    _buildStepContent(context, 3, _buildSummaryStep(textColor)),
                  ],
                ),
              ),

              // Footer Navigation
              Padding(
                padding: const EdgeInsets.all(24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (_step > 0)
                      TextButton(
                        onPressed: _prevStep,
                        child: Text('Back',
                            style: TextStyle(color: Colors.grey.shade600)),
                      )
                    else
                      const SizedBox(),
                    if (_step < 3)
                      ElevatedButton(
                        onPressed: _nextStep,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 32, vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30)),
                        ),
                        child: const Text('Next',
                            style: TextStyle(color: Colors.white)),
                      )
                    else
                      ElevatedButton(
                        onPressed: _applyFilters,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 32, vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30)),
                        ),
                        child: const Text('View Results',
                            style: TextStyle(color: Colors.white)),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepContent(BuildContext context, int stepIndex, Widget child) {
    return AnimatedOpacity(
      duration: Duration(milliseconds: _step == stepIndex ? 400 : 0),
      opacity: _step == stepIndex ? 1.0 : 0.0,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: child,
      ),
    );
  }

  Widget _buildTypeStep(Color textColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'I want a...',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Select the property type you are looking for',
          style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 32),
        Expanded(
          child: GridView.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 1.5,
            ),
            itemCount: _propertyTypes.length,
            itemBuilder: (context, index) {
              final type = _propertyTypes[index];
              final isSelected = _selectedType == type;
              return GestureDetector(
                onTap: () => setState(() => _selectedType = type),
                child: AnimatedContainer(
                  duration: Duration(milliseconds: 200 + index * 50),
                  curve: Curves.easeOut,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color.fromARGB(255, 169, 97, 14)
                        : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected
                          ? const Color.fromARGB(255, 169, 97, 14)
                          : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _getTypeIcon(type),
                        size: 32,
                        color: isSelected
                            ? Colors.white
                            : Colors.grey.shade700,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        type,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isSelected
                              ? Colors.white
                              : Colors.grey.shade800,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  IconData _getTypeIcon(String type) {
    switch (type) {
      case 'House':
        return Icons.home;
      case 'Apartment':
        return Icons.apartment;
      case 'Condominium':
        return Icons.villa;
      case 'Office':
        return Icons.work;
      case 'Land':
        return Icons.terrain;
      case 'Warehouse':
        return Icons.warehouse;
      case 'Hotel':
        return Icons.hotel;
      case 'Shop':
        return Icons.store;
      default:
        return Icons.home;
    }
  }

  Widget _buildPriceStep(Color textColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'of...',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Set your budget range',
          style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 40),
        Text(
          'Minimum Price',
          style: TextStyle(
              fontSize: 14, fontWeight: FontWeight.w600, color: textColor),
        ),
        const SizedBox(height: 8),
        TextField(
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            hintText: 'e.g. 500000',
            filled: true,
            fillColor: Colors.grey.shade100,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
          onChanged: (val) => setState(() => _minPrice = val),
        ),
        const SizedBox(height: 24),
        Text(
          'Maximum Price',
          style: TextStyle(
              fontSize: 14, fontWeight: FontWeight.w600, color: textColor),
        ),
        const SizedBox(height: 8),
        TextField(
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            hintText: 'e.g. 2000000',
            filled: true,
            fillColor: Colors.grey.shade100,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
          onChanged: (val) => setState(() => _maxPrice = val),
        ),
      ],
    );
  }

  Widget _buildLocationStep(Color textColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'in...',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Choose your preferred location',
          style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 32),
        Expanded(
          child: ListView.builder(
            itemCount: _locations.length,
            itemBuilder: (context, index) {
              final loc = _locations[index];
              final isSelected = _selectedLocation == loc;
              return GestureDetector(
                onTap: () => setState(() => _selectedLocation = loc),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: AnimatedContainer(
                    duration: Duration(milliseconds: 200 + index * 50),
                    curve: Curves.easeOut,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 16),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color.fromARGB(255, 169, 97, 14)
                          : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.location_on_outlined,
                          color: isSelected
                              ? Colors.white
                              : Colors.grey.shade700,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          loc,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: isSelected
                                ? Colors.white
                                : Colors.grey.shade800,
                          ),
                        ),
                        const Spacer(),
                        if (isSelected)
                          const Icon(Icons.check, color: Colors.white),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryStep(Color textColor) {
    final primaryColor = const Color.fromARGB(255, 169, 97, 14);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'with...',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Review your preferences',
          style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 40),
        _buildSummaryCard('Property Type', _selectedType, Icons.home),
        const SizedBox(height: 16),
        _buildSummaryCard(
          'Budget',
          _minPrice.isNotEmpty || _maxPrice.isNotEmpty
              ? 'UGX ${_minPrice} - ${_maxPrice}'
              : 'Any',
          Icons.attach_money,
        ),
        const SizedBox(height: 16),
        _buildSummaryCard('Location', _selectedLocation, Icons.location_on),
        const Spacer(),
        Center(
          child: Text(
            'Ready to find your perfect property?',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: primaryColor,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: const Color.fromARGB(255, 169, 97, 14),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
