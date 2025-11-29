import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tablets/src/common/values/gaps.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:tablets/src/common/providers/last_access_provider.dart';
import 'package:tablets/src/common/providers/salesman_info_provider.dart';
import 'package:tablets/src/features/login/repository/accounts_repository.dart';
import 'package:tablets/src/features/customers/controllers/customer_screen_data_cache_provider.dart';
import 'package:tablets/src/features/customers/repository/customer_screen_data_repository_provider.dart';
import 'package:tablets/src/features/products/controllers/product_screen_data_cache_provider.dart';
import 'package:tablets/src/features/products/repository/product_screen_data_repository_provider.dart';
import 'package:tablets/src/features/transactions/controllers/customer_db_cache_provider.dart';
import 'package:tablets/src/features/transactions/controllers/pending_transaction_db_cache_provider.dart';
import 'package:tablets/src/features/transactions/controllers/products_db_cache_provider.dart';
import 'package:tablets/src/features/transactions/repository/customer_repository_provider.dart';
import 'package:tablets/src/features/transactions/repository/pending_transaction_repository_provider.dart';
import 'package:tablets/src/features/transactions/repository/products_repository_provider.dart';
// Commented out - transactions no longer loaded in bulk
// import 'package:tablets/src/features/transactions/controllers/transaction_db_cache_provider.dart';
// import 'package:tablets/src/features/transactions/repository/transactions_repository_provider.dart';

// Create a provider for the LoadingNotifier

final dataLoadingController = StateNotifierProvider<LoadingNotifier, bool>((ref) {
  return LoadingNotifier(ref); // Pass the ref to the LoadingNotifier
});

class LoadingNotifier extends StateNotifier<bool> {
  LoadingNotifier(this._ref) : super(false); // Initial state is not loading

  final Ref _ref;

  void startLoading() {
    state = true; // Set loading to true
  }

  void stopLoading() {
    state = false; // Set loading to false
  }

  // we only set customers once a day, in case there is update, user can press refresh to synch data with
  // fire store (the loadFreshData = true in this case)
  Future<void> loadCustomers({bool loadFreshData = false}) async {
    final salesmanInfoNotifier = _ref.read(salesmanInfoProvider.notifier);
    String? salesmanDbRef = salesmanInfoNotifier.data.dbRef;
    // don't load customers unless salesman info is loaded, because it will load all customers not his customers only
    if (salesmanDbRef == null) {
      return;
    }
    final lastAccessNotifier = _ref.read(lastAccessProvider.notifier);
    final customersRepository = _ref.read(customerRepositoryProvider);
    final customerDbCache = _ref.read(customerDbCacheProvider.notifier);
    startLoading();
    if (customerDbCache.data.isEmpty || lastAccessNotifier.hasOneDayPassed() || loadFreshData) {
      final customers = await customersRepository.fetchItemListAsMaps(
          filterKey: 'salesmanDbRef', filterValue: salesmanDbRef);
      customerDbCache.set(customers);
      lastAccessNotifier.setLastAccessDate();
    }
    stopLoading();
  }

  Future<void> loadCustomerScreenData() async {
    final repository = _ref.read(customerScreenDataRepositoryProvider);
    final cache = _ref.read(customerScreenDataCacheProvider.notifier);
    startLoading();
    final data = await repository.fetchItemListAsMaps();
    cache.set(data);
    stopLoading();
  }

  Future<void> loadPendingTransactions() async {
    _ref.read(dataLoadingController.notifier).startLoading();
    final pendingTransactions =
        await _ref.read(pendingTransactionRepositoryProvider).fetchItemListAsMaps();
    _ref.read(pendingTransactionsDbCache.notifier).set(pendingTransactions);
    _ref.read(dataLoadingController.notifier).stopLoading();
  }

  Future<void> loadSalesmanInfo() async {
    final accountsRepository = _ref.read(accountsRepositoryProvider);
    final email = FirebaseAuth.instance.currentUser!.email;
    final accounts = await accountsRepository.fetchItemListAsMaps();
    final salesmanInfoNotifier = _ref.read(salesmanInfoProvider.notifier);
    var matchingAccounts = accounts.where((account) => account['email'] == email);
    if (matchingAccounts.isNotEmpty) {
      final dbRef = matchingAccounts.first['dbRef'];
      salesmanInfoNotifier.setDbRef(dbRef);
      final name = matchingAccounts.first['name'];
      salesmanInfoNotifier.setName(name);
      final email = matchingAccounts.first['email'];
      salesmanInfoNotifier.setEmail(email);
      final privilage = matchingAccounts.first['privilage'];
      salesmanInfoNotifier.setPrivilage(privilage);
    }
  }

// Products are loaded lazily (only when user navigates to items screen)
// This optimizes startup time - customers and customer_screen_data are loaded first
  Future<void> loadProducts() async {
    final productsRepository = _ref.read(productsRepositoryProvider);
    final productDbCache = _ref.read(productsDbCacheProvider.notifier);
    startLoading();
    final products = await productsRepository.fetchItemListAsMaps();
    productDbCache.set(products);
    stopLoading();
  }

  Future<void> loadProductScreenData() async {
    final repository = _ref.read(productScreenDataRepositoryProvider);
    final cache = _ref.read(productScreenDataCacheProvider.notifier);
    startLoading();
    final data = await repository.fetchItemListAsMaps();
    cache.set(data);
    stopLoading();
  }

// COMMENTED OUT: Transactions are no longer loaded in the phone app
// All calculations are now done in the accountant app and stored in:
// - customer_screen_data (debt info)
// - product_screen_data (stock info)
// This eliminates the need to load 10,000+ transactions, dramatically reducing memory usage
  // Future<void> loadTransactions({bool loadFreshData = false}) async {
  //   if (_ref.read(transactionDbCacheProvider).isEmpty ||
  //       _ref.read(lastAccessProvider.notifier).hasOneDayPassed() ||
  //       loadFreshData) {
  //     final transactions = await _ref.read(transactionRepositoryProvider).fetchItemListAsMaps();
  //     _ref.read(transactionDbCacheProvider.notifier).set(transactions);
  //     _ref.read(lastAccessProvider.notifier).setLastAccessDate();
  //   }
  //   stopLoading();
  // }
}

// LoadingWrapper widget with a dark background and spinner
class LoadingWrapper extends ConsumerWidget {
  final Widget child;

  const LoadingWrapper({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoading = ref.watch(dataLoadingController);

    return Stack(
      children: [
        child, // The main content
        if (isLoading) ...[
          // Dark background with opacity
          Container(
            padding: const EdgeInsets.all(0),
            color: Colors.black54, // Semi-transparent black
          ),
          const Center(
            child: LoadingSpinner(
              text: 'جاري تحميل البيانات',
            ),
          ),
        ],
      ],
    );
  }
}

class LoadingSpinner extends StatelessWidget {
  const LoadingSpinner({this.text, super.key, this.fontColor = Colors.white});
  final String? text;
  final Color fontColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const CircularProgressIndicator(color: Colors.white),
        if (text != null) ...[
          VerticalGap.xl,
          Text(
            text!,
            style: TextStyle(color: fontColor, fontSize: 14),
          ),
        ]
      ],
    );
  }
}
