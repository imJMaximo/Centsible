import 'package:centsible/core/money.dart';
import 'package:centsible/data/mock/mock_seed.dart';
import 'package:centsible/domain/cash_calculator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final calc = CashCalculator(entries: MockSeed.entries(), wallets: MockSeed.wallets);
  final today = MockSeed.today;

  test('MTD reproduces the plan worked example', () {
    final s = calc.summarize(bookId: MockSeed.household, currency: 'PHP', range: DateRange.mtd(today));
    expect(s.opening, minor(48250));
    expect(s.income, minor(62000));
    expect(s.expenses, minor(18430.50));
    expect(s.closing, minor(91819.50));
    expect(s.net, minor(43569.50));
    expect(s.receivable, minor(15000));
    expect(s.payable, minor(6800));
  });

  test('YTD opens at ₱20,000 and closes at the same figure as MTD', () {
    final s = calc.summarize(bookId: MockSeed.household, currency: 'PHP', range: DateRange.ytd(today));
    expect(s.opening, minor(20000));
    expect(s.closing, minor(91819.50));
  });

  test('asset wallet balances add up to closing cash; card debt is separate', () {
    int bal(String id) => calc.walletBalance(MockSeed.wallets.firstWhere((w) => w.id == id));
    expect(bal(MockSeed.wCash), minor(4820.50));
    expect(bal(MockSeed.wBpi), minor(79349));
    expect(bal(MockSeed.wGcash), minor(7650));
    expect(bal(MockSeed.wCard), minor(12480));
  });

  test('USD is never mixed into PHP', () {
    final s = calc.summarize(bookId: MockSeed.household, currency: 'USD', range: DateRange.mtd(today));
    expect(s.opening, minor(1240));
    expect(s.income, minor(450));
    expect(s.expenses, minor(89.99));
    expect(s.receivable, minor(300));
  });
}
