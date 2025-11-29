import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tablets/src/features/products/controllers/product_stock_cache_provider.dart';

double calculateProductStock(WidgetRef ref, String productDbRef) {
  final stockCache = ref.read(productStockCacheProvider.notifier);
  try {
    final stockData = stockCache.getItemByProperty('productDbRef', productDbRef);
    return stockData['stock']?.toDouble() ?? 0.0;
  } catch (e) {
    // Return 0 if stock data not found
    return 0.0;
  }
}
