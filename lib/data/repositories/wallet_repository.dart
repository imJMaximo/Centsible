import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../mock/mock_seed.dart';
import '../models/wallet.dart';

class WalletRepository extends Notifier<List<Wallet>> {
  var _seq = 0;

  @override
  List<Wallet> build() => List.of(MockSeed.wallets);

  Wallet? byId(String? id) => id == null ? null : state.where((w) => w.id == id).firstOrNull;

  String add({required String bookId, required String name, required WalletType type, required String currency, int opening = 0}) {
    final id = 'w-new-${++_seq}';
    state = [
      ...state,
      Wallet(id: id, bookId: bookId, name: name, type: type, currency: currency, openingBalance: opening,
          statementBalance: type == WalletType.card ? opening : 0),
    ];
    return id;
  }

  void update(Wallet w) => state = [for (final x in state) x.id == w.id ? w : x];
}

final walletRepositoryProvider = NotifierProvider<WalletRepository, List<Wallet>>(WalletRepository.new);
