import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tablets/src/common/classes/db_cache.dart';

final pendingTransactionsDbCache =
    StateNotifierProvider<DbCache, List<Map<String, dynamic>>>((ref) {
  return DbCache();
});
