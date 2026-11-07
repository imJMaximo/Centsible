/// Evaluates the entry form's keypad expression, e.g. "1250+420.50" or
/// "3×450-25". Honors × ÷ before + −. A trailing operator is ignored.
/// Returns minor units, or null when the expression is incomplete/invalid.
int? evaluateAmount(String source) {
  final cleaned = source.replaceAll(',', '').replaceAll('*', '×').replaceAll('/', '÷');
  final tokens = RegExp(r'\d*\.?\d+|[+\-×÷]').allMatches(cleaned).map((m) => m.group(0)!).toList();
  if (tokens.isEmpty) return null;
  if (_isOp(tokens.last)) tokens.removeLast();
  if (tokens.isEmpty) return null;

  final nums = <double>[];
  final ops = <String>[];
  var expectNum = true;
  for (final t in tokens) {
    if (_isOp(t)) {
      if (expectNum) return null;
      ops.add(t);
      expectNum = true;
    } else {
      if (!expectNum) return null;
      nums.add(double.parse(t));
      expectNum = false;
    }
  }

  // First pass: × and ÷.
  final terms = <double>[nums.first];
  final addOps = <String>[];
  for (var i = 0; i < ops.length; i++) {
    final b = nums[i + 1];
    switch (ops[i]) {
      case '×':
        terms.add(terms.removeLast() * b);
      case '÷':
        if (b == 0) return null;
        terms.add(terms.removeLast() / b);
      default:
        addOps.add(ops[i]);
        terms.add(b);
    }
  }
  // Second pass: + and −.
  var result = terms.first;
  for (var i = 0; i < addOps.length; i++) {
    result = addOps[i] == '+' ? result + terms[i + 1] : result - terms[i + 1];
  }
  return (result * 100).round();
}

bool hasOperator(String s) => RegExp(r'[+\-×÷*/]').hasMatch(s);

bool _isOp(String t) => t == '+' || t == '-' || t == '×' || t == '÷';
