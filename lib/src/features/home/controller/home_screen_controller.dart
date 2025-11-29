// lib/src/features/home/controller/home_screen_controller.dart
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tablets/src/common/providers/data_loading_provider.dart';
import 'package:tablets/src/features/customers/controllers/customer_screen_data_cache_provider.dart';
import 'package:tablets/src/features/transactions/controllers/cart_provider.dart';
import 'package:tablets/src/features/transactions/controllers/customer_db_cache_provider.dart';
import 'package:tablets/src/features/transactions/controllers/form_data_container.dart';
import 'package:tablets/src/common/functions/dialog_delete_confirmation.dart';
// Commented out - no longer using transactions or transaction streams
// import 'dart:async';
// import 'package:tablets/src/common/functions/debug_print.dart';
// import 'package:tablets/src/common/values/constants.dart';
// import 'package:tablets/src/features/transactions/controllers/selected_customer_transaction_stream_provider.dart';
// import 'package:tablets/src/features/transactions/model/transaction.dart';

class HomeScreenState {
  final num? totalDebt;
  final num? dueDebt;
  final dynamic latestReceiptDate;
  final dynamic latestInvoiceDate;
  final bool isValidUser;
  final bool isLoadingDebt; // For debt calculation loading state
  final String? debtError; // For debt calculation errors

  HomeScreenState({
    this.totalDebt,
    this.dueDebt,
    this.latestReceiptDate,
    this.latestInvoiceDate,
    this.isValidUser = true,
    this.isLoadingDebt = false,
    this.debtError,
  });

  HomeScreenState copyWith({
    num? totalDebt,
    num? dueDebt,
    dynamic latestReceiptDate,
    dynamic latestInvoiceDate,
    bool? isValidUser,
    bool? isLoadingDebt,
    String? debtError,
    bool clearDebtError = false, // Flag to explicitly clear error
  }) {
    return HomeScreenState(
      totalDebt: totalDebt ?? this.totalDebt,
      dueDebt: dueDebt ?? this.dueDebt,
      latestReceiptDate: latestReceiptDate ?? this.latestReceiptDate,
      latestInvoiceDate: latestInvoiceDate ?? this.latestInvoiceDate,
      isValidUser: isValidUser ?? this.isValidUser,
      isLoadingDebt: isLoadingDebt ?? this.isLoadingDebt,
      debtError: clearDebtError ? null : debtError ?? this.debtError,
    );
  }
}

class HomeScreenNotifier extends StateNotifier<HomeScreenState> {
  HomeScreenNotifier(this._ref) : super(HomeScreenState()) {
    // Load salesman info on initialization
    _ref.read(dataLoadingController.notifier).loadSalesmanInfo();
  }

  final Ref _ref;

  void _loadCustomerDebtData(String customerDbRef) {
    final customerScreenDataCache = _ref.read(customerScreenDataCacheProvider.notifier);

    // Debug: Check cache status
    print('DEBUG: Loading debt data for customer: $customerDbRef');
    print('DEBUG: Cache size: ${customerScreenDataCache.data.length}');

    try {
      final debtData = customerScreenDataCache.getItemByProperty('customerDbRef', customerDbRef);

      print('DEBUG: Found debt data: $debtData');

      if (mounted) {
        state = state.copyWith(
          totalDebt: debtData['totalDebt']?.toDouble() ?? 0.0,
          dueDebt: debtData['dueDebt']?.toDouble() ?? 0.0,
          latestReceiptDate: debtData['lastCustomerReceiptDate'] ?? 'لا يوجد',
          latestInvoiceDate: debtData['lastCustomerInvoiceDate'] ?? 'لا يوجد',
          isLoadingDebt: false,
          clearDebtError: true,
        );

        final customerDataMap = _ref.read(customerDbCacheProvider.notifier).getItemByDbRef(customerDbRef);
        final paymentDurationLimit = customerDataMap['paymentDurationLimit'] as num? ?? 0;
        final creditLimit = customerDataMap['creditLimit'] as num? ?? 0;
        _validateCustomer(paymentDurationLimit, creditLimit);
      }
    } catch (e) {
      print('DEBUG: Error loading debt data: $e');
      print('DEBUG: Available customerDbRefs in cache: ${customerScreenDataCache.data.map((d) => d['customerDbRef']).toList()}');

      if (mounted) {
        state = state.copyWith(
          isLoadingDebt: false,
          debtError: "بيانات الدين غير متوفرة",
        );
      }
    }
  }

  // COMMENTED OUT: No longer needed - debt is pre-calculated in accountant app
  // void _listenToSelectedCustomerTransactions() { ... }
  // Map<String, dynamic> _calculateDebtWithGivenTransactions(...) { ... }

  void selectCustomer(WidgetRef ref, Map<String, dynamic> customer) {
    final formDataNotifier = _ref.read(formDataContainerProvider.notifier);
    formDataNotifier.reset();
    _ref.read(cartProvider.notifier).reset();

    final customerDbRef = customer['dbRef'] as String?;

    formDataNotifier.addProperty('name', customer['name']);
    formDataNotifier.addProperty('nameDbRef', customerDbRef);
    formDataNotifier.addProperty('sellingPriceType', customer['sellingPriceType']);
    formDataNotifier.addProperty('isEditable', true);

    // Load debt data from pre-calculated cache
    if (customerDbRef != null) {
      _loadCustomerDebtData(customerDbRef);
    }
  }

  bool customerIsSelected() {
    // Use nameDbRef for a more reliable check if a customer is selected
    return _ref.read(formDataContainerProvider).containsKey('nameDbRef');
  }

  Future<bool> resetTransactionConfirmation(BuildContext context) async {
    final formDataNotifier = _ref.read(formDataContainerProvider.notifier);
    final cartNotifier = _ref.read(cartProvider.notifier);
    final currentFormData = formDataNotifier.data; // Read data once

    if (currentFormData['nameDbRef'] == null) {
      // Check if a customer is truly selected
      formDataNotifier.reset();
      cartNotifier.reset();
      if (mounted) state = HomeScreenState(); // Reset to initial state
      return true;
    }

    final confirmation = await showUserConfirmationDialog(
      context: context,
      messagePart1: "هل أنت متأكد؟",
      messagePart2: 'سيتم إلغاء المعاملة الحالية للزبون ${currentFormData['name']} ؟',
    );

    if (confirmation == true) {
      formDataNotifier.reset();
      cartNotifier.reset();
      if (mounted) state = HomeScreenState(); // Reset to initial state
      return true;
    }
    return false;
  }

  void _validateCustomer(num paymentDurationLimit, num creditLimit) {
    if (!mounted) return;
    if (state.totalDebt == null || state.dueDebt == null) {
      state = state.copyWith(isValidUser: true); // Default if no debt info
      return;
    }
    // A customer is valid if:
    // 1. They have no debt (or credit).
    // 2. Or, their total debt is within the credit limit AND their due debt is zero or less.
    bool isValid = state.totalDebt! <= 0 || (state.totalDebt! < creditLimit && state.dueDebt! <= 0);
    state = state.copyWith(isValidUser: isValid);
  }

  // COMMENTED OUT: No longer needed - due debt is pre-calculated in accountant app
  // double calculateDueDebt(List<Transaction> invoices, num paymentDurationLimit, double totalDebt) { ... }

  // All debt calculations are now done in the accountant app and stored in customer_screen_data collection.
  // This eliminates the need to load and process transactions on the phone.

  @override
  void dispose() {
    // _transactionsSubscription is no longer used with ref.listen,
    // Riverpod handles listener cleanup when the notifier is disposed.
    super.dispose();
  }
}

final homeScreenStateController =
    StateNotifierProvider.autoDispose<HomeScreenNotifier, HomeScreenState>((ref) {
  return HomeScreenNotifier(ref);
});
