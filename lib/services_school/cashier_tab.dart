import 'package:flutter/material.dart';
import '../services/session_service.dart';
import '../services/supabase_service.dart';

class CashierTab extends StatefulWidget {
  final Function(Map<String, dynamic>) onProductSelected;

  const CashierTab({Key? key, required this.onProductSelected})
    : super(key: key);

  @override
  State<CashierTab> createState() => _CashierTabState();
}

class _CashierTabState extends State<CashierTab> {
  double totalAmount = 0.0;
  Map<String, int> selectedProducts = {};
  Map<String, double> productPrices = {};
  Map<String, String> selectedSizeNames = {};
  bool showPaymentSuccess = false;
  final List<Map<String, dynamic>> products = [];
  final Map<String, Map<String, dynamic>> _productById = {};
  bool get _isCampusServiceUnits =>
      (SessionService.currentUserData?['service_category']?.toString() ?? '') ==
      'Campus Service Units';
  bool get _isOrganization {
    final cat = SessionService.currentUserData?['service_category']?.toString();
    return (cat ?? '').toLowerCase().contains('org');
  }

  bool get _isSingleItemMode => _isCampusServiceUnits || _isOrganization;

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  @override
  Widget build(BuildContext context) {
    print('DEBUG: Building CashierTab with ${products.length} products');
    final screenSize = MediaQuery.of(context).size;
    final screenWidth = screenSize.width;
    final isWeb = screenWidth > 600;
    final isTablet = screenWidth > 480 && screenWidth <= 1024;

    // Responsive sizing
    final horizontalPadding = isWeb ? 24.0 : (isTablet ? 20.0 : 16.0);
    final crossAxisCount = isWeb ? 4 : (isTablet ? 3 : 2);
    final childAspectRatio = isWeb ? 1.3 : (isTablet ? 1.2 : 1.1);

    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.symmetric(
          horizontal: horizontalPadding,
          vertical: isWeb ? 20 : 16,
        ),
        child: Column(
          children: [
            // Payment Success Message
            if (showPaymentSuccess)
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(isWeb ? 20 : 15),
                margin: EdgeInsets.only(bottom: isWeb ? 24 : 20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF28A745), Color(0xFF20A038)],
                  ),
                  borderRadius: BorderRadius.circular(isWeb ? 16 : 12),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF28A745).withOpacity(0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Text('✅', style: TextStyle(fontSize: isWeb ? 32 : 24)),
                    SizedBox(height: isWeb ? 8 : 5),
                    Text(
                      'Payment Successful!',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: isWeb ? 18 : 16,
                      ),
                    ),
                    Text(
                      'Transaction completed successfully',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: isWeb ? 14 : 12,
                      ),
                    ),
                  ],
                ),
              ),

            // Total Display (hidden in single-item mode)
            if (!_isSingleItemMode)
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(isWeb ? 24 : 20),
                margin: EdgeInsets.only(bottom: isWeb ? 24 : 20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: const Color(0xFFB91C1C), width: 2),
                  borderRadius: BorderRadius.circular(isWeb ? 16 : 15),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFB91C1C).withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Text(
                      'Total Amount',
                      style: TextStyle(
                        fontSize: isWeb ? 16 : 14,
                        color: const Color(0xFF666666),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: isWeb ? 8 : 5),
                    Text(
                      '₱${totalAmount.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: isWeb ? 36 : (isTablet ? 32 : 28),
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFFB91C1C),
                      ),
                    ),
                  ],
                ),
              ),

            // Product Categories
            if (isWeb) ...[
              if (!_isCampusServiceUnits)
                _buildCategorySection(
                  'Food & Drinks',
                  products
                      .where((p) => ['Food', 'Drinks'].contains(p['category']))
                      .toList(),
                  crossAxisCount,
                  childAspectRatio,
                  isWeb,
                  isTablet,
                ),
              SizedBox(height: isWeb ? 32 : 24),
              _buildCategorySection(
                'Documents & Services',
                products
                    .where(
                      (p) => ['Documents', 'Services'].contains(p['category']),
                    )
                    .toList(),
                crossAxisCount,
                childAspectRatio,
                isWeb,
                isTablet,
              ),
              SizedBox(height: isWeb ? 32 : 24),
              _buildCategorySection(
                'School Items & Fees',
                products
                    .where(
                      (p) => [
                        'School Items',
                        'Merchandise',
                        'Fees',
                      ].contains(p['category']),
                    )
                    .toList(),
                crossAxisCount,
                childAspectRatio,
                isWeb,
                isTablet,
              ),
              SizedBox(height: isWeb ? 32 : 24),
              _buildCustomPaymentSection(
                crossAxisCount,
                childAspectRatio,
                isWeb,
                isTablet,
              ),
            ] else ...[
              // Mobile/tablet grid: filter out Food/Drinks for Campus Service Units
              Builder(
                builder: (context) {
                  final displayedProducts =
                      _isCampusServiceUnits
                          ? products
                              .where(
                                (p) =>
                                    !['Food', 'Drinks'].contains(p['category']),
                              )
                              .toList()
                          : products;
                  // Product Grid for mobile/tablet
                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      crossAxisSpacing: isWeb ? 16 : 12,
                      mainAxisSpacing: isWeb ? 16 : 12,
                      childAspectRatio: childAspectRatio,
                    ),
                    itemCount:
                        displayedProducts.length + 1, // +1 for the plus button
                    itemBuilder: (context, index) {
                      if (index == displayedProducts.length) {
                        // Plus button as the last item
                        return _buildAddPaymentCard(isWeb, isTablet);
                      }
                      final product = displayedProducts[index];
                      return _buildProductCard(product, isWeb, isTablet);
                    },
                  );
                },
              ),
            ],

            SizedBox(height: isWeb ? 32 : 20),

            // Action Buttons (hidden in single-item mode)
            if (!_isSingleItemMode)
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _clearOrder,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6C757D),
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(
                          vertical: isWeb ? 16 : 12,
                          horizontal: isWeb ? 24 : 16,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(isWeb ? 12 : 10),
                        ),
                        elevation: 2,
                      ),
                      child: Text(
                        'Clear Order',
                        style: TextStyle(
                          fontSize: isWeb ? 16 : (isTablet ? 14 : 12),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: isWeb ? 16 : 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: totalAmount > 0 ? _processPayment : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            totalAmount > 0
                                ? const Color(0xFFB91C1C)
                                : const Color(0xFFCCCCCC),
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(
                          vertical: isWeb ? 16 : 12,
                          horizontal: isWeb ? 24 : 16,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(isWeb ? 12 : 10),
                        ),
                        elevation: totalAmount > 0 ? 3 : 0,
                      ),
                      child: Text(
                        'Process Payment',
                        style: TextStyle(
                          fontSize: isWeb ? 16 : (isTablet ? 14 : 12),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),

            SizedBox(height: isWeb ? 40 : 100), // Space for bottom navigation
          ],
        ),
      ),
    );
  }

  Widget _buildCategorySection(
    String title,
    List<Map<String, dynamic>> categoryProducts,
    int crossAxisCount,
    double childAspectRatio,
    bool isWeb,
    bool isTablet,
  ) {
    if (categoryProducts.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: isWeb ? 22 : 18,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF333333),
          ),
        ),
        const SizedBox(height: 16),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: childAspectRatio,
          ),
          itemCount: categoryProducts.length,
          itemBuilder: (context, index) {
            final product = categoryProducts[index];
            return _buildProductCard(product, isWeb, isTablet);
          },
        ),
      ],
    );
  }

  Widget _buildCustomPaymentSection(
    int crossAxisCount,
    double childAspectRatio,
    bool isWeb,
    bool isTablet,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Custom Payment',
          style: TextStyle(
            fontSize: isWeb ? 22 : 18,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF333333),
          ),
        ),
        const SizedBox(height: 16),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: childAspectRatio,
          ),
          itemCount: 1, // Only one custom payment card
          itemBuilder: (context, index) {
            return _buildAddPaymentCard(isWeb, isTablet);
          },
        ),
      ],
    );
  }

  Widget _buildProductCard(
    Map<String, dynamic> product,
    bool isWeb,
    bool isTablet,
  ) {
    final isSelected = selectedProducts.containsKey(product['id']);
    final count = selectedProducts[product['id']] ?? 0;
    final categoryColor = _getCategoryColor(product['category']);

    return GestureDetector(
      onTap: () => _selectProduct(product),
      child: Container(
        decoration: BoxDecoration(
          color: isSelected ? categoryColor.withOpacity(0.1) : Colors.white,
          border: Border.all(
            color: isSelected ? categoryColor : const Color(0xFFE9ECEF),
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(isWeb ? 16 : 12),
          boxShadow: [
            if (isSelected)
              BoxShadow(
                color: categoryColor.withOpacity(0.2),
                blurRadius: 12,
                offset: const Offset(0, 4),
              )
            else
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
          ],
        ),
        child: Padding(
          padding: EdgeInsets.all(isWeb ? 16 : (isTablet ? 14 : 12)),
          child: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Category Badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: categoryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      product['category'],
                      style: TextStyle(
                        fontSize: isWeb ? 10 : 8,
                        fontWeight: FontWeight.w600,
                        color: categoryColor,
                      ),
                    ),
                  ),
                  const Spacer(),

                  // Product Name
                  Flexible(
                    child: Text(
                      product['name'],
                      style: TextStyle(
                        fontSize: isWeb ? 14 : (isTablet ? 13 : 12),
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF333333),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  SizedBox(height: isWeb ? 6 : 4),

                  // Price
                  Text(
                    product['hasSizes']
                        ? (product['category'] == 'Merchandise'
                            ? _formatSizePriceRange(product)
                            : '₱${_computeMinPriceFromSizes(product).toStringAsFixed(0)}')
                        : '₱${product['price'].toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: isWeb ? 15 : (isTablet ? 14 : 13),
                      fontWeight: FontWeight.bold,
                      color: categoryColor,
                    ),
                  ),
                ],
              ),

              // Selection indicator
              if (isSelected)
                Positioned(
                  top: -4,
                  right: -4,
                  child: Container(
                    width: isWeb ? 24 : 20,
                    height: isWeb ? 24 : 20,
                    decoration: BoxDecoration(
                      color: categoryColor,
                      borderRadius: BorderRadius.circular(isWeb ? 12 : 10),
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: Center(
                      child: Text(
                        count.toString(),
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: isWeb ? 12 : 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'food':
        return const Color(0xFF28A745);
      case 'drinks':
        return const Color(0xFF007BFF);
      case 'documents':
        return const Color(0xFF6C757D);
      case 'services':
        return const Color(0xFF17A2B8);
      case 'school items':
        return const Color(0xFF20C997);
      case 'merchandise':
        return const Color(0xFFFF6347);
      case 'fees':
        return const Color(0xFFFFC107);
      default:
        return const Color(0xFFB91C1C);
    }
  }

  void _selectProduct(Map<String, dynamic> product) {
    if (_isSingleItemMode) {
      if (product['hasSizes']) {
        _showSizeSelectionModal(product, singleItem: true);
      } else if (product['allowCustomAmount'] == true) {
        _showCustomAmountDialog(product, singleItem: true);
      } else {
        widget.onProductSelected({
          'id': product['id'],
          'name': product['name'],
          'price': (product['price'] as num).toDouble(),
          'category': product['category'] ?? 'Custom',
          'orderType': 'single',
        });
      }
      return;
    }

    if (product['hasSizes']) {
      // For products with sizes, open a floating modal to choose size
      _showSizeSelectionModal(product);
    } else if (product['allowCustomAmount'] == true) {
      // For documents that allow custom amounts, show amount input dialog
      _showCustomAmountDialog(product);
    } else {
      // For regular products, add directly to cart
      setState(() {
        if (selectedProducts.containsKey(product['id'])) {
          selectedProducts[product['id']] =
              selectedProducts[product['id']]! + 1;
        } else {
          selectedProducts[product['id']] = 1;
        }
        productPrices[product['id']] = (product['price'] as num).toDouble();
        _calculateTotal();
      });
    }
  }

  void _showSizeSelectionModal(
    Map<String, dynamic> product, {
    bool singleItem = false,
  }) {
    final String productId = product['id'].toString();
    final List<dynamic> sizesDynamic =
        (product['sizes'] ?? []) as List<dynamic>;
    final List<Map<String, dynamic>> sizes =
        sizesDynamic
            .map<Map<String, dynamic>>(
              (e) => Map<String, dynamic>.from(e as Map),
            )
            .toList();
    final Color accent = _getCategoryColor(product['category']);

    if (sizes.isEmpty) {
      // Fallback: treat as regular product
      setState(() {
        if (selectedProducts.containsKey(productId)) {
          selectedProducts[productId] = selectedProducts[productId]! + 1;
        } else {
          selectedProducts[productId] = 1;
        }
        productPrices[productId] = (product['price'] as num).toDouble();
        _calculateTotal();
      });
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        product['name'],
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Choose a size',
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
                ),
                const SizedBox(height: 8),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: sizes.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final size = sizes[index];
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 4,
                        ),
                        title: Text('${size['name']}'),
                        trailing: Text(
                          '₱${(size['price'] as num).toDouble().toStringAsFixed(0)}',
                          style: TextStyle(
                            color: accent,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        onTap: () {
                          if (singleItem) {
                            Navigator.pop(context);
                            widget.onProductSelected({
                              'id': productId,
                              'name': "${product['name']} (${size['name']})",
                              'price': (size['price'] as num).toDouble(),
                              'category': product['category'] ?? 'Custom',
                              'orderType': 'single',
                            });
                          } else {
                            setState(() {
                              if (selectedProducts.containsKey(productId)) {
                                selectedProducts[productId] =
                                    selectedProducts[productId]! + 1;
                              } else {
                                selectedProducts[productId] = 1;
                              }
                              productPrices[productId] =
                                  (size['price'] as num).toDouble();
                              selectedSizeNames[productId] =
                                  size['name'].toString();
                              _calculateTotal();
                            });
                            Navigator.pop(context);
                          }
                        },
                      );
                    },
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  void _calculateTotal() {
    totalAmount = 0.0;
    selectedProducts.forEach((productId, quantity) {
      final price = productPrices[productId] ?? 0.0;
      totalAmount += price * quantity;
    });
  }

  void _clearOrder() {
    setState(() {
      selectedProducts.clear();
      productPrices.clear();
      selectedSizeNames.clear();
      totalAmount = 0.0;
      showPaymentSuccess = false;
    });
  }

  void _showCustomAmountDialog(
    Map<String, dynamic> product, {
    bool singleItem = false,
  }) {
    final amountController = TextEditingController(
      text: product['price'].toStringAsFixed(0),
    );

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('${product['name']} - Enter Amount'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Enter the amount for ${product['name']}:',
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 15),
              TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Amount',
                  prefixText: '₱',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final customAmount = double.tryParse(amountController.text);
                if (customAmount != null && customAmount > 0) {
                  if (singleItem) {
                    Navigator.pop(context);
                    widget.onProductSelected({
                      'id': product['id'],
                      'name': product['name'],
                      'price': customAmount,
                      'category': product['category'] ?? 'Custom',
                      'orderType': 'single',
                    });
                  } else {
                    setState(() {
                      if (selectedProducts.containsKey(product['id'])) {
                        selectedProducts[product['id']] =
                            selectedProducts[product['id']]! + 1;
                      } else {
                        selectedProducts[product['id']] = 1;
                      }
                      productPrices[product['id']] = customAmount;
                      _calculateTotal();
                    });
                    Navigator.pop(context);
                  }
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please enter a valid amount'),
                      backgroundColor: Color(0xFFDC3545),
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFB91C1C),
                foregroundColor: Colors.white,
              ),
              child: const Text('Add to Cart'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildAddPaymentCard(bool isWeb, bool isTablet) {
    return GestureDetector(
      onTap: _showCustomPaymentModal,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(isWeb ? 15 : 12),
          border: Border.all(
            color: const Color(0xFFB91C1C).withOpacity(0.3),
            width: 2,
            style: BorderStyle.solid,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: isWeb ? 50 : (isTablet ? 45 : 40),
              height: isWeb ? 50 : (isTablet ? 45 : 40),
              decoration: BoxDecoration(
                color: const Color(0xFFB91C1C).withOpacity(0.1),
                borderRadius: BorderRadius.circular(25),
              ),
              child: Icon(
                Icons.add,
                color: const Color(0xFFB91C1C),
                size: isWeb ? 28 : (isTablet ? 25 : 22),
              ),
            ),
            SizedBox(height: isWeb ? 12 : 8),
            Text(
              'Custom\nPayment',
              style: TextStyle(
                fontSize: isWeb ? 14 : (isTablet ? 13 : 12),
                fontWeight: FontWeight.w600,
                color: const Color(0xFFB91C1C),
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
            ),
          ],
        ),
      ),
    );
  }

  void _showCustomPaymentModal() {
    String? selectedCategory;
    final priceController = TextEditingController();
    final categories = _getCustomPaymentCategories();
    if (categories.isNotEmpty) {
      selectedCategory = categories.first;
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              title: const Text(
                'Custom Payment',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFB91C1C),
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Create a custom payment for any service or item:',
                    style: TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 20),
                  DropdownButtonFormField<String>(
                    value: selectedCategory,
                    items:
                        categories
                            .map(
                              (c) => DropdownMenuItem<String>(
                                value: c,
                                child: Text(c),
                              ),
                            )
                            .toList(),
                    onChanged: (v) => setModalState(() => selectedCategory = v),
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Payment Category',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 15),
                  TextField(
                    controller: priceController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Amount',
                      prefixText: '₱',
                      hintText: '0.00',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final category = (selectedCategory ?? '').trim();
                    final amount = double.tryParse(priceController.text);

                    if (category.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Please enter a payment category'),
                          backgroundColor: Color(0xFFDC3545),
                        ),
                      );
                      return;
                    }

                    if (amount == null || amount <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Please enter a valid amount'),
                          backgroundColor: Color(0xFFDC3545),
                        ),
                      );
                      return;
                    }

                    // Navigate directly to payment screen with custom payment
                    Navigator.pop(context);
                    widget.onProductSelected({
                      'id':
                          'custom-payment-${DateTime.now().millisecondsSinceEpoch}',
                      'name': category,
                      'price': amount,
                      'category': 'Custom',
                      'orderType': 'single',
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFB91C1C),
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Proceed to Payment'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  List<String> _getCustomPaymentCategories() {
    // Vendor: all categories; Campus Service Units and Organizations: Services/Documents/School Items/Fees
    if (_isCampusServiceUnits || _isOrganization) {
      return ['Services', 'Documents', 'School Items', 'Fees'];
    }
    // Treat others as Vendor by default
    return [
      'Food',
      'Drinks',
      'Desserts',
      'Documents',
      'Services',
      'School Items',
      'Fees',
      'Merchandise',
    ];
  }

  String _formatSizePriceRange(Map<String, dynamic> product) {
    final sizesDynamic = (product['sizes'] ?? []) as List<dynamic>;
    if (sizesDynamic.isEmpty) {
      return '₱${(product['price'] as num).toDouble().toStringAsFixed(2)}';
    }
    final sizes =
        sizesDynamic
            .map<Map<String, dynamic>>(
              (e) => Map<String, dynamic>.from(e as Map),
            )
            .toList();
    double? minPrice;
    double? maxPrice;
    for (final s in sizes) {
      final p = (s['price'] as num?)?.toDouble();
      if (p == null) continue;
      if (minPrice == null || p < minPrice) minPrice = p;
      if (maxPrice == null || p > maxPrice) maxPrice = p;
    }
    if (minPrice == null) {
      return '₱${(product['price'] as num).toDouble().toStringAsFixed(2)}';
    }
    if (maxPrice == null || (maxPrice - minPrice).abs() < 0.0001) {
      return '₱${minPrice.toStringAsFixed(0)}';
    }
    return '₱${minPrice.toStringAsFixed(0)}-${maxPrice.toStringAsFixed(0)}';
  }

  double _computeMinPriceFromSizes(Map<String, dynamic> product) {
    final sizesDynamic = (product['sizes'] ?? []) as List<dynamic>;
    double? minPrice;
    for (final e in sizesDynamic) {
      final map = Map<String, dynamic>.from(e as Map);
      final p = (map['price'] as num?)?.toDouble();
      if (p == null) continue;
      if (minPrice == null || p < minPrice) minPrice = p;
    }
    return (minPrice ?? (product['price'] as num).toDouble());
  }

  void _processPayment() {
    if (totalAmount > 0) {
      // Create order summary for payment
      final orderItems = <Map<String, dynamic>>[];
      selectedProducts.forEach((productId, quantity) {
        final product = products.firstWhere((p) => p['id'] == productId);
        final price = productPrices[productId] ?? product['price'];
        final String displayName =
            selectedSizeNames.containsKey(productId)
                ? '${product['name']} (${selectedSizeNames[productId]})'
                : product['name'];
        orderItems.add({
          'id': productId,
          'name': displayName,
          'price': price,
          'quantity': quantity,
          'total': price * quantity,
        });
      });

      // Navigate to payment screen with order
      widget.onProductSelected({
        'orderItems': orderItems,
        'totalAmount': totalAmount,
        'orderType': 'multiple',
      });
    }
  }

  Future<void> _loadItems() async {
    final serviceIdStr =
        SessionService.currentUserData?['service_id']?.toString() ?? '0';
    final operationalType =
        SessionService.currentUserData?['operational_type']?.toString() ??
        'Main';
    final mainServiceIdStr =
        SessionService.currentUserData?['main_service_id']?.toString();

    final serviceId = int.tryParse(serviceIdStr) ?? 0;
    final mainServiceId = int.tryParse(mainServiceIdStr ?? '');

    final resp = await SupabaseService.getEffectivePaymentItems(
      serviceAccountId: serviceId,
      operationalType: operationalType,
      mainServiceId: mainServiceId,
    );

    if (resp['success'] == true) {
      final List data = resp['data'] as List;
      print('DEBUG: Loading ${data.length} items from database');
      products.clear();
      _productById.clear();
      for (final raw in data) {
        final hasSizes = raw['has_sizes'] == true;
        final Map<String, dynamic> product = {
          'id': raw['id'].toString(),
          'name': raw['name'],
          'price': (raw['base_price'] as num).toDouble(),
          'hasSizes': hasSizes,
          'category': raw['category'],
        };
        if (hasSizes && raw['size_options'] != null) {
          final sizes = <Map<String, dynamic>>[];
          (raw['size_options'] as Map).forEach((k, v) {
            final price = (v as num).toDouble();
            sizes.add({'name': k.toString(), 'price': price});
          });
          product['sizes'] = sizes;
        }
        products.add(product);
        _productById[product['id']] = product;
      }
      print('DEBUG: Successfully loaded ${products.length} products');
      setState(() {}); // Trigger UI rebuild to display loaded items
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load items: ${resp['message'] ?? ''}'),
            backgroundColor: const Color(0xFFDC3545),
          ),
        );
      }
    }
  }
}
