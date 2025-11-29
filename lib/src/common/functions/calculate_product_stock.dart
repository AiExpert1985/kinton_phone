import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tablets/src/features/products/controllers/product_screen_data_cache_provider.dart';

double calculateProductStock(WidgetRef ref, String productDbRef) {
  final productScreenDataCache = ref.read(productScreenDataCacheProvider.notifier);
  try {
    final productData = productScreenDataCache.getItemByProperty('productDbRef', productDbRef);
    return productData['quantity']?.toDouble() ?? 0.0;
  } catch (e) {
    return 0.0;
  }
}
