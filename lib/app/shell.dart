import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'router.dart';
import 'theme.dart';

/// Bottom navigation with the raised "add entry" button in the middle.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.shell});
  final StatefulNavigationShell shell;

  static const _tabs = [
    (Icons.space_dashboard_outlined, Icons.space_dashboard, 'Home'),
    (Icons.format_list_bulleted, Icons.format_list_bulleted, 'Entries'),
    (Icons.account_balance_wallet_outlined, Icons.account_balance_wallet, 'Wallets'),
    (Icons.person_outline, Icons.person, 'Account'),
  ];

  @override
  Widget build(BuildContext context) {
    Widget tab(int i) {
      final (icon, activeIcon, label) = _tabs[i];
      final on = shell.currentIndex == i;
      final color = on ? context.scheme.primary : context.colors.muted;
      return Expanded(
        child: Semantics(
          selected: on,
          button: true,
          label: label,
          excludeSemantics: true,
          child: InkWell(
            onTap: () => shell.goBranch(i, initialLocation: i == shell.currentIndex),
            child: SizedBox(
              height: 64,
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 56,
                  height: 30,
                  decoration: BoxDecoration(
                    color: on ? context.colors.selectedBg : Colors.transparent,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Icon(on ? activeIcon : icon, size: 22, color: color),
                ),
                const SizedBox(height: 4),
                Text(label,
                    style: context.text.labelSmall
                        ?.copyWith(color: color, fontWeight: on ? FontWeight.w800 : FontWeight.w600)),
              ]),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      body: shell,
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          color: context.scheme.surface,
          border: Border(top: BorderSide(color: context.scheme.outlineVariant)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: SizedBox(height: 64, child: Row(children: [
              tab(0),
              tab(1),
              Expanded(
                child: Center(
                  child: Tooltip(
                    message: 'Add entry',
                    child: Material(
                      color: Brand.primary,
                      elevation: 6,
                      shadowColor: Brand.primary.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(20),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () => context.push(Routes.newEntry),
                        child: const SizedBox(
                          width: 58,
                          height: 58,
                          child: Icon(Icons.add, color: Colors.white, size: 28, semanticLabel: 'Add entry'),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              tab(2),
              tab(3),
            ])),
          ),
        ),
      ),
    );
  }
}
