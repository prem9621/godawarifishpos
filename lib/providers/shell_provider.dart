import 'package:flutter/material.dart';

/// Drives bottom navigation (Vyapar-style shell).
class ShellProvider extends ChangeNotifier {
  int _index = 1;
  int _homeRefreshNonce = 0;

  int get currentIndex => _index;

  /// Increment so [VyaparHomeScreen] can reload after returning from new sale, etc.
  int get homeRefreshNonce => _homeRefreshNonce;

  void bumpHomeRefresh() {
    _homeRefreshNonce++;
    notifyListeners();
  }

  void setIndex(int i) {
    if (i < 0 || i > 4 || i == _index) return;
    _index = i;
    notifyListeners();
  }
}
