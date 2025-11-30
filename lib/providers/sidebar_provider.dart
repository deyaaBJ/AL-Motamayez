// providers/sidebar_provider.dart
import 'package:flutter/material.dart';

class SideBarProvider with ChangeNotifier {
  bool _isSideBarOpen = false;

  bool get isSideBarOpen => _isSideBarOpen;

  void toggleSideBar() {
    _isSideBarOpen = !_isSideBarOpen;
    notifyListeners();
  }

  void closeSideBar() {
    _isSideBarOpen = false;
    notifyListeners();
  }

  void openSideBar() {
    _isSideBarOpen = true;
    notifyListeners();
  }
}
