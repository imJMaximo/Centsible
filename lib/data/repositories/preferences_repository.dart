import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class Preferences {
  const Preferences({this.themeMode = ThemeMode.system, this.appLock = true, this.lastSync = 'just now'});
  final ThemeMode themeMode;
  final bool appLock;
  final String lastSync;

  Preferences copyWith({ThemeMode? themeMode, bool? appLock, String? lastSync}) => Preferences(
        themeMode: themeMode ?? this.themeMode,
        appLock: appLock ?? this.appLock,
        lastSync: lastSync ?? this.lastSync,
      );
}

/// Device-local settings (shared_preferences / secure storage later).
class PreferencesRepository extends Notifier<Preferences> {
  @override
  Preferences build() => const Preferences();

  void setTheme(ThemeMode m) => state = state.copyWith(themeMode: m);
  void setAppLock(bool v) => state = state.copyWith(appLock: v);
  void markSynced() => state = state.copyWith(lastSync: 'just now');
}

final preferencesProvider = NotifierProvider<PreferencesRepository, Preferences>(PreferencesRepository.new);
